import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/critical_follow_up.dart';
import 'package:tablet_remainder/features/medication/services/reminder_slot_grouping.dart';

EnhancedMedicine _med(
  String id, {
  bool critical = false,
  int? windowMinutes,
  FrequencyType frequency = FrequencyType.onceDaily,
  List<ScheduledTime>? weekendTimes,
  int hour = 8,
}) =>
    EnhancedMedicine(
      id: id,
      name: id,
      strength: '5mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      criticalAlert: critical,
      schedule: MedicineSchedule(
        frequencyType: frequency,
        intervalHours: frequency == FrequencyType.everyXHours ? 8 : null,
        times: [
          ScheduledTime(hour: hour, minute: 0, windowMinutes: windowMinutes)
        ],
        weekendTimes: weekendTimes,
      ),
    );

void main() {
  group('effectiveWindowMinutes', () {
    final t = _med('x').schedule.times.first;

    test('an ordinary medicine fires once, as before', () {
      expect(effectiveWindowMinutes(_med('a'), t), isNull);
    });

    test('a critical medicine keeps asking across the default window', () {
      expect(effectiveWindowMinutes(_med('a', critical: true), t),
          criticalWindowMinutes);
    });

    test('a window the user chose beats the critical default', () {
      final m = _med('a', critical: true, windowMinutes: 90);
      expect(effectiveWindowMinutes(m, m.schedule.times.first), 90);
    });

    test('a window on a non-critical medicine is left alone', () {
      final m = _med('a', windowMinutes: 45);
      expect(effectiveWindowMinutes(m, m.schedule.times.first), 45);
    });

    test('schedules the follow-up path cannot see are not claimed', () {
      final weekend = _med('w',
          critical: true,
          weekendTimes: [ScheduledTime(hour: 10, minute: 0)]);
      final hourly = _med('h', critical: true, frequency: FrequencyType.everyXHours);
      for (final m in [weekend, hourly]) {
        expect(canFollowUp(m), isFalse, reason: m.id);
        expect(effectiveWindowMinutes(m, m.schedule.times.first), isNull,
            reason: m.id);
      }
    });
  });

  test('the form and the scheduler apply the same rule', () {
    for (final weekend in [false, true]) {
      for (final f in FrequencyType.values) {
        final m = _med('x',
            critical: true,
            frequency: f,
            weekendTimes:
                weekend ? [ScheduledTime(hour: 10, minute: 0)] : null);
        expect(
            canFollowUpWhen(weekendOverride: weekend, frequencyType: f),
            canFollowUp(m),
            reason: '$f weekend=$weekend');
      }
    }
  });

  group('nudgeMinutesForDose', () {
    test('a critical dose rings at the time, then 15 and 30 minutes later', () {
      final m = _med('a', critical: true);
      expect(nudgeMinutesForDose(m, m.schedule.times.first),
          [8 * 60, 8 * 60 + 15, 8 * 60 + 30]);
    });

    test('an ordinary dose has no chain', () {
      final m = _med('a');
      expect(nudgeMinutesForDose(m, m.schedule.times.first), isNull);
    });

    test('the learned take-time moves a chosen window, never a critical one',
        () {
      final windowed = _med('w', windowMinutes: 120);
      final critical = _med('c', critical: true);
      // 08:00 + 120 min window, user usually takes it at 08:50.
      expect(
          nudgeMinutesForDose(windowed, windowed.schedule.times.first,
              adaptiveSuggestedMinutes: 8 * 60 + 50),
          [8 * 60, 8 * 60 + 50, 10 * 60]);
      expect(
          nudgeMinutesForDose(critical, critical.schedule.times.first,
              adaptiveSuggestedMinutes: 8 * 60 + 20),
          [8 * 60, 8 * 60 + 15, 8 * 60 + 30]);
    });
  });

  group('the slot path hands critical doses over, and only those', () {
    List<String> slotIds(List<EnhancedMedicine> ms) => [
          for (final s in groupRemindersBySlot(ms, DateTime(2026, 3, 18)))
            ...s.medicines.map((m) => m.medicineId)
        ];

    test('a critical dose leaves the shared slot; the rest stay', () {
      final ids = slotIds([
        _med('plain'),
        _med('critical', critical: true),
        _med('later', hour: 9),
      ]);
      expect(ids, containsAll(['plain', 'later']));
      expect(ids, isNot(contains('critical')));
    });

    test('a critical dose the follow-ups cannot cover is NOT dropped', () {
      // The no-silent-loss guard: if the slot path skipped it too, no alarm of
      // any kind would exist for the dose.
      final weekend = _med('w',
          critical: true, weekendTimes: [ScheduledTime(hour: 10, minute: 0)]);
      expect(slotIds([weekend]), contains('w'));
    });
  });
}
