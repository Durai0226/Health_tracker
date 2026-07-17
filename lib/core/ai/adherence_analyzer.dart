/// Pure-Dart adherence analytics + a lightweight "about to miss" risk score,
/// computed only from the user's own dose outcomes (no ML framework, no
/// network). The risk score drives a Just-In-Time nudge; the % feeds insights
/// and the clinician report.
enum DoseOutcome { taken, missed, skipped }

class DoseEvent {
  final DateTime scheduled;
  final DoseOutcome outcome;
  const DoseEvent(this.scheduled, this.outcome);
}

class AdherenceAnalyzer {
  const AdherenceAnalyzer._();

  /// Proportion of *due* doses taken (taken ÷ taken+missed+skipped). 0..1.
  /// Every recorded event counts as a due dose.
  static double adherence(List<DoseEvent> history) {
    if (history.isEmpty) return 0;
    final taken = history.where((e) => e.outcome == DoseOutcome.taken).length;
    return taken / history.length;
  }

  /// Miss-risk (0..1) for a dose at [weekday]/[hour], smoothed toward the base
  /// rate so a single data point can't scream 100%. Blends the time-bucket miss
  /// rate with the recent-trend miss rate (last [recentN] doses).
  static double missRisk({
    required int weekday, // 1..7
    required int hour, // 0..23
    required List<DoseEvent> history,
    int recentN = 10,
    double priorStrength = 4, // Laplace-style smoothing toward the base rate
  }) {
    if (history.isEmpty) return 0;

    double rate(Iterable<DoseEvent> set) {
      final list = set.toList();
      if (list.isEmpty) return double.nan;
      final missed =
          list.where((e) => e.outcome != DoseOutcome.taken).length;
      return missed / list.length;
    }

    final base = rate(history);
    final bucket = history.where((e) =>
        e.scheduled.weekday == weekday && e.scheduled.hour == hour);
    final bucketList = bucket.toList();
    final bucketMissed =
        bucketList.where((e) => e.outcome != DoseOutcome.taken).length;

    // Smoothed bucket rate: pull toward the base rate when the bucket is sparse.
    final smoothedBucket =
        (bucketMissed + priorStrength * base) / (bucketList.length + priorStrength);

    // Recent trend.
    final sorted = [...history]..sort((a, b) => b.scheduled.compareTo(a.scheduled));
    final recent = sorted.take(recentN);
    final recentRate = rate(recent);
    final trend = recentRate.isNaN ? base : recentRate;

    // Weight bucket + trend.
    final risk = 0.6 * smoothedBucket + 0.4 * trend;
    return risk.clamp(0.0, 1.0);
  }

  /// Convenience label for a risk score.
  static String riskLabel(double risk) {
    if (risk >= 0.6) return 'high';
    if (risk >= 0.3) return 'medium';
    return 'low';
  }
}
