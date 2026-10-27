/// Pure-Dart intraday hydration pacing.
///
/// Top-tier water apps feel "smart" mostly through pacing: instead of only
/// showing a daily total, they know whether you're on track *for this point in
/// the day* and nudge when you fall behind. This is deterministic math over data
/// we already store (timestamped intake + goal + waking hours) — free, offline,
/// and fully unit-testable.
library;

import 'dart:math' as math;

class HydrationPace {
  /// How much you'd have drunk by now to be exactly on pace.
  final int expectedByNowMl;

  /// expectedByNow − intake. Positive = behind, negative = ahead.
  final int deficitMl;

  /// 'ahead' | 'on-pace' | 'behind'.
  final String status;

  /// Linear projection of end-of-day total at the current rate.
  final int projectedEndOfDayMl;

  /// True when the projection falls short of the goal.
  final bool projectedToMiss;

  /// A sensible next-sip suggestion to get back on pace (0 if on/ahead or done).
  final int suggestedSipMl;

  const HydrationPace({
    required this.expectedByNowMl,
    required this.deficitMl,
    required this.status,
    required this.projectedEndOfDayMl,
    required this.projectedToMiss,
    required this.suggestedSipMl,
  });

  bool get behind => status == 'behind';
  bool get ahead => status == 'ahead';
}

/// How much of the day's goal is expected by a given point of the waking day.
enum PaceCurve {
  /// An even rate from waking to bedtime: half the goal at the midpoint.
  linear,

  /// Drinking weighted to the earlier hours, easing off towards bedtime — what
  /// most people actually do, and kinder to sleep (less to get up for at night).
  /// About 67% of the goal is expected by the midpoint of the waking day
  /// (mid-afternoon, for 07:00-23:00), and only the last tenth in its final
  /// quarter.
  frontLoaded;

  /// How strongly the front-loaded curve leans to the morning: at 1 it is the
  /// straight line. 1.6 puts about 37% of the goal by a quarter of the day, 67%
  /// by half and 89% by three quarters.
  static const double frontLoadedExponent = 1.6;

  /// The share of the goal expected once [elapsed] (0 to 1) of the waking day
  /// has gone.
  double expectedShare(double elapsed) {
    final e = elapsed.clamp(0.0, 1.0);
    switch (this) {
      case PaceCurve.linear:
        return e;
      case PaceCurve.frontLoaded:
        return 1 - math.pow(1 - e, frontLoadedExponent).toDouble();
    }
  }
}

class HydrationPacer {
  const HydrationPacer._();

  /// Compute pacing. Times are minutes-since-midnight so callers can pass real
  /// precision. Only the waking window counts toward "expected by now" — nobody
  /// is expected to drink while asleep. [toleranceMl] is the on-pace band.
  static HydrationPace compute({
    required int intakeMl,
    required int goalMl,
    required int nowMinutes,
    int wakeMinutes = 7 * 60,
    int sleepMinutes = 23 * 60,
    int toleranceMl = 250,

    /// What "on pace" means. Front-loaded by default: expecting an even rate all
    /// day told someone who had drunk well by mid-afternoon they were behind, and
    /// pushed a litre at them before bed.
    PaceCurve curve = PaceCurve.frontLoaded,
  }) {
    if (goalMl <= 0) {
      return const HydrationPace(
        expectedByNowMl: 0,
        deficitMl: 0,
        status: 'on-pace',
        projectedEndOfDayMl: 0,
        projectedToMiss: false,
        suggestedSipMl: 0,
      );
    }

    // The waking window may WRAP past midnight — a night-shift profile wakes at
    // 22:00 and sleeps at 06:00. The old code was
    // `sleepMinutes.clamp(wake + 1, 1440)`, which had two failures:
    //
    //   1. `wakeMinutes: 1440` threw ArgumentError outright (lowerLimit 1441 >
    //      upperLimit 1440), taking the whole dashboard card with it.
    //   2. For any wrapped window it forced sleep down to `wake + 1`, making the
    //      waking span ONE MINUTE. `elapsed` then pinned to 0, expected-by-now
    //      was always 0, and a night-shift worker was permanently reported as
    //      "ahead of pace" and never nudged. Silent, and the worst direction to
    //      be wrong in.
    //
    // Same convention as [QuietHours.isAllowedMinute], which already handles
    // the wrap for the reminder window.
    const dayMinutes = 24 * 60;
    final wake = wakeMinutes.clamp(0, dayMinutes);
    final sleepRaw = sleepMinutes.clamp(0, dayMinutes);

    // Unwrap onto a monotonic line: a wrapped window becomes wake..sleep+1440,
    // and "now" is shifted into the same frame when it sits after midnight.
    final wrapped = sleepRaw <= wake;
    final sleep = wrapped ? sleepRaw + dayMinutes : sleepRaw;
    final now = (wrapped && nowMinutes < wake) ? nowMinutes + dayMinutes : nowMinutes;

    // A zero-length window (wake == sleep, e.g. both midnight) has no pace to
    // measure; treat the whole day as awake rather than dividing by zero.
    final wakingSpan = sleep - wake <= 0 ? dayMinutes : sleep - wake;

    // Fraction of the waking day elapsed (0 before waking, 1 at/after sleep).
    final elapsed = ((now - wake) / wakingSpan).clamp(0.0, 1.0);

    final share = curve.expectedShare(elapsed);
    final expected = (goalMl * share).round();
    final deficit = expected - intakeMl;

    // Already met the goal → nothing to chase.
    if (intakeMl >= goalMl) {
      return HydrationPace(
        expectedByNowMl: expected,
        deficitMl: deficit,
        status: 'ahead',
        projectedEndOfDayMl: intakeMl,
        projectedToMiss: false,
        suggestedSipMl: 0,
      );
    }

    // End-of-day projection from where intake stands against where the curve
    // says it should: on pace projects exactly the goal, whichever curve.
    final projected = share > 0.05 ? (intakeMl / share).round() : goalMl;

    String status;
    if (deficit > toleranceMl) {
      status = 'behind';
    } else if (deficit < -toleranceMl) {
      status = 'ahead';
    } else {
      status = 'on-pace';
    }

    // Suggest a cup sized to close the gap, rounded to 50ml, min 200, capped.
    int suggested = 0;
    if (status == 'behind') {
      final raw = deficit.clamp(200, 750);
      suggested = ((raw / 50).round()) * 50;
    }

    return HydrationPace(
      expectedByNowMl: expected,
      deficitMl: deficit,
      status: status,
      projectedEndOfDayMl: projected,
      projectedToMiss: projected < goalMl,
      suggestedSipMl: suggested,
    );
  }
}
