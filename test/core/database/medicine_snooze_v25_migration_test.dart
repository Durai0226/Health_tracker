// See vitals_v13_migration_test.dart for why the raw-SQLite fixture is written
// with integer DateTimes: drift's default encoding is unix seconds.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tablet_remainder/core/database/app_database.dart';

/// v24 → current on a database that already holds a medicine.
///
/// v25 adds one optional column: how long a medicine's Snooze waits. The risks
/// are the ADD COLUMN ones — what is there must come through untouched with
/// nothing invented (a medicine must not start snoozing for a length it never
/// chose), and a database that ALREADY has the column must still open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sec = DateTime(2026, 2, 1, 21).millisecondsSinceEpoch ~/ 1000;

  void seed(sqlite.Database raw, {bool withColumn = false}) {
    raw.execute('''
      CREATE TABLE enhanced_medicines (
        id TEXT NOT NULL, name TEXT NOT NULL, dosage_form INTEGER NOT NULL,
        start_date INTEGER NOT NULL, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL, schedule_json TEXT NOT NULL,
        reminder_sound TEXT NULL
        ${withColumn ? ', snooze_override_minutes INTEGER NULL' : ''},
        PRIMARY KEY (id));
    ''');
    raw.execute('''
      INSERT INTO enhanced_medicines
        (id, name, dosage_form, start_date, created_at, updated_at, schedule_json,
         reminder_sound)
      VALUES ('m-old', 'Metformin', 0, $sec, $sec, $sec, '{}', 'marimba');
    ''');
    raw.execute('PRAGMA user_version = 24');
  }

  Future<Set<String>> columns(AppDatabase db) async =>
      (await db.customSelect("PRAGMA table_info('enhanced_medicines')").get())
          .map((r) => r.read<String>('name'))
          .toSet();

  group('from a v24 database', () {
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
      expect(db.schemaVersion, greaterThanOrEqualTo(25));
    });

    test('the table has the column, and the medicine keeps following the setting',
        () async {
      expect(await columns(db), contains('snooze_override_minutes'));
      final med = await db
          .customSelect(
              'SELECT name, reminder_sound, snooze_override_minutes '
              'FROM enhanced_medicines')
          .getSingle();
      expect(med.read<String>('name'), 'Metformin');
      expect(med.read<String>('reminder_sound'), 'marimba',
          reason: 'what was there before comes through untouched');
      expect(med.data['snooze_override_minutes'], isNull,
          reason: 'nothing may be invented for a medicine that never chose');
    });

    test('the column takes a value', () async {
      await db.customStatement(
          "UPDATE enhanced_medicines SET snooze_override_minutes = 15 WHERE id = 'm-old'");
      final med = await db
          .customSelect('SELECT snooze_override_minutes FROM enhanced_medicines')
          .getSingle();
      expect(med.read<int>('snooze_override_minutes'), 15);
    });
  });

  test('a database that ALREADY has the column still opens', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => seed(raw, withColumn: true), logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
    expect(await columns(db), contains('snooze_override_minutes'));
  });

  test('a database with no medicines table opens', () async {
    // Older fixtures never created it; the step must not fail on them.
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 24'),
        logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
  });
}
