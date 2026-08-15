/// Pure-Dart medication refill / stock-depletion forecaster.
///
/// Free, offline, deterministic — projects when a medicine will run out from the
/// user's OWN recent consumption, so the app can nudge a refill before they run
/// dry. Decoupled from feature models (takes primitives) so it's trivially
/// unit-testable; a thin service adapter feeds it from the Drift logs.
class RefillPrediction {
  final int currentStock;

  /// Units consumed per day, averaged over the recent window.
  final double avgDailyRate;

  /// Whole days of stock left at the current rate; null if rate is 0 (unknown).
  final int? daysRemaining;

  /// Projected run-out date; null if rate is 0.
  final DateTime? depletionDate;

  /// When to reorder so stock doesn't hit zero before it arrives; null if rate 0.
  final DateTime? refillByDate;

  /// currentStock already at/below the user's low-stock threshold.
  final bool isLow;

  /// True when recent consumption outpaces the expected scheduled rate.
  final bool overConsuming;

  /// One-line human summary suitable for a card or notification.
  final String summary;

  const RefillPrediction({
    required this.currentStock,
    required this.avgDailyRate,
    required this.daysRemaining,
    required this.depletionDate,
    required this.refillByDate,
    required this.isLow,
    required this.overConsuming,
    required this.summary,
  });
}

class RefillPredictor {
  const RefillPredictor._();

  /// Predict depletion from recent taken-dose events.
  ///
  /// [doseTimes] are the timestamps of doses actually taken; [doseAmounts] are
  /// the units per dose (defaults to 1 each). Rate is averaged over the last
  /// [windowDays] so an occasional missed/extra dose doesn't swing it. [leadDays]
  /// is how early to reorder. [expectedDailyRate] (if known from the schedule)
  /// enables an over-consumption flag. [now] is injectable for tests.
  static RefillPrediction predict({
    required int currentStock,
    required List<DateTime> doseTimes,
    List<double>? doseAmounts,
    int? lowStockThreshold,
    int windowDays = 14,
    int leadDays = 7,
    double? expectedDailyRate,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final windowStart = ref.subtract(Duration(days: windowDays));

    // Sum units consumed within the window.
    double consumed = 0;
    DateTime? earliestInWindow;
    for (var i = 0; i < doseTimes.length; i++) {
      final t = doseTimes[i];
      if (t.isBefore(windowStart) || t.isAfter(ref)) continue;
      final amt = (doseAmounts != null && i < doseAmounts.length)
          ? doseAmounts[i]
          : 1.0;
      consumed += amt;
      earliestInWindow ??= t;
    }

    // Average over the ACTUAL observed span (min 1 day), not the full window, so
    // a new user with 3 days of history isn't diluted across 14.
    final observedDays = earliestInWindow == null
        ? 0
        : (ref.difference(earliestInWindow).inHours / 24.0).clamp(1.0, windowDays.toDouble());
    final avgDailyRate = observedDays > 0 ? consumed / observedDays : 0.0;

    final isLow = lowStockThreshold != null && currentStock <= lowStockThreshold;
    final overConsuming = expectedDailyRate != null &&
        expectedDailyRate > 0 &&
        avgDailyRate > expectedDailyRate * 1.15; // >15% above plan

    if (avgDailyRate <= 0 || currentStock <= 0) {
      return RefillPrediction(
        currentStock: currentStock,
        avgDailyRate: avgDailyRate,
        daysRemaining: null,
        depletionDate: null,
        refillByDate: null,
        isLow: isLow,
        overConsuming: false,
        summary: currentStock <= 0
            ? 'Out of stock — refill needed.'
            : isLow
                ? 'Stock is low ($currentStock left).'
                : 'Not enough recent history to project a run-out date yet.',
      );
    }

    final daysRemaining = (currentStock / avgDailyRate).floor();
    final depletion = _dateOnly(ref).add(Duration(days: daysRemaining));
    final refillBy = depletion.subtract(Duration(days: leadDays));

    final rateStr = avgDailyRate == avgDailyRate.roundToDouble()
        ? '${avgDailyRate.toInt()}'
        : avgDailyRate.toStringAsFixed(1);
    var summary =
        '$currentStock left · ~$rateStr/day · runs out in $daysRemaining ${daysRemaining == 1 ? 'day' : 'days'}.';
    if (overConsuming) {
      summary += ' You\'re using this faster than scheduled.';
    } else if (isLow) {
      summary += ' Stock is low — time to refill.';
    }

    return RefillPrediction(
      currentStock: currentStock,
      avgDailyRate: avgDailyRate,
      daysRemaining: daysRemaining,
      depletionDate: depletion,
      refillByDate: refillBy.isBefore(_dateOnly(ref)) ? _dateOnly(ref) : refillBy,
      isLow: isLow,
      overConsuming: overConsuming,
      summary: summary,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
