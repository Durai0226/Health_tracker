/// What today's evening step reminder should say — and whether it should fire.
///
/// The reminder used to be one generic repeating notification, so it arrived at
/// 19:00 whether you had walked 3,000 steps or 14,000. It cannot read today's
/// steps when it fires (the alarm isolate has no database), so the answer is
/// worked out beforehand, whenever the app has fresh numbers:
///
///  * goal already met → nothing today, the repeating reminder starts tomorrow;
///  * not met, numbers fresh at fire time → "1,800 steps to go — about 18
///    minutes of walking";
///  * not met, numbers too old to quote → a generic line that does not claim a
///    figure;
///  * no step data at all → exactly the old behaviour.
///
/// A number is only ever quoted if it was measured within [freshness] of the
/// moment it will be read. A stale "1,800 to go" on a day you then walked 6,000
/// is worse than no number.
library;

import 'package:flutter/foundation.dart';

@immutable
class StepReminderPlan {
  /// A one-off for today, or null when none should fire today.
  final DateTime? todayAt;
  final String? todayBody;

  /// When the repeating daily reminder next fires.
  final DateTime repeatingFrom;

  const StepReminderPlan({
    required this.todayAt,
    required this.todayBody,
    required this.repeatingFrom,
  });
}

class StepReminderPlanner {
  const StepReminderPlanner._();

  /// A brisk walk, in steps a minute — used only to turn a shortfall into a time.
  static const int stepsPerMinute = 100;

  /// How old the step count may be, at fire time, and still be quoted.
  static const Duration freshness = Duration(minutes: 90);

  /// What the generic line says when no figure can be trusted.
  static const String genericBody =
      "If you haven't reached your step goal yet, a short walk could close it.";

  /// Whole minutes to walk [steps], at least one.
  static int walkMinutes(int steps) {
    final m = (steps / stepsPerMinute).ceil();
    return m < 1 ? 1 : m;
  }

  /// [steps] with thousands separators: 1800 → "1,800".
  static String groupThousands(int steps) {
    final s = steps.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  /// The plan for a reminder at [minuteOfDay] given the numbers, if any.
  ///
  /// [stepsAsOf] is when [stepsToday] was last read from a source; null means
  /// there is no real step data for today (an empty in-memory day is not data).
  static StepReminderPlan plan({
    required DateTime now,
    required int minuteOfDay,
    int? stepsToday,
    int? goal,
    DateTime? stepsAsOf,

    /// Today was marked as a rest or unwell day: the goal is paused, so there is
    /// nothing to nudge about.
    bool restDay = false,
  }) {
    final h = (minuteOfDay ~/ 60) % 24;
    final m = minuteOfDay % 60;
    final today = DateTime(now.year, now.month, now.day, h, m);
    final tomorrow = DateTime(now.year, now.month, now.day + 1, h, m);

    // Today's slot has gone by: tomorrow, as ever.
    if (!today.isAfter(now)) {
      return StepReminderPlan(
          todayAt: null, todayBody: null, repeatingFrom: tomorrow);
    }

    // A rest or unwell day: silent today, whatever the numbers say.
    if (restDay) {
      return StepReminderPlan(
          todayAt: null, todayBody: null, repeatingFrom: tomorrow);
    }

    // Nothing known about today: the old behaviour, a generic reminder that
    // starts today.
    if (stepsToday == null || goal == null || stepsAsOf == null) {
      return StepReminderPlan(
          todayAt: null, todayBody: null, repeatingFrom: today);
    }

    // Goal met: silent today.
    if (stepsToday >= goal) {
      return StepReminderPlan(
          todayAt: null, todayBody: null, repeatingFrom: tomorrow);
    }

    final fresh = today.difference(stepsAsOf) <= freshness;
    final togo = goal - stepsToday;
    return StepReminderPlan(
      todayAt: today,
      todayBody: fresh
          ? '${groupThousands(togo)} steps to go — about '
              '${walkMinutes(togo)} ${walkMinutes(togo) == 1 ? 'minute' : 'minutes'} '
              'of walking.'
          : genericBody,
      repeatingFrom: tomorrow,
    );
  }
}
