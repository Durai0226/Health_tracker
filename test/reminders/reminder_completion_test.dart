/// Marking a reminder done — the one implementation behind its card, its
/// notification's Done button and the answers drained on resume.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_alarm.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_completion.dart';
import 'package:tablet_remainder/features/reminders/utils/reminder_occurrence.dart';

import '../support/reminder_harness.dart';

void main() {
  // The harness pins 13:00 today.
  Future<db.ReminderOccurrence?> occurrenceOf(
          ReminderHarness h, String id, DateTime at) =>
      h.database.remindersDao.getOccurrence(id, at);

  Future<Reminder?> stored(String id) async =>
      (await CleanStorageService.getAllReminders()).where((r) => r.id == id).firstOrNull;

  group('a one-off', () {
    reminderTest('is completed, its outcome written against its time, and disarmed',
        (h) async {
      final at = h.now.subtract(const Duration(hours: 1));
      final r = await h.seed('r1', at: at);

      final done = await ReminderCompletion.markDone(r, alarm: h.alarm);

      expect(done, isNotNull);
      expect((await stored('r1'))!.isCompleted, isTrue);
      final o = await occurrenceOf(h, 'r1', at);
      expect(o!.outcome, 'done');
      expect(o.source, 'app');
      expect(h.alarm.disarmed, [r.notificationSlot]);
      expect(h.alarm.armed, isEmpty);
      expect(done!.armed, isTrue, reason: 'nothing to arm is not a failure');
    });

    reminderTest('already done: left as it is, nothing written, nothing armed',
        (h) async {
      final r = await h.seed('r1', at: h.now.subtract(const Duration(hours: 1)), isCompleted: true);
      final done = await ReminderCompletion.markDone(r, alarm: h.alarm);
      expect(done, isNull, reason: 'a second Done must not undo the first');
      expect((await stored('r1'))!.isCompleted, isTrue);
      expect(await h.database.remindersDao.occurrencesBetween(
          DateTime(2000), DateTime(2100)), isEmpty);
      expect(h.alarm.disarmed, isEmpty);
    });

    reminderTest('a source can be named, for what asked', (h) async {
      final at = h.now.subtract(const Duration(hours: 1));
      final r = await h.seed('r1', at: at);
      await ReminderCompletion.markDone(r, source: 'notification', alarm: h.alarm);
      expect((await occurrenceOf(h, 'r1', at))!.source, 'notification');
    });
  });

  group('a repeating reminder', () {
    reminderTest('rolls forward to its next time, and the next is armed', (h) async {
      // A daily 09:00 reminder whose anchor is three days back.
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final r = await h.seed('r1', at: anchor, repeat: RepeatType.daily);

      final done = await ReminderCompletion.markDone(r, alarm: h.alarm);

      final after = (await stored('r1'))!;
      expect(after.isCompleted, isFalse, reason: 'a repeat does not finish');
      expect(after.scheduledTime.isAfter(h.now), isTrue);
      expect(h.alarm.armed, hasLength(1));
      expect(h.alarm.armed.single.id, r.notificationSlot);
      expect(done!.armed, isTrue);
    });

    reminderTest('the outcome goes on the occurrence due, not the stored anchor',
        (h) async {
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final dueToday = DateTime(h.now.year, h.now.month, h.now.day, 9);
      final r = await h.seed('r1', at: anchor, repeat: RepeatType.daily);
      expect(resolveReminderOccurrence(r, now: h.now), dueToday);

      await ReminderCompletion.markDone(r, alarm: h.alarm);

      expect((await occurrenceOf(h, 'r1', dueToday))!.outcome, 'done');
      expect(await occurrenceOf(h, 'r1', anchor), isNull);
    });

    reminderTest('the tap\'s own time decides the occurrence, however late it is applied',
        (h) async {
      // The tap was at 09:05 today; it is applied at 13:00 (the pinned clock),
      // after a second occurrence — tomorrow's 09:00 — has not yet come due.
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final tappedAt = DateTime(h.now.year, h.now.month, h.now.day - 1, 9, 5);
      final r = await h.seed('r1', at: anchor, repeat: RepeatType.daily);

      await ReminderCompletion.markDone(r, now: tappedAt, alarm: h.alarm);

      final yesterday = DateTime(h.now.year, h.now.month, h.now.day - 1, 9);
      final o = await occurrenceOf(h, 'r1', yesterday);
      expect(o!.outcome, 'done');
      expect(o.actedAt!.toLocal(), tappedAt, reason: 'when it was done, not when it was written');
    });

    reminderTest('one past its end date is finished, not rolled forward', (h) async {
      final at = h.now.subtract(const Duration(days: 1));
      final r = await h.seed('r1',
          at: at, repeat: RepeatType.daily, endsAt: h.now.subtract(const Duration(hours: 2)));
      await ReminderCompletion.markDone(r, alarm: h.alarm);
      expect((await stored('r1'))!.isCompleted, isTrue);
      expect(h.alarm.armed, isEmpty);
      expect(h.alarm.disarmed, [r.notificationSlot]);
    });

    reminderTest('a paused one is ticked and left on its schedule', (h) async {
      final at = h.now.subtract(const Duration(days: 2));
      final r = await h.seed('r1', at: at, repeat: RepeatType.daily, isPaused: true);
      await ReminderCompletion.markDone(r, alarm: h.alarm);
      final after = (await stored('r1'))!;
      expect(after.isCompleted, isFalse);
      expect(after.scheduledTime, at);
      expect(h.alarm.armed, isEmpty, reason: 'a paused reminder is never armed');
    });

    reminderTest('a refused arm is reported, and the tick stands', (h) async {
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final r = await h.seed('r1', at: anchor, repeat: RepeatType.daily);
      h.alarm.armResult = false;
      final done = await ReminderCompletion.markDone(r, alarm: h.alarm);
      expect(done!.armed, isFalse);
      expect((await stored('r1'))!.scheduledTime.isAfter(h.now), isTrue,
          reason: 'the roll-forward is already saved');
    });

    reminderTest('an arm that throws is reported too, not raised', (h) async {
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final r = await h.seed('r1', at: anchor, repeat: RepeatType.daily);
      final done = await ReminderCompletion.markDone(r, alarm: _ThrowingAlarm());
      expect(done!.armed, isFalse);
      expect((await stored('r1'))!.scheduledTime.isAfter(h.now), isTrue);
    });
  });

  reminderTest('a disarm that throws does not stop a one-off being completed',
      (h) async {
    final at = h.now.subtract(const Duration(hours: 1));
    final r = await h.seed('r1', at: at);
    await ReminderCompletion.markDone(r, alarm: _ThrowingAlarm());
    expect((await stored('r1'))!.isCompleted, isTrue);
  });

  group('undo', () {
    reminderTest('a one-off: back to open, its occurrence pending, re-armed', (h) async {
      final at = h.now.add(const Duration(hours: 1));
      final r = await h.seed('r1', at: at);
      final done = await ReminderCompletion.markDone(r, alarm: h.alarm);
      h.alarm.clear();

      await ReminderCompletion.undo(done!, alarm: h.alarm);

      expect((await stored('r1'))!.isCompleted, isFalse);
      expect((await occurrenceOf(h, 'r1', at))!.outcome, 'pending');
      expect(h.alarm.armed.single.id, r.notificationSlot);
    });

    reminderTest('a repeat: the old time back, and armed for it', (h) async {
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final r = await h.seed('r1', at: anchor, repeat: RepeatType.daily);
      final done = await ReminderCompletion.markDone(r, alarm: h.alarm);
      h.alarm.clear();

      await ReminderCompletion.undo(done!, alarm: h.alarm);

      expect((await stored('r1'))!.scheduledTime, anchor);
      final dueToday = DateTime(h.now.year, h.now.month, h.now.day, 9);
      expect((await occurrenceOf(h, 'r1', dueToday))!.outcome, 'pending');
    });

    reminderTest('an arm that throws does not stop the undo', (h) async {
      final at = h.now.add(const Duration(hours: 1));
      final r = await h.seed('r1', at: at);
      final done = await ReminderCompletion.markDone(r, alarm: h.alarm);
      await ReminderCompletion.undo(done!, alarm: _ThrowingAlarm());
      expect((await stored('r1'))!.isCompleted, isFalse);
    });
  });

  test('the harness really pins the clock these tests rely on', () {
    final pinned = DateTime(2026, 6, 20, 13);
    withClock(Clock.fixed(pinned), () => expect(clock.now(), pinned));
  });
}

class _ThrowingAlarm implements ReminderAlarm {
  @override
  Future<bool> arm(ReminderArmRequest request) async => throw StateError('arm');

  @override
  Future<void> disarm({
    required int id,
    required RepeatType repeatType,
    List<int>? customDays,
  }) async =>
      throw StateError('disarm');
}
