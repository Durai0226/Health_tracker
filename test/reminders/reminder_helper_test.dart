import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/utils/reminder_helper.dart';

/// QA — reminder recurrence math (F2). `ReminderHelper.getNextOccurrence` had
/// no coverage. It depends on DateTime.now() (it advances until a future slot),
/// so we assert invariants (future, same time-of-day, correct weekday) rather
/// than exact timestamps.
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

  group('getNextOccurrence — negative / edge', () {
    test('custom with empty days falls back to +1 day (no crash)', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final next = ReminderHelper.getNextOccurrence(
          rem(RepeatType.custom, past, customDays: const []));
      expect(next.isAfter(DateTime.now()), isTrue);
    });
  });
}
