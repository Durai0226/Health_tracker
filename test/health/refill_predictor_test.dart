import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/refill_predictor.dart';

void main() {
  // Fixed "now" so the math is deterministic.
  final now = DateTime(2026, 3, 1, 9, 0);

  List<DateTime> dosesPerDay(int days, {int perDay = 1}) {
    final out = <DateTime>[];
    for (var d = days; d >= 1; d--) {
      for (var k = 0; k < perDay; k++) {
        out.add(now.subtract(Duration(days: d, hours: k)));
      }
    }
    return out;
  }

  test('projects a run-out date from ~1 dose/day', () {
    final p = RefillPredictor.predict(
      currentStock: 30,
      doseTimes: dosesPerDay(10),
      now: now,
    );
    expect(p.avgDailyRate, closeTo(1.0, 0.2));
    expect(p.daysRemaining, inInclusiveRange(24, 36));
    expect(p.depletionDate, isNotNull);
    expect(p.refillByDate, isNotNull);
    expect(p.refillByDate!.isBefore(p.depletionDate!), isTrue);
  });

  test('flags over-consumption vs the prescribed rate', () {
    final p = RefillPredictor.predict(
      currentStock: 20,
      doseTimes: dosesPerDay(10, perDay: 2), // ~2/day
      expectedDailyRate: 1, // prescribed once daily
      now: now,
    );
    expect(p.avgDailyRate, greaterThan(1.5));
    expect(p.overConsuming, isTrue);
  });

  test('no history → no projection, honest summary', () {
    final p = RefillPredictor.predict(
      currentStock: 30,
      doseTimes: const [],
      now: now,
    );
    expect(p.daysRemaining, isNull);
    expect(p.depletionDate, isNull);
    expect(p.summary.toLowerCase(), contains('history'));
  });

  test('low-stock flag respects the threshold', () {
    final p = RefillPredictor.predict(
      currentStock: 3,
      doseTimes: dosesPerDay(7),
      lowStockThreshold: 5,
      now: now,
    );
    expect(p.isLow, isTrue);
  });

  test('out of stock → refill-needed summary', () {
    final p = RefillPredictor.predict(
      currentStock: 0,
      doseTimes: dosesPerDay(7),
      now: now,
    );
    expect(p.daysRemaining, isNull);
    expect(p.summary.toLowerCase(), contains('out of stock'));
  });

  /// The result must not depend on how the caller sorted its doses.
  ///
  /// `earliestInWindow` was assigned with `??=`, i.e. element ZERO — and the
  /// production caller feeds `getLogsForMedicine`, which orders
  /// `desc(scheduledTime)`. Element zero is therefore the NEWEST dose, so the
  /// observed span measured now back to the most recent dose — a few hours —
  /// which the `clamp(1.0, …)` rounded up to one day. The average daily rate
  /// became the whole window's total.
  ///
  /// Every existing test above fed doses oldest-first, where `??=` happens to
  /// pick the right one, so none of them could see it.
  group('dose order does not change the answer', () {
    test('newest-first gives the same rate as oldest-first', () {
      final ascending = dosesPerDay(10);
      final descending = ascending.reversed.toList();

      final a = RefillPredictor.predict(
          currentStock: 30, doseTimes: ascending, now: now);
      final d = RefillPredictor.predict(
          currentStock: 30, doseTimes: descending, now: now);

      expect(d.avgDailyRate, closeTo(a.avgDailyRate, 0.001),
          reason: 'the same ten doses, listed the other way round, reported '
              '${d.avgDailyRate}/day instead of ${a.avgDailyRate}/day');
      expect(d.daysRemaining, a.daysRemaining);
    });

    /// The case seen on the device.
    ///
    /// A once-daily Metformin with 16 taken doses across 21 days and 39 pills
    /// left reported "~16.3/day · runs out in 2 days" — against roughly seven
    /// weeks of real supply — and that figure drives the "Refill soon …
    /// reorder now to avoid a gap" card and the refill reminders.
    test('a once-daily medicine is not reported as a 16-a-day habit', () {
      final doses = <DateTime>[
        for (var d = 20; d >= 5; d--) now.subtract(Duration(days: d)),
      ];
      expect(doses, hasLength(16));

      final p = RefillPredictor.predict(
        currentStock: 39,
        doseTimes: doses.reversed.toList(), // newest-first, as the DAO returns
        windowDays: 21,
        now: now,
      );

      expect(p.avgDailyRate, lessThan(1.5),
          reason: 'sixteen doses over sixteen days is about one a day, not '
              '${p.avgDailyRate}');
      expect(p.daysRemaining, greaterThan(20),
          reason: '39 pills at ~1/day is over a month. It said '
              '${p.daysRemaining} days, which is what makes the app shout '
              '"reorder now".');
      expect(p.summary, isNot(contains('runs out in 2 days')));
    });

    test('a genuinely fast rate is still reported', () {
      // Four a day for the last four days, newest-first. The guard must not
      // have flattened real over-consumption.
      final doses = <DateTime>[
        for (var d = 1; d <= 4; d++)
          for (var k = 0; k < 4; k++) now.subtract(Duration(days: d, hours: k)),
      ];
      final p = RefillPredictor.predict(
        currentStock: 20,
        doseTimes: doses,
        now: now,
      );
      expect(p.avgDailyRate, closeTo(4.0, 0.6),
          reason: 'sixteen doses across four days really is four a day');
    });
  });
}
