import 'ai_types.dart';

/// Which feature an insight belongs to (drives its accent/icon in the UI).
enum InsightFeature {
  medicine,
  water,
  focus,
  reminders,
  bloodPressure,
  bloodSugar,
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

  /// The exact rule/data behind the insight — powers the "Why this?" popover
  /// (HAX G11 / PAIR explainability). Deterministic insights can be fully honest.
  final String why;

  /// Optional call-to-action label; the tap target is wired by the screen.
  final String? actionLabel;

  /// Higher = more important; the engine sorts by this for the hub + nudges.
  final double rank;

  /// Which tier produced this insight — drives the honest engine/privacy badge.
  final AiEngineKind engine;

  const Insight({
    required this.id,
    required this.feature,
    required this.severity,
    required this.title,
    required this.detail,
    this.metric,
    required this.why,
    this.actionLabel,
    this.rank = 0,
    this.engine = AiEngineKind.ruleBased,
  });
}
