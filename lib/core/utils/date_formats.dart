import 'package:intl/intl.dart';

/// Shared, pre-built [DateFormat] instances.
///
/// Constructing a `DateFormat` is not free — it parses the skeleton pattern and
/// resolves locale symbols on every call. The vitals history lists were doing
/// `DateFormat('MMM d, h:mm a')` **inline in the row builder**, so a screen with
/// 200 readings built 200 formatters per rebuild, and rebuilt on every scroll,
/// filter change and log write.
///
/// These are `final` rather than `const` because `DateFormat` has no const
/// constructor. They are created once per isolate on first use.
///
/// Only add a pattern here if it is genuinely shared. A one-off format used in a
/// single non-repeating widget is fine inline — the cost only matters inside a
/// list/grid builder or anything that rebuilds often.
class DateFormats {
  DateFormats._();

  /// "Mar 14" — compact day label for chart axes and history grouping.
  static final dayMonth = DateFormat('MMM d');

  /// "Mar 14, 2025" — same, disambiguated when the year is not the current one.
  static final dayMonthYear = DateFormat('MMM d, yyyy');

  /// "Mar 14, 8:05 AM" — a reading's timestamp in a history row.
  static final dayMonthTime = DateFormat('MMM d, h:mm a');


  /// "8:05 AM" — a clock time. The most-used format in the app (dose slots,
  /// reminder times, pillbox cells, timeline rows).
  static final time = DateFormat('h:mm a');

  /// "8:05" and "AM" — the two halves, for layouts that style them differently.
  static final timeNoMeridiem = DateFormat('h:mm');
  static final meridiem = DateFormat('a');

  /// "M" / "Mon" / "Monday" — weekday at three widths.
  static final weekdayNarrow = DateFormat('E');
  static final weekdayShort = DateFormat('EEE');

  /// "Mon, Mar 14" and "Monday, March 14" — dated headers.
  static final weekdayDayMonthShort = DateFormat('EEE, MMM d');
  static final weekdayDayMonthLong = DateFormat('EEEE, MMMM d');
  static final weekdayDayMonthMedium = DateFormat('EEEE, MMM d');

  /// "Mon, Mar 14 at 8:05 AM"
  static final weekdayDayMonthTime = DateFormat('EEE, MMM d at h:mm a');

  /// "Mar 14 · 8:05 AM" — mid-dot variant used in log rows.
  static final dayMonthDotTime = DateFormat('MMM d · h:mm a');

  /// "14" — day-of-month only, for calendar cells.
  static final dayOfMonth = DateFormat('d');

  /// "3/14" — numeric short date for dense chart axes.
  static final numericShort = DateFormat('M/d');

  /// Picks [dayMonth] or [dayMonthYear] depending on whether [day] falls in the
  /// same year as [reference] (defaults to now). Replaces the
  /// `DateFormat(cond ? 'MMM d' : 'MMM d, yyyy')` pattern, which built a fresh
  /// formatter on every call.
  static String dayLabel(DateTime day, {DateTime? reference}) {
    final ref = reference ?? DateTime.now();
    return day.year == ref.year
        ? dayMonth.format(day)
        : dayMonthYear.format(day);
  }
}
