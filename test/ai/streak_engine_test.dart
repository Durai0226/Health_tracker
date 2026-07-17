import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/streak_engine.dart';

void main() {
  final today = DateTime(2026, 3, 15);
  Set<DateTime> days(List<int> offsets) =>
      offsets.map((o) => today.subtract(Duration(days: o))).toSet();

  test('unbroken streak counts every consecutive day incl. today', () {
    final r = StreakEngine.compute(completedDays: days([0, 1, 2, 3]), today: today);
    expect(r.current, 4);
    expect(r.usedGrace, isFalse);
    expect(r.atRisk, isFalse);
  });

  test('one missed day is forgiven (grace) and the streak survives', () {
    // done today, yesterday missed, then 3 more before → grace keeps it going.
    final r = StreakEngine.compute(completedDays: days([0, 2, 3, 4]), today: today);
    expect(r.current, greaterThanOrEqualTo(4));
    expect(r.usedGrace, isTrue);
  });

  test('two misses in a week (grace=1) breaks the streak', () {
    // today ok, then miss, miss → second miss breaks it.
    final r = StreakEngine.compute(completedDays: days([0, 3, 4]), today: today);
    expect(r.current, 1);
  });

  test('today not yet done but yesterday done → at risk, streak intact', () {
    final r = StreakEngine.compute(completedDays: days([1, 2, 3]), today: today);
    expect(r.current, 3);
    expect(r.atRisk, isTrue);
  });

  test('no history → zero streak, not at risk', () {
    final r = StreakEngine.compute(completedDays: const {}, today: today);
    expect(r.current, 0);
    expect(r.atRisk, isFalse);
    expect(r.longest, 0);
  });

  test('longest streak is tracked across history', () {
    final r = StreakEngine.compute(
      completedDays: days([0, 1, 10, 11, 12, 13, 14]),
      today: today,
    );
    expect(r.longest, greaterThanOrEqualTo(5));
  });
}
