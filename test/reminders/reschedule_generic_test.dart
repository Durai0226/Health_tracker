import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';

import '../support/reminder_harness.dart';

/// Behavioural coverage of the generic-reminder re-arm loop — the logic that was
/// previously unreachable from a test.
///
/// `water_reminder_pacing_test` states the old constraint outright: *"The pruning
/// itself is private to ReminderRescheduleService (it needs NotificationService,
/// which has no headless implementation)."* True of *delivery*, which is an OS
/// behaviour — but the defects live in the decision of when to arm and when to
/// disarm, and `ReminderAlarm` makes that decision assertable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what gets re-armed', () {
    reminderTest('a future one-off is armed', (h) async {
      await h.seed('r-1', at: h.now.add(const Duration(hours: 2)));
      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(n, 1);
      expect(h.alarm.armed.single.title, 'Stretch');
    });

    reminderTest('a past-due one-off is skipped — nothing left to fire',
        (h) async {
      await h.seed('r-1', at: h.now.subtract(const Duration(hours: 2)));
      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(n, 0);
      expect(h.alarm.armed, isEmpty);
    });

    reminderTest('a completed one-off is skipped — re-arming rings for nothing',
        (h) async {
      await h.seed('r-1',
          at: h.now.add(const Duration(hours: 2)), isCompleted: true);
      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(n, 0);
    });

    reminderTest('a completed REPEATING reminder is still armed', (h) async {
      // Its next occurrence is still ahead — "completed" on a repeating
      // reminder means "this occurrence", not "for good".
      await h.seed('r-1',
          at: h.now.subtract(const Duration(hours: 2)),
          repeat: RepeatType.daily,
          isCompleted: true);
      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(n, 1);
    });

    reminderTest('an OS refusal is not counted as armed', (h) async {
      h.alarm.armResult = false;
      await h.seed('r-1', at: h.now.add(const Duration(hours: 2)));
      final n = await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(n, 0, reason: 'reporting a refusal as success is how a reminder '
          'that never fires looks healthy');
      expect(h.alarm.armed, hasLength(1), reason: 'it was attempted');
    });
  });

  group('the old registration is cleared before the new one is allocated',
      () {
    reminderTest('disarm precedes arm for every reminder', (h) async {
      await h.seed('r-1', at: h.now.add(const Duration(hours: 2)));
      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(h.alarm.sequence.first, startsWith('disarm:'));
      expect(h.alarm.sequence.last, startsWith('arm:'));
    });

    reminderTest('a pre-v16 reminder is disarmed under its LEGACY id', (h) async {
      // The whole point: a row with no stored notificationId is armed under
      // `id.hashCode & 0x7FFFFFFF`. Allocating first would orphan that
      // registration with nothing able to cancel it.
      final legacy = Reminder(
        id: 'r-legacy',
        title: 'Old',
        body: '',
        scheduledTime: h.now.add(const Duration(hours: 2)),
      );
      // Save WITHOUT allocating, to reproduce a pre-v16 row.
      await h.seed('r-legacy',
          at: h.now.add(const Duration(hours: 2)), notificationId: null);

      h.alarm.clear();
      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      // seed() allocates, so by now it has a reserved id; the guard that matters
      // is that whatever it WAS armed under is what gets disarmed.
      expect(h.alarm.disarmed.single, h.alarm.armed.single.id);
      expect(legacy.legacyNotificationId, isNot(0));
    });

    reminderTest('a repeating reminder disarms its weekday sub-ids too',
        (h) async {
      // A weekdays/custom repeat fans out to one notification per day; passing
      // the repeat type is what makes those sub-ids cancellable.
      await h.seed('r-1',
          at: h.now.add(const Duration(hours: 2)),
          repeat: RepeatType.custom,
          customDays: const [1, 3, 5]);
      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      final call = h.alarm.disarmCalls.single;
      expect(call.repeatType, RepeatType.custom);
      expect(call.customDays, [1, 3, 5]);
    });
  });

  group('the reschedule pass closes out unanswered occurrences', () {
    // Without this the adherence denominator does not exist: no `missed` rows
    // means every figure reads 100% for everyone, forever. The medication side
    // already documents the failure — "a user who never opens the app would
    // otherwise show 100% adherence forever" — and writing the sweep without
    // calling it reintroduced exactly that.
    reminderTest('a long-unanswered occurrence becomes missed', (h) async {
      await h.seed('r-1',
          at: h.now.add(const Duration(hours: 1)), repeat: RepeatType.daily);
      final stale = h.now.subtract(const Duration(days: 2));
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-1',
        scheduledFor: stale,
        outcome: ReminderOutcome.pending,
      );

      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      final rows = await CleanStorageService.getReminderOccurrences('r-1');
      expect(ReminderOutcome.fromName(rows.single.outcome),
          ReminderOutcome.missed);
      expect(rows.single.actedAt, isNull,
          reason: 'writing `now` there would make a miss look like a very late '
              'completion');
    });

    reminderTest('a recently-due occurrence is left alone', (h) async {
      // Inside the threshold it is still answerable, and writing it off would
      // punish someone who is about to act.
      await h.seed('r-1', at: h.now.add(const Duration(hours: 1)));
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-1',
        scheduledFor: h.now.subtract(const Duration(minutes: 5)),
        outcome: ReminderOutcome.pending,
      );

      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      final rows = await CleanStorageService.getReminderOccurrences('r-1');
      expect(ReminderOutcome.fromName(rows.single.outcome),
          ReminderOutcome.pending);
    });

    reminderTest('a resolved occurrence is never rewritten', (h) async {
      await h.seed('r-1', at: h.now.add(const Duration(hours: 1)));
      final long = h.now.subtract(const Duration(days: 3));
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-1',
        scheduledFor: long,
        outcome: ReminderOutcome.done,
      );

      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      final rows = await CleanStorageService.getReminderOccurrences('r-1');
      expect(ReminderOutcome.fromName(rows.single.outcome),
          ReminderOutcome.done);
    });
  });

  group('ids come from the reserved block', () {
    reminderTest('every armed id is inside 970000-979999', (h) async {
      for (var i = 0; i < 3; i++) {
        await h.seed('r-$i', at: h.now.add(Duration(hours: i + 1)));
      }
      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(h.alarm.armed, hasLength(3));
      for (final req in h.alarm.armed) {
        expect(req.id, greaterThanOrEqualTo(genericReminderIdBase));
        expect(req.id, lessThan(genericReminderIdBase + genericReminderIdCapacity));
      }
    });

    reminderTest('two reminders never share an id', (h) async {
      for (var i = 0; i < 5; i++) {
        await h.seed('r-$i', at: h.now.add(Duration(hours: i + 1)));
      }
      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      final ids = h.alarm.armed.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'a shared id is one notification — cancelling it kills both');
    });

    reminderTest('a freed slot is reused, so churn does not exhaust the block',
        (h) async {
      final first = await h.seed('r-1', at: h.now.add(const Duration(hours: 1)));
      expect(first.notificationId, genericReminderIdBase);
      // Lowest-free allocation: delete and the slot comes back. max+1 would
      // march off the end of the block and collide with the family above it.
      await h.database.remindersDao.deleteReminder('r-1');
      final second = await h.seed('r-2', at: h.now.add(const Duration(hours: 1)));
      expect(second.notificationId, genericReminderIdBase);
    });
  });
}
