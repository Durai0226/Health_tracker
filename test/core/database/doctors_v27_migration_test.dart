// See vitals_v13_migration_test.dart for why the raw-SQLite fixture is written
// with integer DateTimes: drift's default encoding is unix seconds.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tablet_remainder/core/database/app_database.dart';

/// v26 → current on a database that already holds a doctor.
///
/// v27 gives a doctor an owner and a "shared with the family" flag. A doctor saved
/// before has no owner and must come through SHARED: until now every doctor showed
/// under every profile, and a migration that made them private would have hidden
/// every one of them from all but the account holder.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sec = DateTime(2026, 2, 1, 21).millisecondsSinceEpoch ~/ 1000;

  void seed(sqlite.Database raw, {bool withColumns = false}) {
    raw.execute('''
      CREATE TABLE doctors (
        id TEXT NOT NULL, name TEXT NOT NULL,
        is_primary INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
        ${withColumns ? ', dependent_id TEXT NULL, shared_with_family INTEGER NOT NULL DEFAULT 1' : ''},
        PRIMARY KEY (id));
    ''');
    raw.execute('''
      INSERT INTO doctors (id, name, created_at) VALUES ('d-old', 'Rao', $sec);
    ''');
    raw.execute('PRAGMA user_version = 26');
  }

  Future<Set<String>> columns(AppDatabase db) async =>
      (await db.customSelect("PRAGMA table_info('doctors')").get())
          .map((r) => r.read<String>('name'))
          .toSet();

  group('from a v26 database', () {
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
      expect(db.schemaVersion, greaterThanOrEqualTo(27));
    });

    test('the table has both columns', () async {
      expect(await columns(db), containsAll(['dependent_id', 'shared_with_family']));
    });

    test('the doctor already saved has no owner and stays shared', () async {
      final d = await db.select(db.doctors).getSingle();
      expect(d.name, 'Rao');
      expect(d.dependentId, isNull);
      expect(d.sharedWithFamily, isTrue,
          reason: 'every doctor showed to every profile before; none may vanish');
    });

    test('the columns take values', () async {
      await db.customStatement(
          "UPDATE doctors SET dependent_id = 'dep-a', shared_with_family = 0");
      final d = await db.select(db.doctors).getSingle();
      expect((d.dependentId, d.sharedWithFamily), ('dep-a', false));
    });
  });

  test('a database that ALREADY has the columns still opens', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => seed(raw, withColumns: true), logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
    expect(await columns(db), containsAll(['dependent_id', 'shared_with_family']));
  });

  test('a database with no doctors table opens', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 26'),
        logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
  });
}
