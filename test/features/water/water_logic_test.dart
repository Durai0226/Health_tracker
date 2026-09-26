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
  int? age,
}) =>
    HydrationProfile(
      id: 'p',
      age: age,
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
  // The goal formula moved to HydrationGoalCalculator, which is asserted
  // against the published IOM/EFSA/ACSM figures in
  // test/health/hydration_goal_test.dart. These tests cover the *profile's*
  // side of it: that the enums map through, and that the behaviours this file
  // has always guarded still hold.
  group('calculatedGoalMl', () {
    test('a moderate male sits on the IOM adult baseline plus sweat', () {
      // Baseline 2960 ml of drinks (3.7 L total water x 80% from beverages),
      // plus replacement for activity above what that baseline assumes.
      // The old answer was 2541, from `70*33*1.1` — a formula with no source.
      final g = prof(weight: 70).calculatedGoalMl;
      expect(g, greaterThan(2960));
      expect(g, lessThan(3500));
    });
    test('a missing weight still yields a real target, not a magic 2500', () {
      // Weight is not the basis of the goal any more, so its absence is not a
      // reason to fall back to a made-up number.
      expect(prof(weight: null).calculatedGoalMl,
          prof(weight: 70).calculatedGoalMl);
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
    test('a garbage weight cannot produce a garbage goal', () {
      final g = prof(weight: -50).calculatedGoalMl;
      expect(g, greaterThanOrEqualTo(1200));
      expect(g, lessThanOrEqualTo(5000));
    });
    test('the goal is NOT reduced for older adults (regression)', () {
      // The old formula applied *0.95 over 65. IOM holds the adult figure flat
      // through >70y; what declines with age is thirst sensitivity, not need.
      expect(prof(weight: 70, age: 70).calculatedGoalMl,
          prof(weight: 70, age: 30).calculatedGoalMl);
    });
    test('a hotter climate band raises the goal', () {
      expect(prof(weight: 70, climate: ClimateType.veryHot).calculatedGoalMl,
          greaterThan(prof(weight: 70, climate: ClimateType.cold).calculatedGoalMl));
    });
    test('a harder activity band raises the goal', () {
      expect(
          prof(weight: 70, activity: ActivityLevel.veryActive).calculatedGoalMl,
          greaterThan(
              prof(weight: 70, activity: ActivityLevel.sedentary).calculatedGoalMl));
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
      expect(prof(weight: 70, custom: 3000, useCustom: false).effectiveGoalMl,
          prof(weight: 70).calculatedGoalMl);
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

    test(
        'explicit wakeMinute/bedMinute=0 produces the same result as '
        'omitting them (no silent behavior change for existing callers)', () {
      final c = WaterReminderConfig(reminderMinutes: [360, 600, 1380]);
      final withDefaults = c.effectiveReminderMinutes(wakeHour: 7, bedHour: 22);
      final withExplicitZeros = c.effectiveReminderMinutes(
          wakeHour: 7, bedHour: 22, wakeMinute: 0, bedMinute: 0);
      expect(withExplicitZeros, withDefaults);
    });

    test('minute-precision window from a sleep-derived wake/bed time', () {
      // wake 07:15 (435), bed 22:45 (1365).
      final c = WaterReminderConfig(reminderMinutes: [434, 435, 1365, 1366]);
      expect(
        c.effectiveReminderMinutes(
            wakeHour: 7, bedHour: 22, wakeMinute: 15, bedMinute: 45),
        [435, 1365],
      );
    });
  });

  group('useSleepSchedule', () {
    test('round-trips through toJson/fromJson', () {
      final c = WaterReminderConfig(useSleepSchedule: true);
      final decoded = WaterReminderConfig.fromJson(c.toJson());
      expect(decoded.useSleepSchedule, true);
    });

    test('defaults to false and round-trips false', () {
      final c = WaterReminderConfig();
      expect(c.useSleepSchedule, false);
      final decoded = WaterReminderConfig.fromJson(c.toJson());
      expect(decoded.useSleepSchedule, false);
    });

    test('fromJson missing the key defaults to false', () {
      final json = WaterReminderConfig().toJson()..remove('useSleepSchedule');
      expect(WaterReminderConfig.fromJson(json).useSleepSchedule, false);
    });

    test('copyWith toggles it independently of respectQuietHours', () {
      final c = const WaterReminderConfig();
      final updated = c.copyWith(useSleepSchedule: true);
      expect(updated.useSleepSchedule, true);
      expect(updated.respectQuietHours, c.respectQuietHours);
    });
  });
}
