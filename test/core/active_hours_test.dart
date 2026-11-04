/// "6 of 9 active hours": which hours count, and when nothing honest can be said.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/active_hours.dart';

void main() {
  /// 24 buckets, with [steps] in each of [hours] and nothing elsewhere.
  List<int> day(Iterable<int> hours, int steps) =>
      [for (var h = 0; h < 24; h++) hours.contains(h) ? steps : 0];

  int total(List<int> hourly) => hourly.fold(0, (a, b) => a + b);

  group('which hours count', () {
    test('250 steps is active; 249 is not', () {
      final r = ActiveHoursCalc.compute(
          hourly: [for (var h = 0; h < 24; h++) h == 8 ? 250 : (h == 9 ? 249 : 0)],
          sensorTotal: 499)!;

      expect(r.hours[8], isTrue);
      expect(r.hours[9], isFalse);
      expect(r.count, 1);
    });

    test('the threshold and target are the documented ones', () {
      expect(ActiveHoursCalc.threshold, 250);
      expect(ActiveHoursCalc.target, 9);
    });

    test('count adds up the active hours, in any part of the day', () {
      final hourly = day([6, 7, 12, 13, 18, 22], 400);
      final r = ActiveHoursCalc.compute(hourly: hourly, sensorTotal: total(hourly))!;

      expect(r.count, 6);
      expect([for (var h = 0; h < 24; h++) if (r.hours[h]) h], [6, 7, 12, 13, 18, 22]);
      expect(r.target, 9);
      expect(r.reached, isFalse);
    });

    test('nine active hours reaches the target; eight does not', () {
      final nine = day(List.generate(9, (i) => 8 + i), 300);
      final eight = day(List.generate(8, (i) => 8 + i), 300);

      expect(ActiveHoursCalc.compute(hourly: nine, sensorTotal: total(nine))!.reached,
          isTrue);
      expect(ActiveHoursCalc.compute(hourly: eight, sensorTotal: total(eight))!.reached,
          isFalse);
    });

    test('a very big hour counts once, not as several', () {
      final hourly = day([10], 6000);
      final r = ActiveHoursCalc.compute(hourly: hourly, sensorTotal: 6000)!;

      expect(r.count, 1);
    });
  });

  group('when nothing honest can be said', () {
    final hourly = day([8, 9, 10], 400); // 1,200 steps

    test('no hourly record', () {
      expect(ActiveHoursCalc.compute(hourly: const [], sensorTotal: 1200), isNull);
    });

    test('a record that is not 24 hours', () {
      expect(ActiveHoursCalc.compute(hourly: [400, 400], sensorTotal: 800), isNull);
      expect(
          ActiveHoursCalc.compute(
              hourly: List.filled(25, 100), sensorTotal: 2500),
          isNull);
    });

    test('no total to check the record against', () {
      expect(ActiveHoursCalc.compute(hourly: hourly, sensorTotal: null), isNull);
      expect(ActiveHoursCalc.compute(hourly: hourly, sensorTotal: 0), isNull);
    });

    test('a record that covers too little of the day', () {
      // The day has 5,000 steps; the buckets, filled before the last sync, hold
      // 1,200. "3 of 9" would be false.
      expect(ActiveHoursCalc.compute(hourly: hourly, sensorTotal: 5000), isNull);
    });

    test('85% coverage is enough; just under is not', () {
      expect(ActiveHoursCalc.compute(hourly: hourly, sensorTotal: 1411), isNotNull,
          reason: '1,200 is 85.05% of 1,411');
      expect(ActiveHoursCalc.compute(hourly: hourly, sensorTotal: 1412), isNull,
          reason: '1,200 is 84.99% of 1,412');
    });

    test('exactly 85% is enough: the line is "under", not "at or under"', () {
      final exact = day([8, 9, 10, 11], 425); // 1,700 steps

      expect(ActiveHoursCalc.compute(hourly: exact, sensorTotal: 2000), isNotNull);
      expect(ActiveHoursCalc.compute(hourly: exact, sensorTotal: 2001), isNull);
    });

    test('a record that holds more than the total is fine', () {
      expect(ActiveHoursCalc.compute(hourly: hourly, sensorTotal: 1000), isNotNull);
    });

    test('a day with no steps at all says nothing, not "0 of 9"', () {
      expect(ActiveHoursCalc.compute(hourly: day([], 0), sensorTotal: 0), isNull);
    });
  });
}
