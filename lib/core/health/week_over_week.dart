/// "2,300 steps ahead of this time last week."
///
/// Today's steps so far against the same weekday a week ago at the same hour.
/// It says nothing unless it can stand behind the figure: last week's day has to
/// have hourly data, and that data has to account for most of that day's steps —
/// the hourly buckets are only filled while the app syncs during the day, so a
/// day synced at 3pm has a morning and nothing after it, and comparing this
/// evening against that would read as "way ahead" when nothing of the sort is
/// true.
library;

import 'package:flutter/foundation.dart';

@immutable
class WeekOverWeek {
  /// Today's steps minus last week's by this time. Negative means behind.
  final int difference;

  /// Last week's steps by this time of day.
  final int lastWeekSoFar;

  const WeekOverWeek(this.difference, this.lastWeekSoFar);

  bool get isAhead => difference > 0;
}

class WeekOverWeekCalc {
  const WeekOverWeekCalc._();

  /// Smaller than this either way is not worth saying: steps are noisy.
  static const int minDifference = 100;

  /// Before this hour a comparison is a handful of steps either side.
  static const int earliestHour = 8;

  /// The hourly buckets must add up to at least this much of the day's total, or
  /// they are a partial record and the comparison is not made.
  static const double minCoverage = 0.85;

  /// Steps taken by [at] given 24 [hourly] buckets: every finished hour plus the
  /// elapsed part of the current one.
  static int stepsBy(List<int> hourly, DateTime at) {
    var sum = 0;
    for (var h = 0; h < at.hour && h < hourly.length; h++) {
      sum += hourly[h];
    }
    if (at.hour < hourly.length) {
      sum += (hourly[at.hour] * at.minute / 60).round();
    }
    return sum;
  }

  /// How today compares, or null when there is nothing honest to say.
  ///
  /// [lastWeekTotal] is last week's day total from the same source as the
  /// hourly buckets, so the coverage check compares like with like.
  static WeekOverWeek? compare({
    required int stepsToday,
    required DateTime now,
    required List<int> lastWeekHourly,
    required int? lastWeekTotal,
  }) {
    if (now.hour < earliestHour) return null;
    if (lastWeekHourly.length != 24 || lastWeekTotal == null || lastWeekTotal <= 0) {
      return null;
    }
    final recorded = lastWeekHourly.fold<int>(0, (a, b) => a + b);
    if (recorded < lastWeekTotal * minCoverage) return null;

    final soFar = stepsBy(lastWeekHourly, now);
    final diff = stepsToday - soFar;
    if (diff.abs() < minDifference) return null;
    return WeekOverWeek(diff, soFar);
  }
}
