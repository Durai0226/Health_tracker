import '../../../core/health/walking_trends.dart';
import 'step_format.dart';

/// How a [WalkingTrend] reads aloud: what it is, how it was measured, and what
/// would turn it. Describes; it does not praise or scold.
extension WalkingTrendWords on WalkingTrend {
  static int get _recentWeeks => WalkingTrends.recentWindow ~/ 7;
  static int get _planWeeks => WalkingTrends.planDays ~/ 7;

  String get headline {
    const against = 'your ${WalkingTrends.baselineWindow}-day average';
    return switch (direction) {
      WalkingDirection.up => 'Up $deltaPercent% on $against',
      WalkingDirection.down => 'Down ${-deltaPercent}% on $against',
      WalkingDirection.steady => 'Steady against $against',
    };
  }

  String get detail =>
      '${formatThousands(recentAvg)} a day over the last $_recentWeeks weeks, '
      'against ${formatThousands(baselineAvg)} over ${WalkingTrends.baselineWindow} days.';

  /// What would turn a trend that is not up, or null when it is up already or
  /// out of reach.
  String? get plan {
    final extra = extraPerDayToTurnUp;
    if (extra == null) return null;
    return extra == 0
        ? 'Walking as you have lately for $_planWeeks weeks would turn this up.'
        : 'Walking about ${formatThousands(extra)} more steps a day than lately, '
            'for $_planWeeks weeks, would turn this up.';
  }
}
