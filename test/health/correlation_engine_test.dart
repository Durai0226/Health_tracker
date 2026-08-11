import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/correlation_engine.dart';

void main() {
  List<DayMetric> days({
    required int adherentCount,
    required double adherentValue,
    required int nonAdherentCount,
    required double nonAdherentValue,
  }) {
    final base = DateTime(2026, 1, 1);
    final out = <DayMetric>[];
    for (var i = 0; i < adherentCount; i++) {
      out.add(DayMetric(day: base.add(Duration(days: i)), adherent: true, value: adherentValue));
    }
    for (var i = 0; i < nonAdherentCount; i++) {
      out.add(DayMetric(
          day: base.add(Duration(days: 100 + i)), adherent: false, value: nonAdherentValue));
    }
    return out;
  }

  group('correlateWithAdherence', () {
    test('positive: computes correct group means', () {
      final r = correlateWithAdherence(
          days(adherentCount: 5, adherentValue: 1.0, nonAdherentCount: 5, nonAdherentValue: 3.0));
      expect(r, isNotNull);
      expect(r!.adherentMean, 1.0);
      expect(r.nonAdherentMean, 3.0);
      expect(r.delta, 2.0);
    });

    test('negative: null when one bucket is empty', () {
      final r = correlateWithAdherence(
          days(adherentCount: 5, adherentValue: 1.0, nonAdherentCount: 0, nonAdherentValue: 3.0));
      expect(r, isNull);
    });

    test('negative: hasEnoughData is false below minPerGroup', () {
      final r = correlateWithAdherence(
          days(adherentCount: 2, adherentValue: 1.0, nonAdherentCount: 2, nonAdherentValue: 3.0));
      expect(r!.hasEnoughData, isFalse);
    });

    test('positive: hasEnoughData is true at exactly minPerGroup', () {
      final r = correlateWithAdherence(days(
          adherentCount: CorrelationResult.minPerGroup,
          adherentValue: 1.0,
          nonAdherentCount: CorrelationResult.minPerGroup,
          nonAdherentValue: 3.0));
      expect(r!.hasEnoughData, isTrue);
    });
  });

  group('CorrelationEngine.moodVsAdherence', () {
    test('positive: a meaningfully worse mood on non-adherent days produces an insight',
        () {
      final insight = CorrelationEngine.moodVsAdherence(days(
          adherentCount: 10, adherentValue: 1.0, // mostly Great/Good
          nonAdherentCount: 10, nonAdherentValue: 2.5)); // Okay-to-Bad
      expect(insight, isNotNull);
      expect(insight!.id, 'correlation_mood_adherence');
    });

    test('negative: insufficient data does not produce an insight', () {
      final insight = CorrelationEngine.moodVsAdherence(days(
          adherentCount: 2, adherentValue: 1.0, nonAdherentCount: 2, nonAdherentValue: 3.0));
      expect(insight, isNull);
    });

    test('negative: a trivial (non-meaningful) delta does not produce an insight', () {
      final insight = CorrelationEngine.moodVsAdherence(days(
          adherentCount: 10, adherentValue: 1.0, nonAdherentCount: 10, nonAdherentValue: 1.1));
      expect(insight, isNull);
    });

    test('negative: mood being BETTER on non-adherent days is not flagged as a problem',
        () {
      // delta is negative here (mood improves on non-adherent days) — not
      // the "missed doses correlate with worse mood" pattern this insight
      // claims, so it must not fire.
      final insight = CorrelationEngine.moodVsAdherence(days(
          adherentCount: 10, adherentValue: 3.0, nonAdherentCount: 10, nonAdherentValue: 1.0));
      expect(insight, isNull);
    });
  });

  group('CorrelationEngine.bloodPressureVsAdherence', () {
    test('positive: a meaningfully higher systolic on non-adherent days produces an insight',
        () {
      final insight = CorrelationEngine.bloodPressureVsAdherence(days(
          adherentCount: 10, adherentValue: 118, nonAdherentCount: 10, nonAdherentValue: 138));
      expect(insight, isNotNull);
      expect(insight!.id, 'correlation_bp_adherence');
    });

    test('negative: a small, clinically-noisy delta does not produce an insight', () {
      final insight = CorrelationEngine.bloodPressureVsAdherence(days(
          adherentCount: 10, adherentValue: 120, nonAdherentCount: 10, nonAdherentValue: 122));
      expect(insight, isNull);
    });
  });
}
