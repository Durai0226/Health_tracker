import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';

/// Regression guards for isActiveOnDate — the QA pass found it compared raw
/// DateTimes (with time-of-day), causing an end date to be excluded a day early
/// and every-X-days / cyclical schedules to fire on the wrong day.
void main() {
  // A time-of-day component on the queried date used to break .inDays math.
  DateTime day(int y, int m, int d, [int h = 8]) => DateTime(y, m, d, h);

  group('endDate is inclusive', () {
    final s = MedicineSchedule(
      frequencyType: FrequencyType.onceDaily,
      times: const [],
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 10),
    );
    test('active on the end date itself (with a time component)', () {
      expect(s.isActiveOnDate(day(2026, 1, 10, 21)), isTrue);
    });
    test('inactive the day after the end date', () {
      expect(s.isActiveOnDate(day(2026, 1, 11)), isFalse);
    });
  });

  group('everyXDays counts whole calendar days', () {
    // Start carries an evening time; the queried days carry a morning time.
    final s = MedicineSchedule(
      frequencyType: FrequencyType.everyXDays,
      times: const [],
      intervalDays: 2,
      startDate: DateTime(2026, 1, 1, 20), // 8pm
    );
    test('fires on start day and every 2nd day (not off-by-one)', () {
      expect(s.isActiveOnDate(day(2026, 1, 1, 8)), isTrue); // day 0
      expect(s.isActiveOnDate(day(2026, 1, 2, 8)), isFalse); // day 1
      expect(s.isActiveOnDate(day(2026, 1, 3, 8)), isTrue); // day 2
      expect(s.isActiveOnDate(day(2026, 1, 5, 8)), isTrue); // day 4
    });
  });

  group('duration is whole days from start', () {
    final s = MedicineSchedule(
      frequencyType: FrequencyType.onceDaily,
      times: const [],
      startDate: DateTime(2026, 1, 1, 22),
      durationDays: 3, // days 0,1,2 active
    );
    test('active across the 3 days, inactive on the 4th', () {
      expect(s.isActiveOnDate(day(2026, 1, 1)), isTrue);
      expect(s.isActiveOnDate(day(2026, 1, 3)), isTrue);
      expect(s.isActiveOnDate(day(2026, 1, 4)), isFalse);
    });
  });
}
