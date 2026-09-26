import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';

/// The resurrection bug that `docs/bug-hunt.md` left Outstanding.
///
/// Sleep and period deletes became tombstones, and `*IncludingDeleted` readers
/// were added with doc comments saying they are "the shape cloud sync needs" —
/// but `HealthCloudSyncService` kept calling the ORDINARY getters, which filter
/// `deletedAt IS NULL`. In `syncLwwCollection` a row missing from `local()`
/// gets `lMs = -1`, so any cloud copy wins and is written back with
/// `deletedAt: null`: the night the user deleted reappears and the tombstone is
/// gone for good. Biometrics and workouts already used the right readers, so
/// this was an inconsistency, not a design choice.
///
/// Steps had the same hole one level deeper — its deletes were hard DELETEs, so
/// there was no tombstone to see at all.
///
/// Two layers, because the defect is *which reader the syncer picked*:
///  1. behavioural — a tombstoned row is invisible to the plain getter and
///     visible to the sync getter, and a delete leaves a row behind at all;
///  2. a source guard — the syncer passes the `*IncludingDeleted` variant.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  final wake = DateTime(2026, 3, 10, 7);
  final from = DateTime(2026, 3, 1);
  final to = DateTime(2026, 3, 31);

  group('sleep', () {
    Future<void> insertNight(String id) => db.into(db.sleepSessions).insert(
          SleepSessionsCompanion.insert(
            id: id,
            dateKey: '2026-03-10',
            bedtime: DateTime(2026, 3, 9, 23),
            wakeTime: wake,
            inBedMinutes: 480,
            asleepMinutes: 450,
            createdAt: wake,
            updatedAt: wake,
          ),
        );

    test('positive: a deleted night stays visible to the syncer', () async {
      await insertNight('n1');
      await db.sleepDao.deleteSession('n1');

      final forUi = await db.sleepDao.getForRange(from, to);
      final forSync = await db.sleepDao.getForRangeIncludingDeleted(from, to);

      expect(forUi.map((r) => r.id), isNot(contains('n1')),
          reason: 'the UI must not show a deleted night');
      expect(forSync.map((r) => r.id), contains('n1'),
          reason: 'the syncer must see the tombstone, or it re-downloads the '
              'night from the cloud');
      expect(forSync.single.deletedAt, isNotNull);
    });

    test('negative: a live night is visible to both readers', () async {
      await insertNight('n2');
      expect((await db.sleepDao.getForRange(from, to)).map((r) => r.id),
          contains('n2'));
      expect(
          (await db.sleepDao.getForRangeIncludingDeleted(from, to))
              .map((r) => r.id),
          contains('n2'));
    });
  });

  group('period', () {
    Future<void> insertDay(String id, DateTime date) =>
        db.into(db.periodDays).insert(PeriodDaysCompanion.insert(
              id: id,
              date: date,
              flowIndex: const Value(2),
              createdAt: date,
              updatedAt: date,
            ));

    test('positive: a deleted day stays visible to the syncer', () async {
      final d = DateTime(2026, 3, 12);
      await insertDay('p1', d);
      await db.periodDao.deleteDay('p1');

      expect((await db.periodDao.getAllDays()).map((r) => r.id),
          isNot(contains('p1')));
      expect((await db.periodDao.getAllDaysIncludingDeleted()).map((r) => r.id),
          contains('p1'),
          reason: 'a period day cleared by the user must not be resurrected');
    });

    test('negative: a live day is visible to both readers', () async {
      await insertDay('p2', DateTime(2026, 3, 13));
      expect((await db.periodDao.getAllDays()).map((r) => r.id), contains('p2'));
    });
  });

  group('steps', () {
    Future<void> insertDay(String id, DateTime date) =>
        db.into(db.stepDailyData).insert(StepDailyDataCompanion.insert(
              id: id,
              date: date,
              createdAt: date,
              updatedAt: date,
            ));

    test('positive: deleteDay tombstones instead of removing the row',
        () async {
      final d = DateTime(2026, 3, 14);
      await insertDay('s1', d);
      await db.stepsDao.deleteDay('s1');

      final row = await db.stepsDao.getDay('s1');
      expect(row, isNotNull,
          reason: 'a hard delete leaves nothing for the sync to propagate, so '
              'the next sync downloads the day back');
      expect(row!.deletedAt, isNotNull);
      expect(row.synced, isFalse,
          reason: 'the tombstone must be re-uploaded');

      expect((await db.stepsDao.getDayRange(d, d)).map((r) => r.id),
          isNot(contains('s1')));
      expect(
          (await db.stepsDao.getDayRangeIncludingDeleted(d, d)).map((r) => r.id),
          contains('s1'));
    });

    test('negative: a live day is visible to both readers', () async {
      final d = DateTime(2026, 3, 15);
      await insertDay('s2', d);
      expect((await db.stepsDao.getDayRange(d, d)).map((r) => r.id),
          contains('s2'));
      expect(
          (await db.stepsDao.getDayRangeIncludingDeleted(d, d)).map((r) => r.id),
          contains('s2'));
    });
  });

  group('un-deletion propagates the other way', () {
    // The mirror image of the resurrection bug, and the same root cause as
    // PV-01: `insertOnConflictUpdate(dataClass)` maps null fields to
    // `Value.absent()`, and ON CONFLICT DO UPDATE writes only the columns a
    // companion sets — so a cloud row with `deletedAt: null` could not clear a
    // local tombstone. Deletions propagated; un-deletions did not.
    //
    // It bites hardest on period_days and step_days, whose ids ARE the calendar
    // date: delete 12 March here, re-log it on another device, and 12 March
    // stayed invisible on this device forever.
    test('positive: a newer cloud period day clears a local tombstone',
        () async {
      final d = DateTime(2026, 3, 12);
      await db.into(db.periodDays).insert(PeriodDaysCompanion.insert(
            id: 'p-undel',
            date: d,
            flowIndex: const Value(2),
            createdAt: d,
            updatedAt: d,
          ));
      await db.periodDao.deleteDay('p-undel');
      expect((await db.periodDao.getAllDays()).map((r) => r.id),
          isNot(contains('p-undel')));

      // What syncLwwCollection's `apply` does with a newer, live cloud copy.
      final live = (await db.periodDao.getAllDaysIncludingDeleted())
          .singleWhere((r) => r.id == 'p-undel')
          .copyWith(deletedAt: const Value(null), updatedAt: DateTime(2026, 3, 13));
      await db
          .into(db.periodDays)
          .insertOnConflictUpdate(live.toCompanion(false));

      expect((await db.periodDao.getAllDays()).map((r) => r.id),
          contains('p-undel'),
          reason: 're-logging a day on another device must bring it back here');
    });

    test('negative: a cloud tombstone still hides a live local row', () async {
      final d = DateTime(2026, 3, 20);
      await db.into(db.periodDays).insert(PeriodDaysCompanion.insert(
            id: 'p-del',
            date: d,
            flowIndex: const Value(2),
            createdAt: d,
            updatedAt: d,
          ));
      expect((await db.periodDao.getAllDays()).map((r) => r.id),
          contains('p-del'));

      final tomb = (await db.periodDao.getAllDaysIncludingDeleted())
          .singleWhere((r) => r.id == 'p-del')
          .copyWith(
              deletedAt: Value(DateTime(2026, 3, 21)),
              updatedAt: DateTime(2026, 3, 21));
      await db
          .into(db.periodDays)
          .insertOnConflictUpdate(tomb.toCompanion(false));

      expect((await db.periodDao.getAllDays()).map((r) => r.id),
          isNot(contains('p-del')),
          reason: 'a deletion made elsewhere must still reach this device');
    });
  });

  test('the syncer reads every LWW collection with tombstones included', () {
    final src = File('lib/core/services/health_cloud_sync_service.dart')
        .readAsStringSync();
    // The plain getters must not appear as a `local:` reader — that is exactly
    // the bug. Matching on the call keeps this readable if the file moves.
    for (final banned in const [
      'db.sleepDao.getForRange(from, now)',
      'db.periodDao.getAllDays()',
      'db.stepsDao.getDayRange(from, now)',
    ]) {
      expect(src.contains(banned), isFalse,
          reason: '$banned filters deletedAt, so the syncer cannot see a '
              'tombstone and will resurrect deleted rows.');
    }
    for (final required in const [
      'getForRangeIncludingDeleted',
      'getAllDaysIncludingDeleted',
      'getDayRangeIncludingDeleted',
    ]) {
      expect(src.contains(required), isTrue,
          reason: 'the syncer must read $required');
    }
  });
}
