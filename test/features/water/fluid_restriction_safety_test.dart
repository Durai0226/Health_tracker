import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// A fluid RESTRICTION inverts what the daily number means: for dialysis or
/// heart-failure patients `dailyGoalMl` is a CEILING they must stay under, not
/// a target to reach (`HydrationProfile.effectiveGoalMl` returns
/// `fluidCeilingMl` in that mode).
///
/// `goalReached` was nonetheless computed as `intake >= dailyGoalMl`, and it
/// feeds `daysGoalMet`, `lastGoalMetDate`, the StreakEngine and every
/// streak/perfectWeek/perfectMonth badge. So a patient with a 1500 ml limit who
/// drank 1600 ml every day was shown a seven-day streak with a flame, a
/// "Goal Achieved!" card and an unlocked badge — the app celebrating exactly
/// the harm the restriction exists to prevent. Only the "overachiever" badge
/// had ever been guarded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => db.close());

  final water = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');

  test('negative: exceeding a fluid ceiling is not a reached goal', () async {
    await WaterService.saveProfile(
        WaterService.getProfile().copyWith(fluidCeilingMl: 1500));
    expect(WaterService.isFluidRestricted, isTrue);
    expect(WaterService.getDailyGoal(), 1500,
        reason: 'the ceiling IS the day number under a restriction');

    await WaterService.addWaterLog(amountMl: 1600, beverage: water);

    final today = WaterService.getTodayData();
    expect(today.totalIntakeMl, 1600, reason: 'the intake is still recorded');
    expect(today.goalReached, isFalse,
        reason: 'breaching a clinical limit must never read as success');
    expect(today.goalReachedAt, isNull);
  });

  test('negative: a breached ceiling earns no streak and no goal-met day',
      () async {
    await WaterService.saveProfile(
        WaterService.getProfile().copyWith(fluidCeilingMl: 1500));
    await WaterService.addWaterLog(amountMl: 1600, beverage: water);

    final a = WaterService.getAchievements();
    expect(a.currentStreak, 0,
        reason: 'the water tab header showed a flame and a streak for this');
    expect(a.daysGoalMet, 0);
  });

  test('negative: no achievement or drink-more insight under a restriction',
      () async {
    await WaterService.saveProfile(
        WaterService.getProfile().copyWith(fluidCeilingMl: 1500));
    await WaterService.addWaterLog(amountMl: 1600, beverage: water);

    final insights = WaterService.getInsights();
    expect(insights.where((i) => i.type == InsightType.achievement), isEmpty,
        reason: '"Goal Achieved!" celebrates the breach itself');
    for (final i in insights) {
      expect(i.title, isNot(contains('Below Average')),
          reason: 'urging a restricted user to drink more is harmful advice');
    }
  });

  test('positive: without a restriction the goal still works normally',
      () async {
    await WaterService.saveProfile(WaterService.getProfile()
        .copyWith(useCustomGoal: true, customGoalMl: 1500));
    expect(WaterService.isFluidRestricted, isFalse);

    await WaterService.addWaterLog(amountMl: 1600, beverage: water);

    final today = WaterService.getTodayData();
    expect(today.goalReached, isTrue,
        reason: 'an ordinary goal of 1500 IS reached by 1600 ml');
    expect(today.goalReachedAt, isNotNull);
    expect(WaterService.getAchievements().daysGoalMet, greaterThan(0));
  });

  test('positive: staying under the ceiling is still recorded faithfully',
      () async {
    await WaterService.saveProfile(
        WaterService.getProfile().copyWith(fluidCeilingMl: 1500));
    await WaterService.addWaterLog(amountMl: 900, beverage: water);

    final today = WaterService.getTodayData();
    expect(today.totalIntakeMl, 900,
        reason: 'the dial against the limit is the real feedback in this mode');
    expect(today.goalReached, isFalse);
  });
}
