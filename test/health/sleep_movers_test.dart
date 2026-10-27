/// "On nights after caffeine after 2 pm you slept 38 min less (9 vs 21 nights)."
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/health/sleep_movers.dart';

void main() {
  var day = 0;
  NightFactors night(int minutes,
          {bool? caffeine, bool? alcohol, bool? active}) =>
      NightFactors(
        night: DateTime(2026, 3, 1 + day++),
        asleepMinutes: minutes,
        lateCaffeine: caffeine,
        eveningAlcohol: alcohol,
        activeDay: active,
      );

  /// [n] nights of [minutes] each.
  List<NightFactors> nights(int n, int minutes,
          {bool? caffeine, bool? alcohol, bool? active}) =>
      [
        for (var i = 0; i < n; i++)
          night(minutes, caffeine: caffeine, alcohol: alcohol, active: active)
      ];

  Insight? only(List<NightFactors> ns, String id) {
    for (final i in SleepMoverInsights.insights(ns)) {
      if (i.id == id) return i;
    }
    return null;
  }

  group('caffeine after 2 pm', () {
    final ns = [
      ...nights(9, 400, caffeine: true), // 6h 40m
      ...nights(21, 438, caffeine: false), // 7h 18m
    ];

    test('is named, with the gap and both samples', () {
      final i = only(ns, 'sleep_mover_late_caffeine')!;
      expect(i.title, 'On nights after caffeine after 2 pm you slept 38 min less');
      expect(i.detail, contains('6h 40m'));
      expect(i.detail, contains('9 nights'));
      expect(i.detail, contains('7h 18m'));
      expect(i.detail, contains('other 21'));
      expect(i.metric, '-38 min');
      expect(i.severity, InsightSeverity.info);
      expect(i.feature, InsightFeature.sleep);
    });

    test('carries its sample, as every cross-day pattern does', () {
      final e = only(ns, 'sleep_mover_late_caffeine')!.evidence!;
      expect([e.groupA, e.groupB], [9, 21]);
      expect(e.line, 'Based on 9 vs 21 nights · Moderate',
          reason: 'nine nights is over the eight a moderate pattern needs, and '
              '38 minutes is nearly twice the floor');
    });

    test('says it is not a cause', () {
      expect(only(ns, 'sleep_mover_late_caffeine')!.detail,
          contains('not a sign that one causes the other'));
    });
  });

  group('the gap and the groups', () {
    test('under 20 minutes is not worth a word; 20 is', () {
      expect(
          only([...nights(6, 420, caffeine: true), ...nights(6, 439, caffeine: false)],
              'sleep_mover_late_caffeine'),
          isNull);
      expect(
          only([...nights(6, 420, caffeine: true), ...nights(6, 440, caffeine: false)],
              'sleep_mover_late_caffeine'),
          isNotNull);
    });

    test('each side needs five nights', () {
      expect(
          only([...nights(4, 360, caffeine: true), ...nights(20, 450, caffeine: false)],
              'sleep_mover_late_caffeine'),
          isNull);
      expect(
          only([...nights(5, 360, caffeine: true), ...nights(4, 450, caffeine: false)],
              'sleep_mover_late_caffeine'),
          isNull);
      expect(
          only([...nights(5, 360, caffeine: true), ...nights(5, 450, caffeine: false)],
              'sleep_mover_late_caffeine'),
          isNotNull);
    });

    test('a night where the factor is unknown is in neither group', () {
      // Eight known "no" nights and five known "yes"; a dozen with no drinks
      // logged at all say nothing about caffeine.
      final ns = [
        ...nights(5, 360, caffeine: true),
        ...nights(8, 450, caffeine: false),
        ...nights(12, 600, caffeine: null),
      ];
      final i = only(ns, 'sleep_mover_late_caffeine')!;
      expect(i.detail, contains('other 8'));
      expect(i.detail, contains('7h 30m'));
    });

    test('more sleep after a factor is a win, not a warning', () {
      final i = only([
        ...nights(6, 480, active: true),
        ...nights(6, 420, active: false),
      ], 'sleep_mover_active_day')!;
      expect(i.title, 'On nights after an active day (step goal met) you slept 1 h more');
      expect(i.severity, InsightSeverity.good);
      expect(i.metric, '+1 h');
    });

    test('an hour and a bit reads as hours and minutes', () {
      final i = only([
        ...nights(6, 360, alcohol: true),
        ...nights(6, 435, alcohol: false),
      ], 'sleep_mover_evening_alcohol')!;
      expect(i.title, contains('1 h 15 min less'));
    });
  });

  group('several factors at once', () {
    /// Sixteen nights in an orthogonal design: each factor is on for exactly
    /// eight and off for eight, independently of the other two, so each one's gap
    /// is exactly its own effect: caffeine 30, alcohol 60, an active day 80.
    List<NightFactors> design() => [
          for (var i = 0; i < 16; i++)
            NightFactors(
              night: DateTime(2026, 5, 1 + i),
              asleepMinutes: 480 -
                  (i & 1 == 1 ? 30 : 0) -
                  (i & 2 == 2 ? 60 : 0) +
                  (i & 4 == 4 ? 0 : -80),
              lateCaffeine: i & 1 == 1,
              eveningAlcohol: i & 2 == 2,
              activeDay: i & 4 == 4,
            ),
        ];

    test('the largest gap first, and no more than two', () {
      final found = SleepMoverInsights.insights(design());
      expect(found.map((i) => i.id),
          ['sleep_mover_active_day', 'sleep_mover_evening_alcohol'],
          reason: 'gaps of 80 and 60; the third, at 30, is left out');
    });

    test('nothing to say when nothing stands out', () {
      expect(SleepMoverInsights.insights(nights(20, 420, caffeine: false)), isEmpty);
      expect(SleepMoverInsights.insights(const []), isEmpty);
    });
  });
}
