import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/utils/reminder_helper.dart';

/// QA — reminder recurrence math (F2).
///
/// The invariant group below is the original suite. It could only assert
/// invariants (future, same time-of-day, correct weekday) because
/// `getNextOccurrence` called `DateTime.now()` directly, so "now" was whatever
/// time the suite happened to run at.
///
/// It now calls `clock.now()`, so the group after it pins the wall clock and
/// asserts the actual instant a repeat should resolve to. Both are kept: the
/// invariants hold in every zone and at every hour, which the fixed instants
/// deliberately do not (they encode a specific date to catch off-by-one and
/// weekday-arithmetic errors). DST behaviour is out of scope here — a Dart
/// process cannot change zone at runtime, so it lives in
/// `test/core/dst_date_arithmetic_probe.dart`, which is re-run under
/// `TZ=America/New_York`.
Reminder rem(RepeatType type, DateTime at, {List<int>? customDays}) => Reminder(
      id: 'r',
      title: 't',
      body: 'b',
      scheduledTime: at,
      repeatType: type,
      customDays: customDays,
    );

void main() {
  group('getNextOccurrence — positive', () {
    test('non-repeating returns the same time (no advance)', () {
      final at = DateTime(2020, 1, 1, 9, 0);
      expect(ReminderHelper.getNextOccurrence(rem(RepeatType.none, at)), at);
    });

    test('daily → a future slot at the same time of day', () {
      final past = DateTime.now().subtract(const Duration(days: 5));
      final next = ReminderHelper.getNextOccurrence(rem(RepeatType.daily, past));
      expect(next.isAfter(DateTime.now()), isTrue);
      expect(next.hour, past.hour);
      expect(next.minute, past.minute);
    });

    test('weekly → future, same weekday, same time', () {
      final past = DateTime.now().subtract(const Duration(days: 21));
      final next = ReminderHelper.getNextOccurrence(rem(RepeatType.weekly, past));
      expect(next.isAfter(DateTime.now()), isTrue);
      expect(next.weekday, past.weekday);
    });

    test('weekdays → future occurrence lands Mon–Fri', () {
      final past = DateTime.now().subtract(const Duration(days: 10));
      final next =
          ReminderHelper.getNextOccurrence(rem(RepeatType.weekdays, past));
      expect(next.isAfter(DateTime.now()), isTrue);
      expect(next.weekday, lessThanOrEqualTo(DateTime.friday));
    });

    test('weekends → future occurrence lands Sat/Sun', () {
      final past = DateTime.now().subtract(const Duration(days: 10));
      final next =
          ReminderHelper.getNextOccurrence(rem(RepeatType.weekends, past));
      expect(next.isAfter(DateTime.now()), isTrue);
      expect(next.weekday, anyOf(DateTime.saturday, DateTime.sunday));
    });

    test('custom [Mon, Wed] → future occurrence lands on Mon or Wed', () {
      final past = DateTime.now().subtract(const Duration(days: 10));
      final next = ReminderHelper.getNextOccurrence(
          rem(RepeatType.custom, past, customDays: [DateTime.monday, DateTime.wednesday]));
      expect(next.isAfter(DateTime.now()), isTrue);
      expect([DateTime.monday, DateTime.wednesday].contains(next.weekday), isTrue);
    });
  });

  // 2026-06-10 is a Wednesday; 09:00 keeps every expectation inside one day.
  group('getNextOccurrence — exact instants, clock pinned', () {
    T at<T>(DateTime now, T Function() body) =>
        withClock(Clock.fixed(now), body);

    final wedMorning = DateTime(2026, 6, 10, 9, 0);

    test('daily advances exactly one calendar day', () {
      at(DateTime(2026, 6, 10, 10, 0), () {
        expect(
          ReminderHelper.getNextOccurrence(rem(RepeatType.daily, wedMorning)),
          DateTime(2026, 6, 11, 9, 0),
        );
      });
    });

    test('daily skips forward past a long gap, landing on the next slot only', () {
      at(DateTime(2026, 6, 20, 10, 0), () {
        expect(
          ReminderHelper.getNextOccurrence(rem(RepeatType.daily, wedMorning)),
          DateTime(2026, 6, 21, 9, 0),
          reason: 'the catch-up loop must stop at the first future slot, '
              'not overshoot or return today',
        );
      });
    });

    test('a future daily reminder still advances (documents the behaviour)', () {
      // getNextOccurrence is called on COMPLETION, so "already in the future"
      // means the user finished early. It advances rather than returning the
      // slot they just completed — otherwise the reminder would re-fire today.
      at(DateTime(2026, 6, 10, 8, 0), () {
        expect(
          ReminderHelper.getNextOccurrence(rem(RepeatType.daily, wedMorning)),
          DateTime(2026, 6, 11, 9, 0),
        );
      });
    });

    test('weekly advances exactly seven days', () {
      at(DateTime(2026, 6, 10, 10, 0), () {
        expect(
          ReminderHelper.getNextOccurrence(rem(RepeatType.weekly, wedMorning)),
          DateTime(2026, 6, 17, 9, 0),
        );
      });
    });

    test('weekdays: Friday jumps the weekend to Monday', () {
      final friday = DateTime(2026, 6, 12, 9, 0);
      at(DateTime(2026, 6, 12, 10, 0), () {
        expect(
          ReminderHelper.getNextOccurrence(rem(RepeatType.weekdays, friday)),
          DateTime(2026, 6, 15, 9, 0),
        );
      });
    });

    test('weekends: Sunday jumps to the next Saturday, not the next day', () {
      final sunday = DateTime(2026, 6, 14, 9, 0);
      at(DateTime(2026, 6, 14, 10, 0), () {
        expect(
          ReminderHelper.getNextOccurrence(rem(RepeatType.weekends, sunday)),
          DateTime(2026, 6, 20, 9, 0),
        );
      });
    });

    test('custom [Mon, Wed] from a Wednesday goes to Monday', () {
      at(DateTime(2026, 6, 10, 10, 0), () {
        expect(
          ReminderHelper.getNextOccurrence(rem(RepeatType.custom, wedMorning,
              customDays: const [DateTime.monday, DateTime.wednesday])),
          DateTime(2026, 6, 15, 9, 0),
        );
      });
    });

    test('month and year boundaries roll over correctly', () {
      final newYearsEve = DateTime(2026, 12, 31, 23, 30);
      at(DateTime(2027, 1, 1, 0, 0), () {
        expect(
          ReminderHelper.getNextOccurrence(rem(RepeatType.daily, newYearsEve)),
          DateTime(2027, 1, 1, 23, 30),
        );
      });
    });

    test('a leap day survives being stepped over', () {
      final feb28 = DateTime(2028, 2, 28, 7, 15);
      at(DateTime(2028, 2, 28, 8, 0), () {
        expect(
          ReminderHelper.getNextOccurrence(rem(RepeatType.daily, feb28)),
          DateTime(2028, 2, 29, 7, 15),
          reason: '2028 is a leap year',
        );
      });
    });
  });

  group('getNextOccurrence — negative / edge', () {
    test('custom with empty days falls back to +1 day (no crash)', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final next = ReminderHelper.getNextOccurrence(
          rem(RepeatType.custom, past, customDays: const []));
      expect(next.isAfter(DateTime.now()), isTrue);
    });
  });
}
