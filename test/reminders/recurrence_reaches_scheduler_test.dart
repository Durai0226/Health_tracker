import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';

import '../support/reminder_harness.dart';

/// The new reminder model never reached the OS scheduler.
///
/// `scheduleGenericReminder` understood only the six-value `RepeatType`; it had
/// no parameter for `recurrenceRule`, `endsAt`, `occurrenceLimit` or `isPaused`,
/// and every caller passed the raw repeat type. Two concrete consequences:
///
///  (a) Smart Add produces `RRULE:FREQ=DAILY;INTERVAL=3` with `repeat` left at
///      `none` (smart_add_recurrence_test pins that). The row was armed as a
///      one-shot at `scheduledTime`, and once that instant passed the re-arm
///      pass skipped it as "a one-off whose time has passed". "Water the plants
///      every 3 days" fired exactly ONCE and then sat under Overdue forever.
///
///  (b) `RepeatType.daily` + an `endsAt` was armed as a native self-rescheduling
///      daily alarm, which has no notion of an end. "Take antibiotics daily for
///      7 days" kept nagging on day 8, 9, 10…
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('an RRULE reminder keeps firing', () {
    reminderTest('positive: a rule-based reminder whose first instant has '
        'passed is still armed', (h) async {
      await h.seed('r-rrule',
          at: h.now.subtract(const Duration(days: 2)),
          recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=3');

      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      expect(n, 1,
          reason: 'this is the Smart Add shape — repeat none plus a rule — and '
              'it used to be retired the moment its first instant passed');
      expect(h.alarm.armed, hasLength(1));
    });

    reminderTest('positive: it is armed for a FUTURE instant, not the stale one',
        (h) async {
      final start = h.now.subtract(const Duration(days: 2));
      await h.seed('r-rrule',
          at: start, recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=3');

      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      final armedAt = h.alarm.armed.single.scheduledTime;
      expect(armedAt.isAfter(h.now), isTrue,
          reason: 'arming the stale creation instant fires immediately');
      expect(armedAt.isAtSameMomentAs(start), isFalse);
    });

    reminderTest('a rule-based reminder is armed one occurrence at a time',
        (h) async {
      await h.seed('r-rrule',
          at: h.now.add(const Duration(hours: 1)),
          recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=3');

      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      expect(h.alarm.armed.single.repeatType, RepeatType.none,
          reason: 'a native repeat cannot express an INTERVAL=3 rule, so the '
              'seam must arm the next occurrence and let the re-arm pass '
              'advance it');
    });
  });

  group('a bounded reminder stops', () {
    reminderTest('negative: a reminder past its endsAt is not armed', (h) async {
      await h.seed('r-ended',
          at: h.now.subtract(const Duration(days: 10)),
          repeat: RepeatType.daily,
          endsAt: h.now.subtract(const Duration(days: 3)));

      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      expect(n, 0, reason: 'day 8, 9, 10 nagging is the bug');
      expect(h.alarm.armed, isEmpty);
      expect(h.alarm.disarmed, isNotEmpty,
          reason: 'an exhausted reminder must also be taken off the OS');
    });

    reminderTest('positive: a daily reminder still inside its endsAt is armed',
        (h) async {
      await h.seed('r-course',
          at: h.now.subtract(const Duration(days: 1)),
          repeat: RepeatType.daily,
          endsAt: h.now.add(const Duration(days: 3)));

      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      expect(n, 1);
      expect(h.alarm.armed.single.repeatType, RepeatType.none,
          reason: 'a bounded daily must be armed per-occurrence, or the native '
              'daily alarm outlives its own end date');
    });
  });

  group('a paused reminder is silent', () {
    reminderTest('negative: a paused reminder is never armed', (h) async {
      await h.seed('r-paused',
          at: h.now.add(const Duration(hours: 2)),
          repeat: RepeatType.daily,
          isPaused: true);

      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      expect(n, 0);
      expect(h.alarm.armed, isEmpty,
          reason: 'isPaused is stored and cloud-synced and ReminderHelper has '
              'always honoured it; the scheduling path did not, so pausing a '
              'reminder did nothing at all');
      expect(h.alarm.disarmed, isNotEmpty);
    });

    reminderTest('positive: an unpaused daily reminder is armed normally',
        (h) async {
      await h.seed('r-live',
          at: h.now.add(const Duration(hours: 2)), repeat: RepeatType.daily);
      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(n, 1);
      expect(h.alarm.armed.single.repeatType, RepeatType.daily,
          reason: 'an unbounded legacy repeat keeps the cheaper native repeat');
    });
  });
}
