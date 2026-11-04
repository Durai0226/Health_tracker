import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/health/bp_tags.dart';
import '../../../core/health/vitals_analyzer.dart';
import '../models/blood_pressure_reading.dart';
import '../models/glucose_reading.dart';
import 'bp_sessions.dart';
import 'report_pdf_parts.dart';

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

    // Average and breakdown are per measurement SESSION (readings taken within
    // 10 minutes count once); the table below still lists every raw reading.
    final sessions = BpSessions.collapse(sorted);
    final averaged = sessions.length != sorted.length;
    final avgSys = VitalsAnalyzer.mean(sessions.map((r) => r.systolic).toList());
    final avgDia = VitalsAnalyzer.mean(sessions.map((r) => r.diastolic).toList());

    final counts = <BpCategory, int>{};
    for (final r in sessions) {
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
          caption: averaged
              ? 'Average of ${sessions.length} measurements '
                  '(${sorted.length} readings; readings within 10 minutes '
                  'are averaged into one)'
              : 'Average of ${sorted.length} readings',
        ),
        pw.SizedBox(height: 18),
        pw.Text('Category breakdown',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _table(
          ['Category', averaged ? 'Measurements' : 'Readings'],
          BpCategory.values
              .where((c) => (counts[c] ?? 0) > 0)
              .map((c) => [VitalsAnalyzer.bpLabel(c), '${counts[c]}'])
              .toList(),
        ),
        pw.SizedBox(height: 18),
        pw.Text('Readings',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        // A "Circumstances" column only when some reading has any: a doctor reading
        // a fortnight of numbers wants to know which were after a coffee or a run,
        // and an empty column on a report with no tags is just noise.
        _table(
          [
            'Date',
            'BP (mm Hg)',
            'Pulse',
            'Category',
            if (sorted.any((r) => r.tags.isNotEmpty)) 'Circumstances',
          ],
          sorted
              .map((r) => [
                    _fmt(r.takenAt),
                    '${r.systolic}/${r.diastolic}',
                    r.pulse?.toString() ?? '-',
                    VitalsAnalyzer.bpLabel(r.category),
                    if (sorted.any((x) => x.tags.isNotEmpty))
                      r.tags.isEmpty ? '-' : BpTags.describe(r.tags),
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

    /// The unit the person reads their own glucose in. Storage and every
    /// calculation stay mg/dL; only what is printed changes.
    GlucoseUnit unit = GlucoseUnit.mgdl,
  }) async {
    final doc = pw.Document();
    final now = generatedAt ?? DateTime.now();
    final sorted = [...readings]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final unitLabel = VitalsAnalyzer.glucoseUnitLabel(unit);

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
          big: avg != null ? VitalsAnalyzer.formatGlucose(avg.round(), unit) : '-',
          unit: '$unitLabel avg',
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
          ['Date', 'Glucose ($unitLabel)', 'Context', 'Class'],
          sorted
              .map((r) => [
                    _fmt(r.takenAt),
                    VitalsAnalyzer.formatGlucose(r.valueMgdl, unit),
                    VitalsAnalyzer.glucoseContextLabel(r.context),
                    VitalsAnalyzer.glucoseLabel(r.glucoseClass),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 20),
        _disclaimer(
            unit == GlucoseUnit.mmoll
                ? 'Targets follow ADA guidance (fasting 4.4-7.2, post-meal <10.0 '
                    'mmol/L). '
                : 'Targets follow ADA guidance (fasting 80-130, post-meal <180 mg/dL). '
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
    return ReportPdfParts.header(
        title: title, patient: patient, period: range, generated: _fmtDate(now));
  }

  static pw.Widget _summaryBox(
          {required String big, required String unit, required String caption}) =>
      ReportPdfParts.summaryBox(big: big, unit: unit, caption: caption);

  static pw.Widget _table(List<String> headers, List<List<String>> rows) =>
      ReportPdfParts.table(headers, rows);

  static pw.Widget _disclaimer(String text) => pw.Text(text,
      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600));

  static String _fmt(DateTime d) =>
      '${_fmtDate(d)} ${_2(d.hour)}:${_2(d.minute)}';
  static String _fmtDate(DateTime d) => '${d.year}-${_2(d.month)}-${_2(d.day)}';
  static String _2(int n) => n.toString().padLeft(2, '0');
}
