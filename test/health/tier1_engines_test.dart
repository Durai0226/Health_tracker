import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/adaptive_timing.dart';
import 'package:tablet_remainder/core/health/adherence_analyzer.dart';
import 'package:tablet_remainder/core/health/focus_insights.dart';

void main() {
  group('AdaptiveTiming', () {
    test('consistent ~40-min-late history → confident later shift', () {
      final s = AdaptiveTiming.suggest(
        scheduledMinutes: 8 * 60, // 08:00
        actualMinutes: [8 * 60 + 38, 8 * 60 + 42, 8 * 60 + 40, 8 * 60 + 41, 8 * 60 + 39],
      );
      expect(s.confident, isTrue);
      expect(s.deltaMinutes, inInclusiveRange(35, 45));
      expect(s.suggestedMinutes, inInclusiveRange(8 * 60 + 35, 8 * 60 + 45));
    });

    test('too few samples → not confident', () {
      final s = AdaptiveTiming.suggest(
        scheduledMinutes: 8 * 60,
        actualMinutes: [8 * 60 + 40, 8 * 60 + 45],
      );
      expect(s.confident, isFalse);
    });

    test('erratic history (huge spread) → not confident', () {
      final s = AdaptiveTiming.suggest(
        scheduledMinutes: 8 * 60,
        actualMinutes: [8 * 60 + 5, 9 * 60 + 30, 8 * 60 + 10, 11 * 60, 7 * 60 + 30],
      );
      expect(s.confident, isFalse);
    });

    test('shift is clamped to the max', () {
      final s = AdaptiveTiming.suggest(
        scheduledMinutes: 8 * 60,
        actualMinutes: List.filled(6, 8 * 60 + 300), // +5h
        maxShiftMinutes: 120,
      );
      expect(s.deltaMinutes, 120);
    });
  });

  group('AdherenceAnalyzer', () {
    List<DoseEvent> mix(int taken, int missed) => [
          for (var i = 0; i < taken; i++)
            DoseEvent(DateTime(2026, 3, 1 + i, 8), DoseOutcome.taken),
          for (var i = 0; i < missed; i++)
            DoseEvent(DateTime(2026, 3, 20 + i, 8), DoseOutcome.missed),
        ];

    test('adherence is taken ÷ total', () {
      expect(AdherenceAnalyzer.adherence(mix(8, 2)), closeTo(0.8, 0.001));
      expect(AdherenceAnalyzer.adherence(const []), 0);
    });

    test('miss-risk rises for a chronically-missed bucket', () {
      // Every Monday 20:00 dose missed; other doses taken.
      final history = <DoseEvent>[
        for (var w = 0; w < 6; w++)
          DoseEvent(DateTime(2026, 1, 5 + w * 7, 20), DoseOutcome.missed), // Mondays
        for (var d = 0; d < 20; d++)
          DoseEvent(DateTime(2026, 2, 1 + d, 8), DoseOutcome.taken),
      ];
      final risk = AdherenceAnalyzer.missRisk(
          weekday: DateTime.monday, hour: 20, history: history);
      final safe = AdherenceAnalyzer.missRisk(
          weekday: DateTime.tuesday, hour: 8, history: history);
      expect(risk, greaterThan(safe));
      expect(AdherenceAnalyzer.riskLabel(risk), anyOf('high', 'medium'));
    });

    test('empty history → zero risk', () {
      expect(AdherenceAnalyzer.missRisk(weekday: 1, hour: 8, history: const []), 0);
    });
  });

  group('FocusInsights', () {
    test('best focus hour picks the busiest bucket', () {
      final sessions = [
        const FocusSessionRef(startHour: 9, minutes: 25),
        const FocusSessionRef(startHour: 9, minutes: 50),
        const FocusSessionRef(startHour: 14, minutes: 25),
        const FocusSessionRef(startHour: 21, minutes: 25),
        const FocusSessionRef(startHour: 9, minutes: 25),
        const FocusSessionRef(startHour: 16, minutes: 25),
      ];
      expect(FocusInsights.bestFocusHour(sessions), 9);
    });

    test('too little history → null (no false precision)', () {
      expect(
        FocusInsights.bestFocusHour(const [FocusSessionRef(startHour: 9, minutes: 25)]),
        isNull,
      );
    });

    test('completion rate + hour label', () {
      final s = [
        const FocusSessionRef(startHour: 9, minutes: 25, completed: true),
        const FocusSessionRef(startHour: 9, minutes: 10, completed: false),
      ];
      expect(FocusInsights.completionRate(s), 0.5);
      expect(FocusInsights.hourLabel(14), '2 PM');
      expect(FocusInsights.hourLabel(0), '12 AM');
    });
  });
}
