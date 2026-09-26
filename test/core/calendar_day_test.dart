// Unit tests for the shared calendar-day helpers.
//
// These run in whatever zone the host is in, so they cannot themselves prove
// the DST property — that is what test/core/dst_date_arithmetic_test.dart's
// out-of-process probe under TZ=America/New_York is for. What they DO pin is
// the calendar semantics that must hold in every zone: month, year and leap
// boundaries, week starts, and the sign/symmetry of the day difference.

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/utils/calendar_day.dart';

void main() {
  group('dayOffset', () {
    test('steps across a month boundary', () {
      expect(dayOffset(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
      expect(dayOffset(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });

    test('steps across a year boundary', () {
      expect(dayOffset(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(dayOffset(DateTime(2027, 1, 1), -1), DateTime(2026, 12, 31));
    });

    test('lands on Feb 29 in a leap year and skips it otherwise', () {
      expect(dayOffset(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
      expect(dayOffset(DateTime(2028, 2, 29), 1), DateTime(2028, 3, 1));
      // 2026 is not a leap year: Feb 28 + 1 is March 1.
      expect(dayOffset(DateTime(2026, 2, 28), 1), DateTime(2026, 3, 1));
    });

    test('normalises the time of day to midnight', () {
      expect(dayOffset(DateTime(2026, 8, 12, 23, 45), 1), DateTime(2026, 8, 13));
      expect(dayOffset(DateTime(2026, 8, 12, 0, 1), 0), DateTime(2026, 8, 12));
    });

    test('large offsets stay on the calendar', () {
      expect(dayOffset(DateTime(2026, 1, 1), 365), DateTime(2027, 1, 1));
      // 2028 is a leap year, so 365 days from Jan 1 2028 is Dec 31, not Jan 1.
      expect(dayOffset(DateTime(2028, 1, 1), 365), DateTime(2028, 12, 31));
    });

    test('nextDay/prevDay are dayOffset ±1', () {
      final d = DateTime(2026, 6, 15, 9, 30);
      expect(nextDay(d), dayOffset(d, 1));
      expect(prevDay(d), dayOffset(d, -1));
    });
  });

  group('startOfDay', () {
    test('strips the time of day', () {
      expect(startOfDay(DateTime(2026, 8, 12, 23, 59, 59, 999)),
          DateTime(2026, 8, 12));
    });

    test('is idempotent', () {
      final once = startOfDay(DateTime(2026, 8, 12, 6));
      expect(startOfDay(once), once);
    });
  });

  group('startOfWeek', () {
    test('Monday is its own week start', () {
      final monday = DateTime(2026, 8, 10); // a Monday
      expect(monday.weekday, DateTime.monday);
      expect(startOfWeek(monday), monday);
    });

    test('Sunday belongs to the week that started six days earlier', () {
      final sunday = DateTime(2026, 8, 16); // a Sunday
      expect(sunday.weekday, DateTime.sunday);
      expect(startOfWeek(sunday), DateTime(2026, 8, 10));
    });

    test('normalises the time of day', () {
      // The Focus "Week" overview dropped Monday precisely because its week
      // start kept the current clock time and was then compared against
      // midnight-normalised day rows.
      expect(startOfWeek(DateTime(2026, 8, 12, 13, 5)), DateTime(2026, 8, 10));
    });

    test('crosses a month boundary', () {
      // Wednesday 2 Sep 2026 -> Monday 31 Aug 2026.
      expect(startOfWeek(DateTime(2026, 9, 2)), DateTime(2026, 8, 31));
    });
  });

  group('calendarDaysBetween', () {
    test('counts whole calendar days and ignores the time of day', () {
      expect(
        calendarDaysBetween(DateTime(2026, 8, 12, 23, 59), DateTime(2026, 8, 13, 0, 1)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 8, 12, 0, 1), DateTime(2026, 8, 12, 23, 59)),
        0,
      );
    });

    test('is negative when `to` is earlier', () {
      expect(calendarDaysBetween(DateTime(2026, 8, 13), DateTime(2026, 8, 12)), -1);
    });

    test('counts across month and leap boundaries', () {
      expect(calendarDaysBetween(DateTime(2026, 1, 31), DateTime(2026, 3, 1)), 29);
      expect(calendarDaysBetween(DateTime(2028, 2, 28), DateTime(2028, 3, 1)), 2);
      expect(calendarDaysBetween(DateTime(2026, 2, 28), DateTime(2026, 3, 1)), 1);
    });

    test('round-trips with dayOffset for a range of offsets', () {
      final base = DateTime(2026, 3, 5, 14, 20);
      for (final n in [-400, -31, -1, 0, 1, 7, 31, 365]) {
        expect(calendarDaysBetween(base, dayOffset(base, n)), n,
            reason: 'offset $n should round-trip');
      }
    });
  });

  group('isSameCalendarDay', () {
    test('true across the whole day, false at the boundary', () {
      expect(
        isSameCalendarDay(DateTime(2026, 8, 12, 0, 0), DateTime(2026, 8, 12, 23, 59)),
        isTrue,
      );
      expect(
        isSameCalendarDay(DateTime(2026, 8, 12, 23, 59), DateTime(2026, 8, 13, 0, 0)),
        isFalse,
      );
    });
  });
}
