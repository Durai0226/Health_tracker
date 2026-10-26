/// Days the person said "I'm resting" or "I'm unwell", as plain data.
///
/// A step goal on a day with a fever is not a goal, and a streak that breaks
/// because of one is a streak that punishes being ill. Marking a day pauses the
/// goal for it: the steps streak skips it (like a vacation day, but for one day
/// and steps only), the evening reminder stays quiet, and the day is left out of
/// the figures the next goal is learned from — otherwise 400 steps on a sick day
/// would drag the following weeks' goals down.
///
/// Distinct from vacation mode on purpose: that is a span of days away that also
/// pauses reminders and freezes four streaks; this is one day, steps only.
library;

import 'package:flutter/foundation.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum RestKind {
  rest('Rest day'),
  unwell('Unwell');

  final String label;
  const RestKind(this.label);
}

@immutable
class RestDay {
  final DateTime day;
  final RestKind kind;
  RestDay(DateTime day, this.kind) : day = _day(day);

  /// `yyyy-MM-dd|kind`.
  String encode() => '${_key(day)}|${kind.name}';

  static RestDay? decode(String s) {
    final parts = s.split('|');
    if (parts.length != 2) return null;
    final d = DateTime.tryParse(parts[0]);
    final k = RestKind.values.where((v) => v.name == parts[1]).firstOrNull;
    return d == null || k == null ? null : RestDay(d, k);
  }

  @override
  bool operator ==(Object other) =>
      other is RestDay && other.day == day && other.kind == kind;

  @override
  int get hashCode => Object.hash(day, kind);
}

class RestDays {
  const RestDays._();

  /// How many days are kept. A streak reaches back only as far as its own run,
  /// and the goal looks back a few weeks; a year is generous.
  static const int keepDays = 400;

  static List<RestDay> decodeAll(Object? stored) {
    if (stored is! List) return const [];
    return [
      for (final s in stored)
        if (s is String) ?RestDay.decode(s),
    ];
  }

  static List<String> encodeAll(List<RestDay> days) =>
      [for (final d in days) d.encode()];

  /// [days] with [day] marked as [kind], replacing any earlier mark for that day,
  /// and anything older than [keepDays] before [today] dropped. Newest last.
  static List<RestDay> mark(
      List<RestDay> days, DateTime day, RestKind kind, {required DateTime today}) {
    final d = _day(day);
    final kept = [for (final r in days) if (r.day != d) r, RestDay(d, kind)];
    return _pruned(kept, today);
  }

  static List<RestDay> unmark(List<RestDay> days, DateTime day) {
    final d = _day(day);
    return [for (final r in days) if (r.day != d) r];
  }

  static RestKind? kindOn(List<RestDay> days, DateTime day) {
    final d = _day(day);
    for (final r in days) {
      if (r.day == d) return r.kind;
    }
    return null;
  }

  /// The marked days up to and including [today]: what a streak must skip. A
  /// future day is left out — nothing has been missed yet.
  static Set<DateTime> frozenDays(List<RestDay> days, DateTime today) {
    final t = _day(today);
    return {for (final r in days) if (!r.day.isAfter(t)) r.day};
  }

  static List<RestDay> _pruned(List<RestDay> days, DateTime today) {
    final cutoff = DateTime(today.year, today.month, today.day - keepDays);
    return [for (final r in days) if (!r.day.isBefore(cutoff)) r];
  }
}
