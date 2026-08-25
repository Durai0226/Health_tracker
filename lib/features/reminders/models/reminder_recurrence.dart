import 'package:rrule/rrule.dart';

import 'reminder_model.dart';

/// How a reminder repeats — the legacy six-value [RepeatType] and RFC 5545
/// `RRULE` behind one interface.
///
/// The old enum could express daily, weekly, weekdays, weekends and a
/// day-of-week set, and nothing else. No "every other Tuesday", no monthly, no
/// "last Friday", no end date, no occurrence count — all of which every
/// comparable app has had for years.
///
/// ## The floating-time convention, which is the whole reason this class exists
///
/// A reminder is a **wall-clock promise**: 08:00 means 08:00, whatever the UTC
/// offset happens to be that day. The `rrule` package requires every `DateTime`
/// to have `isUtc: true` and states plainly that it "doesn't care about any
/// time-zone-related stuff".
///
/// Naively converting local→UTC before generating and back after would reproduce
/// the exact DST bug `ReminderHelper` was just fixed for: across a transition the
/// UTC offset changes, so 08:00 local becomes 07:00 or 09:00 local.
///
/// Instead the local Y/M/D/h/m are *relabelled* as UTC — same numbers, different
/// flag — passed through the generator, and relabelled back. The arithmetic
/// therefore never touches a real zone and cannot gain or lose an hour. This is
/// the standard "floating time" treatment for calendar recurrences, and it is
/// pinned by `test/core/dst_date_arithmetic_probe.dart`, which re-runs under
/// `TZ=America/New_York`.
class ReminderRecurrence {
  const ReminderRecurrence._(this._rule, this._legacy, this._legacyDays);

  /// An RFC 5545 rule.
  factory ReminderRecurrence.rrule(RecurrenceRule rule) =>
      ReminderRecurrence._(rule, null, null);

  /// The pre-RRULE representation, still what most stored reminders use.
  factory ReminderRecurrence.legacy(RepeatType type, [List<int>? customDays]) =>
      ReminderRecurrence._(null, type, customDays);

  /// Parse a stored `RRULE:` string, falling back to [legacy] if it is absent or
  /// unparseable.
  ///
  /// Never throws: a rule string written by a newer build, or corrupted, must
  /// degrade to the reminder still repeating on its old schedule rather than to
  /// a crash on the reminders list.
  factory ReminderRecurrence.parse(
    String? rruleText, {
    required RepeatType fallback,
    List<int>? fallbackDays,
  }) {
    if (rruleText == null || rruleText.trim().isEmpty) {
      return ReminderRecurrence.legacy(fallback, fallbackDays);
    }
    try {
      return ReminderRecurrence.rrule(RecurrenceRule.fromString(rruleText));
    } catch (_) {
      return ReminderRecurrence.legacy(fallback, fallbackDays);
    }
  }

  final RecurrenceRule? _rule;
  final RepeatType? _legacy;
  final List<int>? _legacyDays;

  bool get isRrule => _rule != null;

  /// Whether this repeats at all.
  bool get repeats => isRrule || (_legacy != null && _legacy != RepeatType.none);

  /// The `RRULE:` string to store, or null for a legacy rule.
  String? get asStoredString => _rule?.toString();

  /// Relabel a local wall clock as UTC without shifting it. See the class doc.
  static DateTime _toFloating(DateTime local) => DateTime.utc(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      );

  /// The inverse of [_toFloating].
  static DateTime _fromFloating(DateTime floating) => DateTime(
        floating.year,
        floating.month,
        floating.day,
        floating.hour,
        floating.minute,
        floating.second,
        floating.millisecond,
        floating.microsecond,
      );

  /// The first occurrence strictly after [after], counting from [start].
  ///
  /// Returns null when the rule has run out — an `UNTIL` in the past, a `COUNT`
  /// already exhausted. A null here means "stop scheduling", not "error".
  DateTime? nextAfter({required DateTime start, required DateTime after}) {
    if (!repeats) return null;
    if (_rule != null) {
      final floatingStart = _toFloating(start);
      final floatingAfter = _toFloating(after);
      // `take` bounds the search: an exhausted COUNT/UNTIL yields an empty
      // iterable rather than spinning.
      for (final instance in _rule.getInstances(start: floatingStart)) {
        if (instance.isAfter(floatingAfter)) return _fromFloating(instance);
      }
      return null;
    }
    return _legacyNextAfter(start: start, after: after);
  }

  /// Up to [limit] occurrences from [start] onwards, for a preview.
  List<DateTime> preview({required DateTime start, int limit = 5}) {
    if (!repeats) return const [];
    if (_rule != null) {
      return _rule
          .getInstances(start: _toFloating(start))
          .take(limit)
          .map(_fromFloating)
          .toList();
    }
    final out = <DateTime>[];
    var cursor = start;
    for (var i = 0; i < limit; i++) {
      final next = _legacyNextAfter(start: start, after: cursor);
      if (next == null) break;
      out.add(next);
      cursor = next;
    }
    return out;
  }

  /// A human-readable summary, e.g. "Every other week on Tuesday".
  ///
  /// `RecurrenceRule.toText` needs localised strings loaded, and cannot express
  /// every rule; both failures fall back to the raw rule string rather than
  /// showing nothing.
  Future<String> describe() async {
    if (_rule == null) return _legacyLabel();
    try {
      final l10n = await RruleL10nEn.create();
      return _rule.toText(l10n: l10n);
    } catch (_) {
      return _rule.toString();
    }
  }

  String _legacyLabel() {
    switch (_legacy) {
      case RepeatType.daily:
        return 'Every day';
      case RepeatType.weekly:
        return 'Every week';
      case RepeatType.weekdays:
        return 'Weekdays';
      case RepeatType.weekends:
        return 'Weekends';
      case RepeatType.custom:
        final days = _legacyDays ?? const [];
        if (days.isEmpty) return 'Custom';
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final sorted = [...days]..sort();
        return sorted.map((d) => names[(d - 1).clamp(0, 6)]).join(', ');
      case RepeatType.none:
      case null:
        return 'Does not repeat';
    }
  }

  /// Calendar-day stepping for the legacy types.
  ///
  /// Deliberately not `add(Duration(days: n))` — a Duration is n × 24 absolute
  /// hours, so adding one across a DST boundary moves an 08:00 reminder to 07:00
  /// or 09:00, and each occurrence inherits the drift from the last.
  static DateTime _addDays(DateTime from, int days) => DateTime(
        from.year,
        from.month,
        from.day + days,
        from.hour,
        from.minute,
        from.second,
        from.millisecond,
        from.microsecond,
      );

  DateTime? _legacyNextAfter({required DateTime start, required DateTime after}) {
    var cursor = start;
    // Bounded: two years of daily steps is far past any sane schedule, and an
    // unbounded loop here would hang the reminders list rather than fail.
    for (var i = 0; i < 800; i++) {
      cursor = _legacyStep(cursor);
      if (cursor.isAfter(after)) return cursor;
    }
    return null;
  }

  DateTime _legacyStep(DateTime current) {
    switch (_legacy) {
      case RepeatType.daily:
        return _addDays(current, 1);
      case RepeatType.weekly:
        return _addDays(current, 7);
      case RepeatType.weekdays:
        // Fri→Mon (+3), Sat→Mon (+2), Sun→Mon (+1), else next day.
        return current.weekday >= DateTime.friday
            ? _addDays(current, 8 - current.weekday)
            : _addDays(current, 1);
      case RepeatType.weekends:
        if (current.weekday == DateTime.saturday) return _addDays(current, 1);
        if (current.weekday == DateTime.sunday) return _addDays(current, 6);
        final untilSat = DateTime.saturday - current.weekday;
        return _addDays(current, untilSat > 0 ? untilSat : untilSat + 7);
      case RepeatType.custom:
        final days = _legacyDays;
        if (days == null || days.isEmpty) return _addDays(current, 1);
        var probe = current;
        for (var i = 0; i < 14; i++) {
          probe = _addDays(probe, 1);
          if (days.contains(probe.weekday)) return probe;
        }
        return _addDays(current, 1);
      case RepeatType.none:
      case null:
        return current;
    }
  }
}
