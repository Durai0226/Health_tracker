/// Pure frequency-capping for proactive nudges. Research: 2–5 notifications/week
/// is the opt-out cliff, so we cap per-week AND enforce a minimum gap, and let
/// the caller pick the single most important insight rather than firing on every
/// threshold cross. Pure + injectable [now] → unit-testable.
class NudgeScheduler {
  const NudgeScheduler._();

  /// Whether a nudge may be shown now, given the timestamps of prior nudges.
  static bool shouldShow({
    required List<DateTime> recentShows,
    required DateTime now,
    int maxPerWeek = 4,
    Duration minGap = const Duration(hours: 20),
  }) {
    final weekAgo = now.subtract(const Duration(days: 7));
    final inWeek = recentShows.where((t) => t.isAfter(weekAgo)).length;
    if (inWeek >= maxPerWeek) return false;
    for (final t in recentShows) {
      if (now.difference(t).abs() < minGap) return false;
    }
    return true;
  }
}
