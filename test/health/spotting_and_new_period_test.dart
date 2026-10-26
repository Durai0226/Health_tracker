import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';
import 'package:tablet_remainder/features/period/services/new_period_check.dart';

/// Flow indices: 0 none, 1 spotting, 2 light, 3 medium, 4 heavy.
const spot = 1, light = 2, medium = 3, heavy = 4;

void main() {
  DateTime d(int month, int day) => DateTime(2026, month, day);
  FlowDay f(int month, int day, int flow) => FlowDay(d(month, day), flow);

  group('spotting does not start a period', () {
    test('a lone day of spotting creates no cycle at all', () {
      expect(CyclePredictor.deriveCycles([f(3, 5, spot)]), isEmpty);
    });

    test('a spotting day mid-cycle does not split or add a cycle', () {
      final cycles = CyclePredictor.deriveCycles([
        f(3, 1, heavy), f(3, 2, medium), f(3, 3, light),
        f(3, 14, spot), // a mid-cycle smear
        f(3, 29, heavy), f(3, 30, medium),
      ]);
      expect(cycles.map((c) => c.start), [d(3, 1), d(3, 29)]);
      expect(cycles.first.cycleLengthDays, 28,
          reason: 'the smear on the 14th must not have started a cycle');
    });

    test('spotting BEFORE the first light day does not begin the period', () {
      final cycles = CyclePredictor.deriveCycles([
        f(3, 1, spot), f(3, 2, spot), f(3, 3, light), f(3, 4, heavy),
      ]);
      expect(cycles.single.start, d(3, 3));
    });

    test('a light day still starts one, as before', () {
      expect(CyclePredictor.deriveCycles([f(3, 5, light)]).single.start, d(3, 5));
    });
  });

  group('the spotting tail', () {
    test('spotting straight after a period belongs to it', () {
      final c = CyclePredictor.deriveCycles([
        f(3, 1, heavy), f(3, 2, medium), f(3, 3, light),
        f(3, 4, spot), f(3, 5, spot),
      ]).single;
      expect(c.periodLengthDays, 5);
    });

    test('spotting after a gap is not a tail', () {
      final c = CyclePredictor.deriveCycles([
        f(3, 1, heavy), f(3, 2, medium), f(3, 3, light),
        f(3, 6, spot), f(3, 7, spot), // not contiguous with the 3rd
      ]).single;
      expect(c.periodLengthDays, 3);
    });

    test('a tail runs up to the next period but never merges the two', () {
      final cycles = CyclePredictor.deriveCycles([
        f(3, 1, heavy), f(3, 2, light),
        f(3, 3, spot), f(3, 4, spot), f(3, 5, spot), // tail up to the 5th
        f(3, 6, heavy), f(3, 7, medium),             // a separate run
      ]);
      expect(cycles.length, 2, reason: 'spotting must not fuse two periods');
      expect(cycles.first.periodLengthDays, 5, reason: 'two flow days + tail');
      expect(cycles.last.start, d(3, 6));
    });

    test('spotting is never counted as a tail beyond the next run', () {
      final cycles = CyclePredictor.deriveCycles([
        f(3, 1, heavy), f(3, 2, light),
        f(3, 3, spot),
        f(3, 20, heavy), f(3, 21, light),
      ]);
      expect(cycles.length, 2);
      expect(cycles.first.periodLengthDays, 3, reason: 'light, heavy + the tail');
      expect(cycles.first.cycleLengthDays, 19);
    });
  });

  group('NewPeriodCheck.tooSoon', () {
    // A real period 1-4 March.
    final base = [f(3, 1, heavy), f(3, 2, medium), f(3, 3, light), f(3, 4, light)];

    int? check(DateTime date, int flow, [List<FlowDay>? days]) =>
        NewPeriodCheck.tooSoon(days: days ?? base, date: date, flowIndex: flow);

    test('a light day 9 days after the last start is questioned', () {
      expect(check(d(3, 10), light), 9);
    });

    test('exactly 18 days is a normal short cycle, no question', () {
      expect(check(d(3, 19), light), isNull);
      expect(check(d(3, 18), light), 17);
    });

    test('a long cycle is not questioned', () {
      expect(check(d(3, 29), medium), isNull);
    });

    test('spotting and no-flow never need a question', () {
      expect(check(d(3, 10), spot), isNull);
      expect(check(d(3, 10), 0), isNull);
    });

    test('a day that CONTINUES the current period is not a start', () {
      expect(check(d(3, 5), light), isNull);
      expect(check(d(3, 6), medium), isNull, reason: 'one skipped day is tolerated');
    });

    test('the first period ever has nothing to compare against', () {
      expect(check(d(3, 10), light, const []), isNull);
    });

    test('re-saving an existing period day is not a new start', () {
      expect(check(d(3, 1), heavy), isNull);
      expect(check(d(3, 3), heavy), isNull);
    });

    test('it measures from the MOST RECENT previous start', () {
      final two = [...base, f(3, 29, heavy), f(3, 30, light)];
      // 5 April is 7 days after the 29 March start, though 35 after 1 March.
      expect(check(DateTime(2026, 4, 5), light, two), 7);
    });

    test('the count is calendar days across a DST change', () {
      // US clocks sprang forward on 8 March 2026: 1 March -> 18 March is 17
      // calendar days, which a 24-hour Duration would report as 16.
      expect(check(d(3, 18), light), 17);
    });

    test('a backdated day before an existing period is judged against what '
        'precedes it', () {
      final later = [...base, f(4, 1, heavy), f(4, 2, light)];
      // 10 March sits between the two periods: 9 days after the 1 March start.
      expect(check(d(3, 10), light, later), 9);
    });
  });
}
