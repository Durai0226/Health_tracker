// See vitals_v13_migration_test.dart for why the raw-SQLite fixture is written
// with integer DateTimes: drift's default encoding is unix seconds, and for why
// only `Value` is taken from drift (its column expressions collide with matcher).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tablet_remainder/core/database/app_database.dart';

/// v21 → current on a database that already holds diary entries.
///
/// v22 gives a diary entry an optional mood (`mood_index`) and tags
/// (`tags_json`). The risks are the usual ones for an ADD COLUMN migration: an
/// existing entry must come through untouched, with no mood and no tags (an
/// upgrade must not invent a feeling), and a database that ALREADY has the
/// columns — the `createAll()` calls in older steps leave some upgrade paths
/// that way — must still open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final entryAt = DateTime(2026, 2, 1, 21);
  final entrySec = entryAt.millisecondsSinceEpoch ~/ 1000;

  /// The v21 shape of `diary_entries`.
  String v21Table({bool withNewColumns = false}) => '''
      CREATE TABLE diary_entries (
        id TEXT NOT NULL,
        dependent_id TEXT NULL,
        title TEXT NULL,
        body TEXT NOT NULL,
        entry_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
        ${withNewColumns ? ', mood_index INTEGER NULL, tags_json TEXT NULL' : ''},
        PRIMARY KEY (id));
  ''';

  void seed(sqlite.Database raw, {bool withNewColumns = false}) {
    raw.execute(v21Table(withNewColumns: withNewColumns));
    raw.execute('''
      INSERT INTO diary_entries (id, title, body, entry_at, created_at)
      VALUES ('d-old', 'A long day', 'Walked home in the rain.',
              $entrySec, $entrySec);
    ''');
    raw.execute('PRAGMA user_version = 21');
  }

  group('from a v21 database', () {
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

    test('the existing entry survives intact', () async {
      final all = await db.diaryDao.getAll();
      expect(all, hasLength(1));
      expect(all.single.title, 'A long day');
      expect(all.single.body, 'Walked home in the rain.');
      expect(all.single.entryAt, entryAt);
    });

    test('and it has no mood and no tags: an upgrade invents neither', () async {
      final e = (await db.diaryDao.getAll()).single;
      expect(e.moodIndex, isNull);
      expect(e.tagsJson, isNull);
    });

    test('a new entry can carry both', () async {
      await db.diaryDao.upsert(DiaryEntriesCompanion.insert(
        id: 'd-new',
        body: 'Better.',
        entryAt: entryAt,
        createdAt: entryAt,
      ).copyWith(
        moodIndex: const Value(1),
        tagsJson: const Value('["walk"]'),
      ));
      final e = (await db.diaryDao.getAll()).firstWhere((x) => x.id == 'd-new');
      expect(e.moodIndex, 1);
      expect(e.tagsJson, '["walk"]');
    });
  });

  test('a database that ALREADY has the columns still opens', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => seed(raw, withNewColumns: true), logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
    expect((await db.diaryDao.getAll()).single.id, 'd-old');
  });

  test('a database with no diary table at all gets one, with the columns',
      () async {
    // The older fixtures in this folder (v12, v19) never created it. The step
    // must not fail on them — and a table that is missing is better made than
    // left for the first diary read to trip over.
    final db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 21'),
        logStatements: false));
    addTearDown(() async => db.close());

    await db.customSelect('SELECT 1').get();
    final cols = await db.customSelect("PRAGMA table_info('diary_entries')").get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['mood_index', 'tags_json']));
  });
}
