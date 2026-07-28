import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';

/// QA — MedicineSchedule slot generation (F2). isActiveOnDate is covered
/// elsewhere; this covers getScheduledTimesForDate, especially the everyXHours
/// intra-day fan-out and the PRN/as-needed empty cases.
void main() {
  final date = DateTime(2026, 6, 15); // a plain active day (no start/end set)

  test('onceDaily returns its single fixed time', () {
    final s = MedicineSchedule(
      frequencyType: FrequencyType.onceDaily,
      times: [ScheduledTime(hour: 8, minute: 0)],
    );
    final slots = s.getScheduledTimesForDate(date);
    expect(slots.length, 1);
    expect(slots.first.hour, 8);
  });

  test('everyXHours fans an anchor across the day at the interval', () {
    final s = MedicineSchedule(
      frequencyType: FrequencyType.everyXHours,
      intervalHours: 6,
      times: [ScheduledTime(hour: 8, minute: 0)],
    );
    final slots = s.getScheduledTimesForDate(date);
    // 08:00, 14:00, 20:00 — 02:00 next day is past end-of-day, so stops.
    expect(slots.map((t) => t.hour).toList(), [8, 14, 20]);
  });

  test('PRN schedule generates NO slots (never a missed dose)', () {
    final s = MedicineSchedule(
      frequencyType: FrequencyType.onceDaily,
      times: [ScheduledTime(hour: 8, minute: 0)],
      isPRN: true,
    );
    expect(s.getScheduledTimesForDate(date), isEmpty);
  });

  test('as-needed frequency generates NO slots', () {
    final s = MedicineSchedule(
      frequencyType: FrequencyType.asNeeded,
      times: [ScheduledTime(hour: 8, minute: 0)],
    );
    expect(s.getScheduledTimesForDate(date), isEmpty);
  });

  test('an inactive day (before start) generates NO slots', () {
    final s = MedicineSchedule(
      frequencyType: FrequencyType.onceDaily,
      times: [ScheduledTime(hour: 8, minute: 0)],
      startDate: DateTime(2026, 7, 1),
    );
    expect(s.getScheduledTimesForDate(date), isEmpty); // date is before start
  });
}
