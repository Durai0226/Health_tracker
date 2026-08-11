
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
  });
}
