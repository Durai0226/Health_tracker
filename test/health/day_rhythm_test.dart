/// A typical day laid against the person's own wake time and bedtime.
///
/// General, not measured: these tests pin the arithmetic and the guard rails,
/// not any claim about a body.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/day_rhythm.dart';

void main() {
  int at(int h, [int m = 0]) => h * 60 + m;

  RhythmSpan span(List<RhythmSpan> day, RhythmPhase p) =>
      day.firstWhere((s) => s.phase == p);

  group('a day from 6:30 to 10:30 pm', () {
    final day = DayRhythm.of(wakeMinute: at(6, 30), bedMinute: at(22, 30))!;

    test('has all six phases, in order', () {
      expect(day.map((s) => s.phase), [
        RhythmPhase.waking,
        RhythmPhase.warmingUp,
        RhythmPhase.focus,
        RhythmPhase.dip,
        RhythmPhase.secondWind,
        RhythmPhase.windDown,
      ]);
    });

    test('waking is the first hour', () {
      expect(span(day, RhythmPhase.waking), RhythmSpan(RhythmPhase.waking, at(6, 30), at(7, 30)));
    });

    test('focus is two and a half to five hours after waking', () {
      expect(span(day, RhythmPhase.focus),
          RhythmSpan(RhythmPhase.focus, at(9), at(11, 30)));
    });

    test('the dip is seven to nine hours after waking', () {
      expect(span(day, RhythmPhase.dip),
          RhythmSpan(RhythmPhase.dip, at(13, 30), at(15, 30)));
    });

    test('the wind-down is the last hour and a half before bed', () {
      expect(span(day, RhythmPhase.windDown),
          RhythmSpan(RhythmPhase.windDown, at(21), at(22, 30)));
    });

    test('no two overlap, and each runs forward', () {
      for (var i = 0; i < day.length; i++) {
        expect(day[i].end, greaterThan(day[i].start));
        if (i > 0) expect(day[i].start, greaterThanOrEqualTo(day[i - 1].end));
      }
    });
  });

  group('a later day, past midnight', () {
    // Up at 10:00, to bed at 2:00 the next morning.
    final day = DayRhythm.of(wakeMinute: at(10), bedMinute: at(2))!;

    test('the wind-down lands after midnight, as minutes past 1440', () {
      final w = span(day, RhythmPhase.windDown);
      expect(w.end, at(2) + 1440);
      expect(w.start, at(2) + 1440 - DayRhythm.windDownMinutes);
    });

    test('clock() brings a time back to a time of day', () {
      final w = span(day, RhythmPhase.windDown);
      expect(DayRhythm.clock(w.end), at(2));
      expect(DayRhythm.clock(w.start), at(0, 30));
    });
  });

  group('a short day loses what does not fit before bed', () {
    // Up at 7:00, to bed at 17:30: ten and a half hours awake.
    final day = DayRhythm.of(wakeMinute: at(7), bedMinute: at(17, 30))!;

    test('nothing starts inside the wind-down', () {
      final windDownStart = at(17, 30) - DayRhythm.windDownMinutes;
      for (final s in day) {
        if (s.phase == RhythmPhase.windDown) continue;
        expect(s.start, lessThan(windDownStart));
        expect(s.end, lessThanOrEqualTo(windDownStart),
            reason: '${s.phase.name} is cut short at it');
      }
    });

    test('the second wind, which would start inside it, is gone', () {
      expect(day.where((s) => s.phase == RhythmPhase.secondWind), isEmpty);
    });

    test('the wind-down is still there', () {
      expect(span(day, RhythmPhase.windDown).end, at(17, 30));
    });
  });

  group('a phase that runs into the wind-down is cut short at it', () {
    // Up at 7:00, to bed at 18:30: the second wind would run 15:30 to 19:00, but
    // the wind-down begins at 17:00.
    final day = DayRhythm.of(wakeMinute: at(7), bedMinute: at(18, 30))!;

    test('the second wind ends where the wind-down starts', () {
      expect(span(day, RhythmPhase.secondWind),
          RhythmSpan(RhythmPhase.secondWind, at(16), at(17)));
      expect(span(day, RhythmPhase.windDown).start, at(17));
    });

    test('so no two phases overlap', () {
      for (var i = 1; i < day.length; i++) {
        expect(day[i].start, greaterThanOrEqualTo(day[i - 1].end));
      }
    });
  });

  group('no rhythm without a day to lay it on', () {
    test('no wake time', () {
      expect(DayRhythm.of(wakeMinute: null, bedMinute: at(22)), isNull);
    });

    test('no bedtime', () {
      expect(DayRhythm.of(wakeMinute: at(7), bedMinute: null), isNull);
    });

    test('a wake time and a bedtime too close together', () {
      expect(DayRhythm.of(wakeMinute: at(7), bedMinute: at(14)), isNull,
          reason: 'seven hours awake says one of the two is wrong');
      expect(DayRhythm.of(wakeMinute: at(7), bedMinute: at(16, 59)), isNull);
      expect(DayRhythm.of(wakeMinute: at(7), bedMinute: at(17)), isNotNull);
    });

    test('a bedtime equal to the wake time is a full day, not a zero one', () {
      expect(DayRhythm.of(wakeMinute: at(7), bedMinute: at(7)), isNotNull,
          reason: 'bed at or before wake means after midnight');
    });
  });

  group('the words', () {
    test('every phase has a label and a note, and no verdict in them', () {
      for (final p in RhythmPhase.values) {
        expect(DayRhythm.label(p), isNotEmpty);
        expect(DayRhythm.note(p), isNotEmpty);
        for (final banned in ['should', 'must', 'diagnos', 'healthy', 'unhealthy']) {
          expect(DayRhythm.note(p).toLowerCase(), isNot(contains(banned)),
              reason: p.name);
        }
      }
    });

    test('the focus label says "often", not "is"', () {
      expect(DayRhythm.label(RhythmPhase.focus), contains('Often'));
    });
  });
}
