/// Pure-Dart adaptive reminder timing. Most apps market "AI reminders" that are
/// really this: shift a fixed alarm toward when the user *actually* acts. We use
/// the robust median of (actual − scheduled) deltas and only suggest a shift
/// when there's enough consistent history — a bad shift on a medication alarm is
/// worse than the fixed time, so the bar to move is deliberately high.
class AdaptiveSuggestion {
  /// Suggested time-of-day in minutes-since-midnight.
  final int suggestedMinutes;

  /// Signed shift from the scheduled time (minutes; + = later).
  final int deltaMinutes;
  final int sampleCount;

  /// True only when the shift is meaningful AND the history is consistent.
  final bool confident;

  const AdaptiveSuggestion({
    required this.suggestedMinutes,
    required this.deltaMinutes,
    required this.sampleCount,
    required this.confident,
  });
}

class AdaptiveTiming {
  const AdaptiveTiming._();

  /// [scheduledMinutes] is the current alarm time; [actualMinutes] are the
  /// observed take-times (minutes-since-midnight) for that dose. Returns a
  /// suggestion; [confident] gates whether the UI should offer to apply it.
  static AdaptiveSuggestion suggest({
    required int scheduledMinutes,
    required List<int> actualMinutes,
    int minSamples = 4,
    int minShiftMinutes = 15,
    int maxShiftMinutes = 120,
    int maxSpreadMinutes = 90, // IQR ceiling for "consistent"
  }) {
    if (actualMinutes.isEmpty) {
      return AdaptiveSuggestion(
        suggestedMinutes: scheduledMinutes,
        deltaMinutes: 0,
        sampleCount: 0,
        confident: false,
      );
    }
    final deltas = actualMinutes.map((a) => a - scheduledMinutes).toList()..sort();
    final medianDelta = _median(deltas).round().clamp(-maxShiftMinutes, maxShiftMinutes);
    final spread = _iqr(deltas);
    final suggested = (scheduledMinutes + medianDelta).clamp(0, 24 * 60 - 1);

    final confident = actualMinutes.length >= minSamples &&
        medianDelta.abs() >= minShiftMinutes &&
        spread <= maxSpreadMinutes;

    return AdaptiveSuggestion(
      suggestedMinutes: suggested,
      deltaMinutes: medianDelta,
      sampleCount: actualMinutes.length,
      confident: confident,
    );
  }

  static double _median(List<int> sorted) {
    if (sorted.isEmpty) return 0;
    final n = sorted.length;
    return n.isOdd ? sorted[n ~/ 2].toDouble() : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
  }

  static double _iqr(List<int> sorted) {
    if (sorted.length < 4) {
      // Not enough for quartiles; use full range as a conservative spread.
      return sorted.isEmpty ? 0 : (sorted.last - sorted.first).toDouble();
    }
    final q1 = sorted[(sorted.length * 0.25).floor()];
    final q3 = sorted[(sorted.length * 0.75).floor()];
    return (q3 - q1).toDouble();
  }
}
