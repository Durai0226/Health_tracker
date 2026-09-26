/// W-12 — the hydration streak and its grace "shield" must be computed over
/// the whole persisted history, not the 90-day warm cache.
///
/// `getStreakResult()` folded `_dailyWaterNotifier.value` — the window `init()`
/// pre-loads — and [StreakEngine] stops walking at the EARLIEST day it is
/// given, treating everything before that as prehistory rather than as misses.
/// A truncated day set therefore does two different kinds of damage:
///
///  * a run longer than the window is reported at the window's width, and
///  * a break that lies just outside the window is invisible, so the grace day
///    the user has in fact already spent is reported as still in hand —
///    `aqua_water_dashboard.dart` renders exactly that number as the shield.
///
/// Both cases are pinned below with history deliberately older than
/// [WaterService.warmCacheWindow].
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  /// Fixed so "n days ago" is stable and far from any DST boundary.
  final now = DateTime(2026, 6, 15, 10, 30);

  DateTime dayAgo(int n) => DateTime(now.year, now.month, now.day - n);

  String keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  /// One stored day whose goal was met. Days the user missed are simply absent,
  /// which is how the real table looks — nothing writes a row for a day with no
  /// drinks.
  Future<void> seedGoalMetDay(DateTime date) async {
    final key = keyFor(date);
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(key),
      date: Value(date),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: const Value(2600),
      effectiveHydrationMl: const Value(2600),
      goalReached: const Value(true),
    ));
    await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
      id: Value('$key-log'),
      dailyDataId: Value(key),
      time: Value(DateTime(date.year, date.month, date.day, 9)),
      amountMl: const Value(2600),
      effectiveHydrationMl: const Value(2600),
      beverageId: const Value('water'),
      beverageName: const Value('Water'),
      hydrationPercent: const Value(100),
      caffeineAmount: const Value(0),
      isAlcoholic: const Value(false),
    ));
  }

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async => database.close());

  group('W-12 streak result reads the whole history', () {
    test('a run longer than the warm cache is not capped at its width',
        () async {
      // 200 unbroken days ending today. Only the last ~91 are ever in memory.
      for (var i = 200; i >= 0; i--) {
        await seedGoalMetDay(dayAgo(i));
      }
      await withClock(Clock.fixed(now), () => WaterService.init());

      // Premise guard: if warmCacheWindow ever grew past 200 days this test
      // would pass without proving anything.
      expect(WaterService.getDataForDate(dayAgo(200)), isNull,
          reason: 'the oldest day must be outside the warm cache');

      final result =
          withClock(Clock.fixed(now), WaterService.getStreakResult);

      expect(result.current, 201,
          reason: 'the cached fold stopped at the 90-day window and reported '
              'roughly 91; the streak is 201 days long');
      expect(result.longest, greaterThanOrEqualTo(201));
    });

    test('a grace day already spent outside the window is not offered again',
        () async {
      // Three good days ending today, then a two-day break — which spends the
      // week's single grace and then breaks the run — and an older block of
      // good days far outside the cache.
      //
      // Folding only the cache, the engine sees days 0..2 and nothing else:
      // `earliest` is day 2, the walk stops there before reaching the break,
      // and the grace is reported untouched.
      for (final i in [0, 1, 2]) {
        await seedGoalMetDay(dayAgo(i));
      }
      for (var i = 120; i >= 100; i--) {
        await seedGoalMetDay(dayAgo(i));
      }
      await withClock(Clock.fixed(now), () => WaterService.init());

      expect(WaterService.getDataForDate(dayAgo(100)), isNull,
          reason: 'the older block must be outside the warm cache');

      final result =
          withClock(Clock.fixed(now), WaterService.getStreakResult);

      expect(result.current, 3,
          reason: 'the run itself is the three recent days either way');
      expect(result.gracesRemaining, 0,
          reason: 'the shield the dashboard shows must say the grace is gone; '
              'the cached fold could not see the break and said it was still '
              'in hand');
      expect(result.usedGrace, isTrue,
          reason: 'the miss three days ago is inside the trailing week, so a '
              'grace was spent keeping the run alive');
      expect(result.isProtected, isFalse);
    });

    test('adding a drink keeps the lifetime answer, it does not truncate it',
        () async {
      // The snapshot the streak reads is patched on every write rather than
      // re-read, so a write must not quietly narrow it back to the cache.
      for (var i = 200; i >= 1; i--) {
        await seedGoalMetDay(dayAgo(i));
      }
      await withClock(Clock.fixed(now), () => WaterService.init());

      final before =
          withClock(Clock.fixed(now), WaterService.getStreakResult).current;
      expect(before, 200,
          reason: 'today has no drinks yet, so it does not count; the run is '
              'the 200 days behind it');

      await withClock(
        Clock.fixed(now),
        () => WaterService.addWaterLog(
          amountMl: 100,
          beverage: WaterService.getAllBeverages().first,
        ),
      );

      expect(withClock(Clock.fixed(now), WaterService.getStreakResult).current,
          200,
          reason: 'a 100 ml drink does not meet the goal, so the run is '
              'unchanged — but it must still be the lifetime run');
    });
  });
}
