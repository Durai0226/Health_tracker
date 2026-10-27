
/// Which feature an insight belongs to (drives its accent/icon in the UI).
enum InsightFeature {
  medicine,
  water,
  focus,
  reminders,
  bloodPressure,
  bloodSugar,
  period,
  steps,
  sleep,
  crossCutting,
}

/// Severity of an insight — maps to a color band + tone in the UI.
enum InsightSeverity { good, info, attention, urgent }

/// How strong the evidence behind a cross-day pattern is.
///
/// Every pattern here is two group means ("days you took every dose" vs "days
/// you missed one") and the engine only speaks once each group has at least
/// [CorrelationResult.minPerGroup] days and the gap is past a floor of what is
/// worth mentioning. That is a bar for speaking at all, not a measure of how
/// much to believe it, and "Mood tends to dip on missed-dose days" reads the
/// same off 5 days against 5 as off 40 against 30. This is the missing half:
/// the sample, in the open, and a plain word for it.
enum PatternStrength {
  /// Just over the bar to be mentioned: a first hint, not a finding.
  early('Early signal'),

  /// A fair amount of data and a clear gap.
  moderate('Moderate'),

  /// Plenty of data and a gap well past the floor.
  strong('Strong');

  final String label;
  const PatternStrength(this.label);
}

/// The sample behind a pattern, and what that makes of it.
class PatternEvidence {
  const PatternEvidence({
    required this.groupA,
    required this.groupB,
    required this.effectRatio,
    this.unit = 'days',
  });

  /// Days in each of the two groups compared (or nights: see [unit]).
  final int groupA;
  final int groupB;

  /// What the groups count, for the line: "days", or "nights" for sleep.
  final String unit;

  /// The observed difference divided by the smallest difference the engine
  /// counts as a pattern at all, so 1.0 is "only just" and 2.0 is twice that.
  final double effectRatio;

  /// The smaller group is the one that limits how far the comparison can be
  /// trusted: 40 days against 5 is still a 5-day comparison.
  int get smallerGroup => groupA < groupB ? groupA : groupB;

  /// Thresholds are a judgement, not a statistic: the aim is that "Strong" is
  /// hard to earn and "Early signal" is what most first sightings are.
  static const int moderateMinDays = 8;
  static const double moderateMinRatio = 1.5;
  static const int strongMinDays = 14;
  static const double strongMinRatio = 2.0;

  PatternStrength get strength {
    if (smallerGroup >= strongMinDays && effectRatio >= strongMinRatio) {
      return PatternStrength.strong;
    }
    if (smallerGroup >= moderateMinDays && effectRatio >= moderateMinRatio) {
      return PatternStrength.moderate;
    }
    return PatternStrength.early;
  }

  /// "Based on 9 vs 7 days · Moderate".
  String get line => 'Based on $groupA vs $groupB $unit · ${strength.label}';
}

/// A single "one big thing" insight, produced by the deterministic
/// [InsightEngine] (and, when available, phrased by an LLM tier). Pure model,
/// free of Flutter, so it can be built and unit-tested headlessly and rendered
/// by [InsightCard] in the widget layer.
class Insight {
  /// Stable id (feature + kind) so nudges can dedupe/track dismissal.
  final String id;
  final InsightFeature feature;
  final InsightSeverity severity;

  /// Short headline ("Adherence slipping this week").
  final String title;

  /// Plain-language explanation / suggested next step.
  final String detail;

  /// Optional supporting metric shown prominently ("82%", "150/95").
  final String? metric;

  /// Optional real goal ratio in 0..1 (e.g. doses taken ÷ due, intake ÷ goal).
  /// Present ONLY when a genuine ratio exists so the hub hero can draw a real
  /// [ProgressRing] — never parsed from a string, never fabricated. Null for
  /// streak/trend/pattern insights (the hero falls back to a dot strip / delta).
  final double? progress;

  /// The exact rule/data behind the insight — powers the "Why this?" popover
  /// (HAX G11 / PAIR explainability). Deterministic insights can be fully honest.
  final String why;

  /// Optional call-to-action label; the tap target is wired by the screen.
  final String? actionLabel;

  /// Higher = more important; the engine sorts by this for the hub + nudges.
  final double rank;

  /// For a cross-day pattern: how many days it rests on and how strong that
  /// makes it. Null for everything that is not a comparison of two groups.
  final PatternEvidence? evidence;

  const Insight({
    required this.id,
    required this.feature,
    required this.severity,
    required this.title,
    required this.detail,
    this.metric,
    this.progress,
    required this.why,
    this.actionLabel,
    this.rank = 0,
    this.evidence,
  });
}
