import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/services/reminder_slot_grouping.dart';
import 'package:tablet_remainder/features/medication/services/reminder_window_nudges.dart';
import 'package:tablet_remainder/features/medication/services/vitals_reminder_service.dart';

/// A notification id is last-write-wins: two reminders that compute the same id
/// are ONE notification, and cancelling that id kills both. These are the
/// app's fixed reserved blocks — they must stay disjoint.
void main() {
  Iterable<int> waterIds() => List.generate(
      NotificationService.maxWaterReminders,
      (i) => NotificationService.waterReminderBaseId + i);

  group('interval water reminders vs the rest of the app', () {
    test('do not collide with the vitals reminders', () {
      // Regression: water sat at 900000-900099, which SWALLOWED the four
      // vitals ids. A user with 21+ interval reminders (every 40 min across a
      // waking day) had their blood-pressure and blood-sugar reminders
      // replaced by water ones, and every reschedule sweep deleted them.
      final vitals = <int>{
        VitalsReminderService.bp.id,
        VitalsReminderService.glucose.id,
        VitalsReminderService.weight.id,
        VitalsReminderService.mood.id,
      };
      expect(waterIds().toSet().intersection(vitals), isEmpty);
    });

    test('do not collide with onboarding\'s daily check-in', () {
      // welcome_screen.dart schedules this fixed id.
      expect(waterIds().contains(900001), isFalse);
    });

    test('do not collide with bedtime / step / wake', () {
      expect(
        waterIds().toSet().intersection({
          NotificationService.bedtimeReminderId,
          NotificationService.stepReminderId,
          NotificationService.wakeAlarmId,
        }),
        isEmpty,
      );
    });

    test('do not collide with medicine slots or their snooze twins', () {
      // Slots span one id per minute of the day, snoozes are +100000.
      final slots = <int>{
        for (int m = 0; m < 1440; m++) slotNotificationId(m ~/ 60, m % 60),
      };
      final slotSnoozes = slots.map((id) => id + 100000).toSet();
      expect(waterIds().toSet().intersection(slots), isEmpty);
      expect(waterIds().toSet().intersection(slotSnoozes), isEmpty);
    });

    test('do not collide with caregiver alerts, window nudges or period', () {
      for (final id in waterIds()) {
        expect(id >= 920000 && id <= 920999, isFalse,
            reason: '$id lands in the caregiver alert block');
        expect(id >= 990001 && id <= 990004, isFalse,
            reason: '$id lands in the period reminder block');
        // Window nudges grow with the number of medicines; keep a wide margin.
        final nudgeCeiling = windowNudgeId(400, 0, 0);
        expect(id >= windowNudgeIdOffset && id < nudgeCeiling, isFalse,
            reason: '$id lands in the window-nudge block');
      }
    });

    test('the legacy block is still swept, minus the ids it never owned', () {
      // The move would otherwise orphan water reminders scheduled by an older
      // build — nothing else can cancel them once the base id changes.
      expect(NotificationService.legacyWaterReminderBaseId, 900000);
      expect(NotificationService.legacyWaterReminderBaseId,
          isNot(NotificationService.waterReminderBaseId));
    });
  });
}
