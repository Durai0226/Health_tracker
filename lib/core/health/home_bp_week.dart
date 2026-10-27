/// A guided week of home blood-pressure readings that ends in an average a
/// doctor can use.
///
/// Pure Dart. The protocol home-monitoring guidance (AHA, ESC) asks for: seven
/// days, a reading session each morning and each evening (a session is the
/// couple of readings a minute apart the app already averages), the first day
/// left out because people are not yet settled into it, and the average taken
/// over the rest.
///
/// It describes the readings and which range the average falls in. It does not
/// diagnose, and the cut-offs are the ones the rest of the app uses; a doctor
/// may read a home average against slightly lower ones.
library;

import 'vitals_analyzer.dart';

/// One blood-pressure session: the time of its first reading and its average.
class HomeBpSample {
  const HomeBpSample(this.at, this.systolic, this.diastolic);

  final DateTime at;
  final int systolic;
  final int diastolic;

  /// Morning is before noon, as everywhere else BP is split by time of day.
  bool get isMorning => at.hour < 12;
}

/// One day of the week and which of its two sessions were taken.
class HomeBpDay {
  const HomeBpDay({
    required this.number,
    required this.date,
    required this.morningDone,
    required this.eveningDone,
  });

  /// 1 to 7.
  final int number;
  final DateTime date;
  final bool morningDone;
  final bool eveningDone;
}

/// The average so far, or at the end.
class HomeBpSummary {
  const HomeBpSummary({
    required this.sessions,
    required this.days,
    required this.enough,
    this.systolic,
    this.diastolic,
    this.morning,
    this.evening,
  });

  /// Sessions counted (the first day's are left out) and the days they fall on.
  final int sessions;
  final int days;

  /// Enough to call it a home average: [HomeBpWeek.minDays] days and
  /// [HomeBpWeek.minSessions] sessions. Anything less is "so far".
  final bool enough;

  final int? systolic;
  final int? diastolic;

  /// Morning-only and evening-only averages as "128/78", when there are any.
  final String? morning;
  final String? evening;

  BpCategory? get category => systolic == null
      ? null
      : VitalsAnalyzer.classifyBp(systolic!, diastolic!);

  String? get average => systolic == null ? null : '$systolic/$diastolic';
}

/// Where the week stands.
class HomeBpProgress {
  const HomeBpProgress({
    required this.start,
    required this.dayNumber,
    required this.ended,
    required this.days,
    required this.summary,
    this.due,
  });

  final DateTime start;

  /// Today's day of the week, 1 to 7; 7 once it has [ended] (never past it).
  final int dayNumber;

  /// Past day 7.
  final bool ended;

  final List<HomeBpDay> days;
  final HomeBpSummary summary;

  /// The session that is due now and not yet taken: the morning one before noon,
  /// the evening one after it. Null when today's is done, or the week is over.
  final HomeBpSlot? due;

  /// Sessions taken so far, first day included.
  int get taken =>
      days.fold(0, (n, d) => n + (d.morningDone ? 1 : 0) + (d.eveningDone ? 1 : 0));
}

enum HomeBpSlot { morning, evening }

class HomeBpWeek {
  const HomeBpWeek._();

  static const int length = 7;

  /// Days that must carry a counted session, and sessions in all, before the
  /// result is a home average rather than "so far": four days of two.
  static const int minDays = 4;
  static const int minSessions = 8;

  /// Where a week that began on [start] stands at [now], given [sessions].
  static HomeBpProgress progress({
    required DateTime start,
    required Iterable<HomeBpSample> sessions,
    required DateTime now,
  }) {
    final first = _day(start);
    final last = _addDays(first, length - 1);
    final today = _day(now);
    final inWeek = [
      for (final s in sessions)
        if (!_day(s.at).isBefore(first) && !_day(s.at).isAfter(last)) s,
    ];

    final days = <HomeBpDay>[];
    for (var i = 0; i < length; i++) {
      final date = _addDays(first, i);
      final onDay = inWeek.where((s) => _day(s.at) == date);
      days.add(HomeBpDay(
        number: i + 1,
        date: date,
        morningDone: onDay.any((s) => s.isMorning),
        eveningDone: onDay.any((s) => !s.isMorning),
      ));
    }

    final ended = today.isAfter(last);
    final number = ended
        ? length
        : (_daysBetween(first, today) + 1).clamp(1, length).toInt();

    HomeBpSlot? due;
    if (!ended && !today.isBefore(first)) {
      final d = days[number - 1];
      if (now.hour < 12) {
        if (!d.morningDone) due = HomeBpSlot.morning;
      } else if (!d.eveningDone) {
        due = HomeBpSlot.evening;
      }
    }

    return HomeBpProgress(
      start: first,
      dayNumber: number,
      ended: ended,
      days: days,
      summary: _summarise(inWeek, first),
      due: due,
    );
  }

  static HomeBpSummary _summarise(List<HomeBpSample> inWeek, DateTime first) {
    // The first day is left out.
    final counted = [
      for (final s in inWeek)
        if (_day(s.at) != first) s,
    ];
    final days = {for (final s in counted) _day(s.at)}.length;
    if (counted.isEmpty) {
      return const HomeBpSummary(sessions: 0, days: 0, enough: false);
    }
    String? avgOf(Iterable<HomeBpSample> v) {
      final list = v.toList();
      if (list.isEmpty) return null;
      final sys = _mean(list.map((s) => s.systolic));
      final dia = _mean(list.map((s) => s.diastolic));
      return '$sys/$dia';
    }

    return HomeBpSummary(
      sessions: counted.length,
      days: days,
      enough: days >= minDays && counted.length >= minSessions,
      systolic: _mean(counted.map((s) => s.systolic)),
      diastolic: _mean(counted.map((s) => s.diastolic)),
      morning: avgOf(counted.where((s) => s.isMorning)),
      evening: avgOf(counted.where((s) => !s.isMorning)),
    );
  }

  static int _mean(Iterable<int> v) {
    final list = v.toList();
    return (list.reduce((a, b) => a + b) / list.length).round();
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;
}
