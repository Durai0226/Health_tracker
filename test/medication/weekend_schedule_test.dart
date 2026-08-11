import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';

/// Tier 3: weekend-mode schedule split. A once-daily 8am medicine with a
/// 10am weekend override should fire at 8am on weekdays and 10am on Sat/Sun.
void main() {
  // A known Monday and a known Saturday (2026-08-10 is a Monday).
  final monday = DateTime(2026, 8, 10);
  final saturday = DateTime(2026, 8, 15);
  final sunday = DateTime(2026, 8, 16);

  MedicineSchedule scheduleWithWeekend({List<ScheduledTime>? weekendTimes}) =>
      MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
        weekendTimes: weekendTimes,
      );

  group('hasWeekendOverride', () {
    test('positive: true when weekendTimes is set and non-empty', () {
      final s = scheduleWithWeekend(
          weekendTimes: [ScheduledTime(hour: 10, minute: 0)]);
      expect(s.hasWeekendOverride, isTrue);
    });

    test('negative: false when weekendTimes is null', () {
      expect(scheduleWithWeekend().hasWeekendOverride, isFalse);
    });

    test('negative: false when weekendTimes is an empty list', () {
      expect(scheduleWithWeekend(weekendTimes: const []).hasWeekendOverride,
          isFalse);
    });
  });

  group('getScheduledTimesForDate with a weekend override', () {
    test('positive: Saturday uses the weekend time', () {
      final s = scheduleWithWeekend(
          weekendTimes: [ScheduledTime(hour: 10, minute: 0)]);
      final slots = s.getScheduledTimesForDate(saturday);
      expect(slots.single.hour, 10);
    });

    test('positive: Sunday uses the weekend time', () {
      final s = scheduleWithWeekend(
          weekendTimes: [ScheduledTime(hour: 10, minute: 0)]);
      final slots = s.getScheduledTimesForDate(sunday);
      expect(slots.single.hour, 10);
    });

    test('negative: a weekday is unaffected by the weekend override', () {
      final s = scheduleWithWeekend(
          weekendTimes: [ScheduledTime(hour: 10, minute: 0)]);
      final slots = s.getScheduledTimesForDate(monday);
      expect(slots.single.hour, 8);
    });

    test('negative: no override configured behaves exactly as before', () {
      final s = scheduleWithWeekend();
      expect(s.getScheduledTimesForDate(saturday).single.hour, 8);
      expect(s.getScheduledTimesForDate(monday).single.hour, 8);
    });
  });

  group('MedicineSchedule.weekendTimes round-trip', () {
    test('positive: toJson/fromJson preserves the weekend override', () {
      final s = scheduleWithWeekend(
          weekendTimes: [ScheduledTime(hour: 10, minute: 30)]);
      final back = MedicineSchedule.fromJson(s.toJson());
      expect(back.hasWeekendOverride, isTrue);
      expect(back.weekendTimes!.single.hour, 10);
      expect(back.weekendTimes!.single.minute, 30);
    });

    test('negative: an old schedule with no weekendTimes key round-trips as null',
        () {
      final s = scheduleWithWeekend();
      final json = s.toJson();
      expect(json.containsKey('weekendTimes'), isFalse);
      final back = MedicineSchedule.fromJson(json);
      expect(back.hasWeekendOverride, isFalse);
    });

    test('copyWith clearWeekendOverride actually clears (not a no-op)', () {
      final s = scheduleWithWeekend(
          weekendTimes: [ScheduledTime(hour: 10, minute: 0)]);
      final cleared = s.copyWith(clearWeekendOverride: true);
      expect(cleared.hasWeekendOverride, isFalse);
    });
  });
}
