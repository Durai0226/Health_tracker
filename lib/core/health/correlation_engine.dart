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

  /// Minimum difference in mean daily hydration (ml) worth calling a pattern.
  ///
  /// 200 ml is under one glass. Below that the "finding" is noise dressed as
  /// advice, which is the failure mode this whole file is written to avoid.
  static const double _hydrationMeaningfulDeltaMl = 200;

  /// Hydration against sleep duration.
  ///
  /// [days] carries each day's HYDRATION in millilitres — volume after each
  /// drink's hydration percentage, so a night on beer counts against the day
  /// rather than for it — grouped by whether that night's sleep was above the
  /// user's own median. Not raw intake: "you drink less" would otherwise be
  /// printed over a day whose volume was high and whose hydration was negative.
  ///
  /// The direction worth surfacing is short-sleep-with-less-fluid, and the
  /// literature runs the other way round from the intuition: Rosinger et al.
  /// (SLEEP 2019) found SHORT SLEEP PREDICTS DEHYDRATION — 6 hours versus 8
  /// gave an adjusted odds ratio of 1.59 (95% CI 1.25–2.03) for inadequate
  /// hydration across NHANES (n=4,680 and n=9,559) and 1.42 (1.26–1.60) in the
  /// Chinese Kailuan cohort (n=11,903). The proposed mechanism is vasopressin
  /// released late in the sleep cycle that a shortened night cuts off.
  ///
  /// So the framing is "your short nights come with less fluid", not a claim
  /// that drinking more will fix anyone's sleep.
  static Insight? hydrationVsSleep(List<GroupedDay> days) {
    final r = compareGroups(days);
    if (r == null || !r.hasEnoughData) return null;
    // Only the expected direction: more fluid on longer-sleep days.
    if (r.delta < _hydrationMeaningfulDeltaMl) return null;
    if (r.inGroupMean <= r.outGroupMean) return null;

    String ml(double v) => '${v.round()}ml';
    final total = r.inGroupCount + r.outGroupCount;

    return Insight(
      id: 'correlation_hydration_sleep',
      feature: InsightFeature.crossCutting,
      severity: InsightSeverity.info,
      title: 'You hydrate less on your shorter nights',
      detail: 'Across $total days your hydration averaged ${ml(r.inGroupMean)} '
          'after your longer nights and ${ml(r.outGroupMean)} after your '
          'shorter ones. Population studies find short sleep and low hydration '
          'travel together — it is worth a glass with breakfast on a rough '
          'morning, not a reason to worry.',
      metric: ml(r.delta),
      why: 'Mean hydration on ${r.inGroupCount} longer-sleep days: '
          '${ml(r.inGroupMean)}, vs ${ml(r.outGroupMean)} on ${r.outGroupCount} '
          'shorter-sleep days. Split at your own median sleep duration. '
          'Reference: Rosinger 2019, SLEEP 42(2) — 6h vs 8h sleep, adjusted OR '
          '1.59 for inadequate hydration.',
      // Alongside the other cross-cutting pattern insights.
      rank: 37,
    );
  }

  /// Hydration against medication adherence.
  ///
  /// No mechanism is claimed — this is a "these land on the same days"
  /// observation, and the honest use of it is as a shared-routine signal: the
  /// two habits tend to rise and fall together because they are both part of
  /// the same morning.
  static Insight? hydrationVsAdherence(List<DayMetric> days) {
    final r = correlateWithAdherence(days);
    if (r == null || !r.hasEnoughData) return null;

    // NOTE the sign: [AdherenceCorrelation.delta] is
    // `nonAdherentMean - adherentMean`, because every other metric on it is one
    // where the NON-adherent day is worse (mood, blood pressure). Hydration is
    // the opposite — more is the good direction — so `delta` is negative for the
    // pattern we want and reusing it directly would mean this insight could
    // never fire. Compute the difference in the direction that matters here.
    final excessMl = r.adherentMean - r.nonAdherentMean;
    if (excessMl < _hydrationMeaningfulDeltaMl) return null;

    String ml(double v) => '${v.round()}ml';
    final total = r.adherentCount + r.nonAdherentCount;

    return Insight(
      id: 'correlation_hydration_adherence',
      feature: InsightFeature.crossCutting,
      severity: InsightSeverity.info,
      title: 'Your hydration and your doses rise and fall together',
      detail: 'Over $total logged days your hydration averaged '
          '${ml(r.adherentMean)} on days you took every dose and '
          '${ml(r.nonAdherentMean)} on days you missed one. Neither causes '
          'the other — they are both part of the same routine, which is '
          'useful if you want to anchor one to the other.',
      metric: ml(excessMl),
      why: 'Mean hydration on ${r.adherentCount} fully-adherent days: '
          '${ml(r.adherentMean)}, vs ${ml(r.nonAdherentMean)} on '
          '${r.nonAdherentCount} days with a missed dose.',
      rank: 36,
    );
  }
}
