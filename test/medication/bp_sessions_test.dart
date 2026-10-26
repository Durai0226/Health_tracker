import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/services/bp_sessions.dart';

void main() {
  final t0 = DateTime(2026, 3, 1, 8, 0);

  BloodPressureReading r(String id, int s, int d,
          {int minutes = 0, int? pulse, String? who}) =>
      BloodPressureReading(
        id: id,
        dependentId: who,
        systolic: s,
        diastolic: d,
        pulse: pulse,
        takenAt: t0.add(Duration(minutes: minutes)),
        createdAt: t0,
      );

  group('grouping', () {
    test('two readings a minute apart are one session', () {
      final s = BpSessions.group([r('a', 130, 84), r('b', 126, 80, minutes: 1)]);
      expect(s, hasLength(1));
      expect(s.single.readings.map((x) => x.id), ['a', 'b']);
      expect(s.single.isAveraged, isTrue);
    });

    test('the window is 10 minutes from the FIRST reading, inclusive', () {
      expect(BpSessions.group([r('a', 120, 80), r('b', 120, 80, minutes: 10)]),
          hasLength(1));
      expect(BpSessions.group([r('a', 120, 80), r('b', 120, 80, minutes: 11)]),
          hasLength(2));
    });

    test('it is anchored, not chained: a reading every 8 minutes cannot snowball',
        () {
      final chain = [
        for (var i = 0; i < 5; i++) r('r$i', 120, 80, minutes: i * 8),
      ];
      final s = BpSessions.group(chain);
      // 0 and 8 join; 16 is >10 from 0 so starts a new one; 16 and 24 join; 32 alone.
      expect(s.map((x) => x.readings.length), [2, 2, 1]);
    });

    test('input order does not matter', () {
      final s = BpSessions.group([r('b', 126, 80, minutes: 1), r('a', 130, 84)]);
      expect(s.single.readings.map((x) => x.id), ['a', 'b']);
    });

    test('two people logged a minute apart are never averaged together', () {
      final s = BpSessions.group([
        r('me', 120, 80),
        r('kid', 100, 60, minutes: 1, who: 'dep1'),
      ]);
      expect(s, hasLength(2));
    });

    test('sessions come back oldest first', () {
      final s = BpSessions.group([
        r('late', 120, 80, minutes: 600),
        r('early', 120, 80),
      ]);
      expect(s.map((x) => x.first.id), ['early', 'late']);
    });

    test('empty in, empty out', () {
      expect(BpSessions.group(const []), isEmpty);
      expect(BpSessions.collapse(const []), isEmpty);
    });
  });

  group('the average', () {
    test('averages systolic and diastolic, rounding .5 up', () {
      final s = BpSessions.group([r('a', 131, 85), r('b', 126, 80, minutes: 1)])
          .single;
      expect(s.systolic, 129); // 128.5 -> 129
      expect(s.diastolic, 83); // 82.5 -> 83
    });

    test('pulse is the mean of the pulses that were entered', () {
      final s = BpSessions.group([
        r('a', 120, 80, pulse: 70),
        r('b', 120, 80, minutes: 1),
        r('c', 120, 80, minutes: 2, pulse: 74),
      ]).single;
      expect(s.pulse, 72);
    });

    test('no pulse anywhere stays null', () {
      final s = BpSessions.group([r('a', 120, 80), r('b', 120, 80, minutes: 1)])
          .single;
      expect(s.pulse, isNull);
    });

    test('the session takes the time of its first reading', () {
      final s = BpSessions.group([r('a', 120, 80), r('b', 120, 80, minutes: 6)])
          .single;
      expect(s.takenAt, t0);
    });
  });

  group('collapse', () {
    test('a lone reading comes back untouched', () {
      final one = r('a', 133, 91, pulse: 66);
      final out = BpSessions.collapse([one]).single;
      expect(identical(out, one), isTrue);
    });

    test('a session becomes ONE reading carrying the average', () {
      final out = BpSessions.collapse(
          [r('a', 140, 90), r('b', 130, 80, minutes: 1)]).single;
      expect(out.systolic, 135);
      expect(out.diastolic, 85);
      expect(out.takenAt, t0);
    });

    test('the category is taken from the AVERAGE, not from either reading', () {
      // 125/78 is Elevated, 141/79 is Stage 2; their average (133/79) is
      // Stage 1 — a category NEITHER reading is in, so this can only pass if
      // the average is what gets classified.
      final a = r('a', 125, 78);
      final b = r('b', 141, 79, minutes: 1);
      final out = BpSessions.collapse([a, b]).single;
      expect(a.category, isNot(out.category));
      expect(b.category, isNot(out.category));
      expect(out.category, VitalsAnalyzer.classifyBp(133, 79));
    });

    test('order follows the caller: newest first by default, oldest on request',
        () {
      final list = [
        r('a', 120, 80),
        r('b', 130, 85, minutes: 600),
      ];
      expect(BpSessions.collapse(list).map((x) => x.id), ['b', 'a']);
      expect(BpSessions.collapse(list, newestFirst: false).map((x) => x.id),
          ['a', 'b']);
    });

    test('three readings an hour apart stay three sessions', () {
      final list = [
        for (var i = 0; i < 3; i++) r('r$i', 120, 80, minutes: i * 60),
      ];
      expect(BpSessions.collapse(list), hasLength(3));
    });

    test('a doubled-up morning no longer outweighs a single evening reading',
        () {
      // The reason the feature exists: raw mean of 3 readings is
      // (150+150+110)/3 = 136.7; per-session is (150+110)/2 = 130.
      final list = [
        r('m1', 150, 90),
        r('m2', 150, 90, minutes: 1),
        r('e1', 110, 70, minutes: 600),
      ];
      final sys = BpSessions.collapse(list).map((x) => x.systolic).toList();
      expect(sys.reduce((a, b) => a + b) / sys.length, 130);
    });
  });

  group('containing', () {
    test('finds the session a reading belongs to', () {
      final list = [r('a', 120, 80), r('b', 120, 80, minutes: 1), r('c', 120, 80, minutes: 90)];
      expect(BpSessions.containing(list, 'b')!.readings.length, 2);
      expect(BpSessions.containing(list, 'c')!.readings.length, 1);
      expect(BpSessions.containing(list, 'zzz'), isNull);
    });
  });
}
