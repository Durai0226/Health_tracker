/// A doctor reading a fortnight of pressures wants to know which were after a
/// coffee or a run.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/services/vitals_report_service.dart';

import '../support/pdf_words.dart';

void main() {
  BloodPressureReading reading(String id, DateTime at,
          {List<String> tags = const [], int sys = 130, int dia = 85}) =>
      BloodPressureReading(
          id: id,
          systolic: sys,
          diastolic: dia,
          takenAt: at,
          createdAt: at,
          tags: tags);

  Future<List<String>> words(List<BloodPressureReading> r) async => pdfWords(
      await VitalsReportService.buildBpPdf(
          readings: r, generatedAt: DateTime(2026, 6, 20)));

  test('a reading\'s circumstances are on the report', () async {
    final w = await words([
      reading('a', DateTime(2026, 6, 19, 8), tags: ['after_exercise', 'stressed']),
      reading('b', DateTime(2026, 6, 18, 8)),
    ]);
    expect(w, contains('Circumstances'));
    expect(w.join(' '), contains('After exercise, Stressed'));
  });

  test('a reading with none is a dash, so the rows line up', () async {
    final w = await words([
      reading('a', DateTime(2026, 6, 19, 8), tags: ['after_caffeine']),
      reading('b', DateTime(2026, 6, 18, 8)),
    ]);
    expect(w, contains('-'));
  });

  test('a tag this build does not know is still said', () async {
    final w = await words([reading('a', DateTime(2026, 6, 19, 8), tags: ['after_swim'])]);
    expect(w.join(' '), contains('After swim'));
  });

  test('no tags anywhere: no empty column', () async {
    final w = await words([
      reading('a', DateTime(2026, 6, 19, 8)),
      reading('b', DateTime(2026, 6, 18, 8)),
    ]);
    expect(w, isNot(contains('Circumstances')),
        reason: 'a column of dashes on a report with nothing to say is noise');
    expect(w, contains('Category'), reason: 'the rest of the table is as it was');
  });

  test('the category and the numbers are untouched by a tag', () async {
    final tagged = await words([reading('a', DateTime(2026, 6, 19, 8), tags: ['stressed'])]);
    final plain = await words([reading('a', DateTime(2026, 6, 19, 8))]);
    for (final needed in ['130/85']) {
      expect(tagged, contains(needed));
      expect(plain, contains(needed));
    }
    expect(tagged.where((x) => x.contains('Stage') || x.contains('Elevated')).length,
        plain.where((x) => x.contains('Stage') || x.contains('Elevated')).length,
        reason: 'a circumstance is context, not a correction');
  });
}
