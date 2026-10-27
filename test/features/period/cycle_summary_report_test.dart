/// The one-page cycle summary for a check-up.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/period/services/cycle_pattern.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';
import 'package:tablet_remainder/features/period/services/cycle_summary_report.dart';

import '../../support/pdf_words.dart';

void main() {
  List<DerivedCycle> cycles(List<int> lengths, {int period = 5, bool open = true}) {
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
    if (open) {
      out.add(DerivedCycle(start: start, periodLengthDays: period));
    }
    return out;
  }

  Future<String> text(
    List<DerivedCycle> c, {
    CyclePattern? pattern,
    String? patient,
  }) async =>
      pdfWords(await CycleSummaryReport.build(
        cycles: c,
        pattern: pattern,
        patientName: patient,
        generatedAt: DateTime(2026, 3, 14),
      )).join(' ');

  test('is a PDF', () async {
    final bytes = await CycleSummaryReport.build(cycles: cycles([28, 29, 27]));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('says what it is, when it was made, and that it is not a diagnosis',
      () async {
    final t = await text(cycles([28, 29, 27]));
    expect(t, contains('Cycle Summary'));
    expect(t, contains('Generated: 2026-03-14'));
    expect(t, contains('not a diagnosis'));
  });

  test('the headline figure is the median of the cycles it lists', () async {
    // 27, 28, 29, 30: the median is 28.5, shown as 29 (rounded half up).
    final t = await text(cycles([27, 28, 29, 30]));
    expect(t, contains('29 day cycle (median)'));
    expect(t, contains('Median of 4 completed cycles; shortest 27, longest 30 days'));
  });

  test('an odd count takes the middle one', () async {
    final t = await text(cycles([24, 30, 26]));
    expect(t, contains('26 day cycle (median)'));
    expect(t, contains('Median of 3 completed cycles; shortest 24, longest 30 days'));
  });

  test('with nothing completed it says so rather than printing a figure',
      () async {
    final t = await text(
        [DerivedCycle(start: DateTime(2026, 3, 1), periodLengthDays: 4)]);
    expect(t, contains('No completed cycles logged yet'));
  });

  test('lists each cycle with its start, length and period, newest first',
      () async {
    final c = cycles([28, 30]);
    final t = await text(c);
    // 2025-01-01 (28), 2025-01-29 (30), 2025-02-28 (open).
    final iNew = t.indexOf('2025-02-28');
    final iMid = t.indexOf('2025-01-29');
    final iOld = t.indexOf('2025-01-01');
    expect(iNew, greaterThan(-1));
    expect(iNew, lessThan(iMid));
    expect(iMid, lessThan(iOld));
    expect(t, contains('28 days'));
    expect(t, contains('30 days'));
    expect(t, contains('current'));
  });

  test('is capped at twelve rows', () async {
    final c = cycles(List.filled(20, 28), open: false);
    final t = await text(c);
    // Newest twelve of 20: the first started 2025-01-01, the oldest listed is
    // the ninth.
    expect(t, contains('Median of 12 completed cycles'));
    expect(t, isNot(contains('2025-01-01')));
  });

  test('carries the pattern note when there is one, and only then', () async {
    final c = cycles([24, 30, 36, 28]);
    final pattern = CyclePatternCheck.check(c)!;
    final withNote = await text(c, pattern: pattern);
    expect(withNote, contains('varied by 12 days'));
    expect(withNote, contains('They ran from 24 to 36 days.'));

    final without = await text(cycles([28, 29, 27, 28]));
    expect(without, isNot(contains('varied by')));
  });

  test('names the patient only when given one', () async {
    expect(await text(cycles([28]), patient: 'Ada'), contains('Patient: Ada'));
    expect(await text(cycles([28])), isNot(contains('Patient:')));
  });

  test('is plain ASCII: the default PDF font has no glyphs for the rest',
      () async {
    final c = cycles([24, 30, 36, 28]);
    final t = await text(c, pattern: CyclePatternCheck.check(c));
    expect(t.codeUnits.every((u) => u < 128), isTrue,
        reason: 'a dash or middle dot would print as a box');
  });
}
