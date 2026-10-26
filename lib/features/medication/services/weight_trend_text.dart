import '../../../core/health/weight_trend.dart';
import '../../../core/utils/date_formats.dart';

const double _lbPerKg = 2.2046226218;

String _fmt(double kg, bool lb) => (lb ? kg * _lbPerKg : kg).toStringAsFixed(1);

/// "−0.4 kg a week", "steady", or null before there is a rate to quote.
///
/// A real minus sign, not a hyphen, and the rate rounded the way it is shown:
/// anything that rounds to 0.0 is "steady", never "−0.0 kg a week".
String? weightRateLabel(double? ratePerWeekKg, {required bool lb}) {
  if (ratePerWeekKg == null) return null;
  final shown = double.parse(_fmt(ratePerWeekKg.abs(), lb));
  if (shown == 0 || ratePerWeekKg.abs() < WeightTrend.flatKgPerWeek) {
    return 'steady';
  }
  return '${ratePerWeekKg < 0 ? '−' : '+'}${shown.toStringAsFixed(1)} ${lb ? 'lb' : 'kg'} a week';
}

/// The one sentence under the trend about the goal.
String weightGoalLine(GoalForecast f, double goalKg, {required bool lb}) {
  final goal = '${_fmt(goalKg, lb)} ${lb ? 'lb' : 'kg'}';
  switch (f.status) {
    case GoalStatus.reached:
      return "You're at your goal of $goal.";
    case GoalStatus.onTrack:
      return '$goal around ${DateFormats.dayLabel(f.date!)}';
    case GoalStatus.flat:
      return "Your trend is flat, so there's no date to give for $goal yet.";
    case GoalStatus.wrongWay:
      return 'Your trend is moving away from $goal.';
    case GoalStatus.tooFar:
      return 'At this pace $goal is more than two years away.';
    case GoalStatus.notEnoughData:
      return 'Weigh in over two weeks to see when you would reach $goal.';
  }
}
