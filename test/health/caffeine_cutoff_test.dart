import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/caffeine_cutoff.dart';

void main() {
  DateTime at(int h, [int m = 0, int d = 14]) => DateTime(2026, 3, d, h, m);
  const tenThirty = 22 * 60 + 30;

  CaffeineWarning? check(DateTime now,
          {int bed = tenThirty, int mg = 95}) =>
      CaffeineCutoff.check(now: now, bedtimeMinutes: bed, caffeineMg: mg);

  group('the cut-off is eight hours before bed', () {
    test('22:30 gives 14:30', () {
      expect(CaffeineCutoff.cutoffFor(at(22, 30)), at(14, 30));
    });

    test('a bedtime after midnight gives an afternoon cut-off the same day', () {
      expect(CaffeineCutoff.cutoffFor(at(0, 30, 15)), at(16, 30));
    });
  });

  group('a drink logged at 22:30 bedtime', () {
    test('before the cut-off says nothing', () {
      expect(check(at(14, 29)), isNull);
      expect(check(at(9)), isNull);
    });

    test('from the cut-off on, warns, and names both times', () {
      final w = check(at(14, 30))!;
      expect(w.cutoff, at(14, 30));
      expect(w.bedtime, at(22, 30));
      expect(check(at(18)), isNotNull);
      expect(check(at(22, 29)), isNotNull);
    });

    test('a little past bedtime still counts: they are up, not asleep', () {
      expect(check(at(23, 30)), isNotNull);
      expect(check(at(0, 29, 15)), isNotNull,
          reason: 'the window runs two hours past 22:30, into the small hours');
    });

    test('later than that it is no longer about tonight', () {
      expect(check(at(0, 30, 15)), isNull);
      expect(check(at(2, 0, 15)), isNull);
      expect(check(at(6, 0, 15)), isNull);
    });
  });

  group('a bedtime after midnight', () {
    test('00:30 means tonight, from the afternoon', () {
      final w = check(at(19), bed: 30)!;
      expect(w.bedtime, at(0, 30, 15));
      expect(w.cutoff, at(16, 30));
      expect(check(at(16, 29), bed: 30), isNull);
    });

    test('and 02:00, ten minutes either side of it, is still inside', () {
      expect(check(at(1, 50, 15), bed: 30), isNotNull);
    });
  });

  group('how much caffeine is worth a word', () {
    test('decaf and a trace are not', () {
      expect(check(at(16), mg: 0), isNull);
      expect(check(at(16), mg: 19), isNull);
    });

    test('a weak tea and up are', () {
      expect(check(at(16), mg: 20), isNotNull);
      expect(check(at(16), mg: 200), isNotNull);
    });
  });

  test('a month end does not break the day shift', () {
    final now = DateTime(2026, 1, 31, 20);
    final w = CaffeineCutoff.check(
        now: now, bedtimeMinutes: 30, caffeineMg: 90)!;
    expect(w.bedtime, DateTime(2026, 2, 1, 0, 30));
  });
}
