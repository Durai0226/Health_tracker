/// Which days a visit brief covers, and when to say it is ready.
///
/// "Since your last visit" is the question a clinician asks, so that is the
/// window when there was a last visit with the same doctor — kept between a week
/// and ninety days, because a few days is too little to say anything and a year
/// is too much to read. With no earlier visit it is the last thirty days.
library;

class VisitBriefWindow {
  const VisitBriefWindow({required this.from, required this.to, this.sinceVisit});

  final DateTime from;
  final DateTime to;

  /// The earlier visit the window begins at, or null when it is just the last
  /// [days] days.
  final DateTime? sinceVisit;

  int get days => to.difference(from).inDays;
}

class VisitBriefs {
  const VisitBriefs._();

  /// Without an earlier visit, or when it was too long ago to be one window.
  static const int defaultDays = 30;

  /// Shorter than this says nothing.
  static const int minDays = 7;

  /// Longer than this is not read.
  static const int maxDays = 90;

  /// The brief is announced this long before the visit, at [notifyHour].
  static const int leadDays = 2;
  static const int notifyHour = 9;

  /// The window for a visit at [visitAt], read at [now].
  ///
  /// [earlierVisits] are visits with the same doctor for the same person. The
  /// last of them before both [visitAt] and [now] begins the window — from the
  /// start of its day, so what was logged that afternoon is in it — when that is
  /// between [minDays] and [maxDays] ago; otherwise it is the last [defaultDays]
  /// (or [minDays], or [maxDays]) days and says no more than that.
  static VisitBriefWindow window({
    required DateTime visitAt,
    required DateTime now,
    Iterable<DateTime> earlierVisits = const [],
  }) {
    DateTime? last;
    for (final v in earlierVisits) {
      if (v.isBefore(visitAt) && !v.isAfter(now) && (last == null || v.isAfter(last))) {
        last = v;
      }
    }
    if (last == null) {
      return VisitBriefWindow(from: _daysBefore(now, defaultDays), to: now);
    }
    final since = DateTime(last.year, last.month, last.day);
    final ago = now.difference(since).inDays;
    if (ago < minDays) {
      return VisitBriefWindow(from: _daysBefore(now, minDays), to: now);
    }
    if (ago > maxDays) {
      return VisitBriefWindow(from: _daysBefore(now, maxDays), to: now);
    }
    return VisitBriefWindow(from: since, to: now, sinceVisit: last);
  }

  /// When the "your brief is ready" notice goes for a visit at [visitAt]: 9:00,
  /// [leadDays] days before — or null when that moment has already passed, as it
  /// has for a visit booked at short notice.
  static DateTime? notifyAt({required DateTime visitAt, required DateTime now}) {
    final t = DateTime(visitAt.year, visitAt.month, visitAt.day - leadDays, notifyHour);
    return t.isAfter(now) ? t : null;
  }

  static DateTime _daysBefore(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day - days, d.hour, d.minute);
}
