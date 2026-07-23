import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/insight.dart';
import 'package:tablet_remainder/core/ai/insight_engine.dart';

/// Unit tests for the new Steps / Sleep / Period deterministic insight builders.
/// Pure (no Flutter/Drift) so they run headlessly.
void main() {
  group('InsightEngine.steps', () {
    test('goal reached → good', () {
      final i = InsightEngine.steps(steps: 9000, goal: 8000);
      expect(i, isNotNull);
      expect(i!.feature, InsightFeature.steps);
      expect(i.severity, InsightSeverity.good);
    });
    test('streak → good', () {
      final i = InsightEngine.steps(steps: 100, goal: 8000, streakDays: 5);
      expect(i?.severity, InsightSeverity.good);
      expect(i?.id, 'steps_streak');
    });
    test('short of goal → info nudge', () {
      final i = InsightEngine.steps(steps: 6000, goal: 8000);
      expect(i?.severity, InsightSeverity.info);
      expect(i?.metric, contains('to go'));
    });
    test('no data → null', () {
      expect(InsightEngine.steps(steps: 0, goal: 8000), isNull);
    });
  });

  group('InsightEngine.sleep', () {
    test('well under target → attention', () {
      final i = InsightEngine.sleep(lastNightMinutes: 300, targetMinutes: 480);
      expect(i?.feature, InsightFeature.sleep);
      expect(i?.severity, InsightSeverity.attention);
      expect(i?.id, 'sleep_short');
    });
    test('behind on rest → info (with enough logged nights)', () {
      final i = InsightEngine.sleep(
          lastNightMinutes: 470,
          targetMinutes: 480,
          debtMinutes: 240,
          loggedNights: 5);
      expect(i?.id, 'sleep_balance_low');
      expect(i?.severity, InsightSeverity.info);
    });
    test('behind on rest is suppressed when the week is (near) empty', () {
      final i = InsightEngine.sleep(
          lastNightMinutes: 470,
          targetMinutes: 480,
          debtMinutes: 240,
          loggedNights: 1);
      expect(i, isNull);
    });
    test('met target → good', () {
      final i = InsightEngine.sleep(lastNightMinutes: 490, targetMinutes: 480);
      expect(i?.severity, InsightSeverity.good);
    });
  });

  group('InsightEngine.period', () {
    test('period soon → attention', () {
      final i = InsightEngine.period(daysUntilNextPeriod: 2);
      expect(i?.feature, InsightFeature.period);
      expect(i?.severity, InsightSeverity.attention);
      expect(i?.id, 'period_soon');
    });
    test('fertile window carries the not-for-contraception caveat', () {
      final i = InsightEngine.period(inFertileWindow: true);
      expect(i?.id, 'period_fertile');
      expect(i!.detail.toLowerCase(), contains('not reliable for contraception'));
    });
    test('late → info', () {
      final i = InsightEngine.period(isLate: true, lateDays: 3);
      expect(i?.id, 'period_late');
      expect(i?.metric, contains('late'));
    });
    test('pregnancy mode → suppressed', () {
      expect(
          InsightEngine.period(daysUntilNextPeriod: 1, pregnancyMode: true), isNull);
    });
  });
}
