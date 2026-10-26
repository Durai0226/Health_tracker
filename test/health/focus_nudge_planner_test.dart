import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/focus_nudge_planner.dart';

void main() {
  // Wednesday 11 March 2026, 07:00.
  final now = DateTime(2026, 3, 11, 7, 0);

  DateTime at(int month, int day, [int hour = 9]) =>
      DateTime(2026, month, day, hour);

  group('usualWeekdays', () {
    test('a weekday needs two focused days in the last four weeks', () {
      // Mondays 2 and 9 March, a lone Thursday 5 March.
      final focused = [at(3, 2), at(3, 9), at(3, 5)];
      expect(FocusNudgePlanner.usualWeekdays(focused, now), {DateTime.monday});
    });

    test('two sessions on ONE day are one focused day', () {
      final focused = [at(3, 2, 9), at(3, 2, 15)];
      expect(FocusNudgePlanner.usualWeekdays(focused, now), isEmpty);
    });

    test('days older than 28 are ignored', () {
      final focused = [at(1, 5), at(1, 12)]; // two Mondays, > 28 days ago
      expect(FocusNudgePlanner.usualWeekdays(focused, now), isEmpty);
    });
  });

  group('next', () {
    test('no best hour means no plan (keep the fixed reminder)', () {
      expect(
          FocusNudgePlanner.next(now: now, bestHour: null, focusedAt: []),
          isNull);
    });

    test('is ten minutes before the best hour', () {
      final n = FocusNudgePlanner.next(now: now, bestHour: 9, focusedAt: [])!;
      expect(n, DateTime(2026, 3, 11, 8, 50));
    });

    test('stays quiet today once the user has focused', () {
      final n = FocusNudgePlanner.next(
          now: now, bestHour: 9, focusedAt: [DateTime(2026, 3, 11, 6, 30)])!;
      expect(n.day, isNot(11), reason: 'they already focused this morning');
      expect(n, DateTime(2026, 3, 12, 8, 50));
    });

    test('rolls to tomorrow when today\'s time has passed', () {
      final late = DateTime(2026, 3, 11, 8, 55);
      final n = FocusNudgePlanner.next(now: late, bestHour: 9, focusedAt: [])!;
      expect(n, DateTime(2026, 3, 12, 8, 50));
    });

    test('only fires on weekdays the user usually focuses', () {
      // Usually Mondays and Fridays (twice each in the last four weeks).
      final focused = [at(3, 2), at(3, 9), at(2, 27), at(3, 6)];
      final usual = FocusNudgePlanner.usualWeekdays(focused, now);
      expect(usual, {DateTime.monday, DateTime.friday});
      final n = FocusNudgePlanner.next(now: now, bestHour: 9, focusedAt: focused)!;
      // Wed 11 → next usual day is Fri 13.
      expect(n, DateTime(2026, 3, 13, 8, 50));
      expect(usual.contains(n.weekday), isTrue);
    });

    test('with no pattern yet every day is a candidate', () {
      final n = FocusNudgePlanner.next(
          now: now, bestHour: 14, focusedAt: [at(3, 4)])!;
      expect(n, DateTime(2026, 3, 11, 13, 50));
    });

    test('a best hour of midnight does not break the arithmetic', () {
      final n = FocusNudgePlanner.next(now: now, bestHour: 0, focusedAt: [])!;
      expect(n.isAfter(now), isTrue);
      expect(n.hour, 23);
      expect(n.minute, 50);
    });

    test('always lands strictly in the future', () {
      for (var h = 0; h < 24; h++) {
        final n = FocusNudgePlanner.next(now: now, bestHour: h, focusedAt: [])!;
        expect(n.isAfter(now), isTrue, reason: 'hour $h');
      }
    });
  });
}
