import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/ai/vitals_analyzer.dart';
import '../models/blood_pressure_reading.dart';
import '../models/glucose_reading.dart';

/// Doctor-ready PDF exports for the vitals trackers. Pure Dart (the `pdf`
/// package needs no Flutter bindings) so it is unit-testable headlessly; the UI
/// shares the bytes via `printing`. ASCII-only text (default PDF font).
class VitalsReportService {
  const VitalsReportService._();

  // ---- Blood pressure ------------------------------------------------------

  static Future<Uint8List> buildBpPdf({
    required List<BloodPressureReading> readings,
    DateTime? from,
    DateTime? to,
    String? patientName,
    DateTime? generatedAt,
  }) async {
    final doc = pw.Document();
    final now = generatedAt ?? DateTime.now();
    final sorted = [...readings]..sort((a, b) => b.takenAt.compareTo(a.takenAt));

    final avgSys = VitalsAnalyzer.mean(sorted.map((r) => r.systolic).toList());
    final avgDia = VitalsAnalyzer.mean(sorted.map((r) => r.diastolic).toList());

    final counts = <BpCategory, int>{};
    for (final r in sorted) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
      build: (context) => [
        _header('Blood Pressure Report', patientName, from, to, now),
        pw.SizedBox(height: 16),
        _summaryBox(
          big: avgSys != null ? '${avgSys.round()}/${avgDia!.round()}' : '-',
          unit: 'mm Hg',
          caption: 'Average of ${sorted.length} readings',
        ),
        pw.SizedBox(height: 18),
        pw.Text('Category breakdown',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _table(
          ['Category', 'Readings'],
          BpCategory.values
              .where((c) => (counts[c] ?? 0) > 0)
              .map((c) => [VitalsAnalyzer.bpLabel(c), '${counts[c]}'])
              .toList(),
        ),
        pw.SizedBox(height: 18),
        pw.Text('Readings',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _table(
          ['Date', 'BP (mm Hg)', 'Pulse', 'Category'],
          sorted
              .map((r) => [
                    _fmt(r.takenAt),
                    '${r.systolic}/${r.diastolic}',
                    r.pulse?.toString() ?? '-',
                    VitalsAnalyzer.bpLabel(r.category),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 20),
        _disclaimer(
            'Categories follow the AHA/ACC 2017 guideline. This report classifies '
            'readings from self-measurement; it is not a diagnosis. Discuss with '
            'your clinician.'),
      ],
    ));
    return doc.save();
  }

  // ---- Blood glucose -------------------------------------------------------

  static Future<Uint8List> buildGlucosePdf({
    required List<GlucoseReading> readings,
    DateTime? from,
    DateTime? to,
    String? patientName,
    DateTime? generatedAt,
  }) async {
    final doc = pw.Document();
    final now = generatedAt ?? DateTime.now();
    final sorted = [...readings]..sort((a, b) => b.takenAt.compareTo(a.takenAt));

    final avg = VitalsAnalyzer.mean(sorted.map((r) => r.valueMgdl).toList());
    final eA1c = VitalsAnalyzer.estimatedA1c(
        sorted.map((r) => r.valueMgdl).toList());
    final inRange = VitalsAnalyzer.inRangePercent(
        sorted.map((r) => (mgdl: r.valueMgdl, ctx: r.context)).toList());

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
      build: (context) => [
        _header('Blood Glucose Report', patientName, from, to, now),
        pw.SizedBox(height: 16),
        _summaryBox(
          big: avg != null ? '${avg.round()}' : '-',
          unit: 'mg/dL avg',
          caption: [
            '${sorted.length} readings',
            if (inRange != null) '${(inRange * 100).round()}% in range',
            if (eA1c != null) 'est. A1C ${eA1c.toStringAsFixed(1)}%',
          ].join('  -  '),
        ),
        pw.SizedBox(height: 18),
        pw.Text('Readings',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _table(
          ['Date', 'Glucose (mg/dL)', 'Context', 'Class'],
          sorted
              .map((r) => [
                    _fmt(r.takenAt),
                    '${r.valueMgdl}',
                    VitalsAnalyzer.glucoseContextLabel(r.context),
                    VitalsAnalyzer.glucoseLabel(r.glucoseClass),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 20),
        _disclaimer(
            'Targets follow ADA guidance (fasting 80-130, post-meal <180 mg/dL). '
            'Estimated A1C = (mean glucose + 46.7) / 28.7 and is an estimate, not '
            'a lab result. Not a diagnosis; discuss with your clinician.'),
      ],
    ));
    return doc.save();
  }

  // ---- Shared PDF helpers --------------------------------------------------

  static pw.Widget _header(String title, String? patient, DateTime? from,
      DateTime? to, DateTime now) {
    final range = (from != null && to != null)
        ? '${_fmtDate(from)} to ${_fmtDate(to)}'
        : 'All recorded readings';
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('DailyMinder', style: const pw.TextStyle(fontSize: 11, color: PdfColors.teal700)),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        if (patient != null && patient.trim().isNotEmpty)
          pw.Expanded(child: pw.Text('Patient: $patient', style: const pw.TextStyle(fontSize: 10))),
        pw.Expanded(child: pw.Text('Period: $range', style: const pw.TextStyle(fontSize: 10))),
        pw.Text('Generated: ${_fmtDate(now)}', style: const pw.TextStyle(fontSize: 10)),
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
                fontSize: 30, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
        pw.SizedBox(width: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(unit, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        ),
        pw.Spacer(),
        pw.Expanded(
          child: pw.Text(caption,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ),
      ]),
    );
  }

  static pw.Widget _table(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal600),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  static pw.Widget _disclaimer(String text) => pw.Text(text,
      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600));

  static String _fmt(DateTime d) =>
      '${_fmtDate(d)} ${_2(d.hour)}:${_2(d.minute)}';
  static String _fmtDate(DateTime d) => '${d.year}-${_2(d.month)}-${_2(d.day)}';
  static String _2(int n) => n.toString().padLeft(2, '0');
}
