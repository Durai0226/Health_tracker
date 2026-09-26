import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/hydration_goal.dart';

/// W-07 and W-14 — the two ways the goal calculator could report a number it
/// had no evidence for.
///
///  * The at-rest heat term was `(ambientC - 22) * 160` with no upper bound.
///
/// The magnitudes below are derived from [HydrationGoalCalculator.climateMlPerDegree]
/// rather than written out. W-07 had two halves — an unbounded term (fixed by
/// the ceiling this file pins) and a rate taken from the WHO TOTAL-water span
/// without the beverage share the baseline applies (160 -> 128). Hardcoding the
/// old magnitude made this file fail on the second half even though the
/// behaviour it actually guards — the cap — was untouched.
///    The WHO/IPCS pair it is fitted to only reaches 32 °C, and the sweat term
///    already carries its own `k(T)`, so every degree past the evidence added
///    heat load twice: a felt 45 °C put 3680 ml on the at-rest term alone and
///    drove the total into the [HydrationGoalCalculator.maxGoalMl] clamp.
///  * Once the total clamped, `conditionMl` was `total - preConditions` — a
///    NEGATIVE number, reported even for a profile with no conditions set.
void main() {
  group('W-07 — the heat term stops where its evidence does', () {
    test('a felt 45 °C adds no more than the WHO 32 °C span', () {
      final blazing = HydrationGoalCalculator.compute(
        isMale: true,
        ageYears: 30,
        weightKg: 70,
        activityLevel: HydrationActivityLevel.moderate,
        ambientC: 45,
      );

      expect(blazing.climateMl, HydrationGoalCalculator.maxClimateMl);
      expect(
          HydrationGoalCalculator.maxClimateMl,
          HydrationGoalCalculator.climateMlPerDegree * 10,
          reason: '(32 - 22) °C — the whole 2.9 L -> 4.5 L WHO span, carrying '
              'the beverage share');
    });

    test('32 °C is unchanged — the cap is a ceiling, not a rescale', () {
      // The worked example this finding was raised on: a 30-year-old man,
      // moderate activity, 32 °C. baseline 2960 + activity 225 + the capped
      // climate term (10 degrees above baseline).
      final hot = HydrationGoalCalculator.compute(
        isMale: true,
        ageYears: 30,
        weightKg: 70,
        activityLevel: HydrationActivityLevel.moderate,
        ambientC: 32,
      );
      expect(hot.climateMl, HydrationGoalCalculator.climateMlPerDegree * 10);
      // Stated as the sum of its parts, not a literal: the total moved from
      // 4785 to 4465 when the heat term took the beverage share, and a
      // hardcoded figure makes a correct change look like a regression.
      expect(hot.totalMl, hot.baselineMl + hot.activityMl + hot.climateMl);
      expect(hot.baselineMl, 2960, reason: 'the worked example this was raised on');
      expect(hot.totalMl, 4465,
          reason: 'was 4785 while the heat term demanded 100% of a TOTAL-water '
              'span on top of an 80% drinks baseline');
    });

    test('the heat term is monotonic up to the ceiling', () {
      int climateAt(double c) => HydrationGoalCalculator.compute(
            isMale: true,
            ageYears: 30,
            weightKg: 70,
            ambientC: c,
          ).climateMl;

      expect(climateAt(22), 0, reason: '22 °C is the temperate baseline');
      expect(climateAt(27), HydrationGoalCalculator.climateMlPerDegree * 5);
      expect(climateAt(27), lessThan(climateAt(32)));
    });

    test('an above-evidence reading says so instead of pretending', () {
      final blazing = HydrationGoalCalculator.compute(
          isMale: true, ageYears: 30, weightKg: 70, ambientC: 45);
      expect(blazing.basis.join(' '), contains('45 °C'),
          reason: 'the real reading is still what the user is told about');
      expect(blazing.basis.join(' '), contains('32 °C'),
          reason: 'and that the number was held at the top of the evidence');
    });
  });

  group('W-14 — a condition can never subtract fluid', () {
    /// baseline 2960 + a very large sweat term + the full heat term, all with
    /// NO conditions selected: `baseline + activity + climate` alone is past
    /// the 5 L cap.
    HydrationGoal overCap({Set<HydrationCondition> conditions = const {}}) =>
        HydrationGoalCalculator.compute(
          isMale: true,
          ageYears: 30,
          weightKg: 250,
          activityLevel: HydrationActivityLevel.veryActive,
          ambientC: 40,
          conditions: conditions,
        );

    test('a profile with no conditions reports no condition contribution', () {
      final g = overCap();
      expect(g.totalMl, HydrationGoalCalculator.maxGoalMl,
          reason: 'this scenario only means something while the total clamps');
      expect(g.baselineMl + g.activityMl + g.climateMl,
          greaterThan(HydrationGoalCalculator.maxGoalMl));
      expect(g.conditionMl, 0,
          reason: 'no condition is set, so none of the goal came from one — '
              'this used to report roughly -1700 ml');
    });

    test('a selected condition is never reported as taking fluid away', () {
      final g = overCap(conditions: {HydrationCondition.recurrentUti});
      expect(g.conditionMl, greaterThanOrEqualTo(0),
          reason: 'showing a medical condition as SUBTRACTING water from the '
              'target inverts the advice it stands for');
    });

    test('the breakdown admits when it has been held at the cap', () {
      expect(overCap().basis.join(' '), contains('Held at 5 L'),
          reason: 'the four terms no longer sum to the total once it clamps, '
              'and the screen prints these lines verbatim');
    });

    test('an ordinary profile still attributes the addition to the condition',
        () {
      final plain =
          HydrationGoalCalculator.compute(isMale: true, ageYears: 30);
      final uti = HydrationGoalCalculator.compute(
          isMale: true,
          ageYears: 30,
          conditions: {HydrationCondition.recurrentUti});
      expect(uti.conditionMl, 1500,
          reason: 'the clamp must not flatten the ordinary case to zero');
      expect(uti.totalMl - plain.totalMl, 1500);
      expect(uti.basis.join(' '), isNot(contains('Held at')));
    });
  });
}
