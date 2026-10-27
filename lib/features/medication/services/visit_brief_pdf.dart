import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_strings.dart';
import '../models/enhanced_medicine.dart';
import 'adherence_report_service.dart';
import 'visit_brief_service.dart';

/// The visit brief on one page, to hand over or send ahead.
///
/// One page by construction rather than by luck: the medicines are capped at
/// [maxMedicines] and the discussion points at [maxDiscuss], with a line saying
/// how many were left out, so a long list cannot spill onto a second sheet.
class VisitBriefPdf {
  const VisitBriefPdf._();

  static const int maxMedicines = 10;
  static const int maxDiscuss = 6;

  static Future<Uint8List> build(VisitBrief b) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(b),
            if (b.discuss.isNotEmpty) ..._discuss(b),
            ..._doses(b),
            if (b.hasVitals) ..._vitals(b),
            if (b.started.isNotEmpty || b.stopped.isNotEmpty) ..._changes(b),
            pw.Spacer(),
            pw.Text(
              'Adherence = doses marked taken / doses due over the period. Made by '
              "${AppStrings.productName} from the patient's own logs, for discussion "
              'with a clinician. It is not medical advice.',
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _header(VisitBrief b) {
    final a = b.appointment;
    final w = b.window;
    final covers = w.sinceVisit != null
        ? 'since your last visit on ${_date(w.sinceVisit!)} (${w.days} days)'
        : 'the last ${w.days} days';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Visit brief',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Text(AppStrings.productName,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.teal700)),
        pw.SizedBox(height: 10),
        if (b.patientName != null && b.patientName!.trim().isNotEmpty)
          pw.Text('Patient: ${b.patientName}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
            'Visit: ${a.doctorName}, ${_date(a.dateTime)} at ${_time(a.dateTime)}'
            '${(a.location ?? '').trim().isEmpty ? '' : ', ${a.location!.trim()}'}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Covers: $covers', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Made: ${_date(b.generatedAt)}', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey400, thickness: .5),
      ],
    );
  }

  static List<pw.Widget> _discuss(VisitBrief b) {
    final shown = b.discuss.take(maxDiscuss).toList();
    final more = b.discuss.length - shown.length;
    return [
      _heading('To discuss'),
      for (final d in shown)
        pw.Bullet(text: d, style: const pw.TextStyle(fontSize: 10), bulletSize: 3),
      if (more > 0)
        pw.Text('and $more more', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ];
  }

  static List<pw.Widget> _doses(VisitBrief b) {
    final pct = b.overallPercent;
    if (b.medicines.isEmpty) {
      return [
        _heading('Doses'),
        pw.Text('No medicines were being taken in this period.',
            style: const pw.TextStyle(fontSize: 10)),
      ];
    }
    final shown = b.medicines.take(maxMedicines).toList();
    final more = b.medicines.length - shown.length;
    String label(MedicineAdherence m) {
      final s = m.medicine.strength;
      return (s != null && s.trim().isNotEmpty) ? '${m.medicine.name} $s' : m.medicine.name;
    }

    return [
      _heading('Doses'),
      pw.Text(
        pct == null
            ? 'No scheduled doses came due in this period.'
            : '$pct% of scheduled doses taken: ${b.taken} of ${b.due}, '
                '${b.missed} missed, ${b.skipped} skipped.',
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: const ['Medication', 'Adherence', 'Taken', 'Missed', 'Skipped'],
        data: [
          for (final m in shown)
            [
              label(m),
              m.percent == null ? '-' : '${m.percent}%',
              '${m.taken}',
              '${m.missed}',
              '${m.skipped}',
            ],
        ],
        border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
        headerStyle: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.teal600),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.center,
          3: pw.Alignment.center,
          4: pw.Alignment.center,
        },
      ),
      if (more > 0)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text('and $more more medicines',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ),
    ];
  }

  static List<pw.Widget> _vitals(VisitBrief b) {
    final bp = b.bp;
    final g = b.glucose;
    final w = b.weight;
    pw.Widget line(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(s, style: const pw.TextStyle(fontSize: 10)));
    return [
      _heading('Readings'),
      if (bp != null)
        line('Blood pressure: average ${bp.avgSystolic}/${bp.avgDiastolic} mmHg over '
            '${bp.sessions} measurement${bp.sessions == 1 ? '' : 's'} '
            '(systolic ${bp.minSystolic} to ${bp.maxSystolic}, '
            'diastolic ${bp.minDiastolic} to ${bp.maxDiastolic}).'),
      if (g != null)
        line('Blood sugar: average ${g.avgMgdl} mg/dL over ${g.readings} '
            'reading${g.readings == 1 ? '' : 's'} (${g.minMgdl} to ${g.maxMgdl})'
            '${g.inRangePercent == null ? '' : ', ${g.inRangePercent}% in target'}.'),
      if (w != null)
        line(w.readings == 1
            ? 'Weight: ${_kg(w.lastKg)} kg (one reading).'
            : 'Weight: ${_kg(w.firstKg)} to ${_kg(w.lastKg)} kg '
                '(${w.changeKg >= 0 ? '+' : '-'}${_kg(w.changeKg.abs())} kg).'),
    ];
  }

  static List<pw.Widget> _changes(VisitBrief b) {
    String names(List<EnhancedMedicine> ms) => ms.map((m) => m.name).join(', ');
    return [
      _heading('Changes in this period'),
      if (b.started.isNotEmpty)
        pw.Text('Started: ${names(b.started)}', style: const pw.TextStyle(fontSize: 10)),
      if (b.stopped.isNotEmpty)
        pw.Text('Stopped or put away: ${names(b.stopped)}',
            style: const pw.TextStyle(fontSize: 10)),
    ];
  }

  static String _kg(double kg) => kg.toStringAsFixed(1);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}
