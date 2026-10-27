/// A reminder whose own time has not come yet fires AT that time.
///
/// `ReminderArmRequest.forNextOccurrence` chose the instant to arm for a
/// reminder with an end date or a rule by asking "what is the first occurrence
/// strictly AFTER the current one?" — the right question when rolling forward
/// from a tick or from a stale anchor, and the wrong one for a reminder that has
/// not fired yet. Asked about a reminder due at 18:00 today it answered
/// tomorrow, so:
///
///  * "Daily until Friday", set at 10:00 for 18:00, never fired on its first day;
///  * a Smart Add "every 3 days" was armed three days late;
///  * after every tick the next occurrence was skipped the same way.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_alarm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Saturday 14 March 2026, 10:00.
  final now = DateTime(2026, 3, 14, 10, 0);
  final thisEvening = DateTime(2026, 3, 14, 18, 0);

  Reminder r({
    required DateTime at,
    RepeatType repeat = RepeatType.none,
    String? rule,
    DateTime? endsAt,
  }) =>
      Reminder(
        id: 'x',
        title: 'Take antibiotics',
        body: '',
        scheduledTime: at,
        repeatType: repeat,
        recurrenceRule: rule,
        endsAt: endsAt,
      );

  T pinned<T>(T Function() body) => withClock(Clock.fixed(now), body);

  group('not yet due: it fires at its own time', () {
    test('daily until a date, due this evening', () {
      final req = pinned(() => ReminderArmRequest.forNextOccurrence(r(
            at: thisEvening,
            repeat: RepeatType.daily,
            endsAt: DateTime(2026, 3, 20),
          )));
      expect(req?.scheduledTime, thisEvening,
          reason: 'it used to say tomorrow 18:00, skipping the first day');
    });

    test('a Smart Add every-3-days rule, due this evening', () {
      final req = pinned(() => ReminderArmRequest.forNextOccurrence(r(
            at: thisEvening,
            rule: 'RRULE:FREQ=DAILY;INTERVAL=3',
          )));
      expect(req?.scheduledTime, thisEvening,
          reason: 'it used to say 17 March: three days late');
    });

    test('a weekly rule, due next Tuesday', () {
      final tuesday = DateTime(2026, 3, 17, 9, 0);
      final req = pinned(() => ReminderArmRequest.forNextOccurrence(
          r(at: tuesday, rule: 'RRULE:FREQ=WEEKLY;BYDAY=TU')));
      expect(req?.scheduledTime, tuesday);
    });

    test('it is still armed as one occurrence, not a native repeat', () {
      final req = pinned(() => ReminderArmRequest.forNextOccurrence(r(
            at: thisEvening,
            repeat: RepeatType.daily,
            endsAt: DateTime(2026, 3, 20),
          )));
      expect(req?.repeatType, RepeatType.none,
          reason: 'a native daily alarm has no notion of an end');
    });

    test('but not when its own time is already past its end date', () {
      final req = pinned(() => ReminderArmRequest.forNextOccurrence(r(
            at: DateTime(2026, 3, 22, 18),
            repeat: RepeatType.daily,
            endsAt: DateTime(2026, 3, 20),
          )));
      expect(req, isNull);
    });

    test('and not when it is paused', () {
      final paused = Reminder(
        id: 'x',
        title: 't',
        body: '',
        scheduledTime: thisEvening,
        repeatType: RepeatType.daily,
        endsAt: DateTime(2026, 3, 20),
        isPaused: true,
      );
      expect(pinned(() => ReminderArmRequest.forNextOccurrence(paused)), isNull);
    });
  });

  group('already due: unchanged, the next one after now', () {
    test('a stale anchor on a bounded daily reminder', () {
      final req = pinned(() => ReminderArmRequest.forNextOccurrence(r(
            at: DateTime(2026, 3, 11, 9),
            repeat: RepeatType.daily,
            endsAt: DateTime(2026, 3, 20),
          )));
      expect(req?.scheduledTime, DateTime(2026, 3, 15, 9),
          reason: 'today 09:00 has gone by');
    });

    test('a stale anchor on a rule', () {
      final req = pinned(() => ReminderArmRequest.forNextOccurrence(r(
            at: DateTime(2026, 3, 11, 9),
            rule: 'RRULE:FREQ=DAILY;INTERVAL=3',
          )));
      // 11th, 14th (09:00, already gone), 17th.
      expect(req?.scheduledTime, DateTime(2026, 3, 17, 9));
    });

    test('past its end date, nothing is armed', () {
      final req = pinned(() => ReminderArmRequest.forNextOccurrence(r(
            at: DateTime(2026, 3, 1, 9),
            repeat: RepeatType.daily,
            endsAt: DateTime(2026, 3, 10),
          )));
      expect(req, isNull);
    });
  });

  group('no bound, no rule: the native repeat, at its own time', () {
    test('a plain daily reminder', () {
      final req = pinned(() => ReminderArmRequest.forNextOccurrence(
          r(at: thisEvening, repeat: RepeatType.daily)));
      expect(req?.scheduledTime, thisEvening);
      expect(req?.repeatType, RepeatType.daily);
    });

    test('a one-off', () {
      final req =
          pinned(() => ReminderArmRequest.forNextOccurrence(r(at: thisEvening)));
      expect(req?.scheduledTime, thisEvening);
    });
  });
}
