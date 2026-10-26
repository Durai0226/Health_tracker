/// The adaptive daily step goal, as a pure function of recent history.
///
/// It used to be the median of the last 14 days' steps, nudged up 10%. A single
/// number for every day of the week fits nobody who walks differently on
/// weekends: Saturday's goal was set by Tuesday's commute.
///
/// Now it blends that 14-day median with the median of the SAME weekday over the
/// last eight weeks, so Saturday's goal fits the user's Saturdays. With too few
/// same-weekday days to say anything it falls back to exactly the old number, so
/// nothing changes for a new user or a user who has not tracked weekends.
library;

import 'package:flutter/foundation.dart';

/// Why a goal is what it is, for the settings screen.
@immutable
class StepGoalResult {
  final int goal;

  /// Median of the last 14 days, or null while there is not enough history.
  final int? recentMedian;
  final int recentCount;

  /// Median of the same weekday over [AdaptiveStepGoal.weekdayLookbackDays],
  /// or null when it was not used.
  final int? weekdayMedian;
  final int weekdayCount;

  const StepGoalResult({
    required this.goal,
    required this.recentMedian,
    required this.recentCount,
    required this.weekdayMedian,
    required this.weekdayCount,
  });

  bool get usedWeekday => weekdayMedian != null;
}

class AdaptiveStepGoal {
  const AdaptiveStepGoal._();

  static const int defaultGoal = 8000;
  static const int minGoal = 4000;
  static const int maxGoal = 15000;

  /// How far above the median the goal sits, to keep the user progressing.
  static const double nudge = 1.1;

  /// Days of history needed before the goal adapts at all.
  static const int minRecentDays = 3;

  /// Same-weekday days needed before the weekday is allowed to move the goal.
  /// Fewer than this is one odd Saturday, not a pattern.
  static const int minWeekdayDays = 3;

  /// How far back same-weekday history is read.
  static const int weekdayLookbackDays = 56;

  /// Weight of the weekday median in the blend; the rest is the 14-day median.
  static const double weekdayWeight = 0.5;

  static int median(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  /// [recent] are the effective steps of the last 14 days that had any, and
  /// [sameWeekday] those of the same weekday as the goal's day over the last
  /// [weekdayLookbackDays], today excluded in both.
  static StepGoalResult compute({
    required List<int> recent,
    required List<int> sameWeekday,
  }) {
    if (recent.length < minRecentDays) {
      return StepGoalResult(
        goal: defaultGoal,
        recentMedian: null,
        recentCount: recent.length,
        weekdayMedian: null,
        weekdayCount: sameWeekday.length,
      );
    }
    final recentMedian = median(recent);
    int base = recentMedian;
    int? weekdayMedian;
    if (sameWeekday.length >= minWeekdayDays) {
      weekdayMedian = median(sameWeekday);
      base = (weekdayWeight * weekdayMedian +
              (1 - weekdayWeight) * recentMedian)
          .round();
    }
    return StepGoalResult(
      goal: (base * nudge).round().clamp(minGoal, maxGoal),
      recentMedian: recentMedian,
      recentCount: recent.length,
      weekdayMedian: weekdayMedian,
      weekdayCount: sameWeekday.length,
    );
  }
}
