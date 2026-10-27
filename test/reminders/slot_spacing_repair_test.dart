/// Reminders that repeat on chosen days own a week of notification ids.
///
/// Armed under `slot + 1 … slot + 7`, one a weekday — and the OS keeps one
/// pending notification per id. Slots were handed out `970000, 970001, 970002 …`,
/// so a weekday reminder's Tuesday was the next reminder's slot: whichever was
/// armed second replaced the first, and one of the two never fired.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/core/utils/reminder_slot_spacing.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';

import '../support/reminder_harness.dart';

void main() {
  const base = genericReminderIdBase;

  /// A reminder written the way an older build left it: its slot already chosen.
  Future<Reminder> legacy(
    ReminderHarness h,
    String id, {
    required int slot,
    required int ageInDays,
    RepeatType repeat = RepeatType.none,
    List<int>? customDays,
  }) async {
    final r = Reminder(
      id: id,
      title: id,
      body: '',
      scheduledTime: h.now.add(const Duration(hours: 2)),
      repeatType: repeat,
      customDays: customDays,
      notificationId: slot,
      createdAt: h.now.subtract(Duration(days: ageInDays)),
    );
    await CleanStorageService.saveReminder(r);
    return r;
  }

  Future<Map<String, int>> slots() async => {
        for (final r in await CleanStorageService.getAllReminders())
          r.id: r.notificationId!
      };

  group('new reminders', () {
    reminderTest('are given slots a week of ids apart', (h) async {
      final a = await h.seed('a');
      final b = await h.seed('b');
      final c = await h.seed('c');

      expect([a.notificationId, b.notificationId, c.notificationId],
          [base, base + 8, base + 16]);
    });

    reminderTest('so a weekday reminder\'s days land on nobody else\'s slot',
        (h) async {
      final weekdays = await h.seed('weekdays', repeat: RepeatType.weekdays);
      final others = [
        for (var i = 0; i < 6; i++) await h.seed('other-$i'),
      ];

      final mine = {for (var d = 0; d <= 7; d++) weekdays.notificationId! + d};
      for (final o in others) {
        expect(mine.contains(o.notificationId), isFalse,
            reason: '${o.id} at ${o.notificationId} sits inside the ids '
                '${weekdays.notificationId}..+7 that "weekdays" is armed under');
      }
    });

    reminderTest('a deleted reminder\'s place comes back before the block grows',
        (h) async {
      await h.seed('a');
      final b = await h.seed('b');
      await h.seed('c');
      await h.database.remindersDao.deleteReminder('b');

      final d = await h.seed('d');
      expect(d.notificationId, b.notificationId);
    });

    reminderTest('sit clear of ones an older build gave out a number apart', (h) async {
      await legacy(h, 'old-1', slot: base, ageInDays: 9);
      await legacy(h, 'old-2', slot: base + 1, ageInDays: 8);
      await legacy(h, 'old-3', slot: base + 2, ageInDays: 7);

      final fresh = await h.seed('fresh');
      expect(fresh.notificationId, base + 10,
          reason: 'clear of base + 2\'s whole week, not squeezed in after it');
    });
  });

  group('slots already handed out one apart', () {
    reminderTest('the oldest keeps its slot and the others move a week apart',
        (h) async {
      await legacy(h, 'weekdays', slot: base, ageInDays: 30, repeat: RepeatType.weekdays);
      await legacy(h, 'second', slot: base + 1, ageInDays: 20);
      await legacy(h, 'third', slot: base + 2, ageInDays: 10);
      await legacy(h, 'fourth', slot: base + 3, ageInDays: 1);

      await ReminderRescheduleService.rescheduleGenericReminders(alarm: h.alarm);

      final after = await slots();
      expect(after['weekdays'], base, reason: 'the oldest has been armed longest');
      expect(ReminderSlotSpacing.clashing(after.values.toList(), (s) => s), isEmpty,
          reason: 'no two share an id any more: $after');
      expect(after.values.toSet(), hasLength(4));
    });

    reminderTest('what was armed under the old slot is taken off, and all are armed again',
        (h) async {
      await legacy(h, 'weekdays', slot: base, ageInDays: 30, repeat: RepeatType.weekdays);
      await legacy(h, 'second', slot: base + 1, ageInDays: 20);

      await ReminderRescheduleService.rescheduleGenericReminders(alarm: h.alarm);

      final after = await slots();
      final firstDisarm = h.alarm.sequence.indexOf('disarm:${base + 1}');
      expect(firstDisarm, greaterThanOrEqualTo(0),
          reason: 'the slot it was armed under must be cleared');
      expect(h.alarm.armed.map((r) => r.id).toSet(),
          {after['weekdays'], after['second']},
          reason: 'every reminder is armed, under the slot it now has');
      expect(h.alarm.sequence.indexOf('arm:${after['second']}'),
          greaterThan(firstDisarm),
          reason: 'cleared before the new registration, or the old one is orphaned');
    });

    reminderTest('a second pass moves nothing', (h) async {
      await legacy(h, 'a', slot: base, ageInDays: 3, repeat: RepeatType.weekdays);
      await legacy(h, 'b', slot: base + 1, ageInDays: 2);
      await legacy(h, 'c', slot: base + 2, ageInDays: 1, repeat: RepeatType.weekends);

      await ReminderRescheduleService.rescheduleGenericReminders(alarm: h.alarm);
      final first = await slots();
      h.alarm.clear();
      await ReminderRescheduleService.rescheduleGenericReminders(alarm: h.alarm);

      expect(await slots(), first);
      expect(h.alarm.disarmed.toSet(), first.values.toSet(),
          reason: 'only the ordinary clear-then-arm of each reminder under its own '
              'slot: nothing is moved again');
    });

    reminderTest('already apart, nothing is touched', (h) async {
      await legacy(h, 'a', slot: base, ageInDays: 3);
      await legacy(h, 'b', slot: base + 8, ageInDays: 2);
      await legacy(h, 'c', slot: base + 16, ageInDays: 1);

      await ReminderRescheduleService.rescheduleGenericReminders(alarm: h.alarm);

      expect(await slots(), {'a': base, 'b': base + 8, 'c': base + 16});
    });

    reminderTest('already apart but not packed, they stay exactly where they are',
        (h) async {
      // A reminder that has been armed under a slot for months keeps it: moving
      // it for the sake of tidiness would re-arm it for nothing.
      await legacy(h, 'a', slot: base + 8, ageInDays: 3);
      await legacy(h, 'b', slot: base + 40, ageInDays: 2, repeat: RepeatType.weekdays);
      await legacy(h, 'c', slot: base + 100, ageInDays: 1);

      await ReminderRescheduleService.rescheduleGenericReminders(alarm: h.alarm);

      expect(await slots(), {'a': base + 8, 'b': base + 40, 'c': base + 100});
    });

    reminderTest('reminders with no slot yet are not mistaken for clashes', (h) async {
      await legacy(h, 'a', slot: base, ageInDays: 3);
      await CleanStorageService.saveReminder(Reminder(
        id: 'legacy-id',
        title: 'legacy-id',
        body: '',
        scheduledTime: h.now.add(const Duration(hours: 3)),
      ));

      await ReminderRescheduleService.rescheduleGenericReminders(alarm: h.alarm);

      final after = await slots();
      expect(after['a'], base);
      expect(after['legacy-id'], base + 8,
          reason: 'given a clear slot of its own, beside the one that was there');
    });

    reminderTest('a reminder with no clear place left is left alone, not lost', (h) async {
      // 130 slots handed out one apart: a block that holds 125 whole weeks cannot
      // give every one of them a place.
      for (var i = 0; i < 130; i++) {
        await legacy(h, 'r$i', slot: base + i, ageInDays: 200 - i);
      }

      await ReminderRescheduleService.rescheduleGenericReminders(alarm: h.alarm);

      final after = await slots();
      expect(after, hasLength(130), reason: 'not one reminder was dropped');
      final stillClashing =
          ReminderSlotSpacing.clashing(after.entries.toList(), (e) => e.value);
      expect(stillClashing.length, lessThan(130 - 100),
          reason: 'most were separated; the ones left over keep a slot they had');
      for (final s in after.values) {
        expect(s, greaterThanOrEqualTo(base));
        expect(s + 7, lessThan(base + genericReminderIdCapacity + 130),
            reason: 'nothing walked out of the reserved block');
      }
    });
  });

  group('the repair is just what it says', () {
    reminderTest('it leaves completed one-offs where they are, armed or not', (h) async {
      await legacy(h, 'done', slot: base, ageInDays: 10);
      await CleanStorageService.saveReminder(Reminder(
        id: 'done',
        title: 'done',
        body: '',
        scheduledTime: h.now.subtract(const Duration(days: 1)),
        isCompleted: true,
        notificationId: base,
        createdAt: h.now.subtract(const Duration(days: 10)),
      ));
      await legacy(h, 'live', slot: base + 1, ageInDays: 1);

      await ReminderRescheduleService.rescheduleGenericReminders(alarm: h.alarm);

      final after = await slots();
      expect(after['done'], base, reason: 'the older one keeps its slot');
      expect(after['live'], isNot(base + 1));
      expect(h.alarm.armed.map((r) => r.id), [after['live']],
          reason: 'and only the live one is armed');
    });
  });
}
