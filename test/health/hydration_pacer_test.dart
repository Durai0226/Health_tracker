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

  group('a waking window that wraps past midnight', () {
    // A night-shift profile wakes at 22:00 and sleeps at 06:00. The old
    // `sleepMinutes.clamp(wake + 1, 1440)` forced the span to ONE MINUTE, so
    // `expectedByNow` was always 0 and the user was permanently "ahead" — never
    // nudged, with no error to notice.
    HydrationPace nightShift(int nowMinutes, {int intakeMl = 0}) =>
        HydrationPacer.compute(
          intakeMl: intakeMl,
          goalMl: 2000,
          nowMinutes: nowMinutes,
          wakeMinutes: 22 * 60,
          sleepMinutes: 6 * 60,
        );

    test('the span is the real 8 hours, not one minute', () {
      // Half way through the shift (02:00) expects about half the goal.
      final mid = nightShift(2 * 60);
      expect(mid.expectedByNowMl, closeTo(1000, 60));
    });

    test('a night-shift worker who has drunk nothing is reported behind', () {
      final p = nightShift(2 * 60);
      expect(p.behind, isTrue,
          reason: 'this was silently "ahead" for every night-shift user');
      expect(p.suggestedSipMl, greaterThan(0));
    });

    test('just after waking, little is expected yet', () {
      expect(nightShift(22 * 60 + 30).expectedByNowMl, lessThan(200));
    });

    test('at the end of the window the full goal is expected', () {
      expect(nightShift(6 * 60).expectedByNowMl, 2000);
    });

    test('drinking to pace reads as on-pace, not behind', () {
      expect(nightShift(2 * 60, intakeMl: 1000).behind, isFalse);
    });
  });

  group('degenerate windows do not throw', () {
    test('wakeMinutes at the very end of the day', () {
      // This threw ArgumentError("1441") outright, taking the dashboard card
      // with it: clamp(wake + 1, 1440) has lowerLimit > upperLimit.
      expect(
        () => HydrationPacer.compute(
            intakeMl: 500,
            goalMl: 2000,
            nowMinutes: 600,
            wakeMinutes: 24 * 60,
            sleepMinutes: 24 * 60),
        returnsNormally,
      );
    });

    test('an identical wake and bed time is treated as a full day', () {
      final p = HydrationPacer.compute(
          intakeMl: 0,
          goalMl: 2000,
          nowMinutes: 12 * 60,
          wakeMinutes: 0,
          sleepMinutes: 0);
      // Midday through a 24h window expects about half.
      expect(p.expectedByNowMl, closeTo(1000, 60));
    });

    test('out-of-range inputs are clamped rather than crashing', () {
      expect(
        () => HydrationPacer.compute(
            intakeMl: 500,
            goalMl: 2000,
            nowMinutes: 600,
            wakeMinutes: -300,
            sleepMinutes: 5000),
        returnsNormally,
      );
    });
  });
}
