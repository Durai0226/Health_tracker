/// Which days a visit brief covers, and when it is announced.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/visit_brief.dart';

void main() {
  final now = DateTime(2026, 6, 20, 15, 30);
  final visit = DateTime(2026, 6, 25, 10, 30);

  VisitBriefWindow window([List<DateTime> earlier = const []]) =>
      VisitBriefs.window(visitAt: visit, now: now, earlierVisits: earlier);

  group('the window', () {
    test('with no earlier visit: the last thirty days', () {
      final w = window();
      expect(w.days, 30);
      expect(w.to, now);
      expect(w.sinceVisit, isNull);
      expect(w.from, DateTime(2026, 5, 21, 15, 30));
    });

    test('with one: from the start of that day', () {
      final w = window([DateTime(2026, 5, 4, 14, 0)]);
      expect(w.sinceVisit, DateTime(2026, 5, 4, 14, 0));
      expect(w.from, DateTime(2026, 5, 4), reason: 'what was logged that afternoon counts');
      expect(w.to, now);
    });

    test('the latest of several', () {
      final w = window([
        DateTime(2026, 2, 1, 9),
        DateTime(2026, 5, 4, 14),
        DateTime(2026, 3, 10, 9),
      ]);
      expect(w.sinceVisit, DateTime(2026, 5, 4, 14));
    });

    test('a visit after this one, or still to come, is not an earlier one', () {
      final w = window([
        DateTime(2026, 7, 30, 9), // after this visit
        DateTime(2026, 6, 22, 9), // before it but not yet happened
      ]);
      expect(w.sinceVisit, isNull);
      expect(w.days, 30);
    });

    test('the visit itself is not its own earlier visit', () {
      expect(window([visit]).sinceVisit, isNull);
    });

    test('under a week ago says a week, and no "since"', () {
      final w = window([DateTime(2026, 6, 16, 9)]); // four days ago
      expect(w.days, 7);
      expect(w.sinceVisit, isNull);
    });

    test('exactly a week ago is a "since"', () {
      final w = window([DateTime(2026, 6, 13, 9)]);
      expect(w.sinceVisit, DateTime(2026, 6, 13, 9));
      expect(w.days, 7);
    });

    test('six days is not', () {
      final w = window([DateTime(2026, 6, 14, 9)]);
      expect(w.sinceVisit, isNull);
      expect(w.days, 7);
    });

    test('ninety days is the longest "since"', () {
      final w = window([DateTime(2026, 3, 22, 9)]);
      expect(now.difference(DateTime(2026, 3, 22)).inDays, 90);
      expect(w.sinceVisit, DateTime(2026, 3, 22, 9));
      expect(w.days, 90);
    });

    test('longer than that is the last ninety days, not "since"', () {
      final w = window([DateTime(2026, 3, 21, 9)]);
      expect(w.sinceVisit, isNull);
      expect(w.days, 90);
      expect(w.from, DateTime(2026, 3, 22, 15, 30));
    });

    test('a visit a year ago is the last ninety days', () {
      final w = window([DateTime(2025, 6, 1, 9)]);
      expect(w.sinceVisit, isNull);
      expect(w.days, 90);
    });
  });

  group('when it is announced', () {
    test('9:00, two days before', () {
      expect(VisitBriefs.notifyAt(visitAt: visit, now: now), DateTime(2026, 6, 23, 9));
    });

    test('not when that moment has passed', () {
      // Booked on the 24th for the 25th: the 23rd at 9:00 is gone.
      expect(
          VisitBriefs.notifyAt(visitAt: visit, now: DateTime(2026, 6, 24, 8)), isNull);
    });

    test('a moment from now is still a moment from now', () {
      expect(VisitBriefs.notifyAt(visitAt: visit, now: DateTime(2026, 6, 23, 8, 59)),
          DateTime(2026, 6, 23, 9));
      expect(VisitBriefs.notifyAt(visitAt: visit, now: DateTime(2026, 6, 23, 9)), isNull,
          reason: 'at 9:00 exactly it is no longer ahead');
    });

    test('the month boundary: two days before the 1st', () {
      expect(
          VisitBriefs.notifyAt(
              visitAt: DateTime(2026, 7, 1, 10), now: DateTime(2026, 6, 1)),
          DateTime(2026, 6, 29, 9));
    });
  });
}
