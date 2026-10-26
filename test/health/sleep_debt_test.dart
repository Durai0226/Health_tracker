import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/sleep_debt.dart';

void main() {
  const target = 480;

  List<LoggedNight> nights(Map<int, int> ageToAsleep) => [
        for (final e in ageToAsleep.entries)
          (ageDays: e.key, asleepMinutes: e.value),
      ];

  SleepDebtResult debt(Map<int, int> m) =>
      SleepDebt.compute(nights: nights(m), targetMinutes: target);

  group('honesty', () {
    test('no logged nights is no debt, not a made-up one', () {
      expect(debt({}).debtMinutes, 0);
      expect(debt({}).nights, 0);
    });

    test('an unlogged night (0 minutes) is ignored, not counted as no sleep', () {
      final r = debt({0: 0, 1: 0, 2: 0, 3: 480});
      expect(r.nights, 1);
      expect(r.debtMinutes, 0);
    });

    test('nights outside the 14-night window are ignored', () {
      final r = debt({14: 300, 20: 300, 0: 480});
      expect(r.nights, 1);
      expect(r.debtMinutes, 0);
    });

    test('a bad target does not divide by zero or invent debt', () {
      expect(
          SleepDebt.compute(nights: nights({0: 300}), targetMinutes: 0)
              .debtMinutes,
          0);
    });
  });

  group('weighting', () {
    test('equal weights collapse to the plain total over equal nights', () {
      // One night only: weight cancels. 480-300 = 180.
      expect(debt({0: 300}).debtMinutes, 180);
    });

    test('recent short nights weigh more than old ones', () {
      final recentBad = debt({0: 300, 1: 300, 2: 300, 12: 480, 13: 480});
      final oldBad = debt({0: 480, 1: 480, 2: 480, 12: 300, 13: 300});
      expect(recentBad.nights, oldBad.nights);
      expect(recentBad.debtMinutes, greaterThan(oldBad.debtMinutes));
    });

    test('a night a week ago counts about half, two weeks ago about a quarter', () {
      // Two nights: a 180-short night at age 0 against a 0-short at age N.
      // Mean weighted = 180*1/(1+w); scaled by 2.
      final half = debt({0: 300, 7: 480}); // w(7) = 0.5
      expect(half.debtMinutes, closeTo(180 * 1 / 1.5 * 2, 1));
      final quarter = debt({0: 300, 14 - 1: 480}); // w(13) ~ 0.2757
      expect(quarter.debtMinutes, closeTo(180 / (1 + 0.2757) * 2, 2));
    });
  });

  group('one lie-in cannot erase a week', () {
    test('a surplus pays back at most an hour, however long the lie-in', () {
      final week = {for (var i = 1; i <= 6; i++) i: 360}; // 6 nights, 2h short
      final cappedExactly = debt({...week, 0: 540}); // target + 60
      expect(debt({...week, 0: 600}).debtMinutes, cappedExactly.debtMinutes);
      expect(debt({...week, 0: 780}).debtMinutes, cappedExactly.debtMinutes,
          reason: 'a 13-hour night pays back no more than a 9-hour one');
      // ...but a surplus UNDER the cap still counts in full.
      expect(debt({...week, 0: 500}).debtMinutes,
          greaterThan(cappedExactly.debtMinutes));
    });

    test('so one lie-in cannot clear six short nights', () {
      final week = {for (var i = 1; i <= 6; i++) i: 360};
      expect(debt({...week, 0: 780}).debtMinutes, greaterThan(300));
    });

    test('with only surplus nights the debt is zero, never negative', () {
      final r = debt({0: 700, 1: 700, 2: 700, 3: 700});
      expect(r.debtMinutes, 0);
      expect(r.catchUp, isNull);
      expect(r.nights, 4);
    });
  });

  group('the catch-up plan', () {
    test('a modest debt clears in a week at a handful of minutes a night', () {
      // 4 nights, 45 short each, all age 0..3 — debt around 180.
      final r = debt({0: 435, 1: 435, 2: 435, 3: 435});
      expect(r.catchUp, isNotNull);
      expect(r.catchUp!.days, 7);
      expect(r.catchUp!.minutesPerNight % 5, 0);
      expect(r.catchUp!.minutesPerNight * 7, greaterThanOrEqualTo(r.debtMinutes));
    });

    test('too big for a week is spread over two', () {
      // Seven nights 90 min short: ~630 min is 90 a night over a week, too
      // much, but 45 a night over two.
      final r = debt({for (var i = 0; i < 7; i++) i: 390});
      expect(r.debtMinutes, greaterThan(7 * 60));
      expect(r.catchUp!.days, 14);
      expect(r.catchUp!.minutesPerNight, lessThanOrEqualTo(60));
    });

    test('too big for two weeks gives no number rather than a silly one', () {
      final r = debt({for (var i = 0; i < 14; i++) i: 60});
      expect(r.catchUp, isNull);
      expect(r.behindLine, contains('spreading some extra rest'));
    });

    test('never asks for more than an hour extra a night', () {
      for (final asleep in [420, 400, 380, 360, 300, 240]) {
        final r = debt({for (var i = 0; i < 8; i++) i: asleep});
        final c = r.catchUp;
        if (c != null) expect(c.minutesPerNight, lessThanOrEqualTo(60));
      }
    });
  });

  group('the sentence', () {
    test('quotes the debt, the nights, and the plan', () {
      final r = debt({0: 435, 1: 435, 2: 435, 3: 435});
      expect(r.behindLine,
          matches(RegExp(r'^\dh( \d+m)? behind over 4 nights — about \d+ extra minutes a night for a week clears it\.$')));
    });

    test('says "1 night", not "1 nights"', () {
      expect(debt({0: 240}).behindLine, contains('over 1 night '));
    });

    test('uses no guilt words', () {
      final line = debt({for (var i = 0; i < 6; i++) i: 360}).behindLine.toLowerCase();
      for (final bad in ['debt', 'failed', 'should have', 'lazy', 'bad']) {
        expect(line, isNot(contains(bad)));
      }
    });
  });
}
