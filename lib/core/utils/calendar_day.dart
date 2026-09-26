/// Calendar-day arithmetic that survives DST.
///
/// A local civil day is 23 or 25 hours long across a daylight-saving
/// transition, so `d.add(const Duration(days: 1))` steps onto the *wrong*
/// calendar day exactly once per transition, and `a.difference(b).inDays`
/// truncates to one day fewer (spring forward) or reports one too many once
/// 25-hour spans accumulate. Both are elapsed-time operations being used to
/// answer a calendar question.
///
/// That off-by-one is load-bearing across this app: it has previously decided
/// whether a fixed-duration antibiotic course was still active, which days an
/// every-X-days medicine was reminded on, where a 21-on/7-off contraceptive
/// cycle sat, whether a streak survived, and whether "today" was visited at all
/// by a day-stepping loop (it is not: the cursor lands at 01:00 or 23:00 and
/// compares `isAfter` the midnight bound, so the loop exits one day early).
///
/// The fix in every case is the same: let the `DateTime` constructor normalise
/// an out-of-range `day` field against the local calendar, or anchor both ends
/// at UTC midnight before subtracting. This file is the one place that logic
/// lives; `test/core/dst_date_arithmetic_probe.dart` re-executes its callers
/// under `TZ=America/New_York` to keep it honest.
library;

/// Midnight at the start of [d]'s calendar day, in local time.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// The calendar day [n] days after [d] (negative [n] steps backwards), at
/// midnight local time.
///
/// Use this for every day-stepping loop and every "N days ago" window bound.
/// `DateTime(y, m, day + n)` normalises overflow across month, year and leap
/// boundaries, and re-resolves the local offset, so it is DST-safe where
/// `add(Duration(days: n))` is not.
DateTime dayOffset(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// The next calendar day at midnight — `dayOffset(d, 1)`.
DateTime nextDay(DateTime d) => dayOffset(d, 1);

/// The previous calendar day at midnight — `dayOffset(d, -1)`.
DateTime prevDay(DateTime d) => dayOffset(d, -1);

/// Midnight on the Monday of [d]'s week.
///
/// Normalises the time-of-day too: a week start that keeps `d`'s clock time
/// silently excludes rows on the first day of the week when compared against
/// midnight-normalised day keys (this is why the Focus "Week" overview
/// disagreed with the bar chart under it).
DateTime startOfWeek(DateTime d) {
  final day = startOfDay(d);
  return dayOffset(day, -(day.weekday - DateTime.monday));
}

/// The same wall-clock time, [n] calendar days away.
///
/// Unlike [dayOffset] this preserves hour/minute/second, and unlike
/// `add(Duration(days: n))` it preserves them *across a DST transition*: "I
/// went to bed at 23:00 the previous evening" must stay 23:00, not become
/// 22:00 because the intervening civil day was only 23 hours long. Use this
/// wherever a clock time is being moved to another date — a bedtime shifted to
/// the evening before, a reminder placed N days before a predicted event.
DateTime shiftCalendarDays(DateTime d, int n) => DateTime(d.year, d.month,
    d.day + n, d.hour, d.minute, d.second, d.millisecond, d.microsecond);

/// Whole CALENDAR days from [from] to [to], time-of-day ignored.
///
/// Positive when [to] is later. Anchoring both ends at UTC midnight removes
/// DST from the subtraction entirely while preserving the civil date, which is
/// what "how many days apart are these two dates" actually means.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// Whether [a] and [b] fall on the same calendar day.
bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
