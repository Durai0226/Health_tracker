/// The vitals and mood reports are made of the same header, summary box and table.
///
/// They were written out in each service, word for word, and a change to how a report
/// looks had to be made in each. This reads the two services: neither builds those
/// pieces itself any more, and both still produce a document.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String code(String path) => File(path)
      .readAsLinesSync()
      .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
      .join('\n');

  for (final path in [
    'lib/features/medication/services/vitals_report_service.dart',
    'lib/features/medication/services/mood_report_service.dart',
  ]) {
    test('${path.split('/').last} builds them through ReportPdfParts', () {
      final source = code(path);

      expect(source, contains('ReportPdfParts.header('));
      expect(source, contains('ReportPdfParts.summaryBox('));
      expect(source, contains('ReportPdfParts.table('));
      expect(source, isNot(contains('TableHelper.fromTextArray')),
          reason: 'the table is the shared one');
      expect(source, isNot(contains('PdfColors.teal50')),
          reason: 'nor is the summary box written out again here');
    });
  }
}
