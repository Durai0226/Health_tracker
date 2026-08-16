// NOT `package:drift/drift.dart`: its `isNull`/`isNotNull` column expressions
// collide with matcher's, and nothing here needs the query builder.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tablet_remainder/core/database/app_database.dart';

/// v12 → v13 on a database that already holds readings.
///
/// Every other DB test builds a fresh database, so `onCreate` runs and
/// `onUpgrade` never does — the migration path had **no coverage at all**. The
/// v13 step is the riskiest statement in the schema's history: it cannot use
/// `addColumn` (SQLite rejects ADD COLUMN NOT NULL without a constant default,
/// and CURRENT_TIMESTAMP is explicitly disallowed), so it RECREATES all four
/// vitals tables and copies the rows across. That is real blood-pressure and
/// glucose history moving through a rebuild.
///
/// Drift stores DateTime as INTEGER unix seconds by default — no
/// `storeDateTimeAsText` is configured — which is why the fixtures below write
/// integers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Seconds since epoch, matching drift's default DateTime encoding. Local,
  // not UTC: drift decodes the stored integer back into a LOCAL DateTime, so
  // UTC fixtures would fail the round-trip by the machine's offset.
  final takenAt = DateTime(2026, 2, 1, 8);
  final createdAt = DateTime(2026, 2, 1, 9);
  final takenSec = takenAt.millisecondsSinceEpoch ~/ 1000;
  final createdSec = createdAt.millisecondsSinceEpoch ~/ 1000;

  /// The v12 shape of the four vitals tables: `created_at` + `synced` only
  /// (mood not even `synced`), and no `updated_at` / `deleted_at` /
  /// `schema_ver` / `data_json`.
  void seedV12(sqlite.Database raw) {
    raw.execute('''
      CREATE TABLE blood_pressure_readings (
        id TEXT NOT NULL,
        dependent_id TEXT NULL,
        systolic INTEGER NOT NULL,
        diastolic INTEGER NOT NULL,
        pulse INTEGER NULL,
        arm_index INTEGER NULL,
        position_index INTEGER NULL,
        taken_at INTEGER NOT NULL,
        tags_json TEXT NULL,
        note TEXT NULL,
        category_index INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id));
      CREATE TABLE glucose_readings (
        id TEXT NOT NULL,
        dependent_id TEXT NULL,
        value_mgdl INTEGER NOT NULL,
        context_index INTEGER NOT NULL DEFAULT 4,
        taken_at INTEGER NOT NULL,
        carbs INTEGER NULL,
        insulin_units REAL NULL,
        med_note TEXT NULL,
        tags_json TEXT NULL,
        note TEXT NULL,
        class_index INTEGER NOT NULL DEFAULT 2,
        created_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id));
      CREATE TABLE weight_readings (
        id TEXT NOT NULL,
        dependent_id TEXT NULL,
        value_kg REAL NOT NULL,
        taken_at INTEGER NOT NULL,
        tags_json TEXT NULL,
        note TEXT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id));
      CREATE TABLE mood_entries (
        id TEXT NOT NULL,
        dependent_id TEXT NULL,
        mood_index INTEGER NOT NULL,
        taken_at INTEGER NOT NULL,
        tags_json TEXT NULL,
        note TEXT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (id));
    ''');

    raw.execute(
      'INSERT INTO blood_pressure_readings '
      '(id, systolic, diastolic, pulse, taken_at, note, category_index, created_at, synced) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      ['bp-old', 142, 91, 78, takenSec, 'after a walk', 2, createdSec, 1],
    );
    raw.execute(
      'INSERT INTO glucose_readings '
      '(id, value_mgdl, context_index, taken_at, carbs, created_at, synced) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['g-old', 112, 1, takenSec, 40, createdSec, 0],
    );
    raw.execute(
      'INSERT INTO weight_readings (id, value_kg, taken_at, created_at, synced) '
      'VALUES (?, ?, ?, ?, ?)',
      ['w-old', 71.25, takenSec, createdSec, 1],
    );
    raw.execute(
      'INSERT INTO mood_entries (id, mood_index, taken_at, created_at) '
      'VALUES (?, ?, ?, ?)',
      ['m-old', 3, takenSec, createdSec],
    );

    // What makes drift run onUpgrade(12, 13) rather than onCreate.
    raw.execute('PRAGMA user_version = 12');
  }

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: seedV12, logStatements: false));
    // Migrations are lazy — the first query is what triggers them.
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async => db.close());

  test('the migration actually ran', () async {
    final row =
        await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, 13);
  });

  test('existing readings survive the table rebuild intact', () async {
    final bp = await db.vitalsDao.getAllBp();
    expect(bp, hasLength(1));
    expect(bp.single.id, 'bp-old');
    expect(bp.single.systolic, 142);
    expect(bp.single.diastolic, 91);
    expect(bp.single.pulse, 78);
    expect(bp.single.note, 'after a walk');
    expect(bp.single.categoryIndex, 2);
    expect(bp.single.takenAt, takenAt);
    expect(bp.single.synced, isTrue, reason: 'synced must not be reset');

    final g = await db.vitalsDao.getAllGlucose();
    expect(g.single.valueMgdl, 112);
    expect(g.single.carbs, 40);
    expect(g.single.contextIndex, 1);

    final w = await db.vitalsDao.getAllWeight();
    expect(w.single.valueKg, 71.25);

    final m = await db.vitalsDao.getAllMood();
    expect(m.single.moodIndex, 3);
  });

  test('updatedAt is back-filled from createdAt, not from now()', () async {
    // The truthful value: nothing has been edited since it was written.
    // Stamping DateTime.now() would tell the LWW reconciler that every
    // historical reading changed at migration time, and a stale cloud copy
    // could then lose to — or beat — a row it should not have been compared to.
    for (final t in [
      (await db.vitalsDao.getAllBp()).single.updatedAt,
      (await db.vitalsDao.getAllGlucose()).single.updatedAt,
      (await db.vitalsDao.getAllWeight()).single.updatedAt,
      (await db.vitalsDao.getAllMood()).single.updatedAt,
    ]) {
      expect(t, createdAt);
    }
  });

  test('new nullable/defaulted columns land with sane values', () async {
    final bp = (await db.vitalsDao.getAllBp()).single;
    expect(bp.deletedAt, isNull, reason: 'migrated rows are not deleted');
    expect(bp.schemaVer, 1);
    expect(bp.dataJson, isNull);
    // Mood had no `synced` column at all before v13.
    expect((await db.vitalsDao.getAllMood()).single.synced, isFalse);
  });

  test('indexes dropped by the rebuild are restored', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    // Recreating a table drops its indexes; the v13 block's trailing
    // createAll() is what puts them back.
    expect(names, containsAll(<String>[
      'idx_bp_taken_at',
      'idx_glucose_taken_at',
      'idx_weight_taken_at',
      'idx_mood_taken_at',
    ]));
  });

  test('a migrated reading can still be tombstoned and undone', () async {
    await db.vitalsDao.deleteBp('bp-old');
    expect(await db.vitalsDao.getAllBp(), isEmpty);

    final withDeleted = await db.vitalsDao.getBpForRangeIncludingDeleted(
        takenAt.subtract(const Duration(days: 1)),
        takenAt.add(const Duration(days: 1)));
    expect(withDeleted.single.deletedAt, isNotNull);
  });

  test('tables created fresh by the same migration are present', () async {
    // The v13 block ends in createAll(), which must not have been skipped.
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(<String>['step_daily_data', 'sleep_sessions']));
  });
}
