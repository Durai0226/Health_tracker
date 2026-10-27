/// What the Done and Later buttons asked for, written down when the app next
/// opens.
///
/// The button ran in a background isolate and could only queue its answer; this
/// is where the reminder is ticked off, or put off, by the same code a tick in
/// the app uses.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart'
    show genericReminderFollowUpOffset;
import 'package:tablet_remainder/core/services/background_alarm_service.dart'
    show snoozeIdOffset;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/reminder_action_queue.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_action_service.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_completion.dart';

import '../support/reminder_harness.dart';

void main() {
  // The harness pins 13:00 today.
  Future<Reminder?> stored(String id) async =>
      (await CleanStorageService.getAllReminders()).where((r) => r.id == id).firstOrNull;

  Future<db.ReminderOccurrence?> occurrenceOf(
          ReminderHarness h, String id, DateTime at) =>
      h.database.remindersDao.getOccurrence(id, at);

  Future<void> done(String id, DateTime at) => ReminderActionQueue.enqueue(
      reminderId: id, action: ReminderNotificationAction.done, at: at);

  Future<void> later(String id, DateTime at, DateTime laterAt) =>
      ReminderActionQueue.enqueue(
          reminderId: id,
          action: ReminderNotificationAction.later,
          at: at,
          laterAt: laterAt);

  reminderTest('nothing queued: nothing applied', (h) async {
    expect(await ReminderActionService.drainPending(alarm: h.alarm), isEmpty);
    expect(h.alarm.armed, isEmpty);
    expect(h.alarm.disarmed, isEmpty);
  });

  group('Done', () {
    reminderTest('ticks the reminder off, as the notification, at the moment of the tap',
        (h) async {
      final due = h.now.subtract(const Duration(hours: 2));
      final r = await h.seed('r1', title: 'Call the clinic', at: due);
      final tapped = h.now.subtract(const Duration(minutes: 20));
      await done('r1', tapped);

      final applied = await ReminderActionService.drainPending(alarm: h.alarm);

      expect(applied, hasLength(1));
      expect(applied.single.title, 'Call the clinic');
      expect(applied.single.action, ReminderNotificationAction.done);
      expect((await stored('r1'))!.isCompleted, isTrue);
      final o = await occurrenceOf(h, 'r1', due);
      expect(o!.outcome, 'done');
      expect(o.source, 'notification',
          reason: 'what asked: the adherence view can tell a button from a tick');
      expect(o.actedAt!.toLocal(), tapped,
          reason: 'when it was done, not when the app got round to writing it');
      expect(h.alarm.disarmed, [r.notificationSlot]);
    });

    reminderTest('is acknowledged: a second drain finds nothing', (h) async {
      await h.seed('r1', at: h.now.subtract(const Duration(hours: 1)));
      await done('r1', h.now);

      await ReminderActionService.drainPending(alarm: h.alarm);

      expect(await ReminderActionQueue.drain(), isEmpty);
      expect(await ReminderActionService.drainPending(alarm: h.alarm), isEmpty);
    });

    reminderTest('about a reminder already done: acknowledged, and says nothing',
        (h) async {
      await h.seed('r1', at: h.now.subtract(const Duration(hours: 1)), isCompleted: true);
      await done('r1', h.now);

      expect(await ReminderActionService.drainPending(alarm: h.alarm), isEmpty,
          reason: 'a Done left on a lock screen must not undo the first');
      expect(await ReminderActionQueue.drain(), isEmpty);
      expect((await stored('r1'))!.isCompleted, isTrue);
    });

    reminderTest('about a reminder that was deleted: acknowledged, and says nothing',
        (h) async {
      await done('gone', h.now);
      expect(await ReminderActionService.drainPending(alarm: h.alarm), isEmpty);
      expect(await ReminderActionQueue.drain(), isEmpty,
          reason: 'it can never be applied, so it must not wait for ever');
    });

    reminderTest('a repeating reminder rolls forward and arms its next time',
        (h) async {
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final r = await h.seed('r1', at: anchor, repeat: RepeatType.daily);
      await done('r1', h.now);

      await ReminderActionService.drainPending(alarm: h.alarm);

      final after = (await stored('r1'))!;
      expect(after.isCompleted, isFalse);
      expect(after.scheduledTime.isAfter(h.now), isTrue);
      expect(h.alarm.armed.single.id, r.notificationSlot);
    });

    reminderTest('answers are applied oldest first, one at a time', (h) async {
      await h.seed('a', title: 'First', at: h.now.subtract(const Duration(hours: 3)));
      await h.seed('b', title: 'Second', at: h.now.subtract(const Duration(hours: 2)));
      await done('a', h.now.subtract(const Duration(minutes: 30)));
      await done('b', h.now.subtract(const Duration(minutes: 10)));

      final applied = await ReminderActionService.drainPending(alarm: h.alarm);

      expect(applied.map((a) => a.title), ['First', 'Second']);
      expect(await ReminderActionQueue.drain(), isEmpty);
    });

    reminderTest('two drains at once apply each answer once', (h) async {
      await h.seed('r1', at: h.now.subtract(const Duration(hours: 1)));
      await done('r1', h.now);

      final both = await Future.wait([
        ReminderActionService.drainPending(alarm: h.alarm),
        ReminderActionService.drainPending(alarm: h.alarm),
      ]);

      expect(both.expand((x) => x), hasLength(1),
          reason: 'the shell drains on a cold start AND on resume');
      expect(h.alarm.disarmed, hasLength(1));
    });

    reminderTest('Undo puts the reminder back', (h) async {
      final due = h.now.subtract(const Duration(hours: 1));
      await h.seed('r1', at: due);
      await done('r1', h.now);

      final applied = await ReminderActionService.drainPending(alarm: h.alarm);
      expect(ReminderActionService.canUndo(applied), isTrue);
      await ReminderActionService.undo(applied, alarm: h.alarm);

      expect((await stored('r1'))!.isCompleted, isFalse);
      expect((await occurrenceOf(h, 'r1', due))!.outcome, 'pending');
    });
  });

  group('Later', () {
    DateTime eveningOf(ReminderHarness h) =>
        DateTime(h.now.year, h.now.month, h.now.day, 18);

    reminderTest('moves a one-off to the time it was set to ring, and arms it there',
        (h) async {
      final r = await h.seed('r1',
          title: 'Call the clinic', at: h.now.subtract(const Duration(hours: 1)));
      await later('r1', h.now, eveningOf(h));

      final applied = await ReminderActionService.drainPending(alarm: h.alarm);

      expect(applied.single.movedTo, eveningOf(h));
      expect(applied.single.movedLabel, 'this evening');
      final after = (await stored('r1'))!;
      expect(after.scheduledTime, eveningOf(h));
      expect(after.isCompleted, isFalse);
      expect(h.alarm.armed.single.id, r.notificationSlot);
      expect(h.alarm.armed.single.scheduledTime, eveningOf(h));
    });

    reminderTest('and withdraws the ring the button set up in the background, '
        'so it does not ring twice', (h) async {
      final r = await h.seed('r1', at: h.now.subtract(const Duration(hours: 1)));
      await later('r1', h.now, eveningOf(h));

      await ReminderActionService.drainPending(alarm: h.alarm);

      final slot = r.notificationSlot & 0x7FFFFFFF;
      expect(h.alarm.disarmed, contains((slot + snoozeIdOffset) & 0x7FFFFFFF),
          reason: 'one hop: Later tapped on the first ring');
      expect(h.alarm.disarmed, contains((slot + 2 * snoozeIdOffset) & 0x7FFFFFFF),
          reason: 'two: Later tapped on a snoozed re-fire');
      expect(
          h.alarm.disarmed,
          contains((slot + genericReminderFollowUpOffset + snoozeIdOffset) &
              0x7FFFFFFF),
          reason: 'or on its "Still pending" follow-up, whose id is its own');
    });

    reminderTest('where the OS refused its own alarm, the background ring stays',
        (h) async {
      await h.seed('r1', at: h.now.subtract(const Duration(hours: 1)));
      h.alarm.armResult = false;
      await later('r1', h.now, eveningOf(h));

      final applied = await ReminderActionService.drainPending(alarm: h.alarm);

      expect(applied, hasLength(1), reason: 'the move itself stands');
      expect(h.alarm.disarmed, isEmpty,
          reason: 'until the reminder\'s own alarm is armed, that ring is all there is');
    });

    reminderTest('a repeating reminder is put off for one ring: its schedule stays',
        (h) async {
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      await h.seed('r1', at: anchor, repeat: RepeatType.daily);
      await later('r1', h.now, eveningOf(h));

      final applied = await ReminderActionService.drainPending(alarm: h.alarm);

      expect(applied, isEmpty, reason: 'nothing changed in the list, so nothing to say');
      expect((await stored('r1'))!.scheduledTime, anchor);
      expect(h.alarm.armed, isEmpty);
      expect(await ReminderActionQueue.drain(), isEmpty, reason: 'but it is acknowledged');
    });

    reminderTest('one the person has since moved on past that time is left alone',
        (h) async {
      final tomorrow = DateTime(h.now.year, h.now.month, h.now.day + 1, 8);
      await h.seed('r1', at: tomorrow);
      await later('r1', h.now, eveningOf(h));

      expect(await ReminderActionService.drainPending(alarm: h.alarm), isEmpty);
      expect((await stored('r1'))!.scheduledTime, tomorrow,
          reason: 'a Later must never pull a reminder EARLIER');
    });

    reminderTest('one that is already done is left alone', (h) async {
      final due = h.now.subtract(const Duration(hours: 1));
      await h.seed('r1', at: due, isCompleted: true);
      await later('r1', h.now, eveningOf(h));

      expect(await ReminderActionService.drainPending(alarm: h.alarm), isEmpty);
      expect((await stored('r1'))!.isCompleted, isTrue);
    });

    reminderTest('applied after its time has already passed: moved, not armed',
        (h) async {
      // Tapped at 09:00, applied at 13:00 — the 18:00 ring is still ahead; make
      // it 11:00 instead: the ring has already rung, in the background.
      final at = DateTime(h.now.year, h.now.month, h.now.day, 9);
      final past = DateTime(h.now.year, h.now.month, h.now.day, 11);
      await h.seed('r1', at: DateTime(h.now.year, h.now.month, h.now.day, 8));
      await later('r1', at, past);

      await ReminderActionService.drainPending(alarm: h.alarm);

      expect((await stored('r1'))!.scheduledTime, past,
          reason: 'the list should say it was due at 11:00, and it was');
      expect(h.alarm.armed, isEmpty,
          reason: 'arming a past time would ring at once');
    });

    reminderTest('a Later with no time recorded is dropped, and acknowledged',
        (h) async {
      await h.seed('r1', at: h.now.subtract(const Duration(hours: 1)));
      await ReminderActionQueue.enqueue(
          reminderId: 'r1', action: ReminderNotificationAction.later, at: h.now);

      expect(await ReminderActionService.drainPending(alarm: h.alarm), isEmpty);
      expect(await ReminderActionQueue.drain(), isEmpty);
    });

    reminderTest('a Later and then a Done: moved to the evening, then ticked off',
        (h) async {
      // Due at 07:00; Later tapped at 08:00 for 11:00; Done tapped at 12:00.
      await h.seed('r1', at: h.now.subtract(const Duration(hours: 6)));
      await later('r1', h.now.subtract(const Duration(hours: 5)),
          DateTime(h.now.year, h.now.month, h.now.day, 11));
      await done('r1', h.now.subtract(const Duration(hours: 1)));

      final applied = await ReminderActionService.drainPending(alarm: h.alarm);

      expect(applied.map((a) => a.action), [
        ReminderNotificationAction.later,
        ReminderNotificationAction.done,
      ]);
      expect((await stored('r1'))!.isCompleted, isTrue);
    });
  });

  group('what the person is told', () {
    AppliedReminderAction doneOf(String title) => AppliedReminderAction(
        title: title, action: ReminderNotificationAction.done);
    AppliedReminderAction movedOf(String title, String label) =>
        AppliedReminderAction(
            title: title,
            action: ReminderNotificationAction.later,
            movedTo: DateTime(2026, 10, 27, 18),
            movedLabel: label);

    test('one done, by name', () {
      expect(ReminderActionService.say([doneOf('Call the clinic')]),
          'Marked "Call the clinic" done');
    });

    test('several done, by number', () {
      expect(ReminderActionService.say([doneOf('A'), doneOf('B'), doneOf('C')]),
          'Marked 3 reminders done');
    });

    test('one moved, and where to', () {
      expect(ReminderActionService.say([movedOf('Call the clinic', 'this evening')]),
          'Moved "Call the clinic" to this evening');
      expect(ReminderActionService.say([movedOf('Renew', 'tomorrow morning')]),
          'Moved "Renew" to tomorrow morning');
    });

    test('several moved, by number', () {
      expect(
          ReminderActionService.say(
              [movedOf('A', 'this evening'), movedOf('B', 'this evening')]),
          'Moved 2 reminders to later');
    });

    test('both, joined', () {
      expect(
          ReminderActionService.say(
              [doneOf('A'), movedOf('B', 'this evening')]),
          'Marked "A" done · Moved "B" to this evening');
    });

    test('nothing applied: nothing said', () {
      expect(ReminderActionService.say(const []), isNull);
    });

    test('only a Done can be undone', () {
      expect(ReminderActionService.canUndo([movedOf('B', 'this evening')]), isFalse);
      expect(
          ReminderActionService.canUndo([
            movedOf('B', 'this evening'),
            AppliedReminderAction(
                title: 'A',
                action: ReminderNotificationAction.done,
                done: _someDone()),
          ]),
          isTrue);
    });
  });

  // The shell is where the queue is drained, on a cold start and on resume.
  test('the shell drains reminder answers with the other notification answers', () {
    final src = File('lib/features/home/screens/app_shell.dart').readAsStringSync();
    final start = src.indexOf('Future<void> _drainQueuedAnswers()');
    expect(start, greaterThan(0));
    final end = src.indexOf('\n  /// A launcher-shortcut tap', start);
    final body = src.substring(start, end);
    expect(body, contains('ReminderActionService.drainPending()'));
    expect(body, contains('ReminderActionService.say(reminders)'));
    expect(body, contains('ReminderActionService.undo(reminders)'),
        reason: 'a Done the app wrote for them must have its Undo');
  });
}

DoneUndo _someDone() => DoneUndo(
      original: Reminder(
        id: 'x',
        title: 'x',
        body: '',
        scheduledTime: DateTime(2026, 10, 27, 9),
      ),
      occurrence: DateTime(2026, 10, 27, 9),
      armed: true,
    );
