import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';

void main() {
  group('classifyBp (AHA/ACC cascade)', () {
    test('canonical categories', () {
      expect(VitalsAnalyzer.classifyBp(118, 76), BpCategory.normal);
      expect(VitalsAnalyzer.classifyBp(122, 78), BpCategory.elevated);
      expect(VitalsAnalyzer.classifyBp(135, 78), BpCategory.stage1);
      expect(VitalsAnalyzer.classifyBp(150, 95), BpCategory.stage2);
      expect(VitalsAnalyzer.classifyBp(185, 125), BpCategory.crisis);
    });

    test('mismatched systolic/diastolic resolves to the more severe', () {
      // Elevated systolic but high diastolic → Stage 1 via diastolic.
      expect(VitalsAnalyzer.classifyBp(118, 82), BpCategory.stage1);
      // Systolic in Stage 1 range, diastolic normal → Stage 1 via systolic.
      expect(VitalsAnalyzer.classifyBp(135, 70), BpCategory.stage1);
      // Crisis via diastolic alone.
      expect(VitalsAnalyzer.classifyBp(150, 121), BpCategory.crisis);
    });

    test('elevated requires diastolic < 80 (boundary)', () {
      expect(VitalsAnalyzer.classifyBp(125, 79), BpCategory.elevated);
      expect(VitalsAnalyzer.classifyBp(129, 79), BpCategory.elevated);
      expect(VitalsAnalyzer.classifyBp(130, 79), BpCategory.stage1);
    });

    test('crisis flag + validation', () {
      expect(VitalsAnalyzer.isBpCrisis(181, 90), isTrue);
      expect(VitalsAnalyzer.isBpCrisis(160, 100), isFalse);
      expect(VitalsAnalyzer.isValidBp(120, 80), isTrue);
      expect(VitalsAnalyzer.isValidBp(80, 120), isFalse); // sys must exceed dia
      expect(VitalsAnalyzer.isValidBp(400, 80), isFalse);
    });
  });

  group('classifyGlucose (ADA, per context)', () {
    test('severity overrides context', () {
      expect(VitalsAnalyzer.classifyGlucose(50, GlucoseContext.afterMeal),
          GlucoseClass.severeLow);
      expect(VitalsAnalyzer.classifyGlucose(65, GlucoseContext.fasting),
          GlucoseClass.low);
      expect(VitalsAnalyzer.classifyGlucose(300, GlucoseContext.fasting),
          GlucoseClass.veryHigh);
    });

    test('fasting: >=130 is high, in-range below', () {
      expect(VitalsAnalyzer.classifyGlucose(110, GlucoseContext.fasting),
          GlucoseClass.inRange);
      expect(VitalsAnalyzer.classifyGlucose(140, GlucoseContext.fasting),
          GlucoseClass.high);
    });

    test('after-meal target is looser (<180 in range)', () {
      // 150 is HIGH when fasting but IN-RANGE after a meal.
      expect(VitalsAnalyzer.classifyGlucose(150, GlucoseContext.fasting),
          GlucoseClass.high);
      expect(VitalsAnalyzer.classifyGlucose(150, GlucoseContext.afterMeal),
          GlucoseClass.inRange);
      expect(VitalsAnalyzer.classifyGlucose(200, GlucoseContext.afterMeal),
          GlucoseClass.high);
    });

    test('emergency-low + validation', () {
      expect(VitalsAnalyzer.isGlucoseEmergencyLow(53), isTrue);
      expect(VitalsAnalyzer.isGlucoseEmergencyLow(54), isFalse);
      expect(VitalsAnalyzer.isValidGlucoseMgdl(120), isTrue);
      expect(VitalsAnalyzer.isValidGlucoseMgdl(1000), isFalse);
    });
  });

  group('unit conversion', () {
    test('mg/dL ↔ mmol/L round-trips near the factor', () {
      expect(VitalsAnalyzer.mgdlToMmol(126), closeTo(7.0, 0.05));
      expect(VitalsAnalyzer.mgdlToMmol(180), closeTo(10.0, 0.05));
      expect(VitalsAnalyzer.mmolToMgdl(7.0), inInclusiveRange(125, 127));
    });
  });

  group('aggregates', () {
    test('estimated A1C gated on data, then uses the ADAG formula', () {
      expect(VitalsAnalyzer.estimatedA1c([120, 130, 140]), isNull); // too few
      final vals = List<int>.filled(20, 154); // mean 154 → GMI/ADAG agree ~7.0
      final a1c = VitalsAnalyzer.estimatedA1c(vals);
      expect(a1c, isNotNull);
      expect(a1c!, closeTo((154 + 46.7) / 28.7, 0.001));
    });

    test('in-range % honors each reading context', () {
      final pct = VitalsAnalyzer.inRangePercent([
        (mgdl: 110, ctx: GlucoseContext.fasting), // in range
        (mgdl: 150, ctx: GlucoseContext.afterMeal), // in range
        (mgdl: 150, ctx: GlucoseContext.fasting), // high
        (mgdl: 60, ctx: GlucoseContext.random), // low
      ]);
      expect(pct, closeTo(0.5, 0.001));
      expect(VitalsAnalyzer.inRangePercent(const []), isNull);
    });

    test('mean handles empty', () {
      expect(VitalsAnalyzer.mean(const []), isNull);
      expect(VitalsAnalyzer.mean([100, 200]), 150);
    });
  });
}
