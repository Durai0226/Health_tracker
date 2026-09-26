import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/correlation_engine.dart';

/// `CorrelationEngine` took no water input at all, so hydration was never
/// correlated with sleep, steps, mood or adherence — even though all of it sits
/// in one Drift database. These are the two correlations with real literature
/// behind them.
void main() {
  DateTime d(int n) => DateTime(2026, 8, n);

  group('hydrationVsSleep', () {
    List<GroupedDay> days({
      required double longMean,
      required double shortMean,
      int n = 6,
    }) =>
        [
          for (var i = 0; i < n; i++)
            GroupedDay(day: d(i + 1), inGroup: true, value: longMean),
          for (var i = 0; i < n; i++)
            GroupedDay(day: d(i + 10), inGroup: false, value: shortMean),
        ];

    test('surfaces less fluid on shorter nights', () {
      final insight = CorrelationEngine.hydrationVsSleep(
          days(longMean: 2400, shortMean: 1800));
      expect(insight, isNotNull);
      expect(insight!.title.toLowerCase(), contains('shorter nights'));
      expect(insight.metric, '600ml');
      // The literature is short-sleep -> dehydration, not the reverse, and the
      // copy must not promise that drinking fixes sleep.
      expect(insight.why, contains('Rosinger'));
      expect(insight.detail.toLowerCase(), isNot(contains('improve your sleep')));
    });

    test('stays silent on a difference under one glass', () {
      expect(
          CorrelationEngine.hydrationVsSleep(
              days(longMean: 2300, shortMean: 2200)),
          isNull,
          reason: '100ml is noise dressed as advice');
    });

    test('stays silent on the reverse direction', () {
      // "You drink MORE after a short night" is a noise finding; surfacing it
      // would be inventing a pattern to have something to say.
      expect(
          CorrelationEngine.hydrationVsSleep(
              days(longMean: 1700, shortMean: 2500)),
          isNull);
    });

    test('stays silent without enough days', () {
      expect(
          CorrelationEngine.hydrationVsSleep(
              days(longMean: 2400, shortMean: 1700, n: 1)),
          isNull);
    });
  });

  group('hydrationVsAdherence', () {
    List<DayMetric> days({
      required double adherentMean,
      required double missedMean,
      int n = 6,
    }) =>
        [
          for (var i = 0; i < n; i++)
            DayMetric(day: d(i + 1), adherent: true, value: adherentMean),
          for (var i = 0; i < n; i++)
            DayMetric(day: d(i + 10), adherent: false, value: missedMean),
        ];

    test('surfaces the shared-routine pattern', () {
      // Guards a real sign trap: AdherenceCorrelation.delta is
      // `nonAdherentMean - adherentMean`, so for hydration — where more is
      // better — it is negative for exactly the pattern we want. Reusing it
      // directly means this insight can never fire.
      final insight = CorrelationEngine.hydrationVsAdherence(
          days(adherentMean: 2500, missedMean: 1900));
      expect(insight, isNotNull, reason: 'the delta sign trap must be handled');
      expect(insight!.metric, '600ml');
      expect(insight.detail.toLowerCase(), contains('neither causes the other'),
          reason: 'no causal claim may be made here');
    });

    test('stays silent when adherent days are drier', () {
      expect(
          CorrelationEngine.hydrationVsAdherence(
              days(adherentMean: 1800, missedMean: 2600)),
          isNull);
    });

    test('stays silent on a trivial difference', () {
      expect(
          CorrelationEngine.hydrationVsAdherence(
              days(adherentMean: 2250, missedMean: 2200)),
          isNull);
    });
  });
}
