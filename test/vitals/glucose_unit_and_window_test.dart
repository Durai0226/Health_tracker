import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';

/// PV-16 and PV-13 on the blood-sugar screen.
///
/// PV-16: every number on that screen goes through `_display`, which honours
/// the mmol/L setting — except the chart, which drew the raw mg/dL series
/// against a mg/dL axis with a mg/dL in-range band. A glucose figure in the
/// wrong unit is out by ~18x, on the screen a person checks before deciding
/// whether to treat a low.
///
/// PV-13: "In range" was computed over ALL history while Average and eA1c
/// beside it were 90-day — one card, two windows, no label saying so.
///
/// Source-scanned rather than pumped: BloodSugarScreen reaches
/// CleanStorageService and the vitals store on construction, and the arithmetic
/// is what has the defect in it. The conversion itself is checked numerically
/// below, so the guard is not only textual.
void main() {
  final src = File('lib/features/medication/screens/vitals/blood_sugar_screen.dart')
      .readAsStringSync();

  group('PV-16 — the chart speaks the user\'s unit', () {
    test('series, both axis bounds and both band edges convert together', () {
      expect(src, contains('double chartY(double mgdl)'),
          reason: 'one converter for everything the chart draws');
      expect(src, contains('final series = rawSeries.map(chartY).toList()'));
      expect(src, contains('final minY = chartY(rawMinY)'));
      expect(src, contains('final maxY = chartY(rawMaxY)'));
      expect(src, contains('bandLow: chartY(70)'));
      expect(src, contains('bandHigh: chartY(180)'));
      expect(src.contains('bandLow: 70,'), isFalse,
          reason: 'a converted series against a raw band is WORSE than '
              'converting neither — the line would be right and its context '
              'wrong');
    });

    test('and the band says which unit it is in', () {
      expect(src, contains('bandLabel:'),
          reason: 'the axis carries no unit label, so the band legend is where '
              'the unit has to be stated');
      expect(src, contains(r'$_unitLabel'));
    });

    test('the conversion is right (the 18x that makes this dangerous)', () {
      // Hand-computed: 70 mg/dL = 3.9 mmol/L, 180 = 10.0, 120 = 6.7.
      expect(VitalsAnalyzer.mgdlToMmol(70), closeTo(3.9, 0.05));
      expect(VitalsAnalyzer.mgdlToMmol(180), closeTo(10.0, 0.05));
      expect(VitalsAnalyzer.mgdlToMmol(120), closeTo(6.7, 0.05));
      // A severe low must not read as an in-range number after conversion.
      expect(VitalsAnalyzer.mgdlToMmol(50), lessThan(3.0));
    });
  });

  group('PV-13 — one window for the whole card', () {
    test('in-range uses the same 90-day set as average and eA1c', () {
      expect(src, contains('recent.map((r) => (mgdl: r.valueMgdl, ctx: r.context))'),
          reason: 'in-range must read the windowed list, not _readings');
      expect(
          src.contains('_readings.map((r) => (mgdl: r.valueMgdl, ctx: r.context))'),
          isFalse,
          reason: 'that is the all-time computation this finding is about');
      expect(src, contains('final values90 = recent.map((r) => r.valueMgdl)'));
    });

    test('the window is calendar-day based, not Duration-based', () {
      expect(src, contains('calendarDaysBetween(r.takenAt, clock.now()) < 90'),
          reason: 'a civil day is 23 or 25 hours across DST; .inDays moves the '
              'boundary reading in and out of the window by season');
      expect(src.contains('DateTime.now().difference(r.takenAt).inDays'), isFalse);
    });
  });

  test('the scanner is reading the real screen', () {
    expect(src.length, greaterThan(10000));
    expect(src, contains('class BloodSugarScreen'));
  });
}
