import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/refill_predictor.dart';

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
}
