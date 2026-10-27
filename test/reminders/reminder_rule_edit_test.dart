/// A repeat Smart Add wrote can be read, said, and moved further apart or closer
/// together — without losing what else it says.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rrule/rrule.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_rule_edit.dart';

void main() {
  group('read', () {
    test('how far apart, and by what', () {
      final r = ReminderRuleEdit.read('RRULE:FREQ=DAILY;INTERVAL=3')!;
      expect(r.frequency, Frequency.daily);
      expect(r.interval, 3);
    });

    test('no INTERVAL means every one', () {
      expect(ReminderRuleEdit.read('RRULE:FREQ=MONTHLY')!.interval, 1);
    });

    test('a weekday and an end do not stop it being read', () {
      final r = ReminderRuleEdit.read(
          'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU;COUNT=6')!;
      expect(r.frequency, Frequency.weekly);
      expect(r.interval, 2);
    });

    test('anything finer than a day is not offered: the app has no hourly reminders',
        () {
      expect(ReminderRuleEdit.read('RRULE:FREQ=HOURLY;INTERVAL=2'), isNull);
      expect(ReminderRuleEdit.read('RRULE:FREQ=MINUTELY'), isNull);
    });

    test('nothing, or nonsense, is nothing — and never throws', () {
      expect(ReminderRuleEdit.read(null), isNull);
      expect(ReminderRuleEdit.read(''), isNull);
      expect(ReminderRuleEdit.read('   '), isNull);
      expect(ReminderRuleEdit.read('not a rule'), isNull);
      expect(ReminderRuleEdit.read('RRULE:FREQ=SOMETIMES'), isNull);
    });
  });

  group('withInterval', () {
    test('changes the gap and nothing else', () {
      final out = ReminderRuleEdit.withInterval(
          'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU;COUNT=6', 4)!;
      final r = RecurrenceRule.fromString(out);
      expect(r.frequency, Frequency.weekly);
      expect(r.actualInterval, 4);
      expect(r.byWeekDays.single.day, DateTime.tuesday,
          reason: 'which weekday it falls on is the rule\'s, not the stepper\'s');
      expect(r.count, 6, reason: 'and so is when it stops');
    });

    test('an end date survives too', () {
      final out = ReminderRuleEdit.withInterval(
          'RRULE:FREQ=DAILY;INTERVAL=3;UNTIL=20301231T000000Z', 5)!;
      final r = RecurrenceRule.fromString(out);
      expect(r.until, DateTime.utc(2030, 12, 31));
      expect(r.actualInterval, 5);
    });

    test('every one drops the INTERVAL rather than writing INTERVAL=1', () {
      final out = ReminderRuleEdit.withInterval('RRULE:FREQ=DAILY;INTERVAL=2', 1)!;
      expect(out, isNot(contains('INTERVAL')));
      expect(ReminderRuleEdit.read(out)!.interval, 1);
    });

    test('is kept between one and a year of them', () {
      expect(ReminderRuleEdit.read(ReminderRuleEdit.withInterval('RRULE:FREQ=DAILY', 0)!)!.interval, 1);
      expect(ReminderRuleEdit.read(ReminderRuleEdit.withInterval('RRULE:FREQ=DAILY', -4)!)!.interval, 1);
      expect(ReminderRuleEdit.read(ReminderRuleEdit.withInterval('RRULE:FREQ=DAILY', 9999)!)!.interval,
          ReminderRuleEdit.maxInterval);
    });

    test('a rule it cannot read comes back null, not a guess', () {
      expect(ReminderRuleEdit.withInterval('not a rule', 3), isNull);
      expect(ReminderRuleEdit.withInterval('RRULE:FREQ=HOURLY', 3), isNull);
    });
  });

  group('words', () {
    test('every one', () {
      expect(ReminderRuleEdit.say(Frequency.daily, 1), 'Every day');
      expect(ReminderRuleEdit.say(Frequency.weekly, 1), 'Every week');
    });

    test('every other, because that is what people say', () {
      expect(ReminderRuleEdit.say(Frequency.weekly, 2), 'Every other week');
      expect(ReminderRuleEdit.say(Frequency.daily, 2), 'Every other day');
    });

    test('every N, in the plural', () {
      expect(ReminderRuleEdit.say(Frequency.daily, 3), 'Every 3 days');
      expect(ReminderRuleEdit.say(Frequency.monthly, 6), 'Every 6 months');
      expect(ReminderRuleEdit.say(Frequency.yearly, 10), 'Every 10 years');
    });
  });

  group('isPlain', () {
    test('only how far apart', () {
      expect(ReminderRuleEdit.isPlain('RRULE:FREQ=DAILY;INTERVAL=3'), isTrue);
      expect(ReminderRuleEdit.isPlain('RRULE:FREQ=MONTHLY'), isTrue);
    });

    test('a count or an end is not a "where" — still plain', () {
      expect(ReminderRuleEdit.isPlain('RRULE:FREQ=DAILY;COUNT=5'), isTrue);
    });

    test('a weekday or a day of the month is not', () {
      expect(ReminderRuleEdit.isPlain('RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU'), isFalse);
      expect(ReminderRuleEdit.isPlain('RRULE:FREQ=MONTHLY;BYMONTHDAY=15'), isFalse);
    });

    test('nonsense is not plain', () {
      expect(ReminderRuleEdit.isPlain('nope'), isFalse);
    });
  });
}
