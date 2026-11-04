/// Finding what happened near a moment without looking at everything that did.
///
/// The import's "already kept?" question, asked once per reading against the whole
/// list, is the two lengths multiplied. This is what lets it look in five minute
/// buckets instead — and the one way that goes wrong is a bucket edge, so most of
/// these are about that.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/time_index.dart';

void main() {
  final base = DateTime(2026, 9, 30, 8, 3, 0);
  const twoMinutes = Duration(minutes: 2);

  TimeIndex<({DateTime at, int value})> indexOf(Iterable<(DateTime, int)> items) =>
      TimeIndex(items.map((e) => (at: e.$1, value: e.$2)), at: (e) => e.at);

  bool near(TimeIndex<({DateTime at, int value})> index, DateTime at,
          {int? value, Duration within = twoMinutes}) =>
      index.anyNear(at, within, (e) => value == null || e.value == value);

  test('nothing in it, nothing near', () {
    expect(near(indexOf(const []), base), isFalse);
  });

  group('how near is near', () {
    test('the same moment', () {
      expect(near(indexOf([(base, 1)]), base), isTrue);
    });

    test('a minute either side', () {
      final index = indexOf([(base, 1)]);

      expect(near(index, base.add(const Duration(minutes: 1))), isTrue);
      expect(near(index, base.subtract(const Duration(minutes: 1))), isTrue);
    });

    test('exactly the limit, either side: that is still near', () {
      final index = indexOf([(base, 1)]);

      expect(near(index, base.add(twoMinutes)), isTrue);
      expect(near(index, base.subtract(twoMinutes)), isTrue);
    });

    test('a millisecond past the limit: not', () {
      final index = indexOf([(base, 1)]);

      expect(near(index, base.add(twoMinutes + const Duration(milliseconds: 1))), isFalse);
      expect(near(index, base.subtract(twoMinutes + const Duration(milliseconds: 1))), isFalse);
    });

    test('far away: not', () {
      expect(near(indexOf([(base, 1)]), base.add(const Duration(days: 3))), isFalse);
    });
  });

  group('a minute boundary is not a gap', () {
    // 08:03:59.5 and 08:05:59.5 are in buckets two apart and exactly the limit apart;
    // 08:03:00.0 and 08:05:00.0 likewise. Anything that looks only in its own bucket,
    // or one either side, misses them.
    test('the two ends of a stretch that spans three buckets', () {
      final late = DateTime(2026, 9, 30, 8, 3, 59, 500);
      final index = indexOf([(late, 1)]);

      expect(near(index, late.add(twoMinutes)), isTrue);
      expect(near(index, late.subtract(twoMinutes)), isTrue);
    });

    test('just either side of a boundary', () {
      final before = DateTime(2026, 9, 30, 8, 4, 59, 999);
      final after = DateTime(2026, 9, 30, 8, 5, 0, 1);
      final index = indexOf([(before, 1)]);

      expect(near(index, after), isTrue);
    });

    test('across the hour and the day', () {
      final midnight = DateTime(2026, 10, 1, 0, 0, 0);
      final index = indexOf([(midnight.subtract(const Duration(seconds: 90)), 1)]);

      expect(near(index, midnight.add(const Duration(seconds: 30))), isTrue);
    });

    test('a limit that is not a whole number of minutes', () {
      const within = Duration(seconds: 90);
      // Late in its minute, so that 90 seconds on is two buckets away, not one.
      final late = DateTime(2026, 9, 30, 8, 3, 59, 500);
      final index = indexOf([(late, 1)]);

      expect(near(index, late.add(within), within: within), isTrue);
      expect(near(index, late.subtract(within), within: within), isTrue);
      expect(near(index, late.add(within + const Duration(milliseconds: 1)), within: within),
          isFalse);
    });

    test('a limit of nothing is the same moment only', () {
      const none = Duration.zero;
      final index = indexOf([(base, 1)]);

      expect(near(index, base, within: none), isTrue);
      expect(near(index, base.add(const Duration(milliseconds: 1)), within: none), isFalse);
    });

    test('before 1970 it finds what is near, and only that', () {
      final old = DateTime.utc(1969, 12, 31, 23, 59, 30);
      final index = indexOf([(old, 1)]);

      expect(near(index, DateTime.utc(1970, 1, 1, 0, 1, 20)), isTrue);
      expect(near(index, DateTime.utc(1970, 1, 1, 0, 2, 31)), isFalse);
    });
  });

  group('what is near must also be what was asked for', () {
    test('a near item that does not match is not a yes', () {
      final index = indexOf([(base, 1)]);

      expect(near(index, base, value: 2), isFalse);
      expect(near(index, base, value: 1), isTrue);
    });

    test('a far item that matches is not a yes', () {
      final index = indexOf([(base, 1)]);

      expect(near(index, base.add(const Duration(minutes: 30)), value: 1), isFalse);
    });

    test('one of several near items matching is enough', () {
      final index = indexOf([
        (base, 1),
        (base.add(const Duration(seconds: 20)), 2),
        (base.add(const Duration(seconds: 40)), 3),
      ]);

      expect(near(index, base, value: 3), isTrue);
      expect(near(index, base, value: 9), isFalse);
    });

    test('items inserted in any order are all found', () {
      final index = indexOf([
        (base.add(const Duration(hours: 5)), 5),
        (base, 1),
        (base.add(const Duration(hours: 2)), 2),
      ]);

      for (final entry in {0: 1, 2: 2, 5: 5}.entries) {
        expect(near(index, base.add(Duration(hours: entry.key)), value: entry.value), isTrue,
            reason: '${entry.key}h');
      }
    });
  });

  test('an item filed afterwards is found by the next question', () {
    final index = indexOf([(base, 1)]);
    expect(near(index, base.add(const Duration(hours: 3))), isFalse);

    index.add((at: base.add(const Duration(hours: 3)), value: 2));

    expect(near(index, base.add(const Duration(hours: 3, minutes: 1)), value: 2), isTrue);
    expect(near(index, base, value: 1), isTrue, reason: 'and what was there still is');
  });

  test('it looks at the few near a moment, not at all of them', () {
    // The point of the thing: a month of readings every five minutes, asked about
    // one moment, must not mean a month of comparisons.
    final month = [
      for (var i = 0; i < 30 * 288; i++) (at: base.add(Duration(minutes: 5 * i)), value: i),
    ];
    var timesRead = 0;
    final index = TimeIndex(month, at: (e) {
      timesRead++;
      return e.at;
    });
    expect(timesRead, month.length, reason: 'each is read once, to file it');
    timesRead = 0;

    final found = index.anyNear(base.add(const Duration(days: 12, minutes: 1)), twoMinutes,
        (e) => e.value == -1);

    expect(found, isFalse);
    expect(timesRead, lessThanOrEqualTo(2),
        reason: 'only what is filed under the five minutes around it is looked at');
    expect(timesRead, greaterThan(0));
  });

  test('and it agrees with the plain scan on every pair', () {
    // Every moment on a grid of ten-second steps against a few hundred items at
    // awkward offsets: the index and the O(n) scan must never disagree.
    final items = [
      for (var i = 0; i < 400; i++)
        (base.add(Duration(seconds: 37 * i + (i % 7) * 11, milliseconds: (i * 313) % 1000)), i),
    ];
    final index = indexOf(items);

    for (var s = -300; s < 400 * 40; s += 10) {
      final at = base.add(Duration(seconds: s, milliseconds: 137));
      final scan = items.any((e) => e.$1.difference(at).abs() <= twoMinutes);
      expect(near(index, at), scan, reason: 'at +${s}s');
    }
  });
}
