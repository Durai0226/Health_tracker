// See vitals_v13_migration_test.dart for why the raw-SQLite fixture is written
// with integer DateTimes: drift's default encoding is unix seconds.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tablet_remainder/core/database/app_database.dart';

/// v25 → current on a database that already holds a reminder.
///
/// v26 adds one optional column: how many steps tick a reminder off by itself.
/// What is there must come through untouched with nothing invented (a reminder
/// must not start ticking itself off), and a database that ALREADY has the
/// column must still open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sec = DateTime(2026, 2, 1, 21).millisecondsSinceEpoch ~/ 1000;

  void seed(sqlite.Database raw, {bool withColumn = false}) {
    raw.execute('''
      CREATE TABLE reminders (
        id TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
        scheduled_time INTEGER NOT NULL, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
        ${withColumn ? ', auto_complete_steps INTEGER NULL' : ''},
        PRIMARY KEY (id));
    ''');
    raw.execute('''
      INSERT INTO reminders (id, title, body, scheduled_time, created_at, updated_at)
      VALUES ('r-old', 'Walk', '', $sec, $sec, $sec);
    ''');
    raw.execute('PRAGMA user_version = 25');
  }

  Future<Set<String>> columns(AppDatabase db) async =>
      (await db.customSelect("PRAGMA table_info('reminders')").get())
          .map((r) => r.read<String>('name'))
          .toSet();

  group('from a v25 database', () {
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
      expect(db.schemaVersion, greaterThanOrEqualTo(26));
    });

    test('the table has the column, and the reminder ticks nothing off itself',
        () async {
      expect(await columns(db), contains('auto_complete_steps'));
      final r = await db
          .customSelect('SELECT title, auto_complete_steps FROM reminders')
          .getSingle();
      expect(r.read<String>('title'), 'Walk');
      expect(r.data['auto_complete_steps'], isNull,
          reason: 'nothing may be invented for a reminder that never chose');
    });

    test('the column takes a value', () async {
      await db.customStatement(
          "UPDATE reminders SET auto_complete_steps = 5000 WHERE id = 'r-old'");
      final r = await db
          .customSelect('SELECT auto_complete_steps FROM reminders')
          .getSingle();
      expect(r.read<int>('auto_complete_steps'), 5000);
    });
  });

  test('a database that ALREADY has the column still opens', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => seed(raw, withColumn: true), logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
    expect(await columns(db), contains('auto_complete_steps'));
  });

  test('a database with no reminders table opens', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 25'),
        logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
  });
}
