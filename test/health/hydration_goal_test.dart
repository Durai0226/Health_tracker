import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/hydration_goal.dart';

/// The old goal formula (`weightKg * 33` x activity x climate x 0.9-if-female,
/// -5% over 65) had no source, and two of its terms contradicted the ones that
/// do exist. These tests assert the replacement against the PUBLISHED figures,
/// so the model cannot drift away from what it claims to implement.
void main() {
  group('IOM/NASEM adequate intake baseline', () {
    test('adult men: 3.7 L total water, 3.0 L from drinks', () {
      // IOM's own worked figures for 19-30y: 3.7 L total of which 3.0 L is
      // beverages.
      expect(HydrationGoalCalculator.baselineDrinkMl(isMale: true, ageYears: 30),
          2960);
    });

    test('adult women: 2.7 L total water, ~2.2 L from drinks', () {
      expect(
          HydrationGoalCalculator.baselineDrinkMl(isMale: false, ageYears: 30),
          2160);
    });

    test('the adult figure is FLAT from 19 through over-70', () {
      // The old formula applied *0.95 over 65. IOM holds 3.7/2.7 across every
      // adult band, and EFSA says the elderly value is the same as adults.
      // What changes with age is thirst sensitivity — the risk, not the need.
      final at30 =
          HydrationGoalCalculator.baselineDrinkMl(isMale: true, ageYears: 30);
      for (final age in [19, 45, 66, 75, 90]) {
        expect(
          HydrationGoalCalculator.baselineDrinkMl(isMale: true, ageYears: age),
          at30,
          reason: 'no authority reduces the target for older adults (age $age)',
        );
      }
    });

    test('pregnancy is 3.0 L total, lactation 3.8 L', () {
      expect(
        HydrationGoalCalculator.baselineDrinkMl(
            isMale: false, ageYears: 30, isPregnant: true),
        2400,
      );
      expect(
        HydrationGoalCalculator.baselineDrinkMl(
            isMale: false, ageYears: 30, isBreastfeeding: true),
        3040,
      );
    });

    test('breastfeeding replaces pregnancy rather than stacking', () {
      // They are separate rows in the IOM table, not additive adjustments.
      expect(
        HydrationGoalCalculator.baselineDrinkMl(
            isMale: false, ageYears: 30, isPregnant: true, isBreastfeeding: true),
        HydrationGoalCalculator.baselineDrinkMl(
            isMale: false, ageYears: 30, isBreastfeeding: true),
      );
    });

    test('children follow their own bands', () {
      expect(HydrationGoalCalculator.baselineDrinkMl(isMale: true, ageYears: 2),
          (1.3 * 1000 * 0.8).round());
      expect(HydrationGoalCalculator.baselineDrinkMl(isMale: false, ageYears: 11),
          (2.1 * 1000 * 0.8).round());
      expect(HydrationGoalCalculator.baselineDrinkMl(isMale: true, ageYears: 16),
          (3.3 * 1000 * 0.8).round());
    });

    test('pregnancy and breastfeeding never apply to a male profile', () {
      // The old code guarded this because the toggles are not reset on a gender
      // change; the guard has to survive the rewrite.
      expect(
        HydrationGoalCalculator.baselineDrinkMl(
            isMale: true, ageYears: 30, isPregnant: true, isBreastfeeding: true),
        HydrationGoalCalculator.baselineDrinkMl(isMale: true, ageYears: 30),
      );
    });
  });

  group('ACSM sweat model', () {
    test('reaches the theoretical 1.38 mL/kcal ceiling at skin temperature', () {
      // 0.80 of metabolic energy becomes heat; evaporating sweat carries
      // 0.58 kcal/g; 0.80/0.58 = 1.38 mL per kcal when evaporation does all the
      // cooling. That happens when dry heat loss stops — at skin temperature,
      // ~36 C. The fit hitting the ceiling exactly there is what validates it.
      expect(HydrationGoalCalculator.sweatMlPerKcal(36.0), closeTo(1.38, 0.01));
    });

    test('needs less sweat in cool air, where convection does the work', () {
      expect(HydrationGoalCalculator.sweatMlPerKcal(10.0),
          lessThan(HydrationGoalCalculator.sweatMlPerKcal(30.0)));
    });

    test('never exceeds the physical ceiling, however hot the input', () {
      expect(HydrationGoalCalculator.sweatMlPerKcal(55.0),
          lessThanOrEqualTo(1.38));
    });
  });

  group('composition', () {
    test('ordinary activity does not inflate the goal', () {
      // The adequate intake is a population figure for people living ordinary
      // lives, so only activity BEYOND that adds water. Without this the model
      // double-counts and hands every user a target they will never hit.
      final g = HydrationGoalCalculator.compute(
        isMale: true,
        ageYears: 30,
        activeKcal: HydrationGoalCalculator.baselineActiveKcal,
      );
      expect(g.activityMl, 0);
      expect(g.totalMl, g.baselineMl);
    });

    test('a hard training day adds real sweat replacement', () {
      final rest = HydrationGoalCalculator.compute(
          isMale: true, ageYears: 30, activeKcal: 250);
      final trained = HydrationGoalCalculator.compute(
          isMale: true, ageYears: 30, activeKcal: 1250);

      // 1000 kcal above baseline at 22 C: k = 1.13 + 0.014*4 = 1.186
      expect(trained.activityMl, closeTo(1186, 2));
      expect(trained.totalMl, greaterThan(rest.totalMl));
    });

    test('heat adds on top of activity', () {
      final mild = HydrationGoalCalculator.compute(
          isMale: true, ageYears: 30, activeKcal: 600, ambientC: 22);
      final hot = HydrationGoalCalculator.compute(
          isMale: true, ageYears: 30, activeKcal: 600, ambientC: 34);

      expect(hot.climateMl, greaterThan(0));
      expect(mild.climateMl, 0, reason: '22 C is the temperate baseline');
      expect(hot.totalMl, greaterThan(mild.totalMl));
    });

    test('real measured energy is preferred over the activity-level guess', () {
      final measured = HydrationGoalCalculator.compute(
          isMale: true, ageYears: 30, activeKcal: 900, weightKg: 70);
      final guessed = HydrationGoalCalculator.compute(
          isMale: true,
          ageYears: 30,
          activityLevel: HydrationActivityLevel.sedentary,
          weightKg: 70);

      expect(measured.activityMl, greaterThan(guessed.activityMl),
          reason: 'measuring the load must beat guessing it from body mass');
    });

    test('weight affects the goal only through energy expenditure', () {
      // Not as a direct multiplier on the target — that is the folklore this
      // model replaces. With activity fixed, a heavier person still needs more,
      // but because they burn more moving, not because they weigh more.
      final light = HydrationGoalCalculator.compute(
          isMale: true,
          ageYears: 30,
          weightKg: 55,
          activityLevel: HydrationActivityLevel.moderate);
      final heavy = HydrationGoalCalculator.compute(
          isMale: true,
          ageYears: 30,
          weightKg: 110,
          activityLevel: HydrationActivityLevel.moderate);

      expect(heavy.totalMl, greaterThan(light.totalMl));
      expect(light.baselineMl, heavy.baselineMl,
          reason: 'the baseline itself must not scale with body weight');
    });

    test('stays inside the sane range for absurd inputs', () {
      final absurd = HydrationGoalCalculator.compute(
        isMale: true,
        ageYears: 30,
        activeKcal: 99999,
        ambientC: 50,
      );
      expect(absurd.totalMl, HydrationGoalCalculator.maxGoalMl);

      final tiny = HydrationGoalCalculator.compute(isMale: false, ageYears: 2);
      expect(tiny.totalMl, greaterThanOrEqualTo(HydrationGoalCalculator.minGoalMl));
    });

    test('every goal explains itself', () {
      final g = HydrationGoalCalculator.compute(
          isMale: false, ageYears: 30, activeKcal: 800, ambientC: 30);
      expect(g.basis, isNotEmpty);
      expect(g.basis.join(' '), contains('IOM'));
      expect(g.totalMl, g.baselineMl + g.activityMl + g.climateMl);
    });
  });

  group('safety', () {
    test('the hourly ceiling is the renal one, not the heat-casualty one', () {
      // ~800-1000 mL/h is maximal free-water clearance, and IOM's stated reason
      // for setting no Tolerable Upper Level is that healthy kidneys handle
      // more than 0.7 L/h. TB MED 507's 1.42 L/h is a ceiling for acclimatised
      // soldiers under work load and must never be applied to a desk worker.
      expect(HydrationGoalCalculator.safeHourlyCeilingMl, 1000);
      expect(HydrationGoalCalculator.safeHourlyCeilingMl, lessThan(1420));
    });

    test('the floor is above anything that would be a fluid restriction', () {
      // A restriction is a clinical decision with its own path — it must never
      // fall out of an odd profile.
      expect(HydrationGoalCalculator.minGoalMl, greaterThan(1000));
    });
  });
}
