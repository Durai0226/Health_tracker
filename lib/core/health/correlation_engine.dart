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
  // A thin adapter over [compareGroups], so there is one implementation of the
  // split rather than two that can drift. The field names differ (adherent vs
  // inGroup) and nothing else does.
  final cmp = compareGroups([
    for (final d in days)
      GroupedDay(day: d.day, inGroup: d.adherent, value: d.value)
  ]);
  if (cmp == null) return null;
  return CorrelationResult(
    adherentMean: cmp.inGroupMean,
    nonAdherentMean: cmp.outGroupMean,
    adherentCount: cmp.inGroupCount,
    nonAdherentCount: cmp.outGroupCount,
  );
}

/// One day, bucketed by an arbitrary boolean, with a metric for that day.
///
/// The generic form of [DayMetric], whose `adherent` field named the only
/// grouping variable that existed when it was written. Focus needs the same
/// arithmetic against "did the user sleep more than usual", so the split moved
/// here rather than being copied with a different field name.
class GroupedDay {
  final DateTime day;

  /// Whether this day is in the group being tested.
  final bool inGroup;

  final double value;

  const GroupedDay(
      {required this.day, required this.inGroup, required this.value});
}

/// Two group means and their counts. Same shape and thresholds as
/// [CorrelationResult].
class GroupComparison {
  final double inGroupMean;
  final double outGroupMean;
  final int inGroupCount;
  final int outGroupCount;

  const GroupComparison({
    required this.inGroupMean,
    required this.outGroupMean,
    required this.inGroupCount,
    required this.outGroupCount,
  });

  bool get hasEnoughData =>
      inGroupCount >= CorrelationResult.minPerGroup &&
      outGroupCount >= CorrelationResult.minPerGroup;

  /// in-group mean − out-group mean. The caller decides which direction is good.
  double get delta => inGroupMean - outGroupMean;
}

/// Splits [days] by [GroupedDay.inGroup] and compares means. Null when either
/// bucket is empty.
GroupComparison? compareGroups(List<GroupedDay> days) {
  final inGroup = days.where((d) => d.inGroup).map((d) => d.value).toList();
  final outGroup = days.where((d) => !d.inGroup).map((d) => d.value).toList();
  if (inGroup.isEmpty || outGroup.isEmpty) return null;

  double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  return GroupComparison(
    inGroupMean: mean(inGroup),
    outGroupMean: mean(outGroup),
    inGroupCount: inGroup.length,
    outGroupCount: outGroup.length,
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

  /// A day the user attempted at least one focus session.
  ///
  /// Deliberately a type of its own rather than a raw pair: the fields it makes
  /// mandatory are the ones the honesty of this insight depends on.
  static const double _completionMeaningfulDelta = 0.15;

  /// "Sessions finish more often after a longer night" — or nothing.
  ///
  /// Three decisions carry the honesty here, and each one was a way to get this
  /// wrong:
  ///
  ///  1. **Days with no session started are EXCLUDED, not counted as zero.**
  ///     Counting them as failures would make this a measure of whether the user
  ///     OPENED THE APP, not of how their focus went. This is the same defect
  ///     class `SleepService.sleepDebtMinutes` already documents — "the same
  ///     class of defect as reporting 100% adherence against zero doses". The
  ///     caller is responsible for passing only attempted days, which is why the
  ///     parameter is named for it.
  ///  2. **Completion RATE, not minutes.** Minutes conflate "had time" with "had
  ///     capacity": a day off produces more focus minutes regardless of sleep.
  ///     A rate is only defined on days something was actually attempted.
  ///  3. **The grouping is the user's OWN median, not a 7-hour constant.** A
  ///     six-hour sleeper is not sleep-deprived against their own baseline, and
  ///     a fixed threshold would label them permanently deficient.
  ///
  /// The copy says "after", never "because". The sleep happened first, so the
  /// arrow is at least not backwards — but a bad night and a bad focus day share
  /// obvious causes (illness, a deadline, alcohol, a sick child), and this app
  /// never claims causation.
  static Insight? focusVsSleep(List<GroupedDay> attemptedDays) {
    final r = compareGroups(attemptedDays);
    if (r == null || !r.hasEnoughData) return null;
    // Only the expected direction is surfaced. "You finish MORE after a short
    // night" is a noise finding dressed as advice.
    if (r.delta < _completionMeaningfulDelta) return null;

    String pct(double v) => '${(v * 100).round()}%';
    final total = r.inGroupCount + r.outGroupCount;

    return Insight(
      id: 'correlation_focus_sleep',
      feature: InsightFeature.crossCutting,
      severity: InsightSeverity.info,
      title: 'Sessions finish more often after a longer night',
      detail: 'Across $total days you started a focus session, you finished '
          '${pct(r.inGroupMean)} of them after your longer nights and '
          '${pct(r.outGroupMean)} after your shorter ones. This is a pattern in '
          'your own data — plenty of other things move both numbers.',
      metric: pct(r.delta),
      why: 'Mean completion rate on ${r.inGroupCount} longer-sleep days: '
          '${pct(r.inGroupMean)}, vs ${pct(r.outGroupMean)} on '
          '${r.outGroupCount} shorter-sleep days. Days with no session started '
          'are excluded.',
      // Below focus_completion (42) — a concrete "try shorter sessions" is more
      // actionable than a pattern — and above focus_besthour (34).
      rank: 38,
    );
  }
}
