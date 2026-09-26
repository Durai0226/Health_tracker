import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/reminder_slot_grouping.dart';

/// The weekend time override was honoured by everything EXCEPT the schedulers.
///
/// `MedicineSchedule.getScheduledTimesForDate` substitutes `weekendTimes` on a
/// Sat/Sun, and Today, adherence and missed-dose reconciliation all use it. But
/// `groupRemindersBySlot` read the weekday `times` directly, and the fire-time
/// gate in `alarmCallback` checked only `isActiveOnDate` — not whether the
/// clock time was a slot for THAT day.
///
/// Levothyroxine at 07:00 weekdays with a 10:00 weekend override, on a Saturday:
/// the 07:00 alarm rang (wrong), a Take from it logged an orphan dose at a time
/// that is not a slot — still decrementing stock — Today went on showing the
/// 10:00 dose as pending, no 10:00 alarm had ever been armed, and at 13:00
/// reconciliation wrote a `missed` row for a dose the user had actually taken.
void main() {
  final saturday = DateTime(2026, 3, 7); // a Saturday
  final sunday = DateTime(2026, 3, 8);
  final wednesday = DateTime(2026, 3, 4);

  EnhancedMedicine levo() => EnhancedMedicine(
        id: 'levo',
        name: 'Levothyroxine',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 7, minute: 0)],
          weekendTimes: [ScheduledTime(hour: 10, minute: 0)],
          startDate: DateTime(2026, 3, 1),
        ),
        createdAt: DateTime(2026, 3, 1),
      );

  EnhancedMedicine plain() => EnhancedMedicine(
        id: 'plain',
        name: 'Aspirin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 9, minute: 0)],
          startDate: DateTime(2026, 3, 1),
        ),
        createdAt: DateTime(2026, 3, 1),
      );

  Set<String> clockTimes(DateTime date, List<EnhancedMedicine> meds) =>
      groupRemindersBySlot(meds, date)
          .map((s) => '${s.hour}:${s.minute}')
          .toSet();

  group('both slot sets are armed', () {
    test('positive: the weekend slot exists at all', () {
      expect(clockTimes(saturday, [levo()]), contains('10:0'),
          reason: 'the 10:00 weekend alarm was never armed, so the weekend '
              'dose had no reminder whatsoever');
    });

    test('the weekday slot is armed too, and the gate sorts out which fires',
        () {
      // Arming both is only safe because the fire-time gate checks the slot
      // against that day's scheduled times.
      expect(clockTimes(saturday, [levo()]), containsAll(['7:0', '10:0']));
      expect(clockTimes(wednesday, [levo()]), containsAll(['7:0', '10:0']));
    });

    test('negative: a medicine with no override is unchanged', () {
      expect(clockTimes(saturday, [plain()]), {'9:0'});
      expect(clockTimes(wednesday, [plain()]), {'9:0'});
    });

    test('duplicate clock times collapse to one slot', () {
      final same = EnhancedMedicine(
        id: 'same',
        name: 'Same',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
          weekendTimes: [ScheduledTime(hour: 8, minute: 0)],
          startDate: DateTime(2026, 3, 1),
        ),
        createdAt: DateTime(2026, 3, 1),
      );
      expect(clockTimes(saturday, [same]), {'8:0'});
    });
  });

  group('the schedule model still decides which slot belongs to a day', () {
    // This is what the fire gate now consults, so pin it directly.
    test('positive: Saturday and Sunday resolve to the weekend time', () {
      for (final d in [saturday, sunday]) {
        final slots = levo().schedule.getScheduledTimesForDate(d);
        expect(slots.map((t) => t.hour), [10],
            reason: 'the weekday 07:00 alarm must be suppressed at the gate');
      }
    });

    test('negative: a weekday resolves to the weekday time only', () {
      final slots = levo().schedule.getScheduledTimesForDate(wednesday);
      expect(slots.map((t) => t.hour), [7],
          reason: 'the weekend 10:00 alarm must be suppressed on Wednesday');
    });
  });

  test('the fire-time gate compares the slot, not just the day', () {
    // The gate lives in the alarm isolate and needs SharedPreferences plus a
    // platform channel, so its decision is pinned by source — the repo already
    // uses this idiom for alarm-isolate behaviour.
    final src =
        File('lib/core/services/background_alarm_service.dart').readAsStringSync();
    expect(src, contains('schedule.getScheduledTimesForDate(doseInstant)'),
        reason: 'isActiveOnDate alone cannot tell 07:00 from 10:00 on a '
            'Saturday');
    expect(src, contains('t.hour == slotHour && t.minute == slotMinute'));
  });
}
