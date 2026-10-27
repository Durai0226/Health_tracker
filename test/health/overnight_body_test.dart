/// "2 of 5 overnight signals are outside your usual range." and "Heart rate
/// dropped 18% below daytime; lowest around 2 am."
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/overnight_body.dart';
import 'package:tablet_remainder/core/health/usual_range.dart';

void main() {
  /// Fourteen days of [v], with a little spread so the range has a width.
  List<double> steady(double v, {int n = 14, double spread = 1.0}) =>
      [for (var i = 0; i < n; i++) v + (i.isEven ? spread : -spread)];

  group('the body check', () {
    final history = {
      BodySignal.restingHr: steady(56),
      BodySignal.hrv: steady(45, spread: 4),
      BodySignal.breathing: steady(14, spread: 0.4),
      BodySignal.bloodOxygen: steady(96, spread: 1),
      BodySignal.temperature: steady(33.5, spread: 0.2),
    };

    test('counts how many are outside, out of how many were checked', () {
      final c = OvernightBodyCheck.evaluate(
        last: {
          BodySignal.restingHr: 66, // well above 54–58
          BodySignal.hrv: 45, // within
          BodySignal.breathing: 14, // within
          BodySignal.bloodOxygen: 91, // below
          BodySignal.temperature: 33.5, // within
        },
        history: history,
      )!;
      expect([c.checked, c.outside], [5, 2]);
      expect(c.headline, '2 of 5 overnight signals are outside your usual range.');
      expect(c.outsideSignals.map((s) => s.signal),
          [BodySignal.restingHr, BodySignal.bloodOxygen]);
    });

    test('all within says so', () {
      final c = OvernightBodyCheck.evaluate(
        last: {
          BodySignal.restingHr: 56,
          BodySignal.hrv: 45,
          BodySignal.bloodOxygen: 96,
        },
        history: history,
      )!;
      expect(c.outside, 0);
      expect(c.headline, 'All 3 overnight signals are within your usual range.');
    });

    test('each says what it was and what is usual', () {
      final c = OvernightBodyCheck.evaluate(
        last: {BodySignal.restingHr: 66, BodySignal.breathing: 16.2},
        history: history,
      )!;
      final hr = c.signals.firstWhere((s) => s.signal == BodySignal.restingHr);
      expect(hr.valueText, '66 bpm');
      expect(hr.usualText, 'usual 54–58',
          reason: 'the range is a 56 with a spread of 1, widened to the 2 bpm '
              'floor');
      expect(hr.status, RangeStatus.above);
      final br = c.signals.firstWhere((s) => s.signal == BodySignal.breathing);
      expect(br.valueText, '16.2 breaths/min');
      expect(br.usualText, 'usual 13.5–14.5',
          reason: 'a spread of 0.4, widened to the 0.5 floor');
    });

    test('a change from baseline reads with its sign, and is its own signal', () {
      final c = OvernightBodyCheck.evaluate(
        last: {
          BodySignal.temperatureChange: 0.6,
          BodySignal.restingHr: 56,
        },
        history: {
          BodySignal.temperatureChange: steady(0.0, spread: 0.2),
          BodySignal.restingHr: steady(56),
        },
      )!;
      final t = c.signals.firstWhere((s) => s.signal == BodySignal.temperatureChange);
      expect(t.valueText, '+0.6 °C');
      expect(t.usualText, 'usual -0.2–+0.2');
      expect(t.isOutside, isTrue);
      expect(BodySignal.temperatureChange.label, 'Skin temperature vs your baseline');
      expect(BodySignal.temperature, isNot(BodySignal.temperatureChange));

      // Nothing reads as "+0.0".
      final flat = OvernightBodyCheck.evaluate(
        last: {BodySignal.temperatureChange: 0.02, BodySignal.restingHr: 56},
        history: {
          BodySignal.temperatureChange: steady(0.0, spread: 0.2),
          BodySignal.restingHr: steady(56),
        },
      )!;
      expect(
          flat.signals
              .firstWhere((s) => s.signal == BodySignal.temperatureChange)
              .valueText,
          '0.0 °C');
    });

    test('a steady series does not make a hairline: a floor on the width', () {
      final c = OvernightBodyCheck.evaluate(
        last: {BodySignal.restingHr: 58, BodySignal.bloodOxygen: 96},
        history: {
          BodySignal.restingHr: [for (var i = 0; i < 14; i++) 56.0],
          BodySignal.bloodOxygen: [for (var i = 0; i < 14; i++) 96.0],
        },
      )!;
      expect(c.outside, 0, reason: '58 is within 2 bpm of a steady 56');
    });

    test('and a change past that floor is outside', () {
      final c = OvernightBodyCheck.evaluate(
        last: {BodySignal.restingHr: 58.1, BodySignal.bloodOxygen: 96},
        history: {
          BodySignal.restingHr: [for (var i = 0; i < 14; i++) 56.0],
          BodySignal.bloodOxygen: [for (var i = 0; i < 14; i++) 96.0],
        },
      )!;
      expect(c.outside, 1);
    });

    test('a signal with no value last night, or no history, is not checked', () {
      final c = OvernightBodyCheck.evaluate(
        last: {
          BodySignal.restingHr: 56,
          BodySignal.hrv: null,
          BodySignal.bloodOxygen: 96,
          BodySignal.temperature: 33.5,
        },
        history: {
          ...history,
          BodySignal.temperature: steady(33.5).take(6).toList(), // under seven
        },
      )!;
      expect(c.signals.map((s) => s.signal),
          [BodySignal.restingHr, BodySignal.bloodOxygen]);
    });

    test('fewer than two signals say nothing: "1 of 1" is not a check', () {
      expect(
          OvernightBodyCheck.evaluate(
              last: {BodySignal.restingHr: 56}, history: history),
          isNull);
      expect(OvernightBodyCheck.evaluate(last: const {}, history: history), isNull);
    });

    test('history must be seven days', () {
      final short = {
        BodySignal.restingHr: steady(56, n: 6),
        BodySignal.bloodOxygen: steady(96, n: 6),
      };
      expect(
          OvernightBodyCheck.evaluate(
              last: {BodySignal.restingHr: 56, BodySignal.bloodOxygen: 96},
              history: short),
          isNull);
    });
  });

  group('the heart-rate dip', () {
    /// A day: [day] bpm from 09:00 to 20:59 and [rest] elsewhere.
    List<int?> hours({int rest = 70, int day = 70, Map<int, int?> over = const {}}) => [
          for (var h = 0; h < 24; h++)
            over.containsKey(h) ? over[h] : (h >= 9 && h < 21 ? day : rest)
        ];

    final bed = DateTime(2026, 6, 14, 23);
    final wake = DateTime(2026, 6, 15, 7);

    NightHeartDip? dip({List<int?>? before, List<int?>? after, DateTime? b, DateTime? w}) =>
        NightHeartDip.compute(
          dayBefore: before ?? hours(day: 70),
          wakeDay: after ?? hours(over: {for (var h = 0; h < 7; h++) h: 54}),
          bedtime: b ?? bed,
          wakeTime: w ?? wake,
        );

    test('a night lower than the day: how much, and when the lowest was', () {
      final d = dip(
        before: hours(day: 66, over: {23: 58}),
        after: hours(over: {0: 56, 1: 54, 2: 50, 3: 52, 4: 54, 5: 56, 6: 58}),
      )!;
      expect(d.dayAvg, 66);
      // 23:00 -> 58; 00:00..06:00 -> 56 54 50 52 54 56 58: mean of eight = 54.75.
      expect(d.nightAvg, 55);
      expect(d.lowestBpm, 50);
      expect(d.lowestHour, 2);
      expect(d.dipPercent, 17);
      expect(d.line,
          'Your heart rate was 17% lower overnight than by day (about 55 vs 66 '
          'bpm); lowest around 2 am.');
    });

    test('the lowest hour reads as a clock hour', () {
      String at(int h) => NightHeartDip(
              dayAvg: 66, nightAvg: 55, lowestBpm: 50, lowestHour: h)
          .line;
      expect(at(0), endsWith('lowest around 12 am.'));
      expect(at(1), endsWith('lowest around 1 am.'));
      expect(at(11), endsWith('lowest around 11 am.'));
      expect(at(12), endsWith('lowest around 12 pm.'));
      expect(at(13), endsWith('lowest around 1 pm.'));
      expect(at(23), endsWith('lowest around 11 pm.'));
    });

    test('a night about the same as the day says that', () {
      final d = dip(
        before: hours(day: 60, rest: 60),
        after: hours(rest: 60, over: {for (var h = 0; h < 7; h++) h: 60}),
      )!;
      expect(d.line, startsWith('Your heart rate was about the same overnight'));
    });

    test('a night higher than the day says so, without alarm', () {
      final d = dip(
        before: hours(day: 60, over: {23: 70}),
        after: hours(over: {for (var h = 0; h < 7; h++) h: 72}),
      )!;
      expect(d.dipPercent, lessThan(0));
      expect(d.line, isNot(contains('lower')));
      expect(d.line, contains('% higher overnight than by day'));
    });

    test('hours are the whole ones inside the night', () {
      // In bed 23:40, up 06:20: whole hours 00:00 to 05:00 only.
      final d = dip(
        b: DateTime(2026, 6, 14, 23, 40),
        w: DateTime(2026, 6, 15, 6, 20),
        after: hours(over: {0: 60, 1: 60, 2: 60, 3: 60, 4: 60, 5: 60, 6: 40}),
        before: hours(over: {23: 40}),
      )!;
      expect(d.nightAvg, 60, reason: '23:00 and 06:00 are partial hours');
    });

    test('a bedtime after midnight uses the whole previous day by day', () {
      final d = dip(
        b: DateTime(2026, 6, 15, 0, 30),
        w: DateTime(2026, 6, 15, 7),
        before: hours(day: 66),
        after: hours(over: {for (var h = 1; h < 7; h++) h: 55}),
      )!;
      expect(d.dayAvg, 66);
      expect(d.nightAvg, 55);
    });

    test('an hour already in bed is not daytime', () {
      // Bed at 20:00: daytime is 09:00-19:59 only; the 20:00 slot is excluded.
      final d = dip(
        b: DateTime(2026, 6, 14, 20),
        w: DateTime(2026, 6, 15, 6),
        before: hours(day: 70, over: {20: 40, 21: 40, 22: 40, 23: 40}),
        after: hours(over: {for (var h = 0; h < 6; h++) h: 55}),
      )!;
      expect(d.dayAvg, 70);
    });

    test('too few hours on either side say nothing', () {
      expect(
          dip(
              before: hours(over: {23: null}),
              after: hours(over: {
                0: 54,
                1: 54,
                for (var h = 2; h < 7; h++) h: null,
              })),
          isNull,
          reason: 'two overnight hours');
      expect(
          dip(
              before: hours(over: {23: null}),
              after: hours(over: {
                0: 54,
                1: 54,
                2: 54,
                for (var h = 3; h < 7; h++) h: null,
              })),
          isNotNull,
          reason: 'three is enough');
      expect(
          dip(before: hours(over: {for (var h = 9; h < 21; h++) h: h < 13 ? 70 : null})),
          isNull,
          reason: 'only four daytime hours');
    });

    test('a day with no hourly data at all says nothing', () {
      expect(dip(before: const [], after: const []), isNull);
    });
  });
}
