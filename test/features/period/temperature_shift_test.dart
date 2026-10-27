/// "Temperature rise from day 17 — ovulation likely around day 16 (estimate)."
///
/// The three-over-six rule on a basal body temperature log, found per cycle.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';
import 'package:tablet_remainder/features/period/services/temperature_shift.dart';

void main() {
  final start = DateTime(2026, 3, 1);
  DateTime day(int cycleDay) => DateTime(2026, 3, cycleDay); // day 1 = Mar 1

  /// A log from cycle day [from] on: one value per day.
  List<BbtReading> log(Map<int, double> byCycleDay) => [
        for (final e in byCycleDay.entries) BbtReading(day(e.key), e.value),
      ];

  /// Cycle days 1..[through], flat at [t] with a little jitter that stays under
  /// [t] + 0.1 (so it never sets a high coverline).
  Map<int, double> flat(int through, {double t = 36.3, int from = 1}) => {
        for (var d = from; d <= through; d++) d: t + (d.isEven ? 0.05 : 0.0),
      };

  TemperatureShift? detect(Map<int, double> m, {DateTime? end}) =>
      TemperatureShiftCheck.detect(
          cycleStart: start, cycleEnd: end, readings: log(m));

  group('a clear shift', () {
    // Flat to day 15, then 36.6, 36.7, 36.7 from day 16.
    final m = {...flat(15), 16: 36.6, 17: 36.7, 18: 36.7};

    test('is found, with the day it began', () {
      final s = detect(m)!;
      expect(s.riseCycleDay, 16);
      expect(s.firstHighDay, day(16));
    });

    test('and ovulation is the day before it, an estimate', () {
      final s = detect(m)!;
      expect(s.ovulationCycleDay, 15);
      expect(s.ovulationDay, day(15));
    });

    test('the coverline is the highest of the six before it', () {
      final s = detect(m)!;
      expect(s.coverline, closeTo(36.35, 1e-9)); // day 14 (even) is 36.35
      expect(s.thirdDayRise, closeTo(0.35, 1e-9));
    });
  });

  group('what is not a shift', () {
    test('two warm days are not three', () {
      expect(detect({...flat(15), 16: 36.6, 17: 36.7}), isNull);
      expect(detect({...flat(15), 16: 36.6, 17: 36.7, 18: 36.3}), isNull);
    });

    test('three days that do not clear the coverline are not', () {
      // Day 18 equals the coverline (36.35): not warmer than it.
      expect(detect({...flat(15), 16: 36.5, 17: 36.5, 18: 36.35}), isNull);
    });

    test('the third day has to be 0.2 above, not just above', () {
      expect(detect({...flat(15), 16: 36.4, 17: 36.45, 18: 36.5}), isNull,
          reason: '0.15 over the coverline');
      expect(detect({...flat(15), 16: 36.4, 17: 36.5, 18: 36.55}), isNotNull,
          reason: '0.2 over: just enough');
    });

    test('0.2 exactly counts, floating point or not', () {
      // 36.4 - 36.2 is 0.19999999999999574 in a double.
      final m = {for (var d = 1; d <= 15; d++) d: 36.2, 16: 36.3, 17: 36.35, 18: 36.4};
      expect(detect(m), isNotNull);
    });

    test('a gap inside the three days breaks them', () {
      expect(detect({...flat(15), 16: 36.6, 18: 36.7, 19: 36.7}), isNull,
          reason: 'day 17 was not logged');
    });

    test('a spike that falls back is not a shift', () {
      expect(
          detect({...flat(15), 16: 36.9, 17: 36.3, 18: 36.3, 19: 36.3}), isNull);
    });

    test('fewer than nine readings cannot make a shift', () {
      expect(detect({for (var d = 1; d <= 8; d++) d: 36.3 + (d > 5 ? 0.4 : 0)}),
          isNull);
    });

    test('not before the eighth day: an early rise is a cold reading', () {
      // Six flat readings on days 1-6, then 7, 8, 9 high: the rise begins day 7.
      final m = {...flat(6), 7: 36.7, 8: 36.8, 9: 36.8};
      expect(detect(m), isNull);
    });

    test('a baseline spread over a month is not a baseline', () {
      // Six readings, one every five days, then three warm ones.
      final m = {1: 36.3, 6: 36.3, 11: 36.3, 16: 36.3, 21: 36.3, 26: 36.3,
          30: 36.7, 31: 36.8, 32: 36.8};
      expect(
          TemperatureShiftCheck.detect(
              cycleStart: start,
              readings: [
                for (final e in m.entries)
                  BbtReading(DateTime(2026, 3, 1).add(Duration(days: e.key - 1)), e.value)
              ]),
          isNull);
    });

    test('a mistyped reading is ignored, not believed', () {
      // 98.6 is Fahrenheit, written where a Celsius reading goes; it sits inside
      // the six days that set the coverline.
      final s = detect({...flat(15), 14: 98.6, 16: 36.6, 17: 36.7, 18: 36.7})!;
      expect(s.coverline, closeTo(36.35, 1e-9));
      expect(s.riseCycleDay, 16);
    });

    test('six readings are enough to set a coverline, five or seven are not '
        'the rule', () {
      // A log that starts late: days 3-8 flat (six readings), then three warm
      // days. The rise is on day 9.
      final late = {for (var d = 3; d <= 8; d++) d: 36.3, 9: 36.6, 10: 36.7, 11: 36.7};
      expect(detect(late)!.riseCycleDay, 9);
    });

    test('the SIXTH reading back counts toward the coverline', () {
      // Day 9 spikes to 36.6; days 10-14 are flat at 36.3; days 15-17 reach
      // 36.5. That is above the five readings before it, and below the sixth.
      final m = {
        ...flat(8),
        9: 36.6,
        for (var d = 10; d <= 14; d++) d: 36.3,
        15: 36.5,
        16: 36.5,
        17: 36.55,
      };
      expect(detect(m), isNull);
    });
  });

  group('what is read', () {
    final m = {...flat(15), 16: 36.6, 17: 36.7, 18: 36.7};

    test('only the readings inside the cycle', () {
      final readings = [
        ...log(m),
        // Last cycle's warm tail, before this one began.
        BbtReading(DateTime(2026, 2, 27), 37.2),
      ];
      final s = TemperatureShiftCheck.detect(cycleStart: start, readings: readings);
      expect(s!.coverline, closeTo(36.35, 1e-9));
    });

    test('a closed cycle stops at its last day', () {
      // The shift is on days 16-18; the cycle ended on day 17.
      expect(detect(m, end: day(17)), isNull);
      expect(detect(m, end: day(18)), isNotNull);
    });

    test('the time of day does not matter', () {
      final s = TemperatureShiftCheck.detect(
        cycleStart: DateTime(2026, 3, 1, 15, 30),
        readings: [
          for (final e in m.entries)
            BbtReading(DateTime(2026, 3, e.key, 6, 45), e.value),
        ],
      );
      expect(s!.riseCycleDay, 16);
    });

    test('the first shift is the one reported', () {
      final twice = {...m, 19: 36.2, 20: 36.2, 21: 36.2, 22: 36.2, 23: 36.2,
          24: 36.2, 25: 36.8, 26: 36.9, 27: 36.9};
      expect(detect(twice)!.riseCycleDay, 16);
    });
  });

  group('across cycles', () {
    test('one per cycle that has one, oldest first', () {
      // Two cycles of 28 days. Both warm from day 16 (of their own cycle).
      DerivedCycle cycle(DateTime s, DateTime? e, int? len) => DerivedCycle(
          start: s, end: e, cycleLengthDays: len, periodLengthDays: 5);
      final c1 = cycle(DateTime(2026, 1, 1), DateTime(2026, 1, 28), 28);
      final c2 = cycle(DateTime(2026, 1, 29), DateTime(2026, 2, 25), 28);
      final c3 = cycle(DateTime(2026, 2, 26), null, null);

      List<BbtReading> forCycle(DateTime s) => [
            for (var d = 1; d <= 15; d++)
              BbtReading(DateTime(s.year, s.month, s.day + d - 1), 36.3),
            for (var d = 16; d <= 18; d++)
              BbtReading(DateTime(s.year, s.month, s.day + d - 1), 36.7),
          ];

      final shifts = TemperatureShiftCheck.forCycles(
          [c1, c2, c3], [...forCycle(c1.start), ...forCycle(c2.start)]);

      expect(shifts, hasLength(2));
      expect(shifts.map((s) => s.cycleStart), [c1.start, c2.start]);
      expect(shifts.map((s) => s.riseCycleDay), [16, 16]);
    });

    DerivedCycle cycleAt(DateTime s, {bool open = false}) => DerivedCycle(
        start: s,
        end: open ? null : DateTime(s.year, s.month, s.day + 27),
        cycleLengthDays: open ? null : 28,
        periodLengthDays: 5);

    /// A shift on cycle day 16 of the cycle that began on [s].
    List<BbtReading> shiftIn(DateTime s) => [
          for (var d = 1; d <= 15; d++)
            BbtReading(DateTime(s.year, s.month, s.day + d - 1), 36.3),
          for (var d = 16; d <= 18; d++)
            BbtReading(DateTime(s.year, s.month, s.day + d - 1), 36.7),
        ];

    final starts = [for (var i = 0; i < 6; i++) DateTime(2026, 1, 1 + 28 * i)];
    final sixCycles = [
      for (var i = 0; i < 6; i++) cycleAt(starts[i], open: i == 5),
    ];

    test('recent: the newest shift and up to three before it, oldest first', () {
      final shifts = TemperatureShiftCheck.recent(
          sixCycles, [for (final s in starts) ...shiftIn(s)]);
      expect(shifts.map((s) => s.cycleStart), starts.sublist(2));
    });

    test('recent: a shift in the cycle before the open one is still news', () {
      final shifts = TemperatureShiftCheck.recent(
          sixCycles, [...shiftIn(starts[4])]);
      expect(shifts.map((s) => s.cycleStart), [starts[4]]);
    });

    test('recent: two cycles back is history', () {
      expect(TemperatureShiftCheck.recent(sixCycles, [...shiftIn(starts[3])]),
          isEmpty);
    });

    test('recent: with only one cycle, that is the cycle', () {
      expect(
          TemperatureShiftCheck.recent(
              [cycleAt(starts[0], open: true)], shiftIn(starts[0])),
          hasLength(1));
    });

    test('recent: nothing to look at is nothing to say', () {
      expect(TemperatureShiftCheck.recent(const [], const []), isEmpty);
      expect(TemperatureShiftCheck.recent(sixCycles, const []), isEmpty);
    });

    test('no readings, no shifts', () {
      expect(TemperatureShiftCheck.forCycles(const [], const []), isEmpty);
    });
  });
}
