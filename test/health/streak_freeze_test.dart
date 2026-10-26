import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/streak_engine.dart';

/// Vacation mode freezes streaks: frozen days are neither completions nor
/// misses, spend no grace, and cannot put a streak at risk.
void main() {
  DateTime mar(int d) => DateTime(2026, 3, d);
  Set<DateTime> days(int from, int to) => {for (var d = from; d <= to; d++) mar(d)};

  StreakResult run({
    required Set<DateTime> done,
    Set<DateTime> frozen = const {},
    int today = 20,
    int grace = 1,
  }) =>
      StreakEngine.compute(
          completedDays: done,
          today: mar(today),
          graceDaysPerWeek: grace,
          frozenDays: frozen);

  test('with nothing frozen the result is exactly what it always was', () {
    final done = {...days(1, 10), ...days(14, 16)};
    final a = StreakEngine.compute(
        completedDays: done, today: mar(17), graceDaysPerWeek: 1);
    final b = run(done: done, today: 17);
    expect(b.current, a.current);
    expect(b.longest, a.longest);
    expect(b.atRisk, a.atRisk);
    expect(b.gracesRemaining, a.gracesRemaining);
  });

  test('a holiday that would have broken the streak does not', () {
    final done = days(1, 10); // ten days, then nothing for nine days
    expect(run(done: done).current, 0, reason: 'premise: it breaks unfrozen');
    final r = run(done: done, frozen: days(11, 19));
    expect(r.current, 10);
  });

  test('frozen days add nothing: the streak is the days actually done', () {
    // 1-10 done, 11-13 frozen, 14-16 done.
    final r = run(
        done: {...days(1, 10), ...days(14, 16)},
        frozen: days(11, 13),
        today: 17);
    expect(r.current, 13, reason: '10 + 3, the three frozen days count as none');
  });

  test('without the freeze the same gap costs the streak', () {
    final done = {...days(1, 10), ...days(14, 16)};
    expect(run(done: done, today: 17).current, lessThan(13));
  });

  test('a frozen day spends no grace day', () {
    final done = {...days(1, 10), ...days(14, 16)};
    final frozen = run(done: done, frozen: days(11, 13), today: 17);
    expect(frozen.usedGrace, isFalse);
    expect(frozen.gracesRemaining, 1);
  });

  test('a frozen day that was also completed still counts', () {
    final r = run(done: days(1, 12), frozen: days(10, 12), today: 13);
    expect(r.current, 12);
  });

  test('a frozen today is never "at risk"', () {
    final done = days(1, 10);
    expect(run(done: done, today: 11).atRisk, isTrue, reason: 'premise');
    expect(run(done: done, frozen: {mar(11)}, today: 11).atRisk, isFalse);
  });

  test('the longest streak ignores frozen days too', () {
    final done = {...days(1, 5), ...days(10, 14)};
    final unfrozen = run(done: done, today: 15);
    final frozen = run(done: done, frozen: days(6, 9), today: 15);
    expect(frozen.longest, greaterThan(unfrozen.longest));
    expect(frozen.longest, 10);
  });

  test('freezing only the future changes nothing', () {
    final done = days(1, 10);
    final a = run(done: done, today: 11);
    final b = run(done: done, frozen: days(25, 30), today: 11);
    expect(b.current, a.current);
  });
}
