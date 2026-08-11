import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/hydration_pacer.dart';

void main() {
  // Waking window 07:00–23:00 (default). Midday = 15:00 → 50% elapsed.
  const midday = 15 * 60; // 900

  test('behind pace → deficit, behind status, projected miss, sip suggestion', () {
    final p = HydrationPacer.compute(
      intakeMl: 200,
      goalMl: 2000,
      nowMinutes: midday,
    );
    expect(p.expectedByNowMl, closeTo(1000, 30)); // ~50% of 2000
    expect(p.deficitMl, greaterThan(250));
    expect(p.status, 'behind');
    expect(p.behind, isTrue);
    expect(p.projectedEndOfDayMl, lessThan(2000));
    expect(p.projectedToMiss, isTrue);
    expect(p.suggestedSipMl, greaterThan(0));
    expect(p.suggestedSipMl % 50, 0); // rounded to 50ml
  });

  test('ahead of pace → ahead status, no sip needed', () {
    final p = HydrationPacer.compute(
      intakeMl: 1500,
      goalMl: 2000,
      nowMinutes: 12 * 60, // ~31% elapsed
    );
    expect(p.status, 'ahead');
    expect(p.ahead, isTrue);
    expect(p.suggestedSipMl, 0);
  });

  test('on pace → within tolerance band, no nudge', () {
    final p = HydrationPacer.compute(
      intakeMl: 1000, // exactly expected at midday
      goalMl: 2000,
      nowMinutes: midday,
    );
    expect(p.status, 'on-pace');
    expect(p.suggestedSipMl, 0);
  });

  test('goal already met → ahead, nothing to chase', () {
    final p = HydrationPacer.compute(
      intakeMl: 2100,
      goalMl: 2000,
      nowMinutes: 10 * 60,
    );
    expect(p.status, 'ahead');
    expect(p.projectedToMiss, isFalse);
    expect(p.suggestedSipMl, 0);
  });

  test('zero goal → safe defaults', () {
    final p = HydrationPacer.compute(intakeMl: 0, goalMl: 0, nowMinutes: midday);
    expect(p.status, 'on-pace');
    expect(p.expectedByNowMl, 0);
  });
}
