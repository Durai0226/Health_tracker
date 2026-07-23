import 'cycle_phase.dart';

/// How much the engine trusts the current prediction. Shown honestly in the UI.
enum PredictionConfidence { low, medium, high }

extension PredictionConfidenceX on PredictionConfidence {
  String get label {
    switch (this) {
      case PredictionConfidence.low:
        return 'Low confidence';
      case PredictionConfidence.medium:
        return 'Medium confidence';
      case PredictionConfidence.high:
        return 'High confidence';
    }
  }
}

/// The lifecycle state that drives which body the dashboard shows.
enum CycleState {
  /// No data yet — cold start / onboarding.
  onboarding,

  /// Some data, but <3 completed cycles: still learning the rhythm.
  learning,

  /// Enough consistent history for a trustworthy prediction.
  ready,

  /// Enough history but cycle length swings too much to predict tightly.
  irregular,

  /// Predicted period window has passed with no new flow logged.
  late,

  /// Pregnancy tracking mode.
  pregnancy,
}

extension CycleStateX on CycleState {
  String get label {
    switch (this) {
      case CycleState.onboarding:
        return 'Getting started';
      case CycleState.learning:
        return 'Learning your cycle';
      case CycleState.ready:
        return 'On track';
      case CycleState.irregular:
        return 'Irregular cycles';
      case CycleState.late:
        return 'Period may be late';
      case CycleState.pregnancy:
        return 'Pregnancy';
    }
  }
}

/// Aggregate statistics derived from a person's recent (≤12) completed cycles.
/// Pure data — safe to build in the unit-testable predictor.
class CycleStats {
  /// Number of completed cycles used for these stats (after outlier rejection).
  final int cycleCount;

  /// Total number of flow-derived cycles detected (including the open one).
  final int totalCyclesDetected;

  final double? avgCycleLength;
  final int? medianCycleLength;
  final double cycleLengthStd;
  final int? shortestCycle;
  final int? longestCycle;

  final double? avgPeriodLength;
  final int? medianPeriodLength;

  /// True when cycle length varies enough that predictions can't be tight.
  final bool isIrregular;

  const CycleStats({
    this.cycleCount = 0,
    this.totalCyclesDetected = 0,
    this.avgCycleLength,
    this.medianCycleLength,
    this.cycleLengthStd = 0,
    this.shortestCycle,
    this.longestCycle,
    this.avgPeriodLength,
    this.medianPeriodLength,
    this.isIrregular = false,
  });

  bool get hasData => cycleCount > 0;

  static const CycleStats empty = CycleStats();
}

/// Immutable result of a single prediction run. All dates are day-precision.
class CyclePrediction {
  /// Estimated first day of the next period.
  final DateTime? predictedStart;

  /// Uncertainty band around [predictedStart].
  final DateTime? windowStart;
  final DateTime? windowEnd;

  /// Estimated ovulation day and the fertile window around it (estimate only —
  /// never for contraception or conception decisions).
  final DateTime? ovulationDay;
  final DateTime? fertileStart;
  final DateTime? fertileEnd;

  /// 1-based day of the current cycle on the queried date.
  final int? dayOfCycle;

  /// The learned/blended cycle length used ("~Y" in "Day X of ~Y").
  final int? cycleLengthEstimate;

  /// The phase the queried date falls in.
  final CyclePhase? phaseToday;

  final PredictionConfidence confidence;
  final CycleState state;

  /// Signed days from the queried date to [predictedStart] (negative ⇒ overdue).
  final int? daysUntilNextPeriod;

  /// Days since the last logged period start (pregnancy: since [pregnancyStart]).
  final int? gestationalDays;

  /// Count of completed cycles behind this prediction (for honesty in the UI).
  final int completedCycles;

  final DateTime? lastPeriodStart;

  const CyclePrediction({
    this.predictedStart,
    this.windowStart,
    this.windowEnd,
    this.ovulationDay,
    this.fertileStart,
    this.fertileEnd,
    this.dayOfCycle,
    this.cycleLengthEstimate,
    this.phaseToday,
    this.confidence = PredictionConfidence.low,
    this.state = CycleState.onboarding,
    this.daysUntilNextPeriod,
    this.gestationalDays,
    this.completedCycles = 0,
    this.lastPeriodStart,
  });

  /// Cold-start result: no data yet.
  static const CyclePrediction onboarding = CyclePrediction();

  /// Full gestational weeks (pregnancy mode).
  int? get gestationalWeeks =>
      gestationalDays == null ? null : gestationalDays! ~/ 7;

  /// Remainder days into the current gestational week.
  int? get gestationalWeekDays =>
      gestationalDays == null ? null : gestationalDays! % 7;
}
