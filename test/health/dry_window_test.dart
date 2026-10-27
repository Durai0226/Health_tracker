/// "Rain from 6 pm — 4–5 pm looks dry." Only when there is rain to dodge.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/dry_window.dart';

void main() {
  /// A day of [p]% everywhere, with [over] hours (index → percent) overridden.
  List<int?> day({int p = 0, Map<int, int?> over = const {}}) =>
      [for (var h = 0; h < 24; h++) over.containsKey(h) ? over[h] : p];

  group('when there is nothing to dodge', () {
    test('a dry day says nothing', () {
      expect(DryWindows.find(day(), nowHour: 14, nowMinute: 0), isNull);
    });

    test('rain that has already gone says nothing', () {
      final d = day(over: {9: 80, 10: 90});
      expect(DryWindows.find(d, nowHour: 14, nowMinute: 0), isNull,
          reason: 'it rained this morning; that is not a reason now');
    });

    test('rain after waking hours says nothing', () {
      final d = day(over: {22: 90, 23: 90});
      expect(DryWindows.find(d, nowHour: 14, nowMinute: 0), isNull);
    });

    test('a "maybe" is not rain', () {
      final d = day(over: {16: 45, 17: 49});
      expect(DryWindows.find(d, nowHour: 14, nowMinute: 0), isNull,
          reason: 'under 50% is not wet enough to talk about');
    });

    test('half is rain, and so is more', () {
      for (final p in [50, 55, 59, 90]) {
        expect(DryWindows.find(day(over: {18: p}), nowHour: 14, nowMinute: 0), isNotNull,
            reason: '$p%');
      }
      expect(DryWindows.find(day(over: {18: 49}), nowHour: 14, nowMinute: 0), isNull);
    });

    test('too late in the day for a walk says nothing', () {
      final d = day(over: {21: 90});
      expect(DryWindows.find(d, nowHour: 21, nowMinute: 10), isNull);
      expect(DryWindows.find(d, nowHour: 22, nowMinute: 0), isNull);
    });

    test('no forecast for the day is no tip', () {
      expect(DryWindows.find(const [], nowHour: 14, nowMinute: 0), isNull);
      expect(DryWindows.find(List<int?>.filled(24, null), nowHour: 14, nowMinute: 0), isNull);
    });
  });

  group('dry now, rain coming', () {
    test('the stretch before it, from now', () {
      final d = day(over: {18: 70, 19: 80, 20: 60});
      final w = DryWindows.find(d, nowHour: 14, nowMinute: 0)!;
      expect(w.rainingNow, isFalse);
      expect(w.rainHour, 18);
      expect(w.fromHour, 14);
      expect(w.toHour, 16, reason: 'a walk, not the whole afternoon: two hours');
    });

    test('a short dry stretch is all of it', () {
      final d = day(p: 80, over: {15: 5});
      final w = DryWindows.find(d, nowHour: 13, nowMinute: 0)!;
      // Wet now, so this is the "eases" case; see below. Here: dry at 15 only.
      expect(w.fromHour, 15);
      expect(w.toHour, 16);
    });

    test('from the half hour on, the current hour is as good as gone', () {
      final d = day(over: {18: 70});
      expect(DryWindows.find(d, nowHour: 14, nowMinute: 29)!.fromHour, 14);
      expect(DryWindows.find(d, nowHour: 14, nowMinute: 30)!.fromHour, 15);
    });

    test('before waking hours it starts at the first of them', () {
      final d = day(over: {18: 70});
      expect(DryWindows.find(d, nowHour: 3, nowMinute: 0)!.fromHour, DryWindows.firstHour);
    });

    test('rain right away leaves no stretch before it, so it is the one after',
        () {
      // Dry 14, rain 15–16, dry again from 17.
      final d = day(over: {15: 80, 16: 70});
      final w = DryWindows.find(d, nowHour: 14, nowMinute: 0)!;
      expect(w.rainHour, 15);
      expect(w.fromHour, 14, reason: 'the first dry hour left is still the next one');
    });
  });

  group('raining now', () {
    test('rain until it eases, and the dry after it', () {
      final d = day(over: {13: 90, 14: 85, 15: 70});
      final w = DryWindows.find(d, nowHour: 13, nowMinute: 0)!;
      expect(w.rainingNow, isTrue);
      expect(w.rainHour, 16, reason: 'the hour it is expected to ease');
      expect(w.fromHour, 16);
      expect(w.toHour, 18);
    });

    test('rain that does not ease in waking hours: nothing to point at', () {
      final d = day(p: 80);
      expect(DryWindows.find(d, nowHour: 13, nowMinute: 0), isNull);
    });

    test('an easing that is only a "maybe" is not yet dry', () {
      // Wet 13–14, maybe 15–16, dry from 17.
      final d = day(over: {13: 90, 14: 85, 15: 40, 16: 40});
      final w = DryWindows.find(d, nowHour: 13, nowMinute: 0)!;
      expect(w.rainHour, 15, reason: 'it eases at 15');
      expect(w.fromHour, 17, reason: 'but "looks dry" waits for the dry');
    });
  });

  group('what counts as dry', () {
    // Rain at 18:00 so there is something to dodge; the question is the hours
    // before it, from 15:00.
    int? windowStart(int p) =>
        DryWindows.find(day(over: {15: p, 18: 90}), nowHour: 15, nowMinute: 0)?.fromHour;

    test('under 30% is dry', () {
      expect(windowStart(0), 15);
      expect(windowStart(25), 15);
      expect(windowStart(29), 15);
    });

    test('30% and over is not promised dry', () {
      expect(windowStart(30), 16, reason: 'the first hour is only a "maybe"');
      expect(windowStart(35), 16);
      expect(windowStart(45), 16);
    });
  });

  group('the edges', () {
    test('a dry run shorter than asked for is not a window', () {
      final d = day(p: 80, over: {15: 5});
      expect(DryWindows.find(d, nowHour: 14, nowMinute: 0, minHours: 2), isNull);
    });

    test('unknown hours are neither wet nor dry', () {
      final d = day(over: {16: null, 17: null, 18: 80});
      final w = DryWindows.find(d, nowHour: 14, nowMinute: 0)!;
      expect(w.fromHour, 14);
      expect(w.toHour, 16, reason: 'it stops at what is not known to be dry');
    });

    test('a window ends at an unknown hour, not past it', () {
      final d = day(over: {16: null, 18: 80});
      final w = DryWindows.find(d, nowHour: 15, nowMinute: 0)!;
      expect(w.fromHour, 15);
      expect(w.toHour, 16, reason: 'hour 16 is unknown; 17 being dry does not join them');
    });

    test('windows are ordered and inside waking hours', () {
      for (var now = 0; now < 24; now++) {
        for (final rain in [10, 14, 17, 20]) {
          final w = DryWindows.find(day(over: {rain: 90}), nowHour: now, nowMinute: 0);
          if (w == null) continue;
          expect(w.fromHour, lessThan(w.toHour));
          expect(w.fromHour, greaterThanOrEqualTo(DryWindows.firstHour));
          expect(w.toHour, lessThanOrEqualTo(DryWindows.lastHour));
        }
      }
    });
  });
}
