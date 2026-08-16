import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/health_windows.dart';

/// The date-key and window rules Steps, Sleep and Biometrics all share.
///
/// These were private copies inside SleepService and StepService. A third copy
/// in BiometricsService would have let "last night" mean two different things
/// in two features — unfixable once the data is written — so they live here
/// instead and are pinned here.
void main() {
  group('date keys', () {
    test('always zero-padded, so string sort equals date sort', () {
      expect(dateKeyOf(DateTime(2026, 1, 5)), '2026-01-05');
      expect(dateKeyOf(DateTime(2026, 12, 31)), '2026-12-31');
      final keys = [
        dateKeyOf(DateTime(2026, 2, 9)),
        dateKeyOf(DateTime(2026, 2, 10)),
        dateKeyOf(DateTime(2026, 10, 1)),
      ];
      expect(keys.toList()..sort(), keys);
    });

    test('round-trips through parseDateKey', () {
      final d = DateTime(2026, 7, 4);
      expect(parseDateKey(dateKeyOf(d)), d);
    });

    test('a malformed key throws rather than guessing', () {
      // These are primary keys the app writes itself, so a bad one is a bug.
      expect(() => parseDateKey('nonsense'), throwsFormatException);
      expect(() => parseDateKey('2026-01'), throwsFormatException);
    });
  });

  group('the 18:00 night rule', () {
    test('before 18:00 belongs to the same morning', () {
      expect(nightDateKeyFor(DateTime(2026, 3, 10, 2)), '2026-03-10');
      expect(nightDateKeyFor(DateTime(2026, 3, 10, 17, 59)), '2026-03-10');
    });

    test('18:00 and later belongs to the NEXT morning', () {
      expect(nightDateKeyFor(DateTime(2026, 3, 10, 18)), '2026-03-11');
      expect(nightDateKeyFor(DateTime(2026, 3, 10, 23, 30)), '2026-03-11');
    });

    test('it rolls over month and year boundaries', () {
      expect(nightDateKeyFor(DateTime(2026, 1, 31, 20)), '2026-02-01');
      expect(nightDateKeyFor(DateTime(2026, 12, 31, 20)), '2027-01-01');
    });
  });

  group('windows', () {
    test('the day window is midnight to midnight', () {
      final w = dayWindowFor('2026-03-10');
      expect(w.start, DateTime(2026, 3, 10));
      expect(w.end, DateTime(2026, 3, 11));
    });

    test('the night window is the previous evening to this evening', () {
      final w = nightWindowFor('2026-03-10');
      expect(w.start, DateTime(2026, 3, 9, 18));
      expect(w.end, DateTime(2026, 3, 10, 18));
    });

    // The distinction that caused a real bug: nightWindowFor spans a full 24
    // hours and only answers "which night does this belong to". Deriving a
    // resting heart rate over it counts the entire waking day, so a brisk
    // afternoon reads as "resting".
    test('the sleep-proxy window excludes the waking day', () {
      final w = sleepProxyWindowFor('2026-03-10');
      expect(w.start, DateTime(2026, 3, 9, 22));
      expect(w.end, DateTime(2026, 3, 10, 8));

      final midday = DateTime(2026, 3, 10, 14);
      final night = nightWindowFor('2026-03-10');
      expect(midday.isAfter(night.start) && midday.isBefore(night.end), isTrue,
          reason: 'the night bucket does contain midday — that is the trap');
      expect(midday.isBefore(w.end), isFalse,
          reason: 'the sleep proxy must not');
    });
  });

  group('calendar arithmetic, not elapsed time', () {
    test('nextDay and previousDay cross month and year ends', () {
      expect(nextDay(DateTime(2026, 1, 31)), DateTime(2026, 2, 1));
      expect(nextDay(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
      expect(previousDay(DateTime(2026, 3, 1)), DateTime(2026, 2, 28));
      expect(previousDay(DateTime(2026, 1, 1)), DateTime(2025, 12, 31));
    });

    test('leap day is handled', () {
      expect(nextDay(DateTime(2028, 2, 28)), DateTime(2028, 2, 29));
      expect(previousDay(DateTime(2028, 3, 1)), DateTime(2028, 2, 29));
    });

    // The real point of using DateTime(y, m, d + 1) over
    // .add(Duration(days: 1)): a Duration is ELAPSED time, so across a DST
    // boundary it lands on 23:00 or 01:00 of the wrong day. That produced 34
    // assertion failures under TZ=America/New_York — see docs/bug-hunt.md.
    // Under a DST-observing zone the two disagree; under UTC they agree, so
    // this asserts the invariant that holds everywhere.
    test('a day boundary is always midnight, whatever the offset', () {
      for (final d in [
        DateTime(2026, 3, 8), // US spring forward
        DateTime(2026, 11, 1), // US fall back
        DateTime(2026, 3, 29), // EU spring forward
      ]) {
        final next = nextDay(d);
        expect(next.hour, 0, reason: 'crossed a DST boundary and drifted');
        expect(next.minute, 0);
        expect(previousDay(next), d);
      }
    });

    test('dayWindowFor is exactly one calendar day across a DST change', () {
      for (final key in ['2026-03-08', '2026-11-01', '2026-03-29']) {
        final w = dayWindowFor(key);
        expect(w.start.hour, 0);
        expect(w.end.hour, 0);
        expect(dateKeyOf(w.end), dateKeyOf(nextDay(w.start)));
      }
    });
  });
}
