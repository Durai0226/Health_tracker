import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/utils/calendar_day.dart';
import 'package:tablet_remainder/features/insights/services/insight_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// The two hydration numbers `InsightService.gatherAll` feeds the engines, at
/// the layer where both were wrong.
///
/// * **INS-01.** `InsightEngine.trend` now normalises by logged days, but the
///   normalisation only happens if the caller hands over the counts it already
///   computed. Fixing the engine alone made `trend` return null forever, which
///   is a different wrong answer, not a fix.
/// * **INS-10.** The hydration correlations took `totalIntakeMl` — raw volume —
///   while every other water surface in the app reports `effectiveHydrationMl`.
///   Alcohol is the only drink this app discounts (everything non-alcoholic
///   counts at 100%), so the raw figure credited a night on beer as hydration.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  // The callers read `DateTime.now()`, so the seed has to be anchored to the
  // real today. `dayOffset` is the same helper the windows step with, which is
  // what keeps the keys agreeing across a DST boundary.
  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> seedWaterDay(
    DateTime date, {
    required int rawMl,
    required int effectiveMl,
  }) async {
    final key = WaterService.dateKeyFor(date);
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(key),
      date: Value(date),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: Value(rawMl),
      effectiveHydrationMl: Value(effectiveMl),
    ));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await StepService.resetForTesting();
    await SleepService.resetForTesting();
  });

  tearDown(() async => database.close());

  Insight? byId(List<Insight> all, String id) {
    for (final i in all) {
      if (i.id == id) return i;
    }
    return null;
  }

  group('INS-01 — the week-over-week card is wired to the day counts', () {
    test('a bigger total across more logged days reads as a fall, not a rise',
        () async {
      // This week: 1500ml on each of 7 days  → total 10500, avg 1500.
      // Last week: 2500ml on each of 3 days  → total  7500, avg 2500.
      // Sums say +40% ("water up"). Per logged day it is −40%, which is what
      // actually happened to the habit.
      final t = today();
      for (var i = 1; i <= 7; i++) {
        await seedWaterDay(dayOffset(t, -i), rawMl: 1500, effectiveMl: 1500);
      }
      for (var i = 8; i <= 10; i++) {
        await seedWaterDay(dayOffset(t, -i), rawMl: 2500, effectiveMl: 2500);
      }
      await WaterService.init();

      final trend = byId(await InsightService.gatherAll(), 'water_trend');
      expect(trend, isNotNull,
          reason: 'the engine returns null unless the caller passes the '
              'logged-day counts it already has');
      expect(trend!.metric, '-40%');
      expect(trend.title.toLowerCase(), contains('down'));
      expect(trend.why, contains('7 logged days'));
      expect(trend.why, contains('3'));
    });

    test('the same daily habit logged on more days is not a trend at all',
        () async {
      // 2000ml x 7 days vs 2000ml x 3 days. Nothing about the drinking
      // changed; only the logging did. Raw sums call this +133%.
      final t = today();
      for (var i = 1; i <= 7; i++) {
        await seedWaterDay(dayOffset(t, -i), rawMl: 2000, effectiveMl: 2000);
      }
      for (var i = 8; i <= 10; i++) {
        await seedWaterDay(dayOffset(t, -i), rawMl: 2000, effectiveMl: 2000);
      }
      await WaterService.init();

      expect(byId(await InsightService.gatherAll(), 'water_trend'), isNull);
    });
  });

  group('INS-10 — hydration correlations compare hydration, not volume', () {
    test('a discounted day is compared at its hydration, not its volume',
        () async {
      // Ten nights, five long and five short, split at the user's own median.
      // Every day carries the SAME raw volume, so on raw intake the two groups
      // are identical and no pattern exists. The short-sleep days were drunk
      // at half hydration, which is the pattern that is really there.
      final t = today();
      final longDays = <DateTime>[];
      final shortDays = <DateTime>[];
      for (var i = 0; i < 5; i++) {
        longDays.add(dayOffset(t, -(2 + i)));
        shortDays.add(dayOffset(t, -(9 + i)));
      }
      for (final d in longDays) {
        await SleepService.logManualSession(
          bedtime: DateTime(d.year, d.month, d.day - 1, 23, 0),
          wakeTime: DateTime(d.year, d.month, d.day, 7, 0),
        );
        await seedWaterDay(d, rawMl: 2000, effectiveMl: 2000);
      }
      for (final d in shortDays) {
        await SleepService.logManualSession(
          bedtime: DateTime(d.year, d.month, d.day, 2, 0),
          wakeTime: DateTime(d.year, d.month, d.day, 7, 0),
        );
        await seedWaterDay(d, rawMl: 2000, effectiveMl: 1000);
      }
      await WaterService.init();

      final c = byId(
          await InsightService.gatherAll(), 'correlation_hydration_sleep');
      expect(c, isNotNull,
          reason: 'on raw intake both groups average 2000ml, so the insight '
              'cannot fire at all');
      expect(c!.metric, '1000ml');
      expect(c.detail, contains('2000ml'));
      expect(c.detail, contains('1000ml'));
      // The copy has to name what was measured. "you drank 1000ml" is false of
      // a day the user drank 2000ml.
      expect(c.detail.toLowerCase(), isNot(contains('you drank')));
      expect(c.detail.toLowerCase(), contains('hydration averaged'));
    });
  });
}
