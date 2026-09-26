import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/hydration_goal.dart';

/// W-07 — the at-rest heat term overstated the goal by the food-moisture share.
///
/// The baseline applies [HydrationGoalCalculator.beverageShare] because this app
/// tracks DRINKS, not total water: the file's own comment says using the total
/// "would silently demand ~700 ml/day more than anyone means by 'drink this
/// much'". The climate term was derived from the WHO total-water span
/// (2.9 L → 4.5 L over 10 °C = 160 ml/°C) and added raw — 80% of the baseline
/// plus 100% of the increment, so the same overstatement reappeared one term
/// later.
///
/// The earlier half of W-07 (an unbounded term, so a garbage temperature scaled
/// linearly to the 5 L clamp) is already fixed by [climateCeilingC]; this pins
/// the rate and the ceiling together so neither can drift back.
void main() {
  test('the per-degree rate carries the beverage share', () {
    expect(HydrationGoalCalculator.climateMlPerDegree, 128,
        reason: '160 ml/°C is the TOTAL-water span; this is added to a '
            'drinks-only baseline, so it must carry the same 0.80');
    // Stated as a relationship, not a magic number, so changing beverageShare
    // cannot leave the two silently inconsistent again.
    expect(
      HydrationGoalCalculator.climateMlPerDegree,
      (160 * HydrationGoalCalculator.beverageShare) ~/ 1,
    );
  });

  test('and the whole heat term is bounded by the evidence', () {
    // 128 ml/°C across the 22 °C → 32 °C span the WHO pair actually covers.
    expect(HydrationGoalCalculator.maxClimateMl, 1280);
    expect(
      HydrationGoalCalculator.maxClimateMl,
      HydrationGoalCalculator.climateMlPerDegree *
          ((HydrationGoalCalculator.climateCeilingC -
                  HydrationGoalCalculator.baselineAmbientC) ~/
              1),
    );
  });

  test('a hot day no longer stacks the food share on top', () {
    // 32 °C is the top of the evidence: 10 degrees above baseline.
    const degrees = 10;
    expect(HydrationGoalCalculator.climateMlPerDegree * degrees, 1280,
        reason: 'was 1600 — a whole extra 320 ml of food moisture asked of '
            'someone who only ever drinks');
  });
}
