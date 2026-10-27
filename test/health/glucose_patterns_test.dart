/// "Your readings after breakfast often run high; lows tend to happen overnight."
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/glucose_patterns.dart';
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';

void main() {
  final now = DateTime(2026, 6, 30, 12);

  String mg(int v) => '$v mg/dL';

  /// [n] readings of [value] at [hour] on consecutive days back from the 29th.
  List<GlucoseSample> run(int n, int value, GlucoseContext ctx, int hour,
          {int fromDay = 29}) =>
      [
        for (var i = 0; i < n; i++)
          GlucoseSample(value, ctx, DateTime(2026, 6, fromDay - i, hour, 15)),
      ];

  List<GlucosePattern> check(List<GlucoseSample> r) =>
      GlucosePatternCheck.check(r, now: now, format: mg);

  group('highs', () {
    test('a context that runs high is named, with how often and how high', () {
      // Fasting: 6 readings of 130 (above the 100 fasting threshold)... and 3 of 90.
      final r = [
        ...run(6, 130, GlucoseContext.fasting, 7),
        ...run(3, 90, GlucoseContext.fasting, 7, fromDay: 20),
      ];
      final p = check(r).single;
      expect(p.id, 'glucose_pattern_fasting_high');
      expect(p.title, 'Fasting readings often run high');
      expect(p.detail, contains('6 of 9 fasting readings'));
      expect(p.detail, contains('130 mg/dL'));
      expect(p.isLow, isFalse);
      expect([p.flagged, p.count], [6, 9]);
    });

    test('four of nine is under half', () {
      expect(
          check([
            ...run(4, 130, GlucoseContext.fasting, 7),
            ...run(5, 90, GlucoseContext.fasting, 7, fromDay: 20),
          ]),
          isEmpty);
    });

    test('half is enough; under half is not', () {
      expect(
          check([
            ...run(4, 130, GlucoseContext.fasting, 7),
            ...run(4, 90, GlucoseContext.fasting, 7, fromDay: 20),
          ]),
          hasLength(1));
      expect(
          check([
            ...run(3, 130, GlucoseContext.fasting, 7),
            ...run(5, 90, GlucoseContext.fasting, 7, fromDay: 20),
          ]),
          isEmpty);
    });

    test('a meal is named by the time of day', () {
      final breakfast = check(run(6, 190, GlucoseContext.afterMeal, 9)).single;
      expect(breakfast.id, 'glucose_pattern_after_breakfast_high');
      expect(breakfast.title, 'After breakfast readings often run high');

      expect(check(run(6, 190, GlucoseContext.afterMeal, 13)).single.id,
          'glucose_pattern_after_lunch_high');
      expect(check(run(6, 190, GlucoseContext.afterMeal, 19)).single.id,
          'glucose_pattern_after_dinner_high');
      expect(check(run(6, 190, GlucoseContext.beforeMeal, 19)).single.id,
          'glucose_pattern_before_dinner_high',
          reason: 'before-meal readings above 130 are high');
    });

    test('bedtime has its own', () {
      expect(check(run(6, 190, GlucoseContext.bedtime, 22)).single.id,
          'glucose_pattern_bedtime_high');
    });

    test('very high counts as high', () {
      expect(check(run(6, 300, GlucoseContext.fasting, 7)).single.flagged, 6);
    });
  });

  group('lows', () {
    test('a context with repeated lows is named, with the lowest', () {
      final r = [
        ...run(2, 60, GlucoseContext.fasting, 7),
        ...run(5, 90, GlucoseContext.fasting, 7, fromDay: 20),
      ];
      final p = check(r).single;
      expect(p.id, 'glucose_pattern_fasting_low');
      expect(p.isLow, isTrue);
      expect(p.detail, contains('2 of 7 fasting readings'));
      expect(p.detail, contains('below 70 mg/dL'));
      expect(p.detail, contains('lowest 60 mg/dL'));
    });

    test('one low is not a pattern, whatever the share', () {
      // One of five is a fifth: the share is met, the count is not.
      expect(
          check([
            ...run(1, 60, GlucoseContext.fasting, 7),
            ...run(4, 90, GlucoseContext.fasting, 7, fromDay: 20),
          ]),
          isEmpty);
    });

    test('the lowest is the lowest of them', () {
      final p = check([
        GlucoseSample(60, GlucoseContext.fasting, DateTime(2026, 6, 28, 7)),
        GlucoseSample(50, GlucoseContext.fasting, DateTime(2026, 6, 27, 7)),
        ...run(4, 90, GlucoseContext.fasting, 7, fromDay: 20),
      ]).single;
      expect(p.detail, contains('lowest 50 mg/dL'));
    });

    test('a low share under a fifth is not either', () {
      expect(
          check([
            ...run(2, 60, GlucoseContext.fasting, 7),
            ...run(10, 90, GlucoseContext.fasting, 7, fromDay: 20),
          ]),
          isEmpty,
          reason: '2 of 12');
    });

    test('lows at night are named for the night, not a meal', () {
      final p = check([
        ...run(3, 55, GlucoseContext.random, 2),
        ...run(3, 100, GlucoseContext.random, 2, fromDay: 20),
      ]).single;
      expect(p.id, 'glucose_pattern_overnight_low');
      expect(p.title, 'Lows tend to happen overnight');
    });

    test('a night of highs is not "a pattern of the night"', () {
      expect(check(run(8, 300, GlucoseContext.random, 2)), isEmpty);
    });

    test('lows come first', () {
      final r = [
        ...run(6, 190, GlucoseContext.afterMeal, 9), // all high
        ...run(2, 60, GlucoseContext.fasting, 7),
        ...run(4, 90, GlucoseContext.fasting, 7, fromDay: 20),
      ];
      final ids = check(r).map((p) => p.id).toList();
      expect(ids.first, 'glucose_pattern_fasting_low');
      expect(ids, contains('glucose_pattern_after_breakfast_high'));
    });
  });

  group('what counts', () {
    test('fewer than five readings in a group say nothing', () {
      expect(check(run(4, 190, GlucoseContext.afterMeal, 9)), isEmpty);
      expect(check(run(5, 190, GlucoseContext.afterMeal, 9)), hasLength(1));
    });

    test('the meal boundaries: breakfast to 10:59, lunch to 15:59, dinner to '
        '22:59', () {
      String? id(int hour) {
        final p = check(run(6, 190, GlucoseContext.afterMeal, hour));
        return p.isEmpty ? null : p.single.id;
      }

      expect(id(4), isNull);
      expect(id(5), 'glucose_pattern_after_breakfast_high');
      expect(id(10), 'glucose_pattern_after_breakfast_high');
      expect(id(11), 'glucose_pattern_after_lunch_high');
      expect(id(15), 'glucose_pattern_after_lunch_high');
      expect(id(16), 'glucose_pattern_after_dinner_high');
      expect(id(22), 'glucose_pattern_after_dinner_high');
      expect(id(23), isNull);
    });

    test('overnight is 23:00 to 04:59', () {
      bool overnight(int hour) => check(run(6, 55, GlucoseContext.random, hour))
          .any((p) => p.id == 'glucose_pattern_overnight_low');

      expect(overnight(22), isFalse);
      expect(overnight(23), isTrue);
      expect(overnight(0), isTrue);
      expect(overnight(4), isTrue);
      expect(overnight(5), isFalse);
    });

    test('the average is of the readings that were high, not of the group', () {
      final p = check([
        ...run(5, 200, GlucoseContext.afterMeal, 9),
        ...run(5, 100, GlucoseContext.afterMeal, 9, fromDay: 20),
      ]).single;
      expect(p.detail, contains('5 of 10'));
      expect(p.detail, contains('averaged 200 mg/dL'));
    });

    test('random readings belong to no meal', () {
      expect(check(run(9, 190, GlucoseContext.random, 12)), isEmpty);
    });

    test('a reading in the small hours belongs to no meal', () {
      expect(check(run(9, 190, GlucoseContext.afterMeal, 2)), isEmpty);
    });

    test('only the last thirty days', () {
      // The 1st of June is day 30 of the window ending on the 30th; May is out.
      final r = [
        for (var i = 0; i < 6; i++)
          GlucoseSample(190, GlucoseContext.afterMeal, DateTime(2026, 5, 20 + i, 9)),
      ];
      expect(check(r), isEmpty);
      final inside = [
        for (var i = 0; i < 6; i++)
          GlucoseSample(190, GlucoseContext.afterMeal, DateTime(2026, 6, 1 + i, 9)),
      ];
      expect(check(inside), hasLength(1));
    });

    test('thirty days means the 1st of June is in and the 31st of May is out',
        () {
      List<GlucoseSample> on(int month, int day) => [
            for (var i = 0; i < 6; i++)
              GlucoseSample(
                  190, GlucoseContext.afterMeal, DateTime(2026, month, day, 9)),
          ];
      expect(check(on(6, 1)), hasLength(1));
      expect(check(on(5, 31)), isEmpty);
    });

    test('nothing from the future', () {
      final r = run(6, 190, GlucoseContext.afterMeal, 9, fromDay: 29)
          .map((s) => GlucoseSample(
              s.mgdl, s.context, s.at.add(const Duration(days: 5))))
          .toList();
      expect(check(r), isEmpty);
    });

    test('the unit is the person\'s', () {
      final p = GlucosePatternCheck.check(
        run(6, 270, GlucoseContext.fasting, 7),
        now: now,
        format: (v) => '${(v / 18).toStringAsFixed(1)} mmol/L',
      ).single;
      expect(p.detail, contains('15.0 mmol/L'));
    });

    test('no more than three, the larger share first', () {
      final r = [
        ...run(10, 190, GlucoseContext.afterMeal, 9),
        ...run(10, 190, GlucoseContext.afterMeal, 13),
        ...run(10, 190, GlucoseContext.afterMeal, 19),
        ...run(10, 190, GlucoseContext.bedtime, 22),
        ...run(5, 90, GlucoseContext.bedtime, 22, fromDay: 12),
      ];
      expect(check(r), hasLength(3));
    });

    test('words that never diagnose or advise a dose', () {
      final r = [
        ...run(6, 190, GlucoseContext.afterMeal, 9),
        ...run(2, 60, GlucoseContext.fasting, 7),
        ...run(4, 90, GlucoseContext.fasting, 7, fromDay: 20),
      ];
      for (final p in check(r)) {
        final text = '${p.title} ${p.detail}'.toLowerCase();
        for (final word in ['diabetes', 'insulin', 'dose', 'medication', 'adjust']) {
          expect(text, isNot(contains(word)));
        }
        expect(text, contains('worth mentioning to your doctor'));
      }
    });
  });
}
