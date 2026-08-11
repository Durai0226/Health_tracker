import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';

/// Titration (dose-escalation) schedules: e.g. "Week 1: 25mg, Week 2: 50mg,
/// Week 3 onward: 100mg" instead of one fixed dose forever. The most
/// important guard here is the negative case — a schedule that never opts in
/// (titrationSteps null/empty) must behave EXACTLY as it did before this
/// feature existed.
void main() {
  final startDate = DateTime(2026, 1, 1);

  MedicineSchedule scheduleWithSteps({List<TitrationStep>? steps}) =>
      MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
        startDate: startDate,
        titrationSteps: steps,
      );

  group('effectiveDosageAmount — regression guard (opt-in only)', () {
    test('negative: titrationSteps null returns the base amount unchanged',
        () {
      final s = scheduleWithSteps();
      expect(s.effectiveDosageAmount(startDate, 25), 25);
      expect(
          s.effectiveDosageAmount(
              startDate.add(const Duration(days: 100)), 25),
          25);
    });

    test(
        'negative: titrationSteps an empty list returns the base amount unchanged',
        () {
      final s = scheduleWithSteps(steps: const []);
      expect(s.effectiveDosageAmount(startDate, 25), 25);
    });

    test(
        'negative: startDate unset returns the base amount unchanged even with steps configured',
        () {
      final s = MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
        titrationSteps: [TitrationStep(startDayOffset: 0, dosageAmount: 999)],
      );
      expect(s.effectiveDosageAmount(DateTime(2026, 5, 5), 25), 25);
    });
  });

  group('effectiveDosageAmount — step selection', () {
    test(
        "positive: returns the base amount before the first step's offset is reached",
        () {
      final s = scheduleWithSteps(steps: [
        TitrationStep(startDayOffset: 7, dosageAmount: 50),
        TitrationStep(startDayOffset: 14, dosageAmount: 100),
      ]);
      expect(s.effectiveDosageAmount(startDate, 25), 25); // day 0
      expect(
          s.effectiveDosageAmount(startDate.add(const Duration(days: 6)), 25),
          25); // day 6, still before the first step
    });

    test('positive: switches to the correct step exactly on each threshold day',
        () {
      final s = scheduleWithSteps(steps: [
        TitrationStep(startDayOffset: 0, dosageAmount: 25, label: 'Week 1'),
        TitrationStep(startDayOffset: 7, dosageAmount: 50, label: 'Week 2'),
        TitrationStep(
            startDayOffset: 14, dosageAmount: 100, label: 'Week 3+'),
      ]);
      expect(s.effectiveDosageAmount(startDate, 1), 25); // day 0
      expect(
          s.effectiveDosageAmount(startDate.add(const Duration(days: 6)), 1),
          25); // day 6, still step 0's amount
      expect(
          s.effectiveDosageAmount(startDate.add(const Duration(days: 7)), 1),
          50); // day 7 crosses into step 1
      expect(
          s.effectiveDosageAmount(startDate.add(const Duration(days: 13)), 1),
          50); // day 13, still step 1's amount
      expect(
          s.effectiveDosageAmount(startDate.add(const Duration(days: 14)), 1),
          100); // day 14 crosses into step 2
      expect(
          s.effectiveDosageAmount(
              startDate.add(const Duration(days: 100)), 1),
          100); // stays on the last step indefinitely
    });

    test('positive: unordered steps still pick the largest qualifying offset',
        () {
      final s = scheduleWithSteps(steps: [
        TitrationStep(startDayOffset: 14, dosageAmount: 100),
        TitrationStep(startDayOffset: 0, dosageAmount: 25),
        TitrationStep(startDayOffset: 7, dosageAmount: 50),
      ]);
      expect(
          s.effectiveDosageAmount(startDate.add(const Duration(days: 10)), 1),
          50);
    });

    test(
        'positive: the day count is normalized to date-only, ignoring time-of-day',
        () {
      final s = scheduleWithSteps(steps: [
        TitrationStep(startDayOffset: 7, dosageAmount: 50),
      ]);
      // 23:59 on Jan 7 is still calendar day 6 since Jan 1 — must not have
      // crossed into the day-7 step yet.
      expect(s.effectiveDosageAmount(DateTime(2026, 1, 7, 23, 59), 1), 1);
      // 00:01 on Jan 8 is calendar day 7 — crosses the threshold.
      expect(s.effectiveDosageAmount(DateTime(2026, 1, 8, 0, 1), 1), 50);
    });
  });

  group('MedicineSchedule.titrationSteps round-trip', () {
    test('positive: toJson/fromJson preserves titration steps', () {
      final s = scheduleWithSteps(steps: [
        TitrationStep(startDayOffset: 0, dosageAmount: 25, label: 'Week 1'),
        TitrationStep(startDayOffset: 7, dosageAmount: 50, label: 'Week 2'),
      ]);
      final back = MedicineSchedule.fromJson(s.toJson());
      expect(back.isTitrating, isTrue);
      expect(back.titrationSteps!.length, 2);
      expect(back.titrationSteps![0].startDayOffset, 0);
      expect(back.titrationSteps![0].dosageAmount, 25);
      expect(back.titrationSteps![0].label, 'Week 1');
      expect(back.titrationSteps![1].startDayOffset, 7);
      expect(back.titrationSteps![1].dosageAmount, 50);
      expect(back.titrationSteps![1].label, 'Week 2');
    });

    test(
        'negative: an OLD schedule JSON blob with no titrationSteps key at all deserializes fine',
        () {
      final s = scheduleWithSteps(); // no titrationSteps set at all
      final json = s.toJson();
      expect(json.containsKey('titrationSteps'), isFalse);
      final back = MedicineSchedule.fromJson(json);
      expect(back.isTitrating, isFalse);
      expect(back.titrationSteps, isNull);
      expect(back.effectiveDosageAmount(startDate, 25), 25);
    });

    test('copyWith clearTitrationSteps actually clears (not a no-op)', () {
      final s = scheduleWithSteps(
          steps: [TitrationStep(startDayOffset: 0, dosageAmount: 50)]);
      final cleared = s.copyWith(clearTitrationSteps: true);
      expect(cleared.isTitrating, isFalse);
      expect(cleared.titrationSteps, isNull);
    });
  });
}
