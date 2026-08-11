/// Pure-Dart intraday hydration pacing.
///
/// Top-tier water apps feel "smart" mostly through pacing: instead of only
/// showing a daily total, they know whether you're on track *for this point in
/// the day* and nudge when you fall behind. This is deterministic math over data
/// we already store (timestamped intake + goal + waking hours) — free, offline,
/// and fully unit-testable.
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

    final wake = wakeMinutes.clamp(0, 24 * 60);
    final sleep = sleepMinutes.clamp(wake + 1, 24 * 60);
    final wakingSpan = sleep - wake;

    // Fraction of the waking day elapsed (0 before waking, 1 at/after sleep).
    final elapsed = ((nowMinutes - wake) / wakingSpan).clamp(0.0, 1.0);

    final expected = (goalMl * elapsed).round();
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

    // Linear end-of-day projection from the current rate.
    final projected = elapsed > 0.05 ? (intakeMl / elapsed).round() : goalMl;

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
