import 'package:rrule/rrule.dart';

import 'reminder_model.dart' show RepeatType;

/// What the reminder form can do with a repeat it did not write.
///
/// Smart Add turns "every 3 days" or "every other Tuesday" into an RFC 5545 rule
/// the six-value repeat dropdown cannot express. The form used to carry it
/// through save untouched and show "Does not repeat" beside it, so a reminder
/// that repeats read as one that does not, and the only way to change it was to
/// throw it away.
///
/// This reads the rule so the form can say what it is and offer the one change
/// that is always safe: how many days, weeks, months or years apart. Everything
/// else the rule carries — which weekday, a count, an end date — is kept exactly.
class ReminderRuleEdit {
  const ReminderRuleEdit._();

  /// Further apart than this is not a reminder, it is a calendar.
  static const int maxInterval = 365;

  /// What [rule] repeats by, or null when it cannot be read or is finer than a
  /// day (the app has no hourly reminders, and the stepper would be a lie).
  static ({Frequency frequency, int interval})? read(String? rule) {
    if (rule == null || rule.trim().isEmpty) return null;
    try {
      final parsed = RecurrenceRule.fromString(rule);
      final f = parsed.frequency;
      if (f != Frequency.daily &&
          f != Frequency.weekly &&
          f != Frequency.monthly &&
          f != Frequency.yearly) {
        return null;
      }
      return (frequency: f, interval: parsed.actualInterval);
    } catch (_) {
      return null;
    }
  }

  /// [rule], but every [interval] units apart. Everything else it says is kept.
  /// Null when the rule cannot be read.
  static String? withInterval(String rule, int interval) {
    final read = ReminderRuleEdit.read(rule);
    if (read == null) return null;
    final n = interval.clamp(1, maxInterval);
    final parsed = RecurrenceRule.fromString(rule);
    return n == 1
        ? parsed.copyWith(clearInterval: true).toString()
        : parsed.copyWith(interval: n).toString();
  }

  /// Whether [rule] says nothing but how far apart — no weekday, no day of the
  /// month — so that the headline ("Every 3 days") is all there is to tell.
  static bool isPlain(String rule) {
    try {
      final r = RecurrenceRule.fromString(rule);
      return !(r.hasBySeconds ||
          r.hasByMinutes ||
          r.hasByHours ||
          r.hasByWeekDays ||
          r.hasByMonthDays ||
          r.hasByYearDays ||
          r.hasByWeeks ||
          r.hasByMonths ||
          r.hasBySetPositions);
    } catch (_) {
      return false;
    }
  }

  /// The standard repeat nearest to [rule], for "use a standard repeat instead":
  /// daily for anything counted in days, weekly for anything in weeks, and none
  /// for the rest — there is no standard "monthly on the 15th", so the person
  /// chooses rather than being given a guess.
  static RepeatType closestStandard(String? rule) {
    final r = read(rule);
    if (r == null) return RepeatType.none;
    if (r.frequency == Frequency.daily) return RepeatType.daily;
    if (r.frequency == Frequency.weekly) return RepeatType.weekly;
    return RepeatType.none;
  }

  /// "day", "week", "month" or "year", in the plural unless there is exactly one.
  static String unit(Frequency f, int n) {
    final base = f == Frequency.daily
        ? 'day'
        : f == Frequency.weekly
            ? 'week'
            : f == Frequency.monthly
                ? 'month'
                : 'year';
    return n == 1 ? base : '${base}s';
  }

  /// "Every day", "Every 3 days", "Every other week", "Every 6 months".
  static String say(Frequency f, int n) {
    if (n == 1) return 'Every ${unit(f, 1)}';
    if (n == 2) return 'Every other ${unit(f, 1)}';
    return 'Every $n ${unit(f, n)}';
  }
}
