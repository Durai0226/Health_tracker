import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_strings.dart';
import 'cycle_pattern.dart';
import 'cycle_predictor.dart';

/// A one-page cycle summary to bring to a check-up: the recent cycle and period
/// lengths, their spread, and the pattern note when there is one.
///
/// Pure Dart (the `pdf` package needs no Flutter bindings), so it is testable
/// headlessly; the UI shares the bytes via `printing`. ASCII-only text: the
/// default PDF font has no glyphs for dashes and the like.
///
/// Says what was logged and nothing more. It does not name a condition, and it
/// carries the same "not a diagnosis" line as the card it is made from.
class CycleSummaryReport {
  const CycleSummaryReport._();

  /// Cycles listed, most recent first.
  static const int maxRows = 12;

  static Future<Uint8List> build({
    required List<DerivedCycle> cycles,
    CyclePattern? pattern,
    String? patientName,
    DateTime? generatedAt,
  }) async {
    final doc = pw.Document();
    final now = generatedAt ?? DateTime.now();
    final sorted = [...cycles]..sort((a, b) => b.start.compareTo(a.start));
    final completed = [
      for (final c in sorted)
        if (c.cycleLengthDays != null) c,
    ];

    // The same cycles the table lists, raw: no outlier rejection, so the
    // summary and the rows beneath it cannot disagree.
    final listed = [
      for (final c in completed.take(maxRows)) c.cycleLengthDays!,
    ]..sort();
    final median = listed.isEmpty
        ? null
        : (listed.length.isOdd
            ? listed[listed.length ~/ 2]
            : ((listed[listed.length ~/ 2 - 1] + listed[listed.length ~/ 2]) /
                    2)
                .round());
    final caption = listed.isEmpty
        ? 'No completed cycles logged yet'
        : 'Median of ${listed.length} completed cycle'
            '${listed.length == 1 ? '' : 's'}; shortest ${listed.first}, '
            'longest ${listed.last} days';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
      build: (context) => [
        _header(patientName, now),
        pw.SizedBox(height: 16),
        _summaryBox(
          big: median != null ? '$median' : '-',
          unit: 'day cycle (median)',
          caption: caption,
        ),
        if (pattern != null) ...[
          pw.SizedBox(height: 14),
          _note(pattern.headline, pattern.detail),
        ],
        pw.SizedBox(height: 18),
        pw.Text('Recent cycles',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _table(
          ['Period started', 'Cycle length', 'Period length'],
          [
            for (final c in sorted.take(maxRows))
              [
                _fmtDate(c.start),
                c.cycleLengthDays != null
                    ? '${c.cycleLengthDays} days'
                    : 'current',
                '${c.periodLengthDays} days',
              ],
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
            'Built from the days logged in ${AppStrings.productName}. Lengths '
            'are counted from the first day of one period to the first day of '
            'the next. This is a record of what was logged, not a diagnosis. '
            'Discuss it with your clinician.',
            style:
                const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _header(String? patient, DateTime now) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Cycle Summary',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(AppStrings.productName,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.teal700)),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        if (patient != null && patient.trim().isNotEmpty)
          pw.Expanded(
              child: pw.Text('Patient: $patient',
                  style: const pw.TextStyle(fontSize: 10))),
        pw.Text('Generated: ${_fmtDate(now)}',
            style: const pw.TextStyle(fontSize: 10)),
      ]),
      pw.SizedBox(height: 10),
      pw.Divider(color: PdfColors.grey400, thickness: .5),
    ]);
  }

  static pw.Widget _summaryBox(
      {required String big, required String unit, required String caption}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(big,
            style: pw.TextStyle(
                fontSize: 30,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal800)),
        pw.SizedBox(width: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(unit,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        ),
        pw.Spacer(),
        pw.Expanded(
          child: pw.Text(caption,
              textAlign: pw.TextAlign.right,
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ),
      ]),
    );
  }

  static pw.Widget _note(String headline, String detail) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber300, width: .5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(headline,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(detail, style: const pw.TextStyle(fontSize: 10)),
      ]),
    );
  }

  static pw.Widget _table(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      headerStyle: pw.TextStyle(
          fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal600),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';
  static String _pad2(int n) => n.toString().padLeft(2, '0');
}
