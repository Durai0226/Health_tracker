/// A guided home week: seven days, morning and evening, the first day left out.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/home_bp_week.dart';
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';

void main() {
  // Monday 1 June 2026 is day 1.
  final start = DateTime(2026, 6, 1);

  HomeBpSample am(int day, int s, int d) =>
      HomeBpSample(DateTime(2026, 6, day, 8, 0), s, d);
  HomeBpSample pm(int day, int s, int d) =>
      HomeBpSample(DateTime(2026, 6, day, 20, 0), s, d);

  HomeBpProgress at(DateTime now, List<HomeBpSample> sessions) =>
      HomeBpWeek.progress(start: start, sessions: sessions, now: now);

  group('where the week stands', () {
    test('day one, nothing taken yet: the morning session is due', () {
      final p = at(DateTime(2026, 6, 1, 7), const []);
      expect(p.dayNumber, 1);
      expect(p.ended, isFalse);
      expect(p.taken, 0);
      expect(p.due, HomeBpSlot.morning);
    });

    test('after noon the evening one is due, not the morning', () {
      final p = at(DateTime(2026, 6, 1, 14), const []);
      expect(p.due, HomeBpSlot.evening,
          reason: 'a morning missed at two in the afternoon is missed');
    });

    test('once today\'s is taken nothing is due', () {
      expect(at(DateTime(2026, 6, 1, 9), [am(1, 120, 80)]).due, isNull);
      expect(at(DateTime(2026, 6, 1, 21), [pm(1, 120, 80)]).due, isNull);
    });

    test('a morning taken does not excuse the evening', () {
      expect(at(DateTime(2026, 6, 1, 21), [am(1, 120, 80)]).due,
          HomeBpSlot.evening);
    });

    test('the day number follows the calendar', () {
      expect(at(DateTime(2026, 6, 3, 10), const []).dayNumber, 3);
      final last = at(DateTime(2026, 6, 7, 23, 59), const []);
      expect(last.dayNumber, 7);
      expect(last.ended, isFalse, reason: 'day seven is still the week');
      expect(last.due, HomeBpSlot.evening);
    });

    test('noon is where morning ends: 11:59 is a morning, 12:00 is not', () {
      expect(at(DateTime(2026, 6, 1, 11, 59), const []).due, HomeBpSlot.morning);
      expect(at(DateTime(2026, 6, 1, 12, 0), const []).due, HomeBpSlot.evening);

      final noonSession = HomeBpSample(DateTime(2026, 6, 1, 12, 0), 120, 80);
      final lateMorning = HomeBpSample(DateTime(2026, 6, 1, 11, 59), 120, 80);
      expect(noonSession.isMorning, isFalse);
      expect(lateMorning.isMorning, isTrue);
    });

    test('after day seven it has ended, and nothing is due', () {
      final p = at(DateTime(2026, 6, 8, 8), const []);
      expect(p.ended, isTrue);
      expect(p.dayNumber, 7);
      expect(p.due, isNull);
    });

    test('each day says which of its two were taken', () {
      final p = at(DateTime(2026, 6, 4, 9),
          [am(1, 120, 80), pm(1, 122, 80), am(2, 118, 78), pm(3, 124, 82)]);
      expect(p.days.map((d) => (d.morningDone, d.eveningDone)).take(4).toList(), [
        (true, true),
        (true, false),
        (false, true),
        (false, false),
      ]);
      expect(p.taken, 4);
    });

    test('readings outside the seven days are not part of it', () {
      final p = at(DateTime(2026, 6, 9, 9), [
        HomeBpSample(DateTime(2026, 5, 31, 8), 170, 100),
        HomeBpSample(DateTime(2026, 6, 8, 8), 170, 100),
        am(2, 118, 78),
      ]);
      expect(p.taken, 1);
      expect(p.summary.sessions, 1);
      expect(p.summary.average, '118/78',
          reason: 'the day before and the day after are not in the average');
    });

    test('a week that has not begun is on day one with nothing due', () {
      final p = at(DateTime(2026, 5, 30, 8), const []);
      expect(p.dayNumber, 1);
      expect(p.due, isNull);
    });
  });

  group('the average', () {
    test('leaves the first day out', () {
      final p = at(DateTime(2026, 6, 3, 21), [
        am(1, 160, 100), pm(1, 160, 100), // day 1: not counted
        am(2, 120, 80), pm(2, 124, 82),
      ]);
      expect(p.summary.sessions, 2);
      expect(p.summary.average, '122/81');
    });

    test('rounds the way the rest of BP does', () {
      final p = at(DateTime(2026, 6, 8, 9), [
        am(2, 120, 80), pm(2, 121, 81), // 120.5/80.5 -> 121/81 (round half up)
      ]);
      expect(p.summary.average, '121/81');
    });

    test('and says morning and evening apart', () {
      final p = at(DateTime(2026, 6, 8, 9), [
        am(2, 126, 80), am(3, 131, 84), pm(2, 132, 86), pm(3, 137, 89),
      ]);
      expect(p.summary.morning, '129/82', reason: '128.5 rounds up');
      expect(p.summary.evening, '135/88', reason: '134.5 and 87.5 round up');
    });

    test('is enough from four days and eight sessions', () {
      List<HomeBpSample> days(int n) => [
            for (var d = 2; d < 2 + n; d++) ...[am(d, 120, 80), pm(d, 120, 80)],
          ];
      expect(at(DateTime(2026, 6, 8, 9), days(3)).summary.enough, isFalse,
          reason: 'three days, six sessions');
      expect(at(DateTime(2026, 6, 8, 9), days(4)).summary.enough, isTrue);
    });

    test('seven sessions over four days is one short', () {
      final p = at(DateTime(2026, 6, 8, 9), [
        for (var d = 2; d <= 4; d++) ...[am(d, 120, 80), pm(d, 120, 80)],
        am(5, 120, 80),
      ]);
      expect([p.summary.sessions, p.summary.days], [7, 4]);
      expect(p.summary.enough, isFalse);
    });

    test('four days of one session each is not eight sessions', () {
      final p = at(DateTime(2026, 6, 8, 9),
          [for (var d = 2; d <= 5; d++) am(d, 120, 80)]);
      expect(p.summary.days, 4);
      expect(p.summary.enough, isFalse);
    });

    test('eight sessions on three days is not four days', () {
      final p = at(DateTime(2026, 6, 8, 9), [
        for (var d = 2; d <= 4; d++) ...[am(d, 120, 80), pm(d, 120, 80)],
        HomeBpSample(DateTime(2026, 6, 2, 10), 120, 80),
        HomeBpSample(DateTime(2026, 6, 3, 10), 120, 80),
      ]);
      expect(p.summary.sessions, 8);
      expect(p.summary.days, 3);
      expect(p.summary.enough, isFalse);
    });

    test('with nothing counted there is no average, not a zero', () {
      final p = at(DateTime(2026, 6, 2, 9), [am(1, 150, 95)]);
      expect(p.summary.average, isNull);
      expect(p.summary.category, isNull);
      expect(p.summary.sessions, 0);
    });

    test('it is placed in a range by the same rules as every other reading', () {
      final p = at(DateTime(2026, 6, 8, 9), [
        for (var d = 2; d <= 5; d++) ...[am(d, 134, 84), pm(d, 134, 84)],
      ]);
      expect(p.summary.category, VitalsAnalyzer.classifyBp(134, 84));
      expect(p.summary.category, BpCategory.stage1);
    });
  });
}
