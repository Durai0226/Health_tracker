import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/cycle_hydration_insight.dart';
import 'package:tablet_remainder/features/period/models/cycle_phase.dart';

/// The luteal-phase osmoregulatory shift is real and specific: basal plasma
/// osmolality 281 vs 286 mOsm/kg, with the thirst and vasopressin thresholds
/// both about 5 mOsm/kg lower.
///
/// What it is NOT is a published change in daily fluid requirement. The whole
/// point of these tests is that the app resists converting it into millilitres —
/// inventing a coefficient and calling it science is exactly what the
/// body-weight formula this app just deleted was doing.
void main() {
  test('the luteal phase gets context, and no other phase does', () {
    expect(CycleHydrationInsight.forPhase(CyclePhase.luteal), isNotNull);
    for (final phase in [
      CyclePhase.menstrual,
      CyclePhase.follicular,
      CyclePhase.ovulation,
    ]) {
      expect(CycleHydrationInsight.forPhase(phase), isNull, reason: phase.name);
    }
  });

  test('an unknown phase says nothing', () {
    expect(CycleHydrationInsight.forPhase(null), isNull);
  });

  test('it explicitly does NOT change the target', () {
    final i = CycleHydrationInsight.forPhase(CyclePhase.luteal)!;
    expect(i.detail.toLowerCase(), contains('has not changed'));
    // No invented millilitre figure anywhere in the copy.
    expect(RegExp(r'\d+\s*ml').hasMatch(i.detail), isFalse,
        reason: 'no authority publishes a luteal-phase intake figure, so the '
            'app must not print one');
    expect(i.why.toLowerCase(), contains('deliberately left alone'));
  });

  test('the mechanism is cited with the real numbers', () {
    final i = CycleHydrationInsight.forPhase(CyclePhase.luteal)!;
    expect(i.why, contains('281'));
    expect(i.why, contains('286'));
    expect(i.why.toLowerCase(), contains('vasopressin'));
  });

  test('nothing is said to someone on a fluid restriction', () {
    // A prescribed ceiling means the last thing they need is a nudge about
    // drinking to thirst.
    expect(
        CycleHydrationInsight.forPhase(CyclePhase.luteal, isRestricted: true),
        isNull);
  });
}
