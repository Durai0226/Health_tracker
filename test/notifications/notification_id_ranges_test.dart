import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
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

  /// Every OTHER family had a reserved block and a test here. Generic user
  /// reminders had neither: their ids were `uuid.hashCode & 0x7FFFFFFF`, which
  /// can land anywhere in the 31-bit space — including directly on top of the
  /// bedtime, focus, water or period ids below. A collision means one reminder
  /// cancels or overwrites another's alarm, with nothing to indicate it.
  group('generic user reminders now have a reserved block too', () {
    /// The whole allocatable block, plus the sub-ids and snooze twin the
    /// scheduler derives from each one.
    Iterable<int> genericIds() => [
          for (var i = 0; i < genericReminderIdCapacity; i++)
            genericReminderIdBase + i,
        ];

    /// `scheduleGenericReminder` arms weekday/weekend/custom repeats at
    /// `base + weekday`, so those must stay inside the block too.
    Iterable<int> genericSubIds() => [
          for (var i = 0; i < genericReminderIdCapacity; i++)
            for (var d = 1; d <= 7; d++) genericReminderIdBase + i + d,
        ];

    test('the block and its weekday sub-ids stay inside 970000-979999', () {
      for (final id in [...genericIds(), ...genericSubIds()]) {
        expect(id, greaterThanOrEqualTo(970000));
        expect(id, lessThan(980000),
            reason: '$id escaped the block — 990001 is the period family');
      }
    });

    test('does not collide with ANY other reserved id', () {
      final others = <int>{
        ...waterIds(),
        NotificationService.waterReminderBaseId,
        for (final spec in VitalsReminderService.all) spec.id,
        NotificationService.bedtimeReminderId,
        NotificationService.stepReminderId,
        NotificationService.stepReminderTodayId,
        NotificationService.wakeAlarmId,
        NotificationService.focusDailyReminderId,
        // Medicine slots: one per minute of the day, plus their snooze twins.
        for (var m = 0; m < 1440; m++) slotIdOffset + m,
        for (var m = 0; m < 1440; m++) slotIdOffset + m + snoozeIdOffset,
      };
      final generic = {...genericIds(), ...genericSubIds()};
      expect(generic.intersection(others), isEmpty);
    });

    test('the snooze twin block is also disjoint', () {
      // Every snooze re-arms at `id + snoozeIdOffset`, so the twin range needs
      // the same clearance the block itself does.
      final twins = {
        for (final id in genericIds()) id + snoozeIdOffset,
      };
      expect(twins.first, genericReminderSnoozeIdBase);
      // Must not fall back onto the medicine slot block or the water block.
      for (final id in twins) {
        expect(id, greaterThanOrEqualTo(1070000));
        expect(
          [
            NotificationService.bedtimeReminderId,
            NotificationService.stepReminderId,
            NotificationService.wakeAlarmId,
            NotificationService.focusDailyReminderId,
          ].contains(id),
          isFalse,
        );
      }
    });

    test('the DAO\'s snooze-offset mirror matches the real one', () {
      // reminders_dao.dart duplicates the constant so a DAO never imports the
      // notification layer. Duplicated constants drift; this is the pin.
      expect(snoozeIdOffsetForIdRanges, snoozeIdOffset);
    });

    test('the capacity leaves room for the weekday sub-ids', () {
      // The highest sub-id must still be inside the block.
      final highest = genericReminderIdBase + genericReminderIdCapacity - 1 + 7;
      expect(highest, lessThan(980000));
    });
  });

  group('interval water reminders vs the rest of the app', () {
    test('do not collide with the vitals reminders', () {
      // Regression: water sat at 900000-900099, which SWALLOWED the four
      // vitals ids. A user with 21+ interval reminders (every 40 min across a
      // waking day) had their blood-pressure and blood-sugar reminders
      // replaced by water ones, and every reschedule sweep deleted them.
      final vitals = <int>{
        for (final spec in VitalsReminderService.all) spec.id,
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
          NotificationService.stepReminderTodayId,
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

  group('the Focus block', () {
    // Focus notifications live in a reserved 918_4xx block. Two of the four ids
    // predate it and were scheduled through `scheduleGenericReminder`, which on
    // Android hands them to AlarmManager — so they were already load-bearing
    // before anything asserted they were unique.
    const focusIds = <int>{
      NotificationService.focusDailyReminderId,
      NotificationService.focusStreakReminderId,
      NotificationService.focusSessionEndId,
    };

    test('has distinct ids inside its reserved range', () {
      expect(focusIds.length, 3, reason: 'two Focus ids collided');
      for (final id in focusIds) {
        expect(id >= 918_400 && id < 918_500, isTrue,
            reason: '$id escaped the reserved 918_4xx block');
      }
    });

    test('does not collide with water, vitals, bedtime, step or wake', () {
      expect(focusIds.intersection(waterIds().toSet()), isEmpty);
      expect(
        focusIds.intersection({
          for (final spec in VitalsReminderService.all) spec.id,
          NotificationService.bedtimeReminderId,
          NotificationService.stepReminderId,
          NotificationService.wakeAlarmId,
          900001, // onboarding's daily check-in
        }),
        isEmpty,
      );
    });

    test('does not collide with medicine slots or their snooze twins', () {
      // This is the one that matters most. A Focus id landing on a medicine slot
      // would mean a session-complete banner REPLACING a dose reminder, and the
      // Focus reschedule sweep silently cancelling it.
      final slots = <int>{
        for (int m = 0; m < 1440; m++) slotNotificationId(m ~/ 60, m % 60),
      };
      expect(focusIds.intersection(slots), isEmpty);
      expect(focusIds.intersection(slots.map((id) => id + 100000).toSet()),
          isEmpty);
    });

    test('does not collide with caregiver, period or window-nudge blocks', () {
      for (final id in focusIds) {
        expect(id >= 920000 && id <= 920999, isFalse,
            reason: '$id lands in the caregiver alert block');
        expect(id >= 990001 && id <= 990004, isFalse,
            reason: '$id lands in the period reminder block');
        expect(id >= windowNudgeIdOffset && id < windowNudgeId(400, 0, 0),
            isFalse,
            reason: '$id lands in the window-nudge block');
      }
    });
  });
}
