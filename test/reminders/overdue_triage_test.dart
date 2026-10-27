/// Catching up on a heap of overdue reminders: move the one-offs, or let it all
/// go, and take the whole thing back with one Undo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/overdue_triage.dart';

import '../support/reminder_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Reminder> stored(String id) async =>
      (await CleanStorageService.getAllReminders()).singleWhere((r) => r.id == id);

  Future<String?> outcomeAt(String id, DateTime at) async {
    final rows = await CleanStorageService.getReminderOccurrences(id);
    final match = rows.where((o) => o.scheduledFor == at);
    return match.isEmpty ? null : match.single.outcome;
  }

  group('which reminders are overdue', () {
    reminderTest('open, past due and not paused, oldest first', (h) async {
      final a = await h.seed('late-1',
          at: h.now.subtract(const Duration(hours: 1)));
      final b = await h.seed('late-2',
          at: h.now.subtract(const Duration(days: 2)));
      final done = await h.seed('done',
          at: h.now.subtract(const Duration(hours: 3)), isCompleted: true);
      final paused = await h.seed('paused',
          at: h.now.subtract(const Duration(hours: 3)), isPaused: true);
      final later = await h.seed('later',
          at: h.now.add(const Duration(hours: 3)));

      final overdue =
          OverdueTriage.overdueOf([a, done, later, b, paused], h.now);
      expect(overdue.map((r) => r.id), ['late-2', 'late-1']);
    });

    reminderTest('a one-off can be moved; a repeating one cannot', (h) async {
      final one = await h.seed('one');
      final daily = await h.seed('daily', repeat: RepeatType.daily);
      final rule = await h.seed('rule',
          recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=3');
      expect(OverdueTriage.canMove(one), isTrue);
      expect(OverdueTriage.canMove(daily), isFalse);
      expect(OverdueTriage.canMove(rule), isFalse,
          reason: 'a Smart Add repeat has repeatType none but is not a one-off');
    });
  });

  group('the slots', () {
    DateTime on(int h, [int m = 0]) => DateTime(2026, 3, 14, h, m);

    test('in the daytime, tonight is 18:00', () {
      expect(OverdueTriage.tonight(on(10)), on(18));
      expect(OverdueTriage.tonight(on(0, 5)), on(18));
    });

    test('an hour before the evening slot is still that slot', () {
      expect(OverdueTriage.tonight(on(17)), on(18));
    });

    test('later than that, an hour on, rounded up to the half hour', () {
      expect(OverdueTriage.tonight(on(17, 10)), on(18, 30));
      expect(OverdueTriage.tonight(on(19, 20)), on(20, 30));
      expect(OverdueTriage.tonight(on(19, 30)), on(20, 30));
      expect(OverdueTriage.tonight(on(19, 31)), on(21));
    });

    test('there is no tonight left from about 21:00', () {
      expect(OverdueTriage.tonight(on(20, 45)), isNull);
      expect(OverdueTriage.tonight(on(21)), isNull);
      expect(OverdueTriage.tonight(on(22, 30)), isNull);
    });

    test('an hour from now being tomorrow is not tonight', () {
      expect(OverdueTriage.tonight(on(23, 30)), isNull,
          reason: '00:30 tomorrow is not "later today", and 00:30 today is '
              'in the past');
    });

    test('the label follows the hour', () {
      expect(OverdueTriage.tonightLabel(on(18)), 'This evening');
      expect(OverdueTriage.tonightLabel(on(19, 30)), 'This evening');
      expect(OverdueTriage.tonightLabel(on(20)), 'Tonight');
    });

    test('tomorrow morning is 9:30, across a month end', () {
      expect(OverdueTriage.tomorrowMorning(DateTime(2026, 3, 14, 23, 50)),
          DateTime(2026, 3, 15, 9, 30));
      expect(OverdueTriage.tomorrowMorning(DateTime(2026, 1, 31, 8)),
          DateTime(2026, 2, 1, 9, 30));
    });
  });

  group('move', () {
    reminderTest('one-offs go to the slot, are armed there, and the occurrence '
        'they leave is settled as skipped', (h) async {
      final a = await h.seed('a', at: h.now.subtract(const Duration(hours: 4)));
      final b = await h.seed('b', at: h.now.subtract(const Duration(days: 1)));
      // The re-arm pass has derived a pending row for each by now.
      await CleanStorageService.recordDueReminderOccurrences();
      expect(await outcomeAt('a', a.scheduledTime), 'pending');

      final slot = DateTime(h.now.year, h.now.month, h.now.day, 18);
      final done = await OverdueTriage.move([a, b], to: slot, alarm: h.alarm);

      expect(done.count, 2);
      expect((await stored('a')).scheduledTime, slot);
      expect((await stored('b')).scheduledTime, slot);
      expect((await stored('a')).isCompleted, isFalse);
      expect(h.alarm.armed.map((r) => r.scheduledTime), [slot, slot]);
      expect(await outcomeAt('a', a.scheduledTime), 'skipped',
          reason: 'put off on purpose, not missed: the sweep must not write '
              'it off, and adherence does not count a skip against anyone');
    });

    reminderTest('repeating reminders are left exactly as they were',
        (h) async {
      final one = await h.seed('one', at: h.now.subtract(const Duration(hours: 2)));
      final daily = await h.seed('daily',
          at: h.now.subtract(const Duration(hours: 5)),
          repeat: RepeatType.daily);

      final slot = DateTime(h.now.year, h.now.month, h.now.day, 18);
      final done =
          await OverdueTriage.move([one, daily], to: slot, alarm: h.alarm);

      expect(done.count, 1);
      expect((await stored('daily')).scheduledTime, daily.scheduledTime);
      expect(h.alarm.armed, hasLength(1),
          reason: 'only the one-off was re-armed');
    });

    reminderTest('undo puts the time, the alarm and the occurrence back',
        (h) async {
      final a = await h.seed('a', at: h.now.subtract(const Duration(hours: 4)));
      await CleanStorageService.recordDueReminderOccurrences();
      final slot = DateTime(h.now.year, h.now.month, h.now.day, 18);

      final done = await OverdueTriage.move([a], to: slot, alarm: h.alarm);
      h.alarm.clear();
      await OverdueTriage.undo(done, alarm: h.alarm);

      expect((await stored('a')).scheduledTime, a.scheduledTime);
      expect(await outcomeAt('a', a.scheduledTime), 'pending');
      // Re-armed at the original time, which is in the past: the request says
      // so and the alarm adapter decides what an overdue arm means.
      expect(h.alarm.armed.single.scheduledTime, a.scheduledTime);
    });
  });

  group('skip', () {
    reminderTest('a one-off is closed, disarmed, and recorded as skipped',
        (h) async {
      final a = await h.seed('a', at: h.now.subtract(const Duration(hours: 4)));
      await CleanStorageService.recordDueReminderOccurrences();

      final done = await OverdueTriage.skip([a], alarm: h.alarm);

      expect(done.count, 1);
      expect((await stored('a')).isCompleted, isTrue);
      expect(h.alarm.disarmed, [a.notificationSlot]);
      expect(await outcomeAt('a', a.scheduledTime), 'skipped');
    });

    reminderTest(
        'a daily reminder jumps to its next time, with today\'s recorded as '
        'skipped', (h) async {
      // Anchored three days back at 09:00; it is 13:00, so today's 09:00 is the
      // occurrence that came due and the next is tomorrow's.
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final daily = await h.seed('daily', at: anchor, repeat: RepeatType.daily);
      final today9 = DateTime(h.now.year, h.now.month, h.now.day, 9);
      final tomorrow9 = DateTime(h.now.year, h.now.month, h.now.day + 1, 9);

      final done = await OverdueTriage.skip([daily], alarm: h.alarm);

      expect(done.count, 1);
      final after = await stored('daily');
      expect(after.scheduledTime, tomorrow9);
      expect(after.isCompleted, isFalse, reason: 'it repeats: not finished');
      expect(await outcomeAt('daily', today9), 'skipped');
      expect(h.alarm.armed.single.scheduledTime, tomorrow9);
      expect(h.alarm.disarmed, isEmpty);
    });

    reminderTest('a Smart Add repeat also jumps on, instead of closing',
        (h) async {
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 1, 9);
      final rule = await h.seed('rule',
          at: anchor, recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=1');

      await OverdueTriage.skip([rule], alarm: h.alarm);

      final after = await stored('rule');
      expect(after.isCompleted, isFalse);
      expect(after.scheduledTime.isAfter(h.now), isTrue);
    });

    reminderTest('a repeating reminder with nothing left to come is closed',
        (h) async {
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final ended = await h.seed('ended',
          at: anchor,
          repeat: RepeatType.daily,
          endsAt: DateTime(h.now.year, h.now.month, h.now.day - 1));

      await OverdueTriage.skip([ended], alarm: h.alarm);

      expect((await stored('ended')).isCompleted, isTrue,
          reason: 'rolling it forward would leave it overdue for ever');
      expect(h.alarm.disarmed, [ended.notificationSlot]);
    });

    reminderTest('undo brings every reminder back as it was', (h) async {
      final one = await h.seed('one', at: h.now.subtract(const Duration(hours: 4)));
      final anchor = DateTime(h.now.year, h.now.month, h.now.day - 3, 9);
      final daily = await h.seed('daily', at: anchor, repeat: RepeatType.daily);
      await CleanStorageService.recordDueReminderOccurrences();

      final done = await OverdueTriage.skip([one, daily], alarm: h.alarm);
      await OverdueTriage.undo(done, alarm: h.alarm);

      expect((await stored('one')).isCompleted, isFalse);
      expect((await stored('daily')).scheduledTime, anchor);
      expect(await outcomeAt('one', one.scheduledTime), 'pending');
      final today9 = DateTime(h.now.year, h.now.month, h.now.day, 9);
      expect(await outcomeAt('daily', today9), 'pending');
    });
  });
}
