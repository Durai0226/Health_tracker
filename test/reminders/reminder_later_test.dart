import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/reminders/utils/reminder_later.dart';

void main() {
  DateTime at(int h, [int m = 0]) => DateTime(2026, 3, 14, h, m);

  test('a morning swipe means this evening at 18:00', () {
    expect(ReminderLater.from(at(8)), DateTime(2026, 3, 14, 18));
    expect(ReminderLater.label(at(8)), 'this evening');
  });

  test('just before 17:00 is still this evening', () {
    expect(ReminderLater.from(at(16, 59)), DateTime(2026, 3, 14, 18));
  });

  test('from 17:00 it is tomorrow at 9:30', () {
    expect(ReminderLater.from(at(17)), DateTime(2026, 3, 15, 9, 30));
    expect(ReminderLater.label(at(17)), 'tomorrow morning');
  });

  test('late at night is tomorrow morning, across a month end', () {
    expect(ReminderLater.from(DateTime(2026, 3, 31, 23, 10)),
        DateTime(2026, 4, 1, 9, 30));
  });

  test('midnight onward counts as the morning of that same day', () {
    expect(ReminderLater.from(at(0, 5)), DateTime(2026, 3, 14, 18));
  });

  test('it is always in the future', () {
    for (var h = 0; h < 24; h++) {
      final now = at(h, 30);
      expect(ReminderLater.from(now).isAfter(now), isTrue, reason: 'hour $h');
    }
  });

  test('the wall-clock time survives a DST change', () {
    // US clocks sprang forward on Sun 8 March 2026: asking on Saturday night
    // must still give 9:30 on the Sunday, not 10:30.
    final later = ReminderLater.from(DateTime(2026, 3, 7, 22));
    expect(later.hour, 9);
    expect(later.minute, 30);
    expect(later.day, 8);
  });
}
