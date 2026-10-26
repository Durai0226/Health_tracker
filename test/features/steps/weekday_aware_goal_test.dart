import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/steps/models/health_profile.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

/// "Saturday's goal fits your Saturdays." The pure blend is in
/// `step_goal_test`; this pins that StepService feeds it the right days.
///
/// Fixture: today is Sunday 15 Mar 2026. Every Saturday in the last eight weeks
/// except 28 Feb is 12,000 steps; every other day is 7,000.
///   * 14-day median      = 7,000 (two Saturdays among fourteen days)
///   * Saturday median    = 12,000  -> blend 9,500 -> goal 10,450
///   * Sunday median      = 7,000   -> blend 7,000 -> goal 7,700
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final today = DateTime(2026, 3, 15, 12); // a Sunday
  final saturday = DateTime(2026, 3, 21);
  final sunday = DateTime(2026, 3, 22);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
  });

  tearDown(() async => database.close());

  Future<void> seed({Set<String> skip = const {}}) async {
    // 20 Jan .. 14 Mar.
    for (var d = DateTime(2026, 1, 20);
        d.isBefore(DateTime(2026, 3, 15));
        d = DateTime(d.year, d.month, d.day + 1)) {
      final key = '${d.month}-${d.day}';
      if (skip.contains(key)) continue;
      final steps = d.weekday == DateTime.saturday ? 12000 : 7000;
      await StepService.addManualStepsForDate(d, steps, maxDaysBack: 90);
    }
  }

  test('the fixture is what it says it is', () {
    expect(today.weekday, DateTime.sunday);
    expect(saturday.weekday, DateTime.saturday);
    expect(sunday.weekday, DateTime.sunday);
  });

  test('a Saturday\'s goal fits Saturdays; a Sunday\'s fits Sundays', () async {
    await withClock(Clock.fixed(today), () async {
      await seed();
      final sat = StepService.adaptiveGoalResult(forDate: saturday);
      final sun = StepService.adaptiveGoalResult(forDate: sunday);

      expect(sat.usedWeekday, isTrue);
      expect(sat.weekdayMedian, 12000);
      expect(sat.recentMedian, 7000);
      expect(sat.goal, 10450);
      expect(sun.weekdayMedian, 7000);
      expect(sun.goal, 7700);
      expect(sat.goal, greaterThan(sun.goal));
    });
  });

  test('today\'s goal is today\'s weekday\'s goal', () async {
    await withClock(Clock.fixed(today), () async {
      await seed();
      expect(StepService.computeAdaptiveGoal(), 7700);
    });
  });

  test('a day created for a past Saturday gets a SATURDAY goal, not today\'s',
      () async {
    await withClock(Clock.fixed(today), () async {
      await seed(skip: {'2-28'}); // a Saturday left empty, to backfill
      final day = await StepService.addManualStepsForDate(
          DateTime(2026, 2, 28), 100,
          maxDaysBack: 90);
      expect(day!.goalSteps, 10450,
          reason: 'it used to take today\'s goal whatever day it was for');
    });
  });

  test('with no weekday history it is the plain 14-day goal', () async {
    await withClock(Clock.fixed(today), () async {
      // Only the last two weeks tracked: two Saturdays, under the threshold of
      // three, so the weekday must not move anything.
      for (var d = DateTime(2026, 3, 1);
          d.isBefore(DateTime(2026, 3, 15));
          d = DateTime(d.year, d.month, d.day + 1)) {
        await StepService.addManualStepsForDate(
            d, d.weekday == DateTime.saturday ? 12000 : 7000,
            maxDaysBack: 30);
      }
      final sat = StepService.adaptiveGoalResult(forDate: saturday);
      expect(sat.usedWeekday, isFalse);
      expect(sat.goal, 7700);
      expect(StepService.adaptiveGoalResult(forDate: sunday).goal, 7700);
    });
  });

  test('a custom goal wins over any weekday', () async {
    await withClock(Clock.fixed(today), () async {
      await seed();
      await StepService.saveProfile(const HealthProfile(
          useCustomStepGoal: true, customStepGoal: 6500));
      expect(StepService.computeAdaptiveGoal(forDate: saturday), 6500);
      expect(StepService.computeAdaptiveGoal(forDate: sunday), 6500);
    });
  });

  test('the explanation names the weekday and the numbers behind it', () async {
    await withClock(Clock.fixed(today), () async {
      await seed();
      final text = StepService.goalExplanation();
      expect(text, contains('Sundays'));
      expect(text, contains('7,000'));
      expect(text, contains('7,700'));
    });
  });
}
