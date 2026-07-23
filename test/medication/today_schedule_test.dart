import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/today_schedule_service.dart';

/// The Today hub's "next dose" hero must pick the right slot: an overdue dose
/// wins, else the next upcoming, else nothing (all taken). Pure logic — testable
/// headlessly without the DB.
void main() {
  EnhancedMedicine med() => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        strength: '500mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.twiceDaily,
          times: [ScheduledTime(hour: 8, minute: 0), ScheduledTime(hour: 20, minute: 0)],
        ),
      );

  final now = DateTime(2026, 1, 1, 12, 0); // noon
  final m = med();

  ScheduledDose dose(int hour, {MedicineLog? log, int idx = 0}) => ScheduledDose(
        medicine: m,
        scheduledTime: DateTime(2026, 1, 1, hour, 0),
        timeIndex: idx,
        log: log,
      );

  group('TodayScheduleService.nextDose', () {
    test('an overdue pending dose wins over an upcoming one', () {
      final r = TodayScheduleService.nextDose(
          [dose(20, idx: 1), dose(8, idx: 0)], now);
      expect(r, isNotNull);
      expect(r!.scheduledTime.hour, 8); // the overdue 8am
    });

    test('with the overdue dose taken, the next upcoming is chosen', () {
      final taken = MedicineLog.taken(
          id: 'l1', medicineId: 'm1', scheduledTime: DateTime(2026, 1, 1, 8, 0));
      final r = TodayScheduleService.nextDose(
          [dose(8, idx: 0, log: taken), dose(20, idx: 1)], now);
      expect(r!.scheduledTime.hour, 20);
    });

    test('all doses taken/skipped → null (all done)', () {
      final taken = MedicineLog.taken(
          id: 'l1', medicineId: 'm1', scheduledTime: DateTime(2026, 1, 1, 8, 0));
      final skipped = MedicineLog.skipped(
          id: 'l2',
          medicineId: 'm1',
          scheduledTime: DateTime(2026, 1, 1, 20, 0),
          reason: SkipReason.values.first);
      final r = TodayScheduleService.nextDose(
          [dose(8, idx: 0, log: taken), dose(20, idx: 1, log: skipped)], now);
      expect(r, isNull);
    });

    test('empty schedule → null', () {
      expect(TodayScheduleService.nextDose(const [], now), isNull);
    });
  });
}
