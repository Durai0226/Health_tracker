import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/health/insight_engine.dart';
import 'package:tablet_remainder/core/health/adherence_analyzer.dart';

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
    test('EMPTY day (0 intake) does NOT cry "behind" — the 1821ml-nonsense guard', () {
      final i = InsightEngine.water(
          intakeMl: 0, goalMl: 2500, behind: true, deficitMl: 1821);
      expect(i, isNull);
    });
  });

  group('InsightEngine.sleep debt guard', () {
    test('empty week (0 logged nights) does NOT fabricate a "56h debt"', () {
      final i = InsightEngine.sleep(
        lastNightMinutes: 0,
        targetMinutes: 480,
        debtMinutes: 3360, // 480*7 from an all-empty week
        loggedNights: 0,
      );
      expect(i, isNull);
    });
    test('debt shows once enough nights are actually logged', () {
      final i = InsightEngine.sleep(
        lastNightMinutes: 360,
        targetMinutes: 480,
        debtMinutes: 600,
        loggedNights: 5,
      );
      expect(i, isNotNull);
      expect(i!.id, anyOf('sleep_short', 'sleep_balance_low'));
    });
  });

  group('InsightEngine.trend (week-over-week)', () {
    test('meaningful rise → good, up label', () {
      final i = InsightEngine.trend(
        feature: InsightFeature.steps,
        id: 'steps_trend',
        label: 'steps',
        thisWeek: 56000,
        lastWeek: 42000,
        higherIsBetter: true,
      );
      expect(i, isNotNull);
      expect(i!.id, 'steps_trend');
      expect(i.severity, InsightSeverity.good);
      expect(i.title.toLowerCase(), contains('up'));
    });
    test('drop when higher-is-better → info, down label', () {
      final i = InsightEngine.trend(
        feature: InsightFeature.water,
        id: 'water_trend',
        label: 'water',
        thisWeek: 10000,
        lastWeek: 14000,
        higherIsBetter: true,
      );
      expect(i!.severity, InsightSeverity.info);
      expect(i.title.toLowerCase(), contains('down'));
    });
    test('tiny change (<8%) or empty baseline → null', () {
      expect(
          InsightEngine.trend(
              feature: InsightFeature.steps,
              id: 'x',
              label: 'steps',
              thisWeek: 10300,
              lastWeek: 10000,
              higherIsBetter: true),
          isNull);
      expect(
          InsightEngine.trend(
              feature: InsightFeature.steps,
              id: 'x',
              label: 'steps',
              thisWeek: 5000,
              lastWeek: 0,
              higherIsBetter: true),
          isNull);
    });
  });

  group('InsightEngine.sleepVsAverage', () {
    test('notably less than usual → info', () {
      final i = InsightEngine.sleepVsAverage(
          lastNightMinutes: 300, avgMinutes: 420, nightsLogged: 5);
      expect(i, isNotNull);
      expect(i!.id, 'sleep_vs_avg');
      expect(i.title.toLowerCase(), contains('less'));
    });
    test('too few logged nights → null', () {
      expect(
          InsightEngine.sleepVsAverage(
              lastNightMinutes: 300, avgMinutes: 420, nightsLogged: 2),
          isNull);
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

  group('Predictive miss-risk (P1-B)', () {
    test('a consistently-missed slot yields high risk → med_missrisk fires', () {
      final base = DateTime(2026, 1, 5, 20, 0); // a fixed weekday, 20:00 slot
      final history = <DoseEvent>[];
      // 6 weeks: the 20:00 slot is always missed.
      for (var w = 0; w < 6; w++) {
        history.add(
            DoseEvent(base.add(Duration(days: 7 * w)), DoseOutcome.missed));
      }
      // 10 morning doses always taken (keeps overall adherence decent).
      for (var d = 0; d < 10; d++) {
        history.add(DoseEvent(DateTime(2026, 1, 5 + d, 8, 0), DoseOutcome.taken));
      }
      final risk = AdherenceAnalyzer.missRisk(
          weekday: base.weekday, hour: 20, history: history);
      expect(risk, greaterThanOrEqualTo(0.5), reason: 'bad slot reads risky');

      // With decent adherence + no refill issue, the engine surfaces the
      // predictive "missed at this time" nudge.
      final i = InsightEngine.medicine(adherence: 0.85, missRisk: risk);
      expect(i?.id, 'med_missrisk');
    });

    test('a reliably-taken slot is low risk (no false nudge)', () {
      final history = [
        for (var d = 0; d < 12; d++)
          DoseEvent(DateTime(2026, 1, 1 + d, 9, 0), DoseOutcome.taken),
      ];
      final risk = AdherenceAnalyzer.missRisk(
          weekday: DateTime(2026, 1, 1, 9, 0).weekday,
          hour: 9,
          history: history);
      expect(risk, lessThan(0.3));
    });
  });
}
