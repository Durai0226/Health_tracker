import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/sleep_score.dart';

void main() {
  group('score', () {
    int score(int asleep, {int target = 480, double eff = 0.9, double reg = 0.8}) =>
        SleepScore.score(
            asleepMinutes: asleep,
            targetMinutes: target,
            efficiency: eff,
            regularity: reg);

    test('is 60 for duration, 25 for efficiency, 15 for regularity', () {
      expect(score(480, eff: 1, reg: 1), 100);
      expect(score(480, eff: 0, reg: 0), 60);
      expect(score(0, eff: 1, reg: 0), 25);
      expect(score(0, eff: 0, reg: 1), 15);
    });

    test('sleeping past the target earns no more than the target', () {
      expect(score(700), score(480));
    });

    test('a missing target falls back to eight hours', () {
      expect(score(240, target: 0), score(240, target: 480));
    });

    test('out-of-range fractions are clamped, never negative or over 100', () {
      expect(score(480, eff: 3, reg: 9), 100);
      expect(score(0, eff: -1, reg: -1), 0);
    });
  });

  group('parts', () {
    test('a typical night splits as the formula says', () {
      // 6 of 8 hours = 45, 84% efficient = 21, and the 9 that is left.
      final p = SleepScore.parts(
          total: 75, asleepMinutes: 360, targetMinutes: 480, efficiency: 0.84);
      expect((p.duration, p.efficiency, p.regularity), (45, 21, 9));
      expect(p.total, 75);
    });

    test('they always add up to the score on the ring, for any night', () {
      final r = math.Random(7);
      for (var i = 0; i < 2000; i++) {
        final total = r.nextInt(101);
        final p = SleepScore.parts(
          total: total,
          asleepMinutes: r.nextInt(700),
          targetMinutes: 300 + r.nextInt(300),
          efficiency: r.nextDouble(),
        );
        expect(p.total, total, reason: '$p vs $total');
        expect(p.duration, inInclusiveRange(0, 60), reason: '$p');
        expect(p.efficiency, inInclusiveRange(0, 25), reason: '$p');
        expect(p.regularity, inInclusiveRange(0, 15), reason: '$p');
      }
    });

    test('a perfect night is full marks on all three', () {
      final p = SleepScore.parts(
          total: 100, asleepMinutes: 480, targetMinutes: 480, efficiency: 1);
      expect((p.duration, p.efficiency, p.regularity), (60, 25, 15));
    });

    test('no sleep logged is all zeros', () {
      final p = SleepScore.parts(
          total: 0, asleepMinutes: 0, targetMinutes: 480, efficiency: 0);
      expect(p.total, 0);
    });

    test('regularity is only what remains, so a ragged bedtime shows up there',
        () {
      // Same night, two stored scores: the 14 points between them can only be
      // regularity.
      SleepScoreParts at(int total) => SleepScore.parts(
          total: total, asleepMinutes: 480, targetMinutes: 480, efficiency: 0.8);
      expect(at(95).regularity - at(81).regularity, 14);
      expect(at(81).duration, at(95).duration);
    });

    test('a stored score the two exact parts cannot explain still adds up', () {
      // The target changed since the night was scored.
      final p = SleepScore.parts(
          total: 40, asleepMinutes: 480, targetMinutes: 480, efficiency: 1);
      expect(p.total, 40);
      expect(p.regularity, 0);
    });
  });
}
