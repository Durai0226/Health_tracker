/// "Ibuprofen · 3 h ago · 2 of 4 · OK after 14:30": where an as-needed medicine
/// stands against the limits set on it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/as_needed_status.dart';

void main() {
  final now = DateTime(2026, 6, 20, 15, 0);
  DateTime ago(Duration d) => now.subtract(d);

  AsNeededStatus status(List<DateTime> taken, {int? max, int? hours}) =>
      AsNeededStatus.of(takenAt: taken, now: now, maxPer24h: max, minHours: hours);

  group('with nothing taken', () {
    test('it is allowed, and has no last dose', () {
      final s = status(const [], max: 4, hours: 6);
      expect(s.takenIn24h, 0);
      expect(s.lastTakenAt, isNull);
      expect(s.allowedNow, isTrue);
      expect(s.atLimit, isFalse);
    });
  });

  group('the gap between doses', () {
    test('a dose three hours ago, six between: allowed from three hours on', () {
      final s = status([ago(const Duration(hours: 3))], hours: 6);
      expect(s.allowedNow, isFalse);
      expect(s.okFrom, now.add(const Duration(hours: 3)));
      expect(s.lastTakenAt, ago(const Duration(hours: 3)));
    });

    test('exactly the gap is allowed', () {
      expect(status([ago(const Duration(hours: 6))], hours: 6).allowedNow, isTrue);
    });

    test('a minute short is not', () {
      final s = status([ago(const Duration(hours: 6) - const Duration(minutes: 1))],
          hours: 6);
      expect(s.allowedNow, isFalse);
      expect(s.okFrom, now.add(const Duration(minutes: 1)));
    });

    test('no gap set means no wait', () {
      expect(status([ago(const Duration(minutes: 1))]).allowedNow, isTrue);
      expect(status([ago(const Duration(minutes: 1))], hours: 0).allowedNow, isTrue);
      expect(status(const [], hours: 0).minGap, isNull);
      expect(status(const [], hours: 6).minGap, const Duration(hours: 6));
    });
  });

  group('the daily limit', () {
    test('counts the last 24 hours, not the calendar day', () {
      // Two this morning, one late last night (17 hours ago): three in 24 h.
      final s = status([
        ago(const Duration(hours: 5)),
        ago(const Duration(hours: 9)),
        ago(const Duration(hours: 17)),
      ], max: 4);
      expect(s.takenIn24h, 3);
      expect(s.atLimit, isFalse);
    });

    test('doses older than 24 hours are not counted', () {
      final s = status([
        ago(const Duration(hours: 24)),
        ago(const Duration(hours: 30)),
        ago(const Duration(hours: 2)),
      ], max: 4);
      expect(s.takenIn24h, 1);
    });

    test('at the limit, the next is allowed when the earliest ages out', () {
      final taken = [
        ago(const Duration(hours: 20)), // out at +4 h
        ago(const Duration(hours: 14)),
        ago(const Duration(hours: 8)),
        ago(const Duration(hours: 2)),
      ];
      final s = status(taken, max: 4);
      expect(s.atLimit, isTrue);
      expect(s.allowedNow, isFalse);
      expect(s.okFrom, now.add(const Duration(hours: 4)));
    });

    test('a limit of three with five taken needs two to age out', () {
      final taken = [
        ago(const Duration(hours: 23)),
        ago(const Duration(hours: 20)),
        ago(const Duration(hours: 12)),
        ago(const Duration(hours: 6)),
        ago(const Duration(hours: 1)),
      ];
      final s = status(taken, max: 3);
      // Taken 5 against 3: allowed again when only two remain in the window, i.e.
      // when the third-oldest (12 h ago) leaves: in 12 h.
      expect(s.okFrom, now.add(const Duration(hours: 12)));
    });

    test('the later of the gap and the limit wins', () {
      final taken = [
        ago(const Duration(hours: 23)), // limit lifts in 1 h
        ago(const Duration(hours: 12)),
        ago(const Duration(hours: 5)),
        ago(const Duration(hours: 1)), // 6 h gap: allowed in 5 h
      ];
      final s = status(taken, max: 4, hours: 6);
      expect(s.okFrom, now.add(const Duration(hours: 5)));
    });

    test('the later of the two, when it is the limit that lasts longer', () {
      final taken = [
        ago(const Duration(hours: 20)), // the limit lifts in 4 h
        ago(const Duration(hours: 14)),
        ago(const Duration(hours: 8)),
        ago(const Duration(hours: 5)), // a 6 h gap lifts in 1 h
      ];
      final s = status(taken, max: 4, hours: 6);
      expect(s.okFrom, now.add(const Duration(hours: 4)));
    });

    test('below the limit and past the gap, allowed', () {
      final s = status([ago(const Duration(hours: 7))], max: 4, hours: 6);
      expect(s.allowedNow, isTrue);
    });

    test('no limit set means none', () {
      final taken = [for (var i = 1; i <= 10; i++) ago(Duration(hours: i))];
      final s = status(taken);
      expect(s.takenIn24h, 10);
      expect(s.atLimit, isFalse);
      expect(s.allowedNow, isTrue);
    });

    test('a limit of zero is no limit', () {
      expect(status([ago(const Duration(hours: 1))], max: 0).maxPer24h, isNull);
    });
  });

  group('the line on its chip', () {
    String line(AsNeededStatus s) =>
        s.line(now: now, formatTime: (t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}');

    test('how long ago, how many of how many, and when it is OK', () {
      final s = status([
        ago(const Duration(hours: 3)),
        ago(const Duration(hours: 9)),
      ], max: 4, hours: 6);
      expect(line(s), '3 h ago · 2 of 4 · OK after 18:00');
    });

    test('allowed now says so', () {
      final s = status([ago(const Duration(hours: 7))], max: 4, hours: 6);
      expect(line(s), '7 h ago · 1 of 4 · OK now');
    });

    test('at the limit it says when the limit lifts', () {
      final s = status([
        ago(const Duration(hours: 20)),
        ago(const Duration(hours: 14)),
        ago(const Duration(hours: 8)),
        ago(const Duration(hours: 2)),
      ], max: 4);
      expect(line(s), '2 h ago · 4 of 4 · Limit reached · OK from 19:00');
    });

    test('never taken', () {
      expect(line(status(const [], max: 4)), 'Not taken in 24 h · 0 of 4 · OK now');
    });

    test('no limits set: only when it was last taken', () {
      expect(line(status([ago(const Duration(minutes: 40))])),
          '40 min ago · OK now');
    });

    test('minutes, hours, and hours and minutes', () {
      String ago0(Duration d) => line(status([ago(d)]));
      expect(ago0(const Duration(seconds: 20)), startsWith('1 min ago'));
      expect(ago0(const Duration(minutes: 59)), startsWith('59 min ago'));
      expect(ago0(const Duration(minutes: 60)), startsWith('1 h ago'));
      expect(ago0(const Duration(minutes: 200)), startsWith('3 h 20 min ago'));
    });
  });

  test('a dose in the future (a clock correction) is not counted', () {
    final s = status([now.add(const Duration(hours: 1))], max: 1);
    expect(s.takenIn24h, 0);
  });

  test('the last dose is the latest one, however they are listed', () {
    final s = status([
      ago(const Duration(hours: 1)),
      ago(const Duration(hours: 9)),
      ago(const Duration(hours: 4)),
    ]);
    expect(s.lastTakenAt, ago(const Duration(hours: 1)));
  });
}
