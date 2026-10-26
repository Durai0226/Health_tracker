import '../../../core/utils/calendar_day.dart';
import '../models/flow_intensity.dart';
import 'cycle_predictor.dart';

/// "Is this log about to start a new period suspiciously soon after the last?"
///
/// A light day logged 9 days after the last period began is far more often
/// spotting or a mid-cycle bleed than a real new period. Starting a new cycle
/// from it quietly distorts the average cycle length, the next-period
/// prediction and the fertile window — and nothing tells the user it happened.
/// So the app ASKS first. It never decides: the user may well be having a
/// short cycle, and "Start a new period" goes ahead exactly as before.
class NewPeriodCheck {
  const NewPeriodCheck._();

  /// A cycle shorter than this is unusual enough to confirm. The shortest
  /// cycles seen in healthy adults are in the low 20s, so 18 leaves room for
  /// genuine short cycles to pass without a question.
  static const int minCycleDays = 18;

  /// The number of days since the previous period began, when logging
  /// [flowIndex] on [date] would START a new period fewer than [minCycleDays]
  /// after it; otherwise null.
  ///
  /// Null means "nothing to ask": spotting and no-flow days can never start a
  /// period, a day that continues an existing run is not a start, and the very
  /// first period has nothing before it to compare against.
  static int? tooSoon({
    required List<FlowDay> days,
    required DateTime date,
    required int flowIndex,
  }) {
    if (flowIndex < FlowIntensity.light.index) return null;
    final d = DateTime(date.year, date.month, date.day);

    // Judge against the log WITHOUT whatever is already stored for this day, so
    // re-saving an existing period day is not mistaken for a new start.
    final others = [
      for (final x in days)
        if (DateTime(x.date.year, x.date.month, x.date.day) != d) x,
    ];
    final before = CyclePredictor.deriveCycles(others);
    final after = CyclePredictor.deriveCycles([...others, FlowDay(d, flowIndex)]);

    final startsNewRun = after.any((c) => c.start == d) &&
        !before.any((c) => c.start == d);
    if (!startsNewRun) return null;

    DateTime? previousStart;
    for (final c in before) {
      if (c.start.isBefore(d) &&
          (previousStart == null || c.start.isAfter(previousStart))) {
        previousStart = c.start;
      }
    }
    if (previousStart == null) return null;
    // Calendar days, not `difference().inDays`: that truncates a span across a
    // DST change to one day short.
    final gap = calendarDaysBetween(previousStart, d);
    return gap < minCycleDays ? gap : null;
  }
}
