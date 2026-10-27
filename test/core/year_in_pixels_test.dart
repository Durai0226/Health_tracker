import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/year_in_pixels.dart';

void main() {
  PixelMood m(int month, int day, int mood, {int hour = 9}) =>
      PixelMood(DateTime(2026, month, day, hour), mood);

  group('the grid', () {
    test('is 12 months of 31 slots, null where the date does not exist', () {
      final y = YearInPixels.build(year: 2026, moods: const []);
      expect(y.months, hasLength(12));
      expect(y.months.every((r) => r.length == 31), isTrue);
      expect(y.months[1][27]!.date, DateTime(2026, 2, 28));
      expect(y.months[1][28], isNull, reason: '29 Feb 2026 does not exist');
      expect(y.months[3][30], isNull, reason: '31 April');
      expect(y.months[0][30]!.date, DateTime(2026, 1, 31));
    });

    test('a leap year has its 29th February', () {
      final y = YearInPixels.build(year: 2028, moods: const []);
      expect(y.months[1][28]!.date, DateTime(2028, 2, 29));
      expect(y.days.length, 366);
    });

    test('an ordinary year has 365 days', () {
      expect(YearInPixels.build(year: 2026, moods: const []).days.length, 365);
    });
  });

  group('a day', () {
    test('one entry is that mood', () {
      final y = YearInPixels.build(year: 2026, moods: [m(3, 4, 1)]);
      final d = y.months[2][3]!;
      expect(d.mood, 1);
      expect(d.entries, 1);
      expect(d.logged, isTrue);
    });

    test('several entries are their mean, rounded to the nearest mood', () {
      // 0 and 3 -> 1.5 -> 2 (rounds half away from zero)
      final y =
          YearInPixels.build(year: 2026, moods: [m(3, 4, 0), m(3, 4, 3, hour: 20)]);
      expect(y.months[2][3]!.mood, 2);
      expect(y.months[2][3]!.entries, 2);
      // 1 and 1 and 2 -> 1.33 -> 1
      final z = YearInPixels.build(
          year: 2026, moods: [m(3, 5, 1), m(3, 5, 1, hour: 12), m(3, 5, 2, hour: 20)]);
      expect(z.months[2][4]!.mood, 1);
    });

    test('an empty day is blank, not neutral', () {
      final y = YearInPixels.build(year: 2026, moods: [m(3, 4, 2)]);
      expect(y.months[2][5]!.mood, isNull);
      expect(y.months[2][5]!.logged, isFalse);
    });

    test('a bad mood row is clamped, not thrown on', () {
      final y = YearInPixels.build(year: 2026, moods: [m(3, 4, 99), m(3, 6, -4)]);
      expect(y.months[2][3]!.mood, 4);
      expect(y.months[2][5]!.mood, 0);
    });

    test('entries from other years do not leak in', () {
      final y = YearInPixels.build(
          year: 2026, moods: [PixelMood(DateTime(2025, 3, 4), 0)]);
      expect(y.loggedDays, 0);
    });
  });

  group('period dots', () {
    test('mark the days they fall on', () {
      final y = YearInPixels.build(
          year: 2026,
          moods: const [],
          periodDays: [DateTime(2026, 3, 4, 15), DateTime(2026, 3, 5)]);
      expect(y.months[2][3]!.period, isTrue);
      expect(y.months[2][4]!.period, isTrue);
      expect(y.months[2][5]!.period, isFalse);
      expect(y.hasPeriod, isTrue);
    });

    test('are independent of whether a mood was logged', () {
      final y = YearInPixels.build(
          year: 2026, moods: const [], periodDays: [DateTime(2026, 1, 1)]);
      expect(y.months[0][0]!.logged, isFalse);
      expect(y.months[0][0]!.period, isTrue);
    });

    test('other years are ignored, and none means no dots', () {
      final y = YearInPixels.build(
          year: 2026, moods: const [], periodDays: [DateTime(2025, 3, 4)]);
      expect(y.hasPeriod, isFalse);
    });
  });

  group('summaries', () {
    test('logged days and the distribution count days, not entries', () {
      final y = YearInPixels.build(year: 2026, moods: [
        m(1, 1, 0),
        m(1, 1, 0, hour: 20),
        m(1, 2, 0),
        m(1, 3, 4),
      ]);
      expect(y.loggedDays, 3);
      expect(y.distribution, [2, 0, 0, 0, 1]);
    });
  });

  group('years and the future', () {
    test('years with data, newest first, always including this one', () {
      final years = YearInPixels.yearsWith([
        PixelMood(DateTime(2024, 5, 1), 1),
        PixelMood(DateTime(2025, 5, 1), 1),
      ], current: 2026);
      expect(years, [2026, 2025, 2024]);
      expect(YearInPixels.yearsWith(const [], current: 2026), [2026]);
    });

    test('a square is in the future only after today', () {
      final today = DateTime(2026, 3, 10, 15);
      expect(YearInPixels.isFuture(DateTime(2026, 3, 10), today), isFalse);
      expect(YearInPixels.isFuture(DateTime(2026, 3, 11), today), isTrue);
      expect(YearInPixels.isFuture(DateTime(2026, 3, 9), today), isFalse);
    });
  });
}
