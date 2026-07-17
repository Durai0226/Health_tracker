import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/insight.dart';
import 'package:tablet_remainder/core/ai/insight_engine.dart';

void main() {
  group('InsightEngine.medicine', () {
    test('low supply → urgent refill (highest priority)', () {
      final i = InsightEngine.medicine(adherence: 0.95, daysOfSupply: 2);
      expect(i, isNotNull);
      expect(i!.id, 'med_refill');
      expect(i.severity, InsightSeverity.urgent);
    });
    test('low adherence → attention', () {
      final i = InsightEngine.medicine(adherence: 0.6);
      expect(i!.id, 'med_adherence');
      expect(i.severity, InsightSeverity.attention);
    });
    test('high miss-risk → attention', () {
      final i = InsightEngine.medicine(adherence: 0.85, missRisk: 0.6);
      expect(i!.id, 'med_missrisk');
    });
    test('streak → good', () {
      final i = InsightEngine.medicine(adherence: 0.85, streakDays: 5);
      expect(i!.id, 'med_streak');
      expect(i.severity, InsightSeverity.good);
    });
    test('nothing notable → null', () {
      expect(InsightEngine.medicine(adherence: 0.85, streakDays: 0), isNull);
    });
  });

  group('InsightEngine.water', () {
    test('behind pace → attention', () {
      final i = InsightEngine.water(intakeMl: 400, goalMl: 2000, behind: true, deficitMl: 500);
      expect(i!.id, 'water_behind');
      expect(i.severity, InsightSeverity.attention);
    });
    test('goal reached → good', () {
      final i = InsightEngine.water(intakeMl: 2100, goalMl: 2000);
      expect(i!.id, 'water_goal');
    });
  });

  group('InsightEngine.focus', () {
    test('best hour → info', () {
      final i = InsightEngine.focus(bestFocusHour: 9, sessionCount: 6, completionRate: 0.8);
      expect(i!.id, 'focus_besthour');
    });
    test('low completion → shorter sessions', () {
      final i = InsightEngine.focus(sessionCount: 6, completionRate: 0.3);
      expect(i!.id, 'focus_completion');
    });
  });

  group('rankAll', () {
    test('urgent sorts before attention before good', () {
      final ranked = InsightEngine.rankAll([
        InsightEngine.focus(bestFocusHour: 9, sessionCount: 6), // info
        InsightEngine.medicine(daysOfSupply: 1), // urgent
        InsightEngine.water(intakeMl: 400, goalMl: 2000, behind: true, deficitMl: 400), // attention
      ]);
      expect(ranked.first.severity, InsightSeverity.urgent);
      expect(ranked.last.severity.index, lessThanOrEqualTo(InsightSeverity.attention.index));
    });
    test('drops nulls', () {
      final ranked = InsightEngine.rankAll([null, InsightEngine.water(intakeMl: 2100, goalMl: 2000), null]);
      expect(ranked, hasLength(1));
    });
  });
}
