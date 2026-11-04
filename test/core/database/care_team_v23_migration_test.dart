// See vitals_v13_migration_test.dart for why the raw-SQLite fixture is written
// with integer DateTimes: drift's default encoding is unix seconds.
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tablet_remainder/core/database/app_database.dart';

/// v22 → current on a database that already holds a medicine, a doctor and a diary
/// entry.
///
/// v23 adds three optional columns that held something with nowhere to put it: what
/// a medicine costs per unit, which clinic record a doctor works at, and a diary
/// entry's photo. The risks are the ADD COLUMN ones: what is there must come through
/// untouched with nothing invented in the new columns, and a database that ALREADY
/// has a column — an older step's `createAll()` leaves some paths that way — must
/// still open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final at = DateTime(2026, 2, 1, 21);
  final sec = at.millisecondsSinceEpoch ~/ 1000;

  /// Only the columns this test reads: the migration adds a column to a table that
  /// exists, and which other columns it has is not its business.
  void seed(sqlite.Database raw, {bool withNewColumns = false}) {
    raw.execute('''
      CREATE TABLE enhanced_medicines (
        id TEXT NOT NULL, name TEXT NOT NULL, dosage_form INTEGER NOT NULL,
        start_date INTEGER NOT NULL, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL, schedule_json TEXT NOT NULL
        ${withNewColumns ? ', cost_per_unit REAL NULL' : ''},
        PRIMARY KEY (id));
    ''');
    raw.execute('''
      INSERT INTO enhanced_medicines
        (id, name, dosage_form, start_date, created_at, updated_at, schedule_json)
      VALUES ('m-old', 'Metformin', 0, $sec, $sec, $sec, '{}');
    ''');
    raw.execute('''
      CREATE TABLE doctors (
        id TEXT NOT NULL, name TEXT NOT NULL, hospital TEXT NULL,
        is_primary INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
        ${withNewColumns ? ', clinic_id TEXT NULL' : ''},
        PRIMARY KEY (id));
    ''');
    raw.execute('''
      INSERT INTO doctors (id, name, hospital, created_at)
      VALUES ('d-old', 'Dr Rao', 'City Hospital', $sec);
    ''');
    raw.execute('''
      CREATE TABLE diary_entries (
        id TEXT NOT NULL, dependent_id TEXT NULL, title TEXT NULL,
        body TEXT NOT NULL, entry_at INTEGER NOT NULL, created_at INTEGER NOT NULL,
        mood_index INTEGER NULL, tags_json TEXT NULL
        ${withNewColumns ? ', photo_path TEXT NULL' : ''},
        PRIMARY KEY (id));
    ''');
    raw.execute('''
      INSERT INTO diary_entries (id, body, entry_at, created_at)
      VALUES ('e-old', 'Walked home in the rain.', $sec, $sec);
    ''');
    raw.execute('PRAGMA user_version = 22');
  }

  Future<Set<String>> columns(AppDatabase db, String table) async =>
      (await db.customSelect("PRAGMA table_info('$table')").get())
          .map((r) => r.read<String>('name'))
          .toSet();

  group('from a v22 database', () {
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
      expect(db.schemaVersion, greaterThanOrEqualTo(23));
    });

    test('each table has its new column', () async {
      expect(await columns(db, 'enhanced_medicines'), contains('cost_per_unit'));
      expect(await columns(db, 'doctors'), contains('clinic_id'));
      expect(await columns(db, 'diary_entries'), contains('photo_path'));
    });

    test('what was there survives, and nothing is invented in the new columns', () async {
      final med = await db
          .customSelect('SELECT name, cost_per_unit FROM enhanced_medicines')
          .getSingle();
      expect(med.read<String>('name'), 'Metformin');
      expect(med.data['cost_per_unit'], isNull);

      final doc = await db
          .customSelect('SELECT name, hospital, clinic_id FROM doctors')
          .getSingle();
      expect(doc.read<String>('hospital'), 'City Hospital',
          reason: 'the typed name stays what is shown');
      expect(doc.data['clinic_id'], isNull);

      final entry = await db
          .customSelect('SELECT body, photo_path FROM diary_entries')
          .getSingle();
      expect(entry.read<String>('body'), 'Walked home in the rain.');
      expect(entry.data['photo_path'], isNull);
    });

    test('the new columns take a value', () async {
      await db.customStatement(
          "UPDATE enhanced_medicines SET cost_per_unit = 2.5 WHERE id = 'm-old'");
      await db.customStatement("UPDATE doctors SET clinic_id = 'c1' WHERE id = 'd-old'");
      await db.customStatement(
          "UPDATE diary_entries SET photo_path = '/p.jpg' WHERE id = 'e-old'");
      final med = await db
          .customSelect('SELECT cost_per_unit FROM enhanced_medicines')
          .getSingle();
      expect(med.read<double>('cost_per_unit'), 2.5);
    });
  });

  test('a database that ALREADY has the columns still opens', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => seed(raw, withNewColumns: true), logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
    expect(await columns(db, 'doctors'), contains('clinic_id'));
  });

  test('a database with none of the tables gets a diary table with the column, and opens',
      () async {
    // The older fixtures in this folder never created them. The step must not fail on
    // them, and a diary table that is missing is better made than left for the first
    // read to trip over.
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 22'),
        logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    expect(await columns(db, 'diary_entries'), contains('photo_path'));
  });
}
