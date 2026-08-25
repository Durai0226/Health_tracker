import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/streak_engine.dart';

/// `StreakEngine` has always forgiven one missed day per rolling week — and
/// always hidden it. The user saw a number that simply didn't drop, never
/// learned a safety net existed, and so got none of the anxiety reduction the
/// forgiveness was added for.
///
/// Duolingo's data on streak freeze: +3.3% D14 retention, +10.5% more daily
/// learners holding a streak. Their load-bearing finding is that the freeze has
/// to be **visible and already held before the miss** — a user who has just
/// broken a streak is not in the app to discover it was actually saved.
void main() {
  DateTime d(int day) => DateTime(2026, 8, day);

  test('an unbroken run reports a full shield', () {
    final r = StreakEngine.compute(
      completedDays: {for (var i = 10; i <= 20; i++) d(i)},
      today: d(20),
      graceDaysPerWeek: 1,
    );
    expect(r.current, 11);
    expect(r.gracesRemaining, 1);
    expect(r.isProtected, isTrue);
    expect(r.usedGrace, isFalse);
  });

  test('a forgiven miss spends the shield but keeps the streak', () {
    // Missed the 17th; everything either side is met.
    final days = {for (var i = 10; i <= 20; i++) d(i)}..remove(d(17));
    final r = StreakEngine.compute(
      completedDays: days,
      today: d(20),
      graceDaysPerWeek: 1,
    );

    expect(r.current, greaterThan(0), reason: 'the miss must be absorbed');
    expect(r.usedGrace, isTrue);
    expect(r.gracesRemaining, 0);
    expect(r.isProtected, isFalse,
        reason: 'having spent it, the user should be told they are exposed');
  });

  test('gracesPerWeek reports the configured allowance', () {
    final r = StreakEngine.compute(
      completedDays: {d(19), d(20)},
      today: d(20),
      graceDaysPerWeek: 2,
    );
    expect(r.gracesPerWeek, 2);
    expect(r.gracesRemaining, lessThanOrEqualTo(2));
  });

  test('no forgiveness configured means no shield is ever claimed', () {
    final r = StreakEngine.compute(
      completedDays: {d(19), d(20)},
      today: d(20),
      graceDaysPerWeek: 0,
    );
    expect(r.gracesRemaining, 0);
    expect(r.isProtected, isFalse);
  });

  test('gracesRemaining never exceeds the weekly allowance', () {
    for (final allowance in [0, 1, 2, 3]) {
      final r = StreakEngine.compute(
        completedDays: {for (var i = 1; i <= 28; i++) d(i)},
        today: d(28),
        graceDaysPerWeek: allowance,
      );
      expect(r.gracesRemaining, lessThanOrEqualTo(allowance));
      expect(r.gracesRemaining, greaterThanOrEqualTo(0));
    }
  });

  test('an empty history is not protected and not at risk', () {
    final r = StreakEngine.compute(
      completedDays: const {},
      today: d(20),
      graceDaysPerWeek: 1,
    );
    expect(r.current, 0);
    expect(r.atRisk, isFalse, reason: 'there is no streak to be at risk of');
  });
}
