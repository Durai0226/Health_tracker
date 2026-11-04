/// "6 of 9 active hours": how many hours of the day had real walking in them.
///
/// An hour is active when it holds at least [threshold] steps — the figure
/// activity trackers commonly use for "you moved this hour" — and the day is
/// asked for [target] such hours. Both are rules of thumb, not a medical
/// standard; the card says so.
///
/// It says nothing unless it can stand behind the figure. The hourly buckets are
/// filled only while the app syncs with a health app during the day, so a day
/// synced at 3 pm has a morning and nothing after it, and "2 of 9" read off that
/// would be false. The same guard [WeekOverWeekCalc] uses: the buckets must
/// account for most of the day's steps.
library;

import 'package:flutter/foundation.dart';

@immutable
class ActiveHours {
  /// One entry per hour of the day, true when that hour reached the threshold.
  final List<bool> hours;

  const ActiveHours(this.hours);

  int get count => hours.where((h) => h).length;

  int get target => ActiveHoursCalc.target;

  bool get reached => count >= target;
}

class ActiveHoursCalc {
  const ActiveHoursCalc._();

  /// Steps in an hour for it to count as active.
  static const int threshold = 250;

  /// Active hours asked of a day.
  static const int target = 9;

  /// The hourly buckets must add up to at least this much of the day's steps, or
  /// they are a partial record and nothing is said.
  static const double minCoverage = 0.85;

  /// Today's active hours, or null when there is nothing honest to say.
  ///
  /// [hourly] is the 24 hourly buckets and [sensorTotal] the day's total from the
  /// same source, so the coverage check compares like with like. Steps typed in
  /// by hand are in neither.
  static ActiveHours? compute({
    required List<int> hourly,
    required int? sensorTotal,
  }) {
    if (hourly.length != 24 || sensorTotal == null || sensorTotal <= 0) {
      return null;
    }
    final recorded = hourly.fold<int>(0, (a, b) => a + b);
    if (recorded < sensorTotal * minCoverage) return null;
    return ActiveHours([for (final steps in hourly) steps >= threshold]);
  }
}
