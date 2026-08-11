import 'insight.dart';

/// One calendar day's adherence outcome + a numeric metric for that same day
/// (mean mood index, mean systolic, mean glucose, …) — the raw input to
/// [correlateWithAdherence].
class DayMetric {
  final DateTime day;
  final bool adherent; // every due (non-PRN) dose that day was taken
  final double value;
  const DayMetric({required this.day, required this.adherent, required this.value});
}

/// A day-bucketed comparison: the metric's mean on adherent days vs
/// non-adherent days. Deterministic, no ML — just two group means.
class CorrelationResult {
  final double adherentMean;
  final double nonAdherentMean;
  final int adherentCount;
  final int nonAdherentCount;

  const CorrelationResult({
    required this.adherentMean,
    required this.nonAdherentMean,
    required this.adherentCount,
    required this.nonAdherentCount,
  });

  /// Below this, a difference is noise, not a pattern worth a claim.
  static const int minPerGroup = 5;

  bool get hasEnoughData =>
      adherentCount >= minPerGroup && nonAdherentCount >= minPerGroup;

  /// non-adherent mean − adherent mean. Positive means the metric is HIGHER
  /// on days a dose was missed; callers decide whether higher is good or bad
  /// for their specific metric (e.g. higher mood INDEX is worse).
  double get delta => nonAdherentMean - adherentMean;
}

/// Splits [days] into adherent/non-adherent buckets and compares means. Null
/// when either bucket is empty (nothing to compare).
CorrelationResult? correlateWithAdherence(List<DayMetric> days) {
  final adherentValues = days.where((d) => d.adherent).map((d) => d.value).toList();
  final nonAdherentValues =
      days.where((d) => !d.adherent).map((d) => d.value).toList();
  if (adherentValues.isEmpty || nonAdherentValues.isEmpty) return null;

  double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  return CorrelationResult(
    adherentMean: mean(adherentValues),
    nonAdherentMean: mean(nonAdherentValues),
    adherentCount: adherentValues.length,
    nonAdherentCount: nonAdherentValues.length,
  );
}

/// Deterministic insights that correlate ANOTHER tracker's daily average
/// against that same day's medication adherence. General reference only —
/// this app never claims causation, only "these tend to land on the same
/// days," and always frames the takeaway as a conversation starter, not a
/// diagnosis (same framing as DrugInteractionService's disclaimers).
class CorrelationEngine {
  const CorrelationEngine._();

  /// Mood index runs 0 (Great) … 4 (Terrible) — LOWER is better, the
  /// opposite of a typical "higher is better" scale. A meaningfully higher
  /// (worse) mean on non-adherent days is the pattern worth surfacing.
  static const double _moodMeaningfulDelta = 0.5;

  static Insight? moodVsAdherence(List<DayMetric> days) {
    final r = correlateWithAdherence(days);
    if (r == null || !r.hasEnoughData) return null;
    if (r.delta < _moodMeaningfulDelta) return null; // not a real pattern

    return Insight(
      id: 'correlation_mood_adherence',
      feature: InsightFeature.crossCutting,
      severity: InsightSeverity.info,
      title: 'Mood tends to dip on missed-dose days',
      detail:
          'Over your last ${r.adherentCount + r.nonAdherentCount} logged days, '
          "your mood entries read lower on days you didn't take every dose. "
          "Worth mentioning at your next check-in — not a diagnosis, just a pattern in your own data.",
      why: 'Mean mood index on fully-adherent days: '
          '${r.adherentMean.toStringAsFixed(1)} (0=Great…4=Terrible) vs '
          '${r.nonAdherentMean.toStringAsFixed(1)} on days with a missed/skipped dose, '
          'across ${r.adherentCount} adherent and ${r.nonAdherentCount} non-adherent days.',
      rank: 35,
    );
  }

  /// Higher systolic/diastolic on non-adherent days is the expected direction
  /// for most BP medicines (a missed antihypertensive dose → higher reading).
  static const double _bpMeaningfulDelta = 5.0; // mmHg

  static Insight? bloodPressureVsAdherence(List<DayMetric> days) {
    final r = correlateWithAdherence(days);
    if (r == null || !r.hasEnoughData) return null;
    if (r.delta < _bpMeaningfulDelta) return null;

    return Insight(
      id: 'correlation_bp_adherence',
      feature: InsightFeature.crossCutting,
      severity: InsightSeverity.attention,
      title: 'Blood pressure runs higher on missed-dose days',
      detail:
          'Your average systolic reading is meaningfully higher on days you '
          "missed or skipped a dose. If this keeps showing up, it's worth "
          'raising with your care team.',
      why: 'Mean systolic on fully-adherent days: ${r.adherentMean.round()} mmHg '
          'vs ${r.nonAdherentMean.round()} mmHg on non-adherent days, across '
          '${r.adherentCount} adherent and ${r.nonAdherentCount} non-adherent days.',
      rank: 45,
    );
  }
}
