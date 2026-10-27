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
      curve: PaceCurve.linear,
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
      intakeMl: 1000, // exactly expected at midday on an even pace
      goalMl: 2000,
      nowMinutes: midday,
      curve: PaceCurve.linear,
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

  group('the front-loaded curve (the default)', () {
    test('its shape: more early, less late, the same start and end', () {
      const c = PaceCurve.frontLoaded;
      expect(c.expectedShare(0), 0);
      expect(c.expectedShare(1), 1);
      expect(c.expectedShare(0.25), closeTo(0.37, 0.01));
      expect(c.expectedShare(0.5), closeTo(0.67, 0.01));
      expect(c.expectedShare(0.75), closeTo(0.89, 0.01));
    });

    test('always at least the even pace, and never going backwards', () {
      var last = 0.0;
      for (var i = 0; i <= 100; i++) {
        final e = i / 100;
        final front = PaceCurve.frontLoaded.expectedShare(e);
        expect(front, greaterThanOrEqualTo(PaceCurve.linear.expectedShare(e)));
        expect(front, greaterThanOrEqualTo(last));
        last = front;
      }
    });

    test('eases off towards bed: the last quarter asks for about a tenth', () {
      final tail = PaceCurve.frontLoaded.expectedShare(1) -
          PaceCurve.frontLoaded.expectedShare(0.75);
      expect(tail, lessThan(0.12));
      expect(PaceCurve.linear.expectedShare(1) - PaceCurve.linear.expectedShare(0.75),
          closeTo(0.25, 1e-9));
    });

    test('out-of-range progress is clamped', () {
      expect(PaceCurve.frontLoaded.expectedShare(-1), 0);
      expect(PaceCurve.frontLoaded.expectedShare(3), 1);
      expect(PaceCurve.linear.expectedShare(-1), 0);
      expect(PaceCurve.linear.expectedShare(3), 1);
    });

    test('it is what the pacer uses unless told otherwise', () {
      final byDefault =
          HydrationPacer.compute(intakeMl: 0, goalMl: 2000, nowMinutes: midday);
      final front = HydrationPacer.compute(
          intakeMl: 0,
          goalMl: 2000,
          nowMinutes: midday,
          curve: PaceCurve.frontLoaded);
      expect(byDefault.expectedByNowMl, front.expectedByNowMl);
      expect(byDefault.expectedByNowMl, closeTo(1340, 20),
          reason: 'about 67% of 2 litres by 15:00');
    });

    test('someone drinking evenly is behind by mid-afternoon, not on pace', () {
      final even = HydrationPacer.compute(
          intakeMl: 1000, goalMl: 2000, nowMinutes: midday);
      expect(even.status, 'behind');
      expect(even.suggestedSipMl, greaterThan(0));
    });

    test('someone who front-loads is on pace by mid-afternoon', () {
      final p = HydrationPacer.compute(
          intakeMl: 1300, goalMl: 2000, nowMinutes: midday);
      expect(p.status, 'on-pace');
    });

    test('and at ten at night the gap to the goal is small, not a litre', () {
      // 22:00 is 15 of 16 waking hours: 94% of the way. Having had 1.7 litres,
      // the even pace would still ask for ~100 ml more; the curve asks for none.
      final p = HydrationPacer.compute(
          intakeMl: 1700, goalMl: 2000, nowMinutes: 22 * 60);
      expect(p.expectedByNowMl, closeTo(1990, 25));
      expect(p.deficitMl, lessThan(350));
    });

    test('exactly on the curve projects exactly the goal', () {
      final expected = HydrationPacer.compute(
              intakeMl: 0, goalMl: 2000, nowMinutes: midday)
          .expectedByNowMl;
      final p = HydrationPacer.compute(
          intakeMl: expected, goalMl: 2000, nowMinutes: midday);
      expect(p.projectedEndOfDayMl, closeTo(2000, 5));
      expect(p.projectedToMiss, isFalse);
    });

    test('the same intake projects LOWER on the front-loaded curve than the '
        'even one: the evening is expected to add less', () {
      final front = HydrationPacer.compute(
          intakeMl: 800, goalMl: 2000, nowMinutes: midday);
      final even = HydrationPacer.compute(
          intakeMl: 800,
          goalMl: 2000,
          nowMinutes: midday,
          curve: PaceCurve.linear);
      expect(front.projectedEndOfDayMl, lessThan(even.projectedEndOfDayMl));
    });

    test('very early in the day it does not project from nothing', () {
      final p = HydrationPacer.compute(
          intakeMl: 100, goalMl: 2000, nowMinutes: 7 * 60 + 10);
      expect(p.projectedEndOfDayMl, 2000,
          reason: 'under 5% expected: too soon to extrapolate');
    });
  });

  group('a waking window that wraps past midnight', () {
    // A night-shift profile wakes at 22:00 and sleeps at 06:00. The old
    // `sleepMinutes.clamp(wake + 1, 1440)` forced the span to ONE MINUTE, so
    // `expectedByNow` was always 0 and the user was permanently "ahead" — never
    // nudged, with no error to notice.
    // On an even pace: this group is about the WINDOW, not the curve.
    HydrationPace nightShift(int nowMinutes, {int intakeMl = 0}) =>
        HydrationPacer.compute(
          intakeMl: intakeMl,
          goalMl: 2000,
          nowMinutes: nowMinutes,
          wakeMinutes: 22 * 60,
          sleepMinutes: 6 * 60,
          curve: PaceCurve.linear,
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
          sleepMinutes: 0,
          curve: PaceCurve.linear);
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
