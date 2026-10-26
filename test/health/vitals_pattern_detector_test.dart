import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/health/vitals_pattern_detector.dart';

void main() {
  DateTime day(int d, int h) => DateTime(2026, 3, d, h);

  /// Anchors the detector's 30-day "recent" window just after the fixtures, so
  /// these assertions are deterministic instead of ageing out over time.
  final asOf = DateTime(2026, 3, 20);

  bool has(List<Insight> l, String id) => l.any((i) => i.id == id);

  group('analyzeBp', () {
    test('rising systolic → bp_trend (attention)', () {
      final pts = [
        for (var i = 0; i < 6; i++)
          BpPoint(at: day(1 + i, 9), systolic: 118 + i * 3, diastolic: 70),
      ];
      final out = VitalsPatternDetector.analyzeBp(pts, now: asOf);
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
      expect(has(VitalsPatternDetector.analyzeBp(pts, now: asOf), 'bp_ampm'), isTrue);
    });

    test('mostly out of range → bp_outofrange', () {
      final pts = [
        for (var i = 0; i < 6; i++)
          BpPoint(at: day(1 + i, 9), systolic: 150, diastolic: 95),
      ];
      final out = VitalsPatternDetector.analyzeBp(pts, now: asOf);
      expect(has(out, 'bp_outofrange'), isTrue);
    });

    /// The headline has to agree with the percentage printed underneath it.
    ///
    /// This card fires from 40% out-of-range but its title was always "Most
    /// readings above target". On device that produced a card reading "Most
    /// readings above target" above a detail line saying "50% of your recent
    /// readings are Stage 1 or higher" — and this is blood-pressure guidance,
    /// where the headline is the part that gets remembered.
    ///
    /// [outOfRange] of 10 readings are Stage 1+; the rest are normal.
    List<Insight> withShare(int outOfRange) =>
        VitalsPatternDetector.analyzeBp([
          for (var i = 0; i < outOfRange; i++)
            BpPoint(at: day(1 + i, 9), systolic: 150, diastolic: 95),
          for (var i = outOfRange; i < 10; i++)
            BpPoint(at: day(1 + i, 9), systolic: 112, diastolic: 70),
        ], now: asOf);

    String titleOf(int outOfRange) =>
        withShare(outOfRange).firstWhere((i) => i.id == 'bp_outofrange').title;

    test('half out of range is not called "most"', () {
      final out = withShare(5);
      expect(has(out, 'bp_outofrange'), isTrue,
          reason: 'premise: the card must fire at 50% for its title to matter');
      expect(titleOf(5), 'Many readings above target');
      expect(titleOf(5), isNot(contains('Most')),
          reason: 'five of ten is not most of them');
    });

    test('the lowest share that fires is not called "most" either', () {
      expect(titleOf(4), isNot(contains('Most')),
          reason: 'the card fires from 40%, which is where the old title was '
              'furthest from true');
    });

    test('an actual majority is called "most"', () {
      expect(titleOf(6), 'Most readings above target');
      expect(titleOf(9), 'Most readings above target');
    });

    test('the title and the detail never disagree', () {
      for (var n = 4; n <= 10; n++) {
        final card =
            withShare(n).firstWhere((i) => i.id == 'bp_outofrange');
        final pct = int.parse(RegExp(r'(\d+)%').firstMatch(card.detail)!.group(1)!);
        expect(card.title.startsWith('Most'), pct > 50,
            reason: 'at $pct% the card said "${card.title}"');
      }
    });


    /// The AM/PM card renders directly beneath the Morning / Evening stat
    /// tiles, and those are computed over the last SEVEN days while this walks
    /// [VitalsPatternDetector.recentWindow] — thirty. The two can reach
    /// opposite conclusions, so the card has to say which days it means.
    test('the AM/PM card states the window it covers', () {
      final pts = [
        BpPoint(at: day(1, 8), systolic: 142, diastolic: 88),
        BpPoint(at: day(2, 9), systolic: 140, diastolic: 86),
        BpPoint(at: day(1, 20), systolic: 120, diastolic: 76),
        BpPoint(at: day(2, 21), systolic: 118, diastolic: 74),
      ];
      final card = VitalsPatternDetector.analyzeBp(pts, now: asOf)
          .firstWhere((i) => i.id == 'bp_ampm');

      final days = '${VitalsPatternDetector.recentWindow.inDays}';
      expect(card.detail, contains(days),
          reason: 'the detail asserts a comparison without saying over what — '
              'directly under tiles that mean something else');
      expect(card.why, contains(days));
      expect(card.why, contains('7'),
          reason: 'and it should name the tiles\' window too, since that is '
              'the number it appears to contradict');
    });

    test('too few points → empty', () {
      expect(VitalsPatternDetector.analyzeBp([BpPoint(at: day(1, 9), systolic: 120, diastolic: 80)], now: asOf), isEmpty);
    });
  });

  group('analyzeGlucose', () {
    GlucosePoint g(int d, int v, [GlucoseContext c = GlucoseContext.random]) =>
        GlucosePoint(at: day(d, 9), mgdl: v, context: c);

    test('rising glucose → gl_trend', () {
      final out = VitalsPatternDetector.analyzeGlucose([g(1, 100), g(2, 110), g(3, 120), g(4, 130), g(5, 140), g(6, 150)], now: asOf);
      expect(has(out, 'gl_trend'), isTrue);
    });

    test('two lows → gl_lows (attention)', () {
      final out = VitalsPatternDetector.analyzeGlucose([g(1, 65), g(2, 60), g(3, 120)], now: asOf);
      expect(has(out, 'gl_lows'), isTrue);
      expect(out.firstWhere((i) => i.id == 'gl_lows').severity, InsightSeverity.attention);
    });

    test('high fasting average → gl_fasting', () {
      final out = VitalsPatternDetector.analyzeGlucose([
        g(1, 140, GlucoseContext.fasting),
        g(2, 150, GlucoseContext.fasting),
        g(3, 135, GlucoseContext.fasting),
      ], now: asOf);
      expect(has(out, 'gl_fasting'), isTrue);
    });
  });
}
