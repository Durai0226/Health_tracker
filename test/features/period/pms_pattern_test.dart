/// "Cramps usually start 3 days before (4 of 5 cycles)": what the person's own
/// log says about the week before a period, and the three reasons it keeps
/// quiet: too few cycles, a symptom that is always there, and no days logged
/// outside the week to compare against.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';
import 'package:tablet_remainder/features/period/services/pms_pattern.dart';

void main() {
  // Five completed 28-day cycles with 5-day periods, then an open one.
  final starts = [
    for (var i = 0; i <= 5; i++) DateTime(2026, 1, 1 + 28 * i),
  ];
  final cycles = [
    for (var i = 0; i < 5; i++)
      DerivedCycle(
        start: starts[i],
        end: DateTime(starts[i].year, starts[i].month, starts[i].day + 27),
        cycleLengthDays: 28,
        periodLengthDays: 5,
      ),
    DerivedCycle(start: starts[5], periodLengthDays: 5),
  ];

  /// [n] days before cycle [i]'s next period.
  DateTime before(int i, int n) =>
      DateTime(starts[i + 1].year, starts[i + 1].month, starts[i + 1].day - n);

  PeriodDay day(DateTime d, [List<String> symptoms = const [], int? mood]) =>
      PeriodDay(
        id: PeriodDay.keyFor(d),
        date: d,
        symptomIds: symptoms,
        mood: mood ?? (symptoms.isEmpty ? 3 : null),
      );

  /// Days well clear of both the period and the window, so there is a baseline.
  List<PeriodDay> baseline(int i, {List<String> symptoms = const []}) => [
        for (final off in [8, 10, 12, 14, 16])
          day(DateTime(starts[i].year, starts[i].month, starts[i].day + off),
              symptoms),
      ];

  /// Cramps from [onset] days before, to the day before, in cycle [i].
  List<PeriodDay> cramps(int i, int onset, {String id = 'cramps'}) => [
        for (var n = onset; n >= 1; n--) day(before(i, n), [id]),
      ];

  /// Quiet logged days in the window, so a cycle counts without the symptom.
  List<PeriodDay> quietWindow(int i) =>
      [for (final n in [5, 3, 1]) day(before(i, n))];

  List<PmsSymptom> run(List<PeriodDay> days) =>
      PmsPatternCheck.check(days: days, cycles: cycles);

  group('a pattern', () {
    test('cramps, usually from 3 days before, in 4 of 5 cycles', () {
      final days = [
        for (var i = 0; i < 4; i++) ...cramps(i, 3),
        ...quietWindow(4),
        for (var i = 0; i < 5; i++) ...baseline(i),
      ];
      final out = run(days);
      expect(out, hasLength(1));
      expect(out.single.symptomId, 'cramps');
      expect(out.single.cyclesWith, 4);
      expect(out.single.cyclesCounted, 5);
      expect(out.single.typicalDaysBefore, 3);
      expect(out.single.line,
          'Cramps: usually from 3 days before (4 of 5 cycles)');
    });

    test('the usual onset is the middle one, rounded', () {
      // 3, 3, 4, 5 days before, and one cycle without it.
      final days = [
        ...cramps(0, 3),
        ...cramps(1, 3),
        ...cramps(2, 4),
        ...cramps(3, 5),
        ...quietWindow(4),
        for (var i = 0; i < 5; i++) ...baseline(i),
      ];
      expect(run(days).single.typicalDaysBefore, 4,
          reason: 'median of 3, 3, 4, 5 is 3.5');
    });

    test('"the day before" for an onset of one', () {
      final days = [
        for (var i = 0; i < 5; i++) ...[
          day(before(i, 1), ['cramps']),
          day(before(i, 3)),
          day(before(i, 5)),
          ...baseline(i),
        ],
      ];
      expect(run(days).single.line,
          'Cramps: usually from the day before (5 of 5 cycles)');
    });

    test('at most three are reported, the most consistent first', () {
      final days = [
        for (var i = 0; i < 5; i++) ...[
          ...cramps(i, 2, id: 'cramps'),
          day(before(i, 4), ['bloating']),
          if (i < 4) day(before(i, 5), ['fatigue']),
          if (i < 3) day(before(i, 6), ['irritable']),
          if (i < 5) day(before(i, 7), ['acne']),
          ...baseline(i),
        ],
      ];
      final out = run(days);
      expect(out, hasLength(3));
      expect(out.map((s) => s.cyclesWith), [5, 5, 5],
          reason: 'cramps, bloating and acne are in all five; fatigue (4) and '
              'irritable (3) are cut');
    });
  });

  group('and the reasons it says nothing', () {
    test('under three cycles with enough logging in the week', () {
      final days = [
        ...cramps(0, 3),
        ...cramps(1, 3),
        // The other three cycles have a day or two logged: not enough to count.
        day(before(2, 2), ['cramps']),
        day(before(3, 1)),
        for (var i = 0; i < 5; i++) ...baseline(i),
      ];
      expect(run(days), isEmpty);
    });

    test('a symptom that is always there is not a pre-period pattern', () {
      final days = [
        for (var i = 0; i < 5; i++) ...[
          ...cramps(i, 3, id: 'headache'),
          ...baseline(i, symptoms: ['headache']),
        ],
      ];
      expect(run(days), isEmpty,
          reason: 'logged every day in the week AND every day outside it');
    });

    test('but one that is twice as common before the period is', () {
      final days = [
        for (var i = 0; i < 5; i++) ...[
          ...cramps(i, 3, id: 'headache'),
          // Logged on 2 of the 5 baseline days: 40%, against 100% before.
          ...baseline(i, symptoms: const []).take(3),
          ...baseline(i, symptoms: ['headache']).skip(3),
        ],
      ];
      expect(run(days).map((s) => s.symptomId), ['headache']);
    });

    test('with no days logged outside the week there is nothing to compare',
        () {
      final days = [for (var i = 0; i < 5; i++) ...cramps(i, 3)];
      expect(run(days), isEmpty,
          reason: 'someone who only opens the log when it hurts would "have" '
              'a pattern in whatever week they opened it');
    });

    test('a symptom in too few of the cycles', () {
      final days = [
        ...cramps(0, 3),
        ...cramps(1, 3),
        ...quietWindow(2),
        ...quietWindow(3),
        ...quietWindow(4),
        for (var i = 0; i < 5; i++) ...baseline(i),
      ];
      expect(run(days), isEmpty, reason: '2 of 5 is under 60%');
    });

    test('three of five is enough', () {
      final days = [
        ...cramps(0, 3),
        ...cramps(1, 3),
        ...cramps(2, 3),
        ...quietWindow(3),
        ...quietWindow(4),
        for (var i = 0; i < 5; i++) ...baseline(i),
      ];
      expect(run(days).single.cyclesWith, 3);
    });

    test('no cycles, or no days, says nothing', () {
      expect(PmsPatternCheck.check(days: const [], cycles: cycles), isEmpty);
      expect(PmsPatternCheck.check(days: [day(starts[0])], cycles: const []),
          isEmpty);
    });
  });

  test('a day that only carries a mood still counts as a day logged', () {
    // The quiet window days above are exactly that: mood 3, no symptom.
    final days = [
      for (var i = 0; i < 3; i++) ...cramps(i, 3),
      ...quietWindow(3),
      ...quietWindow(4),
      for (var i = 0; i < 5; i++) ...baseline(i),
    ];
    expect(run(days).single.cyclesCounted, 5);
  });
}
