/// When "Time to focus" should next fire, decided from the person's own history.
///
/// A fixed 9:00 reminder fires at the wrong time for almost everyone and keeps
/// firing after they have already focused. This plans ONE nudge at a time:
///
///  * ten minutes before the hour they actually focus best;
///  * only on weekdays they usually focus (at least twice in the last four
///    weeks), so a Sunday non-focuser is not nagged on Sundays;
///  * skipped for today once they have focused today, so it stays quiet;
///  * re-planned after every session, which is why it is a one-shot rather than
///    a repeating alarm.
library;

class FocusNudgePlanner {
  const FocusNudgePlanner._();

  /// How long before the best hour the nudge fires.
  static const int leadMinutes = 10;

  /// How far back "usually" looks.
  static const int lookbackDays = 28;

  /// Days a weekday must have been focused on within the lookback to count as
  /// one the person usually focuses on.
  static const int usualMinDays = 2;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Weekdays (`DateTime.monday`..`sunday`) with at least [usualMinDays]
  /// distinct focused days in the last [lookbackDays], today included.
  static Set<int> usualWeekdays(List<DateTime> focusedAt, DateTime now) {
    final today = _day(now);
    final from = DateTime(today.year, today.month, today.day - (lookbackDays - 1));
    final daysByWeekday = <int, Set<DateTime>>{};
    for (final t in focusedAt) {
      final d = _day(t);
      if (d.isBefore(from) || d.isAfter(today)) continue;
      (daysByWeekday[d.weekday] ??= {}).add(d);
    }
    return {
      for (final e in daysByWeekday.entries)
        if (e.value.length >= usualMinDays) e.key,
    };
  }

  /// The next nudge time, or null when there is no best hour to aim at.
  ///
  /// [focusedAt] are the start times of COMPLETED sessions. [bestHour] is the
  /// hour (0–23) with the most accumulated focus, or null with too little
  /// history, in which case the caller keeps its fixed daily reminder.
  static DateTime? next({
    required DateTime now,
    required int? bestHour,
    required List<DateTime> focusedAt,
  }) {
    if (bestHour == null || bestHour < 0 || bestHour > 23) return null;
    final today = _day(now);
    final focusedToday = focusedAt.any((t) => _day(t) == today);
    final usual = usualWeekdays(focusedAt, now);

    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(today.year, today.month, today.day + offset);
      if (offset == 0 && focusedToday) continue;
      // With no pattern yet every day is a candidate, rather than never nudging.
      if (usual.isNotEmpty && !usual.contains(day.weekday)) continue;
      // Wall-clock arithmetic through the constructor, so a DST change cannot
      // shift it an hour.
      final at = DateTime(day.year, day.month, day.day, bestHour, -leadMinutes);
      if (at.isAfter(now)) return at;
    }
    return null;
  }
}
