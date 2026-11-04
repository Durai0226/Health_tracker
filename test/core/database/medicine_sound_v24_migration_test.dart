// See vitals_v13_migration_test.dart for why the raw-SQLite fixture is written
// with integer DateTimes: drift's default encoding is unix seconds.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tablet_remainder/core/database/app_database.dart';

/// v23 → current on a database that already holds a medicine.
///
/// v24 adds one optional column: which bundled sound a medicine's reminder rings
/// with. The risks are the ADD COLUMN ones — what is there must come through
/// untouched with nothing invented (a medicine must not start ringing a sound it
/// never chose), and a database that ALREADY has the column must still open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sec = DateTime(2026, 2, 1, 21).millisecondsSinceEpoch ~/ 1000;

  void seed(sqlite.Database raw, {bool withColumn = false}) {
    raw.execute('''
      CREATE TABLE enhanced_medicines (
        id TEXT NOT NULL, name TEXT NOT NULL, dosage_form INTEGER NOT NULL,
        start_date INTEGER NOT NULL, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL, schedule_json TEXT NOT NULL,
        cost_per_unit REAL NULL
        ${withColumn ? ', reminder_sound TEXT NULL' : ''},
        PRIMARY KEY (id));
    ''');
    raw.execute('''
      INSERT INTO enhanced_medicines
        (id, name, dosage_form, start_date, created_at, updated_at, schedule_json)
      VALUES ('m-old', 'Metformin', 0, $sec, $sec, $sec, '{}');
    ''');
    raw.execute('PRAGMA user_version = 23');
  }

  Future<Set<String>> columns(AppDatabase db) async =>
      (await db.customSelect("PRAGMA table_info('enhanced_medicines')").get())
          .map((r) => r.read<String>('name'))
          .toSet();

  group('from a v23 database', () {
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
      expect(db.schemaVersion, greaterThanOrEqualTo(24));
    });

    test('the table has the column, and the medicine keeps the standard sound',
        () async {
      expect(await columns(db), contains('reminder_sound'));
      final med = await db
          .customSelect('SELECT name, reminder_sound FROM enhanced_medicines')
          .getSingle();
      expect(med.read<String>('name'), 'Metformin');
      expect(med.data['reminder_sound'], isNull,
          reason: 'nothing may be invented for a medicine that never chose');
    });

    test('the column takes a value', () async {
      await db.customStatement(
          "UPDATE enhanced_medicines SET reminder_sound = 'marimba' WHERE id = 'm-old'");
      final med = await db
          .customSelect('SELECT reminder_sound FROM enhanced_medicines')
          .getSingle();
      expect(med.read<String>('reminder_sound'), 'marimba');
    });
  });

  test('a database that ALREADY has the column still opens', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => seed(raw, withColumn: true), logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
    expect(await columns(db), contains('reminder_sound'));
  });

  test('a database with no medicines table opens', () async {
    // Older fixtures never created it; the step must not fail on them.
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 23'),
        logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
  });
}
