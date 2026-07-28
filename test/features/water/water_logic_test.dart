import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/models/water_reminder_config.dart';

/// QA — Water pure logic (F3). Goal math, progress/remaining, hydration factor,
/// and quiet-hours filtering. Includes regressions for two bugs found + fixed:
/// pregnancy bonus applied to male profiles, and quiet-hours dropping every
/// reminder for an overnight (night-shift) awake window.
HydrationProfile prof({
  double? weight,
  bool isMale = true,
  ActivityLevel activity = ActivityLevel.moderate,
  ClimateType climate = ClimateType.moderate,
  bool pregnant = false,
  bool breastfeeding = false,
  int custom = 2500,
  bool useCustom = false,
}) =>
    HydrationProfile(
      id: 'p',
      weightKg: weight,
      isMale: isMale,
      activityLevel: activity,
      climate: climate,
      isPregnant: pregnant,
      isBreastfeeding: breastfeeding,
      customGoalMl: custom,
      useCustomGoal: useCustom,
    );

void main() {
  group('calculatedGoalMl', () {
    test('weight × moderate activity/climate (male)', () {
      // 70*33=2310 ×1.1 (moderate activity) ×1.0 (moderate climate) = 2541
      expect(prof(weight: 70).calculatedGoalMl, 2541);
    });
    test('null weight → default 2500', () {
      expect(prof(weight: null).calculatedGoalMl, 2500);
    });
    test('clamps to the 5000 ceiling', () {
      expect(
          prof(
                  weight: 300,
                  activity: ActivityLevel.veryActive,
                  climate: ClimateType.veryHot)
              .calculatedGoalMl,
          5000);
    });
    test('never below 1500 (negative weight clamps, no crash)', () {
      expect(prof(weight: -50).calculatedGoalMl, 1500);
    });
  });

  group('pregnancy/breastfeeding bonus is female-only (regression)', () {
    test('female + pregnant gets the bonus', () {
      expect(prof(weight: 60, isMale: false, pregnant: true).calculatedGoalMl,
          greaterThan(prof(weight: 60, isMale: false).calculatedGoalMl));
    });
    test('male + pregnant flag adds nothing (guarded)', () {
      expect(prof(weight: 60, isMale: true, pregnant: true).calculatedGoalMl,
          prof(weight: 60, isMale: true).calculatedGoalMl);
    });
    test('male + breastfeeding flag adds nothing (guarded)', () {
      expect(prof(weight: 60, isMale: true, breastfeeding: true).calculatedGoalMl,
          prof(weight: 60, isMale: true).calculatedGoalMl);
    });
  });

  group('effectiveGoalMl', () {
    test('custom on → returns the custom value', () {
      expect(prof(weight: 70, custom: 3000, useCustom: true).effectiveGoalMl, 3000);
    });
    test('custom off → returns calculated (custom ignored)', () {
      expect(prof(weight: 70, custom: 3000, useCustom: false).effectiveGoalMl, 2541);
    });
  });

  group('DailyWaterData.progress / remainingMl', () {
    DailyWaterData day({int goal = 2500, int eff = 0}) => DailyWaterData(
        id: 'd', date: DateTime(2026, 1, 1), dailyGoalMl: goal, effectiveHydrationMl: eff);
    test('half-way progress + remaining', () {
      final d = day(goal: 2500, eff: 1250);
      expect(d.progress, 0.5);
      expect(d.remainingMl, 1250);
    });
    test('zero goal does not divide by zero', () {
      expect(day(goal: 0, eff: 100).progress, 0.0);
    });
    test('over-goal remaining clamps to 0', () {
      expect(day(goal: 2500, eff: 4000).remainingMl, 0);
    });
  });

  group('BeverageType.getEffectiveHydration', () {
    BeverageType bev(int pct) =>
        BeverageType(id: 'b', name: 'B', emoji: 'x', hydrationPercent: pct);
    test('100% → full amount', () => expect(bev(100).getEffectiveHydration(500), 500));
    test('50% → half', () => expect(bev(50).getEffectiveHydration(500), 250));
    test('negative (alcohol) → negative hydration',
        () => expect(bev(-50).getEffectiveHydration(500), -250));
  });

  group('effectiveReminderMinutes — quiet hours', () {
    test('daytime window keeps only in-window times', () {
      final c = WaterReminderConfig(reminderMinutes: [360, 600, 1380]);
      expect(c.effectiveReminderMinutes(wakeHour: 7, bedHour: 22), [600]);
    });
    test('respectQuietHours off → all times', () {
      final c = WaterReminderConfig(
          reminderMinutes: [360, 600, 1380], respectQuietHours: false);
      expect(c.effectiveReminderMinutes(wakeHour: 7, bedHour: 22), [360, 600, 1380]);
    });
    test('overnight (night-shift) window wraps midnight (regression)', () {
      // wake 22:00, bed 06:00 → keep >=1320 OR <=360
      final c = WaterReminderConfig(reminderMinutes: [120, 660, 1400]);
      expect(c.effectiveReminderMinutes(wakeHour: 22, bedHour: 6), [120, 1400]);
    });
  });
}
