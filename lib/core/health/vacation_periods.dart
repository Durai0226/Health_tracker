/// Vacation periods as plain data: when the user said "I'm away", and what that
/// means for a given day.
///
/// Kept as a LIST of periods rather than one current flag because a holiday has
/// to keep protecting the streak it covered after it is over. If ending a
/// vacation forgot it, the streak would break retroactively the moment the user
/// came home, which is exactly what freezing is meant to prevent.
library;

import 'package:flutter/foundation.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Whole calendar days, both ends included.
@immutable
class VacationPeriod {
  final DateTime start;
  final DateTime end;

  VacationPeriod(DateTime start, DateTime end)
      : start = _day(start),
        end = _day(end);

  bool covers(DateTime d) {
    final x = _day(d);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  /// `yyyy-MM-dd|yyyy-MM-dd`.
  String encode() => '${_key(start)}|${_key(end)}';

  static VacationPeriod? decode(String s) {
    final parts = s.split('|');
    if (parts.length != 2) return null;
    final a = DateTime.tryParse(parts[0]);
    final b = DateTime.tryParse(parts[1]);
    if (a == null || b == null || b.isBefore(a)) return null;
    return VacationPeriod(a, b);
  }

  @override
  bool operator ==(Object other) =>
      other is VacationPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'VacationPeriod(${encode()})';
}

class VacationPeriods {
  const VacationPeriods._();

  /// Periods kept. Years of history are not needed: a streak reaches back only
  /// as far as its own run.
  static const int maxKept = 24;

  static List<VacationPeriod> decodeAll(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final s in raw)
        if (VacationPeriod.decode(s.toString()) case final p?) p,
    ];
  }

  static List<String> encodeAll(List<VacationPeriod> periods) =>
      [for (final p in periods) p.encode()];

  /// The period covering [today], if the user is away right now.
  static VacationPeriod? active(List<VacationPeriod> periods, DateTime today) {
    for (final p in periods) {
      if (p.covers(today)) return p;
    }
    return null;
  }

  /// Start a vacation from [from] (default today) to [until] inclusive.
  ///
  /// Overlapping or touching periods are merged into one, and the list is kept
  /// to [maxKept], oldest dropped.
  static List<VacationPeriod> add(List<VacationPeriod> periods,
      {required DateTime from, required DateTime until}) {
    var start = _day(from);
    var end = _day(until);
    if (end.isBefore(start)) end = start;

    final rest = <VacationPeriod>[];
    for (final p in periods) {
      final touches = !p.end.isBefore(DateTime(start.year, start.month, start.day - 1)) &&
          !p.start.isAfter(DateTime(end.year, end.month, end.day + 1));
      if (touches) {
        if (p.start.isBefore(start)) start = p.start;
        if (p.end.isAfter(end)) end = p.end;
      } else {
        rest.add(p);
      }
    }
    final all = [...rest, VacationPeriod(start, end)]
      ..sort((a, b) => a.start.compareTo(b.start));
    return all.length <= maxKept ? all : all.sublist(all.length - maxKept);
  }

  /// End the vacation covering [today] early: it stops being a holiday from
  /// today on. A period that starts today is removed outright (it never
  /// happened); otherwise it is cut to end yesterday, so the days already spent
  /// away stay frozen.
  static List<VacationPeriod> endEarly(
      List<VacationPeriod> periods, DateTime today) {
    final t = _day(today);
    final out = <VacationPeriod>[];
    for (final p in periods) {
      if (!p.covers(t)) {
        out.add(p);
      } else if (p.start.isBefore(t)) {
        out.add(VacationPeriod(p.start, DateTime(t.year, t.month, t.day - 1)));
      }
    }
    return out;
  }

  /// Every vacation day up to and including [today]. These are the days a streak
  /// must skip. Future days are left out: nothing has been missed yet.
  static Set<DateTime> frozenDays(List<VacationPeriod> periods, DateTime today) {
    final t = _day(today);
    final out = <DateTime>{};
    for (final p in periods) {
      for (var d = p.start;
          !d.isAfter(p.end) && !d.isAfter(t);
          d = DateTime(d.year, d.month, d.day + 1)) {
        out.add(d);
      }
    }
    return out;
  }

  /// Whether [instant] falls on a vacation day.
  static bool coversInstant(List<VacationPeriod> periods, DateTime instant) =>
      periods.any((p) => p.covers(instant));
}
