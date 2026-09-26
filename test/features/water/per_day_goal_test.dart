import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// Every history surface — the calendar grid and its day sheet, the history
/// editor, the statistics weekly chart and the dashboard's weekly dials —
/// divided past intake by `getDailyGoal()`, i.e. TODAY's goal.
///
/// So raising the goal on Friday retroactively rewrote Monday from "Goal
/// Achieved!" to 70% and dropped "Goals Hit" from 1 to 0, while the statistics
/// badge on the same card — computed from each day's persisted `goalReached`
/// flag — still said 100%. Lowering the goal awarded goals that were never met.
/// The CSV export, which writes the per-day goal, disagreed with all of it.
///
/// The day row has stored `dailyGoalMl` all along; `WaterService.goalForDay` is
/// now the single place that decides what a day is judged against.
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

  Future<void> setGoal(int ml) async => WaterService.saveProfile(
      WaterService.getProfile().copyWith(useCustomGoal: true, customGoalMl: ml));

  // A PAST day, deliberately: changing the goal SHOULD re-stamp today's, and
  // testing on today would conflate the two.
  final monday = DateTime(2026, 3, 2, 9);

  test('positive: a met day stays met after the goal is raised', () async {
    await setGoal(2000);
    await WaterService.addWaterLogForDate(
        date: monday, amountMl: 2100, beverage: water);

    final before = WaterService.getDataForDate(monday);
    expect(before, isNotNull);
    expect(before!.goalReached, isTrue);
    expect(WaterService.goalForDay(before), 2000);

    // The user raises their goal on Friday.
    await setGoal(3000);

    final after = WaterService.getDataForDate(monday);
    expect(WaterService.goalForDay(after), 2000,
        reason: 'a past day must be judged by the goal it actually had');
    expect(after!.goalReached, isTrue,
        reason: 'raising the goal must not un-achieve a day already achieved');
    // And the number the screens render is now the honest one.
    expect(after.effectiveHydrationMl / WaterService.goalForDay(after),
        greaterThanOrEqualTo(1.0),
        reason: 'the calendar used to show this day at 70% after the change');
  });

  test('negative: an unmet day is not retroactively awarded by lowering the goal',
      () async {
    await setGoal(2000);
    await WaterService.addWaterLogForDate(
        date: monday, amountMl: 1500, beverage: water);
    expect(WaterService.getDataForDate(monday)!.goalReached, isFalse);

    await setGoal(1000);

    final after = WaterService.getDataForDate(monday);
    expect(WaterService.goalForDay(after), 2000);
    expect(after!.goalReached, isFalse,
        reason: 'lowering the goal must not award a goal that was never met');
  });

  test('positive: today DOES follow a goal change', () async {
    await setGoal(2000);
    await WaterService.addWaterLog(amountMl: 500, beverage: water);
    await setGoal(3000);
    expect(WaterService.goalForDay(WaterService.getTodayData()), 3000,
        reason: 'editing the goal is meant to apply to the day in progress');
  });

  test('positive: a day with no row falls back to the current goal', () async {
    await setGoal(2500);
    expect(WaterService.goalForDay(null), 2500,
        reason: 'there is nothing better to judge an unlogged day by');
  });

  test('negative: a stored goal of 0 falls back rather than dividing by zero',
      () async {
    await setGoal(2500);
    // 0/0 is NaN, and NaN.clamp(0, 1) returns the UPPER bound — the shape that
    // once painted a bogus "goal reached" tick.
    expect(WaterService.goalForDay(null), greaterThan(0));
  });
}
