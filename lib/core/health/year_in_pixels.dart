/// A year of moods, one square per day.
///
/// A 12 × 31 grid — a row per month, a column per day-of-month — coloured by how
/// the day felt, with a dot on days of a period. It is the one view that shows a
/// whole year at once, so a run of bad days in February or a good summer is a
/// shape rather than a number.
///
/// A day with several entries is their mean, rounded to the nearest of the five
/// moods; a day with none is blank, never "neutral" — leaving it out is not the
/// same as feeling fine.
library;

import 'package:flutter/foundation.dart';

import '../utils/calendar_day.dart';

/// One mood entry, as the grid needs it. [moodIndex] is 0 = Great … 4 = Terrible,
/// the order the app stores.
@immutable
class PixelMood {
  final DateTime at;
  final int moodIndex;
  const PixelMood(this.at, this.moodIndex);
}

@immutable
class PixelDay {
  final DateTime date;

  /// The day's mood as 0..4, or null when nothing was logged.
  final int? mood;

  /// How many entries went into [mood].
  final int entries;
  final bool period;

  const PixelDay(this.date, {this.mood, this.entries = 0, this.period = false});

  bool get logged => mood != null;
}

@immutable
class PixelYear {
  final int year;

  /// `months[m][d]` is the day `d + 1` of month `m + 1`, or null when that date
  /// does not exist (30 February, 31 April).
  final List<List<PixelDay?>> months;

  const PixelYear(this.year, this.months);

  Iterable<PixelDay> get days sync* {
    for (final m in months) {
      for (final d in m) {
        if (d != null) yield d;
      }
    }
  }

  int get loggedDays => days.where((d) => d.logged).length;
  bool get hasPeriod => days.any((d) => d.period);

  /// How many days landed on each of the five moods.
  List<int> get distribution {
    final out = List<int>.filled(5, 0);
    for (final d in days) {
      final m = d.mood;
      if (m != null) out[m]++;
    }
    return out;
  }
}

class YearInPixels {
  const YearInPixels._();

  /// The grid for [year] from [moods] and the dates of [periodDays].
  ///
  /// Entries outside [year] are ignored, and an out-of-range mood is clamped
  /// rather than thrown on — a bad row must not blank a year.
  static PixelYear build({
    required int year,
    required Iterable<PixelMood> moods,
    Iterable<DateTime> periodDays = const [],
  }) {
    final sums = <DateTime, int>{};
    final counts = <DateTime, int>{};
    for (final m in moods) {
      if (m.at.year != year) continue;
      final day = DateTime(m.at.year, m.at.month, m.at.day);
      sums[day] = (sums[day] ?? 0) + m.moodIndex.clamp(0, 4);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    final period = {
      for (final p in periodDays)
        if (p.year == year) DateTime(p.year, p.month, p.day),
    };

    final months = <List<PixelDay?>>[];
    for (var month = 1; month <= 12; month++) {
      final length = DateTime(year, month + 1, 0).day;
      months.add([
        for (var d = 1; d <= 31; d++)
          if (d > length)
            null
          else
            _day(DateTime(year, month, d), sums, counts, period),
      ]);
    }
    return PixelYear(year, months);
  }

  static PixelDay _day(DateTime date, Map<DateTime, int> sums,
      Map<DateTime, int> counts, Set<DateTime> period) {
    final n = counts[date];
    return PixelDay(
      date,
      mood: n == null ? null : (sums[date]! / n).round().clamp(0, 4),
      entries: n ?? 0,
      period: period.contains(date),
    );
  }

  /// The years that have anything logged, newest first, always including
  /// [current] so the grid opens somewhere.
  static List<int> yearsWith(Iterable<PixelMood> moods, {required int current}) {
    final out = {current, for (final m in moods) m.at.year}.toList()
      ..sort((a, b) => b.compareTo(a));
    return out;
  }

  /// Whether [date] is after [today] — a square that has not happened yet.
  static bool isFuture(DateTime date, DateTime today) =>
      calendarDaysBetween(DateTime(today.year, today.month, today.day), date) > 0;
}
