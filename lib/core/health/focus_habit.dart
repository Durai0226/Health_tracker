/// What someone usually does at this time of day — so the Focus screen can offer
/// it, once, instead of making them set it up again.
///
/// Pure Dart: no clock, no storage, no Flutter, and no feature types — the Focus
/// service maps its sessions onto [HabitSession] (an activity and a sound are
/// just their indexes here).
///
/// ## What counts, and how sure it has to be
///
/// Completed rounds that STARTED within an hour of now — an hour as an hour, to the
/// minute, going round midnight — in the last [FocusHabits.windowDays] days. Completed only: an abandoned round measures the
/// ambition, not what the person actually does at that hour (the same reasoning
/// `FocusInsights.suggestedMinutes` gives).
///
/// The most common activity has to be the clear winner — strictly more than any
/// other, and at least half of the rounds — and rest on [FocusHabits.minSessions]
/// rounds over [FocusHabits.minDays] different days. Two evenings of studying is
/// not a routine, and a 50/50 split between two activities is not one either;
/// naming one of them would be a guess in the voice of a fact. The length is the
/// middle one of that activity's rounds, to the nearest five minutes, and the
/// sound is named only if it was playing in at least half of them.
library;

import 'dart:math' as math;

import '../utils/calendar_day.dart';

/// One finished round, as far as this cares.
class HabitSession {
  const HabitSession({
    required this.startedAt,
    required this.minutes,
    required this.activity,
    this.sound,
    this.completed = true,
  });

  final DateTime startedAt;

  /// Minutes focused.
  final int minutes;

  /// Which activity, as an index. Only compared for equality.
  final int activity;

  /// Which ambient sound was playing, as an index; null for none.
  final int? sound;

  final bool completed;
}

/// A routine at this time of day.
class FocusHabit {
  const FocusHabit({
    required this.activity,
    required this.minutes,
    required this.sound,
    required this.times,
    required this.days,
    required this.total,
  });

  final int activity;

  /// The usual length, in steps of five.
  final int minutes;

  /// The sound that usually plays, or null when there is no usual one.
  final int? sound;

  /// How many rounds of this activity the habit rests on.
  final int times;

  /// On how many different days.
  final int days;

  /// How many rounds near this time were looked at in all, of any activity.
  final int total;
}

abstract final class FocusHabits {
  /// Fewest rounds of the winning activity.
  static const int minSessions = 4;

  /// Fewest different days they must be on.
  static const int minDays = 3;

  /// The share of the rounds near this time that the winning activity must be.
  static const double minShare = 0.5;

  /// How far back still counts as how they work.
  static const int windowDays = 60;

  /// How many minutes either side of now a round may have started.
  ///
  /// Minutes, not the hour of the clock: comparing hours made "within an hour"
  /// anything from nothing to nearly two — at 11:59 a round that began at 10:00
  /// counted, at 11:00 one that began at 09:59 did not.
  static const int minuteSpread = 60;

  /// Shorter than this is not a round worth offering.
  static const int minMinutes = 5;

  static const int maxMinutes = 120;

  /// The habit at [now]'s time of day, or null when there is none worth offering.
  static FocusHabit? at(Iterable<HabitSession> sessions, {required DateTime now}) {
    final since = dayOffset(now, -windowDays);
    final near = [
      for (final s in sessions)
        if (s.completed &&
            s.minutes >= minMinutes &&
            !s.startedAt.isBefore(since) &&
            !s.startedAt.isAfter(now) &&
            _minutesApart(_minuteOfDay(s.startedAt), _minuteOfDay(now)) <= minuteSpread)
          s
    ];
    if (near.length < minSessions) return null;

    final counts = <int, int>{};
    for (final s in near) {
      counts[s.activity] = (counts[s.activity] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.first;
    // A tie for first is not a winner.
    if (ranked.length > 1 && ranked[1].value == top.value) return null;
    if (top.value < near.length * minShare) return null;

    final mine = [for (final s in near) if (s.activity == top.key) s];
    if (mine.length < minSessions) return null;
    final days = _distinctDays(mine);
    if (days < minDays) return null;

    return FocusHabit(
      activity: top.key,
      minutes: _usualMinutes(mine),
      sound: _usualSound(mine),
      times: mine.length,
      days: days,
      total: near.length,
    );
  }

  static int _minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

  /// Minutes between two times of the day, going round midnight: 23:30 and 00:30
  /// are an hour apart.
  static int _minutesApart(int a, int b) {
    final d = (a - b).abs();
    return math.min(d, 24 * 60 - d);
  }

  static int _distinctDays(List<HabitSession> s) =>
      {for (final x in s) (x.startedAt.year, x.startedAt.month, x.startedAt.day)}
          .length;

  /// The middle length, to the nearest five minutes.
  static int _usualMinutes(List<HabitSession> s) {
    final m = [for (final x in s) x.minutes]..sort();
    final mid = m.length ~/ 2;
    final median = m.length.isOdd ? m[mid].toDouble() : (m[mid - 1] + m[mid]) / 2;
    return ((median / 5).round() * 5).clamp(minMinutes, maxMinutes);
  }

  /// The sound that was playing in at least half of [s] — and in clearly more of
  /// them than any other. Null otherwise.
  static int? _usualSound(List<HabitSession> s) {
    final counts = <int, int>{};
    for (final x in s) {
      final sound = x.sound;
      if (sound != null) counts[sound] = (counts[sound] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.first;
    if (ranked.length > 1 && ranked[1].value == top.value) return null;
    return top.value >= s.length * minShare ? top.key : null;
  }
}
