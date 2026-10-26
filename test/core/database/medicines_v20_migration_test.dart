// See vitals_v13_migration_test.dart for why the raw-SQLite fixture is written
// with integer DateTimes: drift's default encoding is unix seconds.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tablet_remainder/core/database/app_database.dart';

/// v19 → current on a database that already holds medicines.
///
/// v20 adds `enhanced_medicines.reminder_enabled` (so the per-medicine
/// Reminders toggle can finally persist — before this there was no column and
/// the constructor default `true` came back on every read, re-arming alarms the
/// user had switched off) and `deleted_at` (so a medicine deletion can
/// propagate through LWW cloud sync instead of being re-downloaded).
///
/// The risk being covered: `addColumn` on a column that already exists is a
/// hard error that would strand the user on an unopenable database. Some
/// upgrade paths already have these columns because the v12/v13 steps call
/// `createAll()`, which is why the migration guards with PRAGMA table_info —
/// and why this test also runs the "already has the column" case.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final createdAt = DateTime(2026, 2, 1, 9);
  final startDate = DateTime(2026, 2, 1);
  final createdSec = createdAt.millisecondsSinceEpoch ~/ 1000;
  final startSec = startDate.millisecondsSinceEpoch ~/ 1000;

  /// The v19 shape: everything except `reminder_enabled` and `deleted_at`.
  String v19Table({bool withNewColumns = false}) => '''
      CREATE TABLE enhanced_medicines (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        generic_name TEXT NULL,
        brand_name TEXT NULL,
        dosage_form INTEGER NOT NULL,
        route_index INTEGER NULL,
        strength REAL NOT NULL DEFAULT 1.0,
        strength_unit TEXT NOT NULL DEFAULT 'mg',
        strength_text TEXT NULL,
        instructions TEXT NULL,
        purpose TEXT NULL,
        side_effects_json TEXT NULL,
        warnings_json TEXT NULL,
        color_index INTEGER NOT NULL DEFAULT 0,
        shape_index INTEGER NOT NULL DEFAULT 0,
        image_path TEXT NULL,
        doctor_id TEXT NULL,
        pharmacy_id TEXT NULL,
        dependent_id TEXT NULL,
        treatment_id TEXT NULL,
        start_date INTEGER NOT NULL,
        end_date INTEGER NULL,
        current_stock INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold INTEGER NOT NULL DEFAULT 7,
        refill_reminder INTEGER NOT NULL DEFAULT 1,
        expiry_date INTEGER NULL,
        prescription_number TEXT NULL,
        notes TEXT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        schedule_json TEXT NOT NULL,
        health_categories_json TEXT NULL,
        custom_health_category TEXT NULL,
        patient_profile_id TEXT NULL,
        requires_continuous_intake INTEGER NOT NULL DEFAULT 0,
        minimum_consecutive_days INTEGER NULL,
        custom_fields_json TEXT NULL
        ${withNewColumns ? ', reminder_enabled INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER NULL' : ''},
        PRIMARY KEY (id));
  ''';

  /// The two tables whose indexes v20 adds. A real v19 database has them
  /// (reminder_occurrences arrived in v17), so the fixture must too — the
  /// migration skips an index whose table is missing, and without these the
  /// index assertions below would pass vacuously.
  const supportingTables = '''
      CREATE TABLE reminder_occurrences (
        id TEXT NOT NULL,
        reminder_id TEXT NOT NULL,
        scheduled_for INTEGER NOT NULL,
        fired_at INTEGER NULL,
        acted_at INTEGER NULL,
        PRIMARY KEY (id));
      CREATE TABLE step_manual_entries (
        id TEXT NOT NULL,
        daily_data_id TEXT NOT NULL,
        time INTEGER NOT NULL,
        steps INTEGER NOT NULL,
        note TEXT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        schema_ver INTEGER NOT NULL DEFAULT 1,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id));
  ''';

  void seed(sqlite.Database raw, {bool withNewColumns = false}) {
    raw.execute(v19Table(withNewColumns: withNewColumns));
    raw.execute(supportingTables);
    raw.execute('''
      INSERT INTO enhanced_medicines
        (id, name, dosage_form, start_date, created_at, updated_at,
         schedule_json, current_stock, notes)
      VALUES
        ('m-old', 'Metformin', 0, $startSec, $createdSec, $createdSec,
         '{"frequencyType":0,"times":[{"hour":8,"minute":0}]}', 42,
         'twice daily with food');
    ''');
    raw.execute('PRAGMA user_version = 19');
  }

  group('from a v19 database', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(
          NativeDatabase.memory(setup: seed, logStatements: false));
      await db.customSelect('SELECT 1').get(); // migrations are lazy
    });

    tearDown(() async => db.close());

    test('the migration ran all the way to the current version', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data.values.first, db.schemaVersion);
    });

    test('positive: the existing medicine survives intact', () async {
      final m = await db.medicationDao.getMedicine('m-old');
      expect(m, isNotNull);
      expect(m!.name, 'Metformin');
      expect(m.currentStock, 42);
      expect(m.notes, 'twice daily with food');
      expect(m.createdAt, createdAt);
    });

    test('positive: a pre-existing row defaults to reminders ON', () async {
      final m = await db.medicationDao.getMedicine('m-old');
      expect(m!.reminderEnabled, isTrue,
          reason: 'an upgrade must not silence reminders someone relies on');
    });

    test('positive: a pre-existing row is NOT made a must-take medicine (v21)',
        () async {
      final m = await db.medicationDao.getMedicine('m-old');
      expect(m!.criticalAlert, isFalse,
          reason: 'an upgrade must not make every existing medicine insistent');
    });

    test('positive: a pre-existing row is not tombstoned', () async {
      final m = await db.medicationDao.getMedicine('m-old');
      expect(m!.deletedAt, isNull,
          reason: 'an upgrade must not look like a deletion to the syncer');
    });

    test('the new indexes exist after the upgrade', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('idx_occ_reminder'));
      expect(names, contains('idx_occ_scheduled'));
      expect(names, contains('idx_step_manual_daily'));
    });
  });

  test('negative: a v19 database that ALREADY has the columns still opens',
      () async {
    // The `createAll()` in the v12/v13 steps means some upgrade paths arrive
    // here with the columns present. An unguarded addColumn would throw and
    // leave the app unable to open its own database.
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => seed(raw, withNewColumns: true),
        logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
    final m = await db.medicationDao.getMedicine('m-old');
    expect(m!.reminderEnabled, isTrue);
  });

  test('negative: a database that ALREADY has critical_alert still opens',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) {
          seed(raw, withNewColumns: true);
          raw.execute('ALTER TABLE enhanced_medicines '
              'ADD COLUMN critical_alert INTEGER NOT NULL DEFAULT 0');
        },
        logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final m = await db.medicationDao.getMedicine('m-old');
    expect(m!.criticalAlert, isFalse);
  });
}
