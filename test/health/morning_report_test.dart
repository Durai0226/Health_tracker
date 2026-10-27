/// One Today card in the morning: last night against the usual, the debt, the
/// body check and at most one suggestion.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/morning_report.dart';
import 'package:tablet_remainder/core/health/overnight_body.dart';
import 'package:tablet_remainder/core/health/sleep_debt.dart';

void main() {
  /// A week of nights at [minutes] each: the usual.
  List<int> usual(int minutes, {int n = 7}) => [for (var i = 0; i < n; i++) minutes];

  OvernightBodyCheck body(int off, {int checked = 4}) {
    List<double> steady(double v) =>
        [for (var i = 0; i < 14; i++) v + (i.isEven ? 1 : -1)];
    final signals = BodySignal.values.take(checked).toList();
    return OvernightBodyCheck.evaluate(
      last: {
        for (var i = 0; i < signals.length; i++)
          signals[i]: i < off ? 200.0 : 50.0,
      },
      history: {for (final s in signals) s: steady(50)},
    )!;
  }

  group('last night', () {
    test('against the usual: under', () {
      final r = MorningReport.build(
          lastNightMinutes: 400, earlierNights: usual(445))!;
      expect(r.lines.first, 'You slept 6h 40m — 45 min under your usual 7h 25m.');
    });

    test('over', () {
      final r = MorningReport.build(
          lastNightMinutes: 505, earlierNights: usual(445))!;
      expect(r.lines.first, 'You slept 8h 25m — 1 h over your usual 7h 25m.');
    });

    test('about the usual, within a quarter of an hour either way', () {
      for (final m in [430, 445, 460]) {
        final r = MorningReport.build(lastNightMinutes: m, earlierNights: usual(445))!;
        expect(r.lines.first, contains('about your usual 7h 25m'), reason: '$m');
      }
      expect(
          MorningReport.build(lastNightMinutes: 429, earlierNights: usual(445))!
              .lines
              .first,
          contains('under'));
    });

    test('without enough nights, no usual is claimed', () {
      final r = MorningReport.build(
          lastNightMinutes: 400, earlierNights: usual(445, n: 4))!;
      expect(r.lines.first, 'You slept 6h 40m.');
    });

    test('and no night at all is no report', () {
      expect(MorningReport.build(lastNightMinutes: 0, earlierNights: usual(445)),
          isNull);
    });
  });

  group('the other lines', () {
    const debt = SleepDebtResult(
        debtMinutes: 130, nights: 10, catchUp: SleepCatchUp(20, 7));

    test('debt, when there is enough of it and it is over enough nights', () {
      final r = MorningReport.build(
          lastNightMinutes: 440, earlierNights: usual(445), debt: debt)!;
      expect(r.lines, contains(debt.behindLine));
    });

    test('under 30 minutes is not worth a line', () {
      const small = SleepDebtResult(
          debtMinutes: 29, nights: 10, catchUp: SleepCatchUp(5, 7));
      final r = MorningReport.build(
          lastNightMinutes: 440, earlierNights: usual(445), debt: small)!;
      expect(r.lines, hasLength(1));
    });

    test('nor over fewer than four nights', () {
      const few = SleepDebtResult(
          debtMinutes: 130, nights: 3, catchUp: SleepCatchUp(20, 7));
      expect(
          MorningReport.build(
                  lastNightMinutes: 440, earlierNights: usual(445), debt: few)!
              .lines,
          hasLength(1));
    });

    test('the body check\'s own headline', () {
      final b = body(1);
      final r = MorningReport.build(
          lastNightMinutes: 440, earlierNights: usual(445), body: b)!;
      expect(r.lines.last, b.headline);
    });
  });

  group('the one suggestion', () {
    const debt = SleepDebtResult(
        debtMinutes: 130, nights: 10, catchUp: SleepCatchUp(20, 7));

    test('none when nothing calls for one', () {
      final r = MorningReport.build(
          lastNightMinutes: 440, earlierNights: usual(445))!;
      expect(r.suggestion, isNull);
    });

    test('a lighter day when most signals are off, ahead of everything else', () {
      final r = MorningReport.build(
        lastNightMinutes: 300,
        earlierNights: usual(445),
        debt: debt,
        body: body(3),
      )!;
      expect(r.suggestion, startsWith('Your body signals are off this morning'));
    });

    test('two signals off is not most of them', () {
      final r = MorningReport.build(
          lastNightMinutes: 440, earlierNights: usual(445), body: body(2))!;
      expect(r.suggestion, isNull);
    });

    test('and four checked, not three', () {
      final r = MorningReport.build(
          lastNightMinutes: 440,
          earlierNights: usual(445),
          body: body(3, checked: 3))!;
      expect(r.suggestion, isNull);
    });

    test('debt with a realistic catch-up: extra minutes tonight', () {
      final r = MorningReport.build(
          lastNightMinutes: 440, earlierNights: usual(445), debt: debt)!;
      expect(r.suggestion,
          'Try 20 extra minutes of sleep tonight, and for a week: it clears the debt.');
    });

    test('two weeks when that is the plan', () {
      const long = SleepDebtResult(
          debtMinutes: 300, nights: 14, catchUp: SleepCatchUp(25, 14));
      final r = MorningReport.build(
          lastNightMinutes: 440, earlierNights: usual(445), debt: long)!;
      expect(r.suggestion, contains('for two weeks'));
    });

    test('an hour of debt is where it starts', () {
      SleepDebtResult d(int m) => SleepDebtResult(
          debtMinutes: m, nights: 10, catchUp: const SleepCatchUp(10, 7));
      expect(
          MorningReport.build(
                  lastNightMinutes: 440, earlierNights: usual(445), debt: d(59))!
              .suggestion,
          isNull);
      expect(
          MorningReport.build(
                  lastNightMinutes: 440, earlierNights: usual(445), debt: d(60))!
              .suggestion,
          isNotNull);
    });

    test('debt too big to clear a little at a time suggests nothing', () {
      const big = SleepDebtResult(debtMinutes: 900, nights: 14, catchUp: null);
      final r = MorningReport.build(
          lastNightMinutes: 440, earlierNights: usual(445), debt: big)!;
      expect(r.suggestion, isNull);
      expect(r.lines, contains(big.behindLine), reason: 'but the line is still said');
    });

    test('a short night, with nothing else to say', () {
      final r = MorningReport.build(
          lastNightMinutes: 390, earlierNights: usual(445))!;
      expect(r.suggestion, 'A short night: an earlier one tonight helps most.');
    });

    test('45 minutes under is where "short" starts', () {
      expect(
          MorningReport.build(lastNightMinutes: 401, earlierNights: usual(445))!
              .suggestion,
          isNull);
      expect(
          MorningReport.build(lastNightMinutes: 400, earlierNights: usual(445))!
              .suggestion,
          isNotNull);
    });

    test('without a usual there is no short night to speak of', () {
      final r = MorningReport.build(lastNightMinutes: 240, earlierNights: const [])!;
      expect(r.suggestion, isNull);
    });
  });
}
