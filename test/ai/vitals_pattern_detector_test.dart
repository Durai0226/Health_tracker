import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/vitals_analyzer.dart';
import 'package:tablet_remainder/core/ai/insight.dart';
import 'package:tablet_remainder/core/ai/vitals_pattern_detector.dart';

void main() {
  DateTime day(int d, int h) => DateTime(2026, 3, d, h);

  bool has(List<Insight> l, String id) => l.any((i) => i.id == id);

  group('analyzeBp', () {
    test('rising systolic → bp_trend (attention)', () {
      final pts = [
        for (var i = 0; i < 6; i++)
          BpPoint(at: day(1 + i, 9), systolic: 118 + i * 3, diastolic: 70),
      ];
      final out = VitalsPatternDetector.analyzeBp(pts);
      expect(has(out, 'bp_trend'), isTrue);
      final t = out.firstWhere((i) => i.id == 'bp_trend');
      expect(t.severity, InsightSeverity.attention);
    });

    test('mornings higher → bp_ampm', () {
      final pts = [
        BpPoint(at: day(1, 8), systolic: 142, diastolic: 88),
        BpPoint(at: day(2, 9), systolic: 140, diastolic: 86),
        BpPoint(at: day(1, 20), systolic: 120, diastolic: 76),
        BpPoint(at: day(2, 21), systolic: 118, diastolic: 74),
      ];
      expect(has(VitalsPatternDetector.analyzeBp(pts), 'bp_ampm'), isTrue);
    });

    test('mostly out of range → bp_outofrange', () {
      final pts = [
        for (var i = 0; i < 6; i++)
          BpPoint(at: day(1 + i, 9), systolic: 150, diastolic: 95),
      ];
      final out = VitalsPatternDetector.analyzeBp(pts);
      expect(has(out, 'bp_outofrange'), isTrue);
    });

    test('too few points → empty', () {
      expect(VitalsPatternDetector.analyzeBp([BpPoint(at: day(1, 9), systolic: 120, diastolic: 80)]), isEmpty);
    });
  });

  group('analyzeGlucose', () {
    GlucosePoint g(int d, int v, [GlucoseContext c = GlucoseContext.random]) =>
        GlucosePoint(at: day(d, 9), mgdl: v, context: c);

    test('rising glucose → gl_trend', () {
      final out = VitalsPatternDetector.analyzeGlucose(
          [g(1, 100), g(2, 110), g(3, 120), g(4, 130), g(5, 140), g(6, 150)]);
      expect(has(out, 'gl_trend'), isTrue);
    });

    test('two lows → gl_lows (attention)', () {
      final out = VitalsPatternDetector.analyzeGlucose([g(1, 65), g(2, 60), g(3, 120)]);
      expect(has(out, 'gl_lows'), isTrue);
      expect(out.firstWhere((i) => i.id == 'gl_lows').severity, InsightSeverity.attention);
    });

    test('high fasting average → gl_fasting', () {
      final out = VitalsPatternDetector.analyzeGlucose([
        g(1, 140, GlucoseContext.fasting),
        g(2, 150, GlucoseContext.fasting),
        g(3, 135, GlucoseContext.fasting),
      ]);
      expect(has(out, 'gl_fasting'), isTrue);
    });
  });
}
