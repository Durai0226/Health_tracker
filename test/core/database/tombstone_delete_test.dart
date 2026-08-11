import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';

/// Regression — deleting health data must stay deleted.
///
/// `SleepDao.deleteSession` and `PeriodDao.deleteDay` used to issue a hard
/// `DELETE`. `HealthCloudSyncService` reconciles by id: a row present in
/// Firestore and absent locally is read as "not downloaded yet", so the very
/// next sync wrote the night / the period day straight back. For period days
/// that also silently re-introduced a flow day into the derived cycle history,
/// corrupting the predictions.
///
/// Both tables already carry the universal sync fields (`deletedAt`,
/// `updatedAt`, `synced`), so the fix is a tombstone write — **no schema change
/// and no Drift migration**.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  final t0 = DateTime(2026, 3, 1, 8);

  Future<void> insertNight(String id, {required DateTime wake}) =>
      db.sleepDao.upsert(SleepSessionsCompanion(
        id: Value(id),
        dateKey: Value('${wake.year}-${wake.month.toString().padLeft(2, '0')}'
            '-${wake.day.toString().padLeft(2, '0')}'),
        bedtime: Value(wake.subtract(const Duration(hours: 8))),
        wakeTime: Value(wake),
        inBedMinutes: const Value(480),
        asleepMinutes: const Value(430),
        createdAt: Value(t0),
        updatedAt: Value(t0),
      ));

  Future<void> insertDay(String id, {required DateTime date, int flow = 2}) =>
      db.periodDao.upsertDay(PeriodDaysCompanion(
        id: Value(id),
        date: Value(date),
        flowIndex: Value(flow),
        createdAt: Value(t0),
        updatedAt: Value(t0),
      ));

  group('SleepDao.deleteSession', () {
    test('hides the night from every normal read', () async {
      await insertNight('n1', wake: DateTime(2026, 3, 2, 7));
      await db.sleepDao.deleteSession('n1');

      expect(await db.sleepDao.getAll(), isEmpty);
      expect(
        await db.sleepDao
            .getForRange(DateTime(2026, 3, 1), DateTime(2026, 3, 3)),
        isEmpty,
      );
      expect(await db.sleepDao.getForDateKey('2026-03-02'), isNull);
    });

    test('leaves a tombstone the cloud sync can upload', () async {
      await insertNight('n1', wake: DateTime(2026, 3, 2, 7));
      await db.sleepDao.deleteSession('n1');

      final rows = await db.sleepDao.getForRangeIncludingDeleted(
          DateTime(2026, 3, 1), DateTime(2026, 3, 3));
      expect(rows, hasLength(1));
      expect(rows.single.deletedAt, isNotNull);
      // The deletion must win last-write-wins, and re-upload.
      expect(rows.single.updatedAt.isAfter(t0), isTrue);
      expect(rows.single.synced, isFalse);
    });

    test('reports the deleted id so an import cannot resurrect it', () async {
      await insertNight('hk_2026-03-02', wake: DateTime(2026, 3, 2, 7));
      await insertNight('hk_2026-03-03', wake: DateTime(2026, 3, 3, 7));
      await db.sleepDao.deleteSession('hk_2026-03-02');

      final deleted = await db.sleepDao
          .deletedIdsInRange(DateTime(2026, 3, 1), DateTime(2026, 3, 4));
      expect(deleted, {'hk_2026-03-02'});
    });

    test('a re-import upsert does not clear the tombstone', () async {
      // Sleep rows are written with `SleepSession.toCompanion()`, which never
      // sets `deletedAt`; Drift's insertOnConflictUpdate only writes the columns
      // the companion carries, so the tombstone has to survive. (SleepService
      // additionally refuses to re-import a deleted night — this pins the
      // storage-layer half of that guarantee.)
      await insertNight('hk_2026-03-02', wake: DateTime(2026, 3, 2, 7));
      await db.sleepDao.deleteSession('hk_2026-03-02');
      await insertNight('hk_2026-03-02', wake: DateTime(2026, 3, 2, 7));

      expect(await db.sleepDao.getForDateKey('2026-03-02'), isNull);
    });
  });

  group('PeriodDao.deleteDay', () {
    test('hides the day from every normal read', () async {
      await insertDay('2026-03-02', date: DateTime(2026, 3, 2));
      await db.periodDao.deleteDay('2026-03-02');

      expect(await db.periodDao.getAllDays(), isEmpty);
      expect(
        await db.periodDao
            .getDaysForRange(DateTime(2026, 3, 1), DateTime(2026, 3, 3)),
        isEmpty,
      );
      expect(await db.periodDao.getDay('2026-03-02'), isNull);
    });

    test('leaves a tombstone the cloud sync can upload', () async {
      await insertDay('2026-03-02', date: DateTime(2026, 3, 2));
      await db.periodDao.deleteDay('2026-03-02');

      final rows = await db.periodDao.getAllDaysIncludingDeleted();
      expect(rows, hasLength(1));
      expect(rows.single.deletedAt, isNotNull);
      expect(rows.single.updatedAt.isAfter(t0), isTrue);
      expect(rows.single.synced, isFalse);
    });

    test('re-logging a deleted day brings it back (tombstone cleared)', () async {
      // Period day ids ARE the date, so a re-log collides with its own
      // tombstone. Without an explicit clear the day would stay invisible —
      // the tombstone fix must not become a new data-loss bug.
      await insertDay('2026-03-02', date: DateTime(2026, 3, 2), flow: 2);
      await db.periodDao.deleteDay('2026-03-02');
      await insertDay('2026-03-02', date: DateTime(2026, 3, 2), flow: 3);

      final days = await db.periodDao.getAllDays();
      expect(days, hasLength(1));
      expect(days.single.flowIndex, 3);
      expect(days.single.deletedAt, isNull);
    });

    test('deleting one day leaves the others alone', () async {
      await insertDay('2026-03-02', date: DateTime(2026, 3, 2));
      await insertDay('2026-03-03', date: DateTime(2026, 3, 3));
      await db.periodDao.deleteDay('2026-03-02');

      final days = await db.periodDao.getAllDays();
      expect(days.map((d) => d.id), ['2026-03-03']);
    });
  });
}
