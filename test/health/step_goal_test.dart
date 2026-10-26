import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/step_goal.dart';

void main() {
  List<int> days(int n, int steps) => List.filled(n, steps);

  group('without enough history', () {
    test('under 3 recent days is the default goal', () {
      final r = AdaptiveStepGoal.compute(recent: [9000, 9000], sameWeekday: []);
      expect(r.goal, 8000);
      expect(r.usedWeekday, isFalse);
      expect(r.recentMedian, isNull);
    });
  });

  group('with no usable weekday data it is EXACTLY the old goal', () {
    // The old rule: 14-day median, +10%, clamped. A new user, or one with no
    // tracked weekends, must see no change at all.
    int oldGoal(List<int> recent) {
      final s = [...recent]..sort();
      final mid = s.length ~/ 2;
      final m = s.length.isOdd ? s[mid] : ((s[mid - 1] + s[mid]) / 2).round();
      return (m * 1.1).round().clamp(4000, 15000);
    }

    test('0, 1 and 2 same-weekday days all fall back', () {
      final recent = [6000, 7000, 8000, 9000, 10000, 7500, 8200];
      for (final n in [0, 1, 2]) {
        final r = AdaptiveStepGoal.compute(
            recent: recent, sameWeekday: days(n, 20000));
        expect(r.goal, oldGoal(recent), reason: '$n weekday days');
        expect(r.usedWeekday, isFalse);
      }
    });

    test('even-length median averages the middle pair, as before', () {
      final recent = [6000, 8000, 9000, 11000];
      expect(AdaptiveStepGoal.compute(recent: recent, sameWeekday: []).goal,
          oldGoal(recent));
    });
  });

  group('with a weekday pattern', () {
    test('a walking Saturday raises Saturday\'s goal', () {
      final recent = days(14, 7000); // 14-day median 7,000
      final r = AdaptiveStepGoal.compute(
          recent: recent, sameWeekday: [12000, 11000, 13000, 12000]);
      // weekday median 12,000; blend 9,500; +10% = 10,450
      expect(r.weekdayMedian, 12000);
      expect(r.goal, 10450);
      expect(r.goal, greaterThan(AdaptiveStepGoal.compute(
          recent: recent, sameWeekday: []).goal));
    });

    test('a quiet Sunday lowers Sunday\'s goal', () {
      final recent = days(14, 9000);
      final r = AdaptiveStepGoal.compute(
          recent: recent, sameWeekday: [3000, 3500, 4000]);
      // weekday median 3,500; blend 6,250; +10% = 6,875
      expect(r.goal, 6875);
      expect(r.goal, lessThan(9900));
    });

    test('three same-weekday days is the threshold, not two', () {
      final recent = days(14, 7000);
      expect(AdaptiveStepGoal.compute(recent: recent, sameWeekday: [12000, 12000]).usedWeekday,
          isFalse);
      expect(AdaptiveStepGoal.compute(recent: recent, sameWeekday: [12000, 12000, 12000]).usedWeekday,
          isTrue);
    });

    test('one outlier weekend cannot swing it (median, not mean)', () {
      final recent = days(14, 7000);
      final steady = AdaptiveStepGoal.compute(
          recent: recent, sameWeekday: [8000, 8000, 8000, 8000, 8000]);
      final withOutlier = AdaptiveStepGoal.compute(
          recent: recent, sameWeekday: [8000, 8000, 8000, 8000, 30000]);
      expect(withOutlier.goal, steady.goal);
    });
  });

  group('clamping', () {
    test('never below 4,000 or above 15,000', () {
      expect(AdaptiveStepGoal.compute(recent: days(14, 1000), sameWeekday: days(5, 500)).goal,
          4000);
      expect(AdaptiveStepGoal.compute(recent: days(14, 30000), sameWeekday: days(5, 40000)).goal,
          15000);
    });
  });

  group('result carries the reasoning', () {
    test('counts and medians are reported for the explanation', () {
      final r = AdaptiveStepGoal.compute(
          recent: days(10, 8000), sameWeekday: days(4, 9000));
      expect(r.recentCount, 10);
      expect(r.recentMedian, 8000);
      expect(r.weekdayCount, 4);
      expect(r.weekdayMedian, 9000);
    });
  });
}
