import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/day_mood.dart';

void main() {
  group('the two scales', () {
    test('5 on the period sheet is Great (0) in the mood log, and back', () {
      expect(DayMood.toMoodIndex(5), 0);
      expect(DayMood.toMoodIndex(4), 1);
      expect(DayMood.toMoodIndex(3), 2);
      expect(DayMood.toMoodIndex(2), 3);
      expect(DayMood.toMoodIndex(1), 4);
    });

    test('every value round-trips', () {
      for (var p = 1; p <= 5; p++) {
        expect(DayMood.toPeriodMood(DayMood.toMoodIndex(p)), p);
      }
      for (var i = 0; i <= 4; i++) {
        expect(DayMood.toMoodIndex(DayMood.toPeriodMood(i)), i);
      }
    });

    test('the direction is the point: good stays good', () {
      // "Great" in the log must never come out as the worst face.
      expect(DayMood.toPeriodMood(0), 5);
      expect(DayMood.toPeriodMood(4), 1);
    });

    test('null stays null, and out-of-range is clamped, not thrown', () {
      expect(DayMood.toMoodIndex(null), isNull);
      expect(DayMood.toPeriodMood(null), isNull);
      expect(DayMood.toMoodIndex(9), 0);
      expect(DayMood.toMoodIndex(-3), 4);
      expect(DayMood.toPeriodMood(12), 1);
      expect(DayMood.toPeriodMood(-5), 5);
    });
  });

  group('resolve — the day\'s mood', () {
    final t0 = DateTime(2026, 3, 10, 9);
    final t1 = DateTime(2026, 3, 10, 18);

    test('only the period mood', () {
      expect(DayMood.resolve(periodMood: 4, periodUpdatedAt: t0), 4);
    });

    test('only a mood-log entry, translated to the period scale', () {
      expect(DayMood.resolve(latestEntryIndex: 0, latestEntryAt: t0), 5);
      expect(DayMood.resolve(latestEntryIndex: 3, latestEntryAt: t0), 2);
    });

    test('neither is nothing', () {
      expect(DayMood.resolve(), isNull);
    });

    test('the one written LAST wins', () {
      // Period sheet at 09:00 said 2; the mood screen at 18:00 said Great.
      expect(
          DayMood.resolve(
              periodMood: 2,
              periodUpdatedAt: t0,
              latestEntryIndex: 0,
              latestEntryAt: t1),
          5);
      // ...and the other way round.
      expect(
          DayMood.resolve(
              periodMood: 2,
              periodUpdatedAt: t1,
              latestEntryIndex: 0,
              latestEntryAt: t0),
          2);
    });

    test('a period day with no timestamp predates the entry', () {
      expect(
          DayMood.resolve(
              periodMood: 2, latestEntryIndex: 0, latestEntryAt: t0),
          5);
    });

    test('a tie keeps what the period sheet says', () {
      expect(
          DayMood.resolve(
              periodMood: 2,
              periodUpdatedAt: t0,
              latestEntryIndex: 0,
              latestEntryAt: t0),
          2);
    });
  });

  group('needsLogEntry', () {
    test('a new answer on a day with no entry', () {
      expect(DayMood.needsLogEntry(periodMood: 5), isTrue);
    });

    test('the same answer the log already holds is not logged again', () {
      expect(DayMood.needsLogEntry(periodMood: 5, latestEntryIndex: 0), isFalse);
    });

    test('a different answer is', () {
      expect(DayMood.needsLogEntry(periodMood: 5, latestEntryIndex: 2), isTrue);
    });

    test('no mood chosen logs nothing', () {
      expect(DayMood.needsLogEntry(periodMood: null), isFalse);
      expect(DayMood.needsLogEntry(periodMood: null, latestEntryIndex: 1), isFalse);
    });
  });
}
