import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';

/// Guards the T0.1 alarm fix: the Android alarm isolate reconstructs a
/// [MedicineSchedule] from the serialized `scheduleJson` and only fires on days
/// where `isActiveOnDate` is true. These tests exercise that exact round-trip so
/// non-daily regimens can never regress back to alarming every day.
MedicineSchedule _roundTrip(MedicineSchedule s) =>
    MedicineSchedule.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);

void main() {
  // A fixed reference week: Mon 2024-01-01 … Sun 2024-01-07.
  final mon = DateTime(2024, 1, 1);
  final tue = DateTime(2024, 1, 2);
  final wed = DateTime(2024, 1, 3);
  final thu = DateTime(2024, 1, 4);

  group('active-day gate survives JSON round-trip (isolate path)', () {
    test('onceDaily is active every day', () {
      final s = _roundTrip(MedicineSchedule.onceDaily(
          hour: 8, minute: 0, startDate: mon));
      expect(s.isActiveOnDate(mon), isTrue);
      expect(s.isActiveOnDate(tue), isTrue);
      expect(s.isActiveOnDate(wed), isTrue);
    });

    test('specificDays fires only on chosen weekdays (Mon/Wed)', () {
      final s = _roundTrip(MedicineSchedule(
        frequencyType: FrequencyType.specificDays,
        times: [ScheduledTime(hour: 9, minute: 0)],
        specificDays: const [1, 3], // Mon, Wed
        startDate: mon,
      ));
      expect(s.isActiveOnDate(mon), isTrue); // Mon
      expect(s.isActiveOnDate(tue), isFalse); // Tue
      expect(s.isActiveOnDate(wed), isTrue); // Wed
      expect(s.isActiveOnDate(thu), isFalse); // Thu
    });

    test('everyXDays (every 2 days) fires on alternate days from start', () {
      final s = _roundTrip(MedicineSchedule(
        frequencyType: FrequencyType.everyXDays,
        times: [ScheduledTime(hour: 9, minute: 0)],
        intervalDays: 2,
        startDate: mon,
      ));
      expect(s.isActiveOnDate(mon), isTrue); // day 0
      expect(s.isActiveOnDate(tue), isFalse); // day 1
      expect(s.isActiveOnDate(wed), isTrue); // day 2
      expect(s.isActiveOnDate(thu), isFalse); // day 3
    });

    test('cyclical (2 on / 1 off) respects the cycle', () {
      final s = _roundTrip(MedicineSchedule(
        frequencyType: FrequencyType.cyclical,
        times: [ScheduledTime(hour: 9, minute: 0)],
        cycleDaysOn: 2,
        cycleDaysOff: 1,
        startDate: mon,
      ));
      expect(s.isActiveOnDate(mon), isTrue); // on
      expect(s.isActiveOnDate(tue), isTrue); // on
      expect(s.isActiveOnDate(wed), isFalse); // off
      expect(s.isActiveOnDate(thu), isTrue); // on again
    });

    test('past end/duration is inactive (no zombie firing)', () {
      final s = _roundTrip(MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
        startDate: mon,
        durationDays: 2, // active Mon, Tue only
      ));
      expect(s.isActiveOnDate(mon), isTrue);
      expect(s.isActiveOnDate(tue), isTrue);
      expect(s.isActiveOnDate(wed), isFalse);
    });

    test('everyXHours is active on in-range days (fans out intra-day)', () {
      final s = _roundTrip(MedicineSchedule(
        frequencyType: FrequencyType.everyXHours,
        times: [ScheduledTime(hour: 8, minute: 0)],
        intervalHours: 6,
        startDate: mon,
      ));
      expect(s.isActiveOnDate(mon), isTrue);
      expect(s.isActiveOnDate(wed), isTrue);
    });
  });
}
