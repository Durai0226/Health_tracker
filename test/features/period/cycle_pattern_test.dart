import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/period/services/cycle_pattern.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';

void main() {
  /// Completed cycles with the given lengths, one after another.
  List<DerivedCycle> cycles(List<int> lengths, {int period = 5}) {
    var start = DateTime(2025, 1, 1);
    final out = <DerivedCycle>[];
    for (final l in lengths) {
      out.add(DerivedCycle(
        start: start,
        end: DateTime(start.year, start.month, start.day + l - 1),
        cycleLengthDays: l,
        periodLengthDays: period,
      ));
      start = DateTime(start.year, start.month, start.day + l);
    }
    return out;
  }

  group('too little to say', () {
    test('under four completed cycles says nothing, however odd they are', () {
      expect(CyclePatternCheck.check(cycles([20, 45, 22])), isNull);
      expect(CyclePatternCheck.check(const []), isNull);
    });

    test('the open cycle is not a completed one', () {
      final c = cycles([28, 28, 28]);
      c.add(DerivedCycle(start: DateTime(2025, 6, 1), periodLengthDays: 5));
      expect(CyclePatternCheck.check(c), isNull);
    });

    test('regular cycles say nothing', () {
      expect(CyclePatternCheck.check(cycles([28, 29, 27, 28, 30, 28])), isNull);
    });
  });

  group('varied', () {
    test('a spread of a week is not yet worth a word, eight days is', () {
      expect(CyclePatternCheck.check(cycles([28, 28, 28, 35])), isNull);
      final p = CyclePatternCheck.check(cycles([28, 28, 28, 36]))!;
      expect(p.flags, {CycleFlag.varied});
      expect(p.spread, 8);
    });

    test('names the count, the spread and the range', () {
      final p = CyclePatternCheck.check(cycles([24, 30, 36, 28, 26, 31]))!;
      expect(p.cyclesCounted, 6);
      expect(p.shortest, 24);
      expect(p.longest, 36);
      expect(p.headline, 'Your last 6 cycles varied by 12 days');
      expect(p.detail, contains('They ran from 24 to 36 days.'));
      expect(p.detail, contains('not a diagnosis'));
    });

    test('only the most recent six are looked at', () {
      // An old 50-day cycle, then six steady ones: nothing to say.
      expect(
          CyclePatternCheck.check(cycles([50, 28, 28, 29, 28, 27, 28])), isNull);
    });

    test('and they are taken in date order, whatever order they arrive in', () {
      final c = cycles([50, 28, 28, 29, 28, 27, 28]).reversed.toList();
      expect(CyclePatternCheck.check(c), isNull);
    });
  });

  group('short, long, and long periods', () {
    test('one short cycle is one odd month; two is a pattern', () {
      // 24 against 20 is a spread of 4, so only the shortness can speak.
      expect(CyclePatternCheck.check(cycles([24, 24, 20, 24])), isNull);
      final p = CyclePatternCheck.check(cycles([24, 20, 20, 24]))!;
      expect(p.flags, {CycleFlag.short});
    });

    test('the boundaries: 21 is fine, 20 is short; 38 is fine, 39 is long', () {
      expect(CyclePatternCheck.check(cycles([21, 21, 22, 22])), isNull);
      expect(
          CyclePatternCheck.check(cycles([20, 20, 24, 24]))!.flags,
          contains(CycleFlag.short));
      expect(CyclePatternCheck.check(cycles([38, 38, 36, 36])), isNull);
      expect(
          CyclePatternCheck.check(cycles([39, 39, 36, 36]))!.flags,
          contains(CycleFlag.long));
    });

    test('a long period is counted from the period length, not the cycle', () {
      final p = CyclePatternCheck.check(cycles([28, 28, 28, 28], period: 9))!;
      expect(p.flags, {CycleFlag.longPeriod});
      expect(p.headline, contains('longer than a week'));
      expect(CyclePatternCheck.check(cycles([28, 28, 28, 28], period: 8)),
          isNull);
    });

    test('several can hold at once, and the spread leads', () {
      final p = CyclePatternCheck.check(cycles([19, 19, 40, 41]))!;
      expect(p.flags, containsAll([CycleFlag.varied, CycleFlag.short, CycleFlag.long]));
      expect(p.headline, startsWith('Your last 4 cycles varied by'));
    });
  });
}
