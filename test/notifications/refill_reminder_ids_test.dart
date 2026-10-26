import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/features/medication/services/refill_loop.dart';
import 'package:tablet_remainder/features/medication/services/refill_reminder_service.dart';
import 'package:tablet_remainder/features/medication/services/reminder_slot_grouping.dart';
import 'package:tablet_remainder/features/medication/services/reminder_window_nudges.dart';

/// Running out of medication is a total adherence failure that no reminder can
/// rescue after the fact — and it is entirely predictable. `RefillPredictor`
/// has computed `refillByDate` and a notification-ready `summary` all along; its
/// own docstring says the summary is *"suitable for a card or notification"*.
/// It only ever became a card.
void main() {
  group('the refill block is disjoint and future-proof', () {
    Iterable<int> refillIds() => [
          for (var i = 0; i < refillReminderCapacity; i++)
            refillReminderIdBase + i,
        ];

    test('it sits below the window-nudge block, not above it', () {
      // Window nudges are allocated as `930000 + medicineIndex * 72`, so a block
      // just above them would silently cap how many medicines a user may have
      // before ids collide. Below 930000 there is no such growth path.
      expect(refillReminderIdBase + refillReminderCapacity,
          lessThan(windowNudgeIdOffset));
    });

    test('it clears the medicine slot block and its snooze twins', () {
      // Slots occupy 100000-101439 and their +100000 twins 200000-201439.
      expect(refillReminderIdBase, greaterThan(slotIdOffset + 1440 + 100000));
    });

    test('no refill id collides with any other reserved id', () {
      final others = <int>{
        for (var m = 0; m < 1440; m++) slotIdOffset + m,
        for (var m = 0; m < 1440; m++) slotIdOffset + m + 100000,
        NotificationService.waterReminderBaseId,
        NotificationService.bedtimeReminderId,
        NotificationService.stepReminderId,
        NotificationService.wakeAlarmId,
        NotificationService.focusDailyReminderId,
        for (var i = 0; i < genericReminderIdCapacity; i++)
          genericReminderIdBase + i,
      };
      expect(refillIds().toSet().intersection(others), isEmpty);
    });

    test('the follow-up block is next door, disjoint, and below the nudges', () {
      // "Did you pick it up?" ids sit in the 1000 right after the run-out ids.
      expect(RefillLoop.followUpIdBase,
          refillReminderIdBase + refillReminderCapacity);
      expect(RefillLoop.followUpIdBase + RefillLoop.followUpCapacity,
          lessThan(windowNudgeIdOffset));
      for (final id in ['a', 'med-1', 'a-very-long-uuid-like-string', '']) {
        expect(RefillLoop.followUpIdFor(id),
            isNot(RefillReminderService.notificationIdFor(id)));
      }
      final others = <int>{
        NotificationService.waterReminderBaseId,
        NotificationService.bedtimeReminderId,
        NotificationService.stepReminderId,
        NotificationService.stepReminderTodayId,
        NotificationService.wakeAlarmId,
        NotificationService.focusDailyReminderId,
        for (var m = 0; m < 1440; m++) slotIdOffset + m,
        for (var m = 0; m < 1440; m++) slotIdOffset + m + 100000,
        for (var i = 0; i < genericReminderIdCapacity; i++)
          genericReminderIdBase + i,
      };
      for (var i = 0; i < RefillLoop.followUpCapacity; i++) {
        expect(others.contains(RefillLoop.followUpIdBase + i), isFalse);
      }
    });

    test('the id is stable for a given medicine', () {
      // Re-arming must REPLACE, not duplicate — stock changes constantly, so
      // this runs on every app start.
      expect(RefillReminderService.notificationIdFor('med-abc'),
          RefillReminderService.notificationIdFor('med-abc'));
    });

    test('every derived id lands inside the block', () {
      for (final id in ['a', 'med-1', 'a-very-long-uuid-like-string', '']) {
        final n = RefillReminderService.notificationIdFor(id);
        expect(n, greaterThanOrEqualTo(refillReminderIdBase));
        expect(n, lessThan(refillReminderIdBase + refillReminderCapacity));
      }
    });
  });

  group('it rides the shared reschedule pass', () {
    test('refills are a registered family', () {
      expect(ReminderRescheduleService.familyNames, contains('refills'));
    });
  });
}
