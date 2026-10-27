/// Tonight's bedtime, and the working behind it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/bedtime_plan.dart';
import 'package:tablet_remainder/core/health/sleep_debt.dart';

void main() {
  const wake7 = 7 * 60;

  group('the plan', () {
    test('wake less need less the allowance, as a time of day', () {
      final p = BedtimePlans.compute(targetMinutes: 465, wakeMinuteOfDay: wake7);
      // 7:00 - (7h45m + 15m) = 23:00.
      expect(p.bedMinuteOfDay, 23 * 60);
      expect(p.inBedMinutes, 480);
      expect(p.needMinutes, 465);
      expect(p.catchUpMinutes, 0);
      expect(p.awakeMinutes, 15);
      expect(p.awakeIsYours, isFalse);
    });

    test('with a catch-up, bed is earlier by that much', () {
      final p = BedtimePlans.compute(
        targetMinutes: 465,
        wakeMinuteOfDay: wake7,
        debt: const SleepDebtResult(
            debtMinutes: 140, nights: 10, catchUp: SleepCatchUp(20, 7)),
      );
      expect(p.catchUpMinutes, 20);
      expect(p.bedMinuteOfDay, 22 * 60 + 40, reason: '10:40 PM');
      expect(p.inBedMinutes, 500);
    });

    test('a debt too large to clear this way asks for nothing extra', () {
      final p = BedtimePlans.compute(
        targetMinutes: 465,
        wakeMinuteOfDay: wake7,
        debt: const SleepDebtResult(debtMinutes: 900, nights: 10, catchUp: null),
      );
      expect(p.catchUpMinutes, 0);
    });

    test('no debt, no catch-up', () {
      final p = BedtimePlans.compute(
          targetMinutes: 480,
          wakeMinuteOfDay: wake7,
          debt: const SleepDebtResult(debtMinutes: 0, nights: 10, catchUp: null));
      expect(p.catchUpMinutes, 0);
    });

    test('the clock wraps: a wake after midnight, a bedtime before it', () {
      final p = BedtimePlans.compute(targetMinutes: 480, wakeMinuteOfDay: 5 * 60);
      // 5:00 - 8h15m = 20:45.
      expect(p.bedMinuteOfDay, 20 * 60 + 45);
    });

    test('and one that falls after midnight', () {
      final p = BedtimePlans.compute(targetMinutes: 480, wakeMinuteOfDay: 11 * 60);
      // 11:00 - 8h15m = 02:45.
      expect(p.bedMinuteOfDay, 2 * 60 + 45);
    });

    test('a wake time outside 0..1439 is read as the same time of day', () {
      final a = BedtimePlans.compute(targetMinutes: 480, wakeMinuteOfDay: wake7);
      final b = BedtimePlans.compute(targetMinutes: 480, wakeMinuteOfDay: wake7 + 1440);
      final c = BedtimePlans.compute(targetMinutes: 480, wakeMinuteOfDay: wake7 - 1440);
      expect(b.bedMinuteOfDay, a.bedMinuteOfDay);
      expect(c.bedMinuteOfDay, a.bedMinuteOfDay);
      expect(b.wakeMinuteOfDay, wake7);
      expect(c.wakeMinuteOfDay, wake7);
    });

    test('no target set: eight hours', () {
      final p = BedtimePlans.compute(targetMinutes: 0, wakeMinuteOfDay: wake7);
      expect(p.needMinutes, 480);
    });
  });

  group('time awake in bed', () {
    test('seven measured nights: their own, rounded to five', () {
      final p = BedtimePlans.compute(
        targetMinutes: 480,
        wakeMinuteOfDay: wake7,
        awakeInBedMinutes: const [28, 31, 26, 33, 29, 27, 30],
      );
      expect(p.awakeMinutes, 30);
      expect(p.awakeIsYours, isTrue);
    });

    test('six nights are not enough', () {
      final p = BedtimePlans.compute(
        targetMinutes: 480,
        wakeMinuteOfDay: wake7,
        awakeInBedMinutes: const [30, 30, 30, 30, 30, 30],
      );
      expect(p.awakeMinutes, 15);
      expect(p.awakeIsYours, isFalse);
    });

    test('the median, not the mean: one bad night does not move it', () {
      final p = BedtimePlans.compute(
        targetMinutes: 480,
        wakeMinuteOfDay: wake7,
        awakeInBedMinutes: const [20, 20, 20, 20, 20, 20, 120],
      );
      expect(p.awakeMinutes, 20);
    });

    test('an even count averages the middle two', () {
      final p = BedtimePlans.compute(
        targetMinutes: 480,
        wakeMinuteOfDay: wake7,
        awakeInBedMinutes: const [10, 10, 10, 20, 30, 30, 30, 30],
      );
      // Middle two: 20 and 30 -> 25.
      expect(p.awakeMinutes, 25);
    });

    test('kept within 10 and 45 minutes', () {
      final low = BedtimePlans.compute(
        targetMinutes: 480,
        wakeMinuteOfDay: wake7,
        awakeInBedMinutes: const [2, 3, 2, 4, 3, 2, 3],
      );
      expect(low.awakeMinutes, 10);
      final high = BedtimePlans.compute(
        targetMinutes: 480,
        wakeMinuteOfDay: wake7,
        awakeInBedMinutes: const [90, 80, 100, 85, 95, 90, 70],
      );
      expect(high.awakeMinutes, 45);
    });

    test('rounds to the nearest five', () {
      int at(int v) => BedtimePlans.compute(
            targetMinutes: 480,
            wakeMinuteOfDay: wake7,
            awakeInBedMinutes: List.filled(7, v),
          ).awakeMinutes;
      expect(at(22), 20);
      expect(at(23), 25);
      expect(at(27), 25);
      expect(at(28), 30);
    });
  });

  group('the wind-down reminder', () {
    test('is the lead time before bed', () {
      final p = BedtimePlans.compute(targetMinutes: 465, wakeMinuteOfDay: wake7);
      expect(p.windDownMinuteOfDay(30), 22 * 60 + 30);
    });

    test('and wraps past midnight the other way', () {
      final p = BedtimePlans.compute(targetMinutes: 480, wakeMinuteOfDay: 11 * 60);
      // Bed 02:45; 30 minutes before is 02:15, and 3 hours before is 23:45.
      expect(p.windDownMinuteOfDay(30), 2 * 60 + 15);
      expect(p.windDownMinuteOfDay(180), 23 * 60 + 45);
    });
  });

  group('words', () {
    test('durations', () {
      expect(BedtimePlans.duration(500), '8 h 20 m');
      expect(BedtimePlans.duration(480), '8 h');
      expect(BedtimePlans.duration(45), '45 m');
      expect(BedtimePlans.duration(60), '1 h');
      expect(BedtimePlans.duration(0), '0 m');
    });
  });

  group('against the debt it is taken from', () {
    test('the catch-up is the debt\'s own figure', () {
      // Ten nights at 6 h 40 m against 8 h: 80 m behind a night.
      final d = SleepDebt.compute(nights: [
        for (var i = 0; i < 10; i++) (ageDays: i, asleepMinutes: 400),
      ], targetMinutes: 480);
      final p = BedtimePlans.compute(
          targetMinutes: 480, wakeMinuteOfDay: wake7, debt: d);
      expect(p.catchUpMinutes, d.catchUp!.minutesPerNight);
      expect(p.catchUpMinutes, lessThanOrEqualTo(SleepDebt.maxCatchUpPerNight));
    });
  });
}
