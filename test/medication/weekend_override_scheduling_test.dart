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

  /// The fire-time gate, asserted by BEHAVIOUR.
  ///
  /// This used to grep `background_alarm_service.dart` for two substrings,
  /// because the gate was written inline inside the alarm isolate. It is now
  /// [slotBelongsToDay], called by both fire-time gates, so the decision can
  /// be exercised directly instead of pattern-matched.
  group('the fire-time gate compares the slot, not just the day', () {
    final saturday = DateTime(2026, 3, 7);
    final wednesday = DateTime(2026, 3, 4);

    test('premise: those dates really are a Saturday and a Wednesday', () {
      expect(saturday.weekday, DateTime.saturday);
      expect(wednesday.weekday, DateTime.wednesday);
    });

    final overridden = MedicineSchedule(
      frequencyType: FrequencyType.onceDaily,
      times: [ScheduledTime(hour: 7, minute: 0)],
      weekendTimes: [ScheduledTime(hour: 10, minute: 0)],
    );

    test('the weekday slot is suppressed on Saturday', () {
      expect(slotBelongsToDay(overridden, saturday, 7, 0), isFalse,
          reason: 'isActiveOnDate alone cannot tell 07:00 from 10:00, and the '
              '07:00 alarm is armed every day');
    });

    test('the weekend slot fires on Saturday', () {
      expect(slotBelongsToDay(overridden, saturday, 10, 0), isTrue);
    });

    test('and the reverse on a weekday', () {
      expect(slotBelongsToDay(overridden, wednesday, 7, 0), isTrue);
      expect(slotBelongsToDay(overridden, wednesday, 10, 0), isFalse);
    });

    test('a medicine with no override is unaffected on either day', () {
      final plain = MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 7, minute: 0)],
      );
      expect(slotBelongsToDay(plain, saturday, 7, 0), isTrue);
      expect(slotBelongsToDay(plain, wednesday, 7, 0), isTrue);
    });

    test('it fails OPEN when the comparison cannot be made', () {
      // No slot time on the alarm payload, and a schedule yielding nothing —
      // never silently drop a dose over a comparison that could not be made.
      expect(slotBelongsToDay(overridden, saturday, null, null), isTrue);
      expect(slotBelongsToDay(overridden, saturday, 7, null), isTrue);
    });

    /// Both fire-time gates are actually wired to it.
    ///
    /// The behaviour above is tested directly, but the two CALL SITES live
    /// inside the alarm isolate, which needs SharedPreferences and a platform
    /// channel to reach — so removing the call from either gate leaves every
    /// assertion above green. That is the gap this closes, and it is why the
    /// original version of this test read the source at all.
    ///
    /// Comments are stripped first: this file explains the gate at length, and
    /// a guard that its own prose satisfies is not a guard. (The registry
    /// guard in `e2e_string_registry_test.dart` was found passing for exactly
    /// that reason.)
    test('both gates in the alarm isolate call it', () {
      final src = File('lib/core/services/background_alarm_service.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

      final calls = RegExp(r'slotBelongsToDay\(').allMatches(src).length;
      expect(calls, 2,
          reason: 'one gate for the medicine slot alarm and one for the '
              'reminder-window nudges. Found $calls. The nudge gate is the '
              'one that shipped without it, so a windowed weekday dose nudged '
              'three times across the weekend morning the user had moved the '
              'dose away from.');
    });

    /// The window nudges had only the `isActiveOnDate` half of this gate.
    ///
    /// `_recomputeWindowNudges` builds nudges from the raw weekday
    /// `schedule.times`, so a windowed 08:00 dose with a 10:00 weekend
    /// override nudged at 08:00 / 08:30 / 09:00 on Saturday — three times, at
    /// the hour the override existed to avoid — alongside the real 10:00
    /// reminder. A Take from one of those wrote a log at an instant that is
    /// not a Saturday slot, decrementing stock while Today still showed the
    /// 10:00 dose pending.
    test('a windowed weekday slot does not nudge across the weekend', () {
      final windowed = MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0, windowMinutes: 60)],
        weekendTimes: [ScheduledTime(hour: 10, minute: 0)],
      );
      expect(slotBelongsToDay(windowed, saturday, 8, 0), isFalse,
          reason: 'the 08:00 nudge chain must be suppressed on Saturday');
      expect(slotBelongsToDay(windowed, wednesday, 8, 0), isTrue,
          reason: 'and must still fire on a weekday');
    });
  });
}
