import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/health/vitals_analyzer.dart';
import '../models/blood_pressure_reading.dart';
import '../models/drug_interaction.dart';
import '../models/enhanced_medicine.dart';
import '../models/glucose_reading.dart';
import '../models/medicine_log.dart';
import 'drug_interaction_service.dart';
import 'medicine_storage_service.dart';
import 'symptom_report_aggregator.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/calendar_day.dart';
import 'bp_sessions.dart';

/// One medicine + its logs for the report.
class MedicineReportEntry {
  final EnhancedMedicine medicine;
  final List<MedicineLog> logs;
  const MedicineReportEntry({required this.medicine, required this.logs});
}

/// Builds a clinician-shareable medication-adherence PDF from the user's own
/// logs — a doctor-visit export (the headline feature of apps like MyTherapy).
/// Unit-testable headlessly via `flutter test` (see
/// test/health/adherence_report_test.dart); the UI shares the result via
/// `printing`. The `pdf` package itself needs no Flutter UI bindings, though
/// this service also calls into the Drift-backed medicine store (for
/// [MedicineCleanStorageService.dedupeByDose]) and the drug-interaction
/// checker, so it is no longer free of Flutter-package imports the way a
/// strictly pure-Dart file would be.
///
/// Beyond adherence, this is also where Dlyminder beats Medisafe's own
/// doctor report: Medisafe's report covers adherence and measurements, but not
/// side effects, mood/effectiveness trends, or interaction warnings — this
/// document folds all of those into one doctor-visit export instead of
/// leaving them scattered across separate exports (or, for symptoms, nowhere
/// at all — see `symptom_report_aggregator.dart`).
/// The adherence numbers the report prints, separated from the PDF drawing so
/// they can be asserted without parsing a PDF.
///
/// Extracted because a test that only pinned the denominator HELPER stayed
/// green when the call site was reverted to counting log rows — the helper was
/// still right, merely unused. The computation and the thing under test have
/// to be the same code.
class AdherenceTally {
  final List<List<String>> rows;
  final List<MedicineSymptomSummary> symptoms;
  final int totalDue;
  final int totalTaken;
  const AdherenceTally({
    required this.rows,
    required this.symptoms,
    required this.totalDue,
    required this.totalTaken,
  });

  /// The headline percentage, as printed.
  int get overallPct =>
      totalDue > 0 ? (totalTaken / totalDue * 100).round() : 0;
}

class AdherenceReportService {
  const AdherenceReportService._();

  /// Scheduled slots for [med] that actually came due inside the window.
  ///
  /// Mirrors the Adherence screen's denominator (`medicine_storage_service`'s
  /// `scheduled` loop) so the PDF and the screen cannot disagree: past days in
  /// full, today only up to [now], never before the medicine existed, and
  /// PRN medicines excluded by the caller.
  /// The denominator the report divides by, for one medicine.
  ///
  /// Scheduled slots that actually came due — NOT the number of log rows.
  ///
  /// This was `taken + missed + skipped`, which counts only slots that HAVE a
  /// row. A slot the user simply ignored gets no row until
  /// `reconcileMissedDoses` reaches it, and its lookback is 14 days while this
  /// report's window is 30. So three weeks of ignored doses were invisible to
  /// the denominator: the PDF read 100% while the Adherence screen — which
  /// counts slots that came due, logged or not — read about half that. Both
  /// print the identical phrase "scheduled doses taken", and the flattering
  /// number is the one handed to a clinician.
  ///
  /// `medicine_storage_service.dart` states the rule this follows: "the number
  /// of scheduled (non-PRN) doses that were actually due within the window,
  /// NOT logs.length".
  ///
  /// A PRN medicine has no schedule to be due against, so its own logs are the
  /// only measure there is.
  @visibleForTesting
  static int dueCountFor(
    EnhancedMedicine med,
    List<MedicineLog> windowedLogs,
    DateTime? from,
    DateTime? to,
    DateTime now,
  ) {
    if (med.schedule.isPRN) {
      return windowedLogs
          .where((l) => l.countsAsTaken || l.isMissed || l.isSkipped)
          .length;
    }
    return dueSlotCount(med, from, to, now);
  }

  @visibleForTesting
  static int dueSlotCount(
      EnhancedMedicine med, DateTime? from, DateTime? to, DateTime now) {
    if (med.schedule.isPRN) return 0;
    // An open-ended window still has to stop at the present: a slot later
    // today has not come due yet.
    final end = (to == null || to.isAfter(now)) ? now : to;
    final start = from ?? med.createdAt;
    if (end.isBefore(start)) return 0;

    var count = 0;
    for (var day = startOfDay(start);
        !day.isAfter(startOfDay(end));
        day = dayOffset(day, 1)) {
      for (final slot in med.schedule.getScheduledTimesForDate(day)) {
        if (slot.isBefore(start)) continue;
        if (slot.isBefore(med.createdAt)) continue;
        if (slot.isAfter(end)) continue;
        count++;
      }
    }
    return count;
  }

  /// Every number the adherence section prints. See [AdherenceTally].
  @visibleForTesting
  static AdherenceTally tallyAdherence(
    List<MedicineReportEntry> entries,
    DateTime? from,
    DateTime? to,
    DateTime now,
  ) {
    var totalDue = 0, totalTaken = 0;
    final rows = <List<String>>[];
    final symptoms = <MedicineSymptomSummary>[];
    for (final e in entries) {
      // Deduped per slot — see MedicineCleanStorageService.dedupeByDose.
      final logs = MedicineCleanStorageService.dedupeByDose(
          _inWindow(e.logs, from, to));
      final taken = logs.where((l) => l.countsAsTaken).length;
      final missed = logs.where((l) => l.isMissed).length;
      final skipped = logs.where((l) => l.isSkipped).length;
      final due = dueCountFor(e.medicine, logs, from, to, now);
      totalDue += due;
      totalTaken += taken;
      final pct = due > 0 ? (taken / due * 100).round() : 0;
      rows.add([
        _medLabel(e.medicine),
        e.medicine.schedule.frequencyDescription,
        due > 0 ? '$pct%' : '-',
        '$taken',
        '$missed',
        '$skipped',
      ]);
      // Same deduped, windowed logs the adherence row above used — a slot
      // superseded by a later action never counts toward symptoms twice.
      symptoms.add(summarizeSymptoms(_medLabel(e.medicine), logs));
    }
    return AdherenceTally(
      rows: rows,
      symptoms: symptoms,
      totalDue: totalDue,
      totalTaken: totalTaken,
    );
  }

  static Future<Uint8List> buildPdf({
    required List<MedicineReportEntry> entries,
    DateTime? from,
    DateTime? to,
    String? patientName,
    DateTime? generatedAt,
    List<BloodPressureReading> bpReadings = const [],
    List<GlucoseReading> glucoseReadings = const [],
  }) async {
    final doc = pw.Document();
    final now = generatedAt ?? DateTime.now();

    // Overall adherence across all entries in the (optional) window.
    final tally = tallyAdherence(entries, from, to, now);
    final totalDue = tally.totalDue;
    final totalTaken = tally.totalTaken;
    final rows = tally.rows;
    final symptomSummaries = tally.symptoms;
    final overall = tally.overallPct;
    final reportedSymptoms =
        symptomSummaries.where((s) => s.hasAnyData).toList();

    // Averaged per measurement session; `bpCount` below stays the raw number
    // of readings, which is what the clinician is told was taken.
    final bpSessions = BpSessions.collapse(bpReadings);
    final avgSys = VitalsAnalyzer.mean(bpSessions.map((r) => r.systolic).toList());
    final avgDia = VitalsAnalyzer.mean(bpSessions.map((r) => r.diastolic).toList());
    final avgGlucose =
        VitalsAnalyzer.mean(glucoseReadings.map((r) => r.valueMgdl).toList());
    final glucoseInRange = VitalsAnalyzer.inRangePercent(
        glucoseReadings.map((r) => (mgdl: r.valueMgdl, ctx: r.context)).toList());

    // Interaction warnings across everything on the list — Medisafe has no
    // equivalent in its own doctor report.
    final interactions = entries.length > 1
        ? DrugInteractionService()
            .checkAllInteractions(entries.map((e) => e.medicine.name).toList())
        : const <DrugInteraction>[];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
        build: (context) => [
          _header(patientName, from, to, now),
          pw.SizedBox(height: 18),
          _summary(overall, totalTaken, totalDue),
          pw.SizedBox(height: 20),
          pw.Text('Per-medication adherence',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _table(rows),
          if (reportedSymptoms.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Symptoms & well-being',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _symptomsTable(reportedSymptoms),
          ],
          if (avgSys != null || avgGlucose != null) ...[
            pw.SizedBox(height: 20),
            pw.Text('Vitals summary',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _vitalsSummary(
              avgSys: avgSys,
              avgDia: avgDia,
              bpCount: bpReadings.length,
              avgGlucose: avgGlucose,
              glucoseInRange: glucoseInRange,
              glucoseCount: glucoseReadings.length,
            ),
          ],
          if (interactions.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Interaction warnings',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _interactionsTable(interactions),
          ],
          pw.SizedBox(height: 24),
          pw.Text(
            'Adherence = doses marked taken / doses due (taken + missed + skipped) '
            "over the selected period. Generated by ${AppStrings.productName} from the patient's "
            'self-reported logs; for clinical discussion only.',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// A per-dose CSV (Date,Time,Medicine,Status,SideEffects,Mood,Effectiveness)
  /// — a spreadsheet-friendly export for the user or their doctor/caregiver.
  /// Pure Dart, on-device.
  static String buildCsv({
    required List<MedicineReportEntry> entries,
    DateTime? from,
    DateTime? to,
  }) {
    final rows = <List<String>>[];
    for (final e in entries) {
      // Deduped per slot, matching buildPdf — without this, a slot holding
      // both a stale `missed` row and the later `taken` row that superseded
      // it would otherwise be emitted twice.
      final logs = MedicineCleanStorageService.dedupeByDose(
          _inWindow(e.logs, from, to));
      for (final l in logs) {
        final t = l.scheduledTime;
        final date = '${t.year}-${_2(t.month)}-${_2(t.day)}';
        final time = '${_2(t.hour)}:${_2(t.minute)}';
        final status = l.isTaken
            ? 'Taken'
            : l.isPreLogged
                ? 'Pre-logged'
                : l.isMissed
                    ? 'Missed'
                    : l.isSkipped
                        ? 'Skipped'
                        : 'Pending';
        rows.add([
          date,
          time,
          _medLabel(e.medicine),
          status,
          l.sideEffects ?? '',
          l.moodRating?.toString() ?? '',
          l.effectivenessRating?.toString() ?? '',
        ]);
      }
    }
    rows.sort((a, b) {
      final byDate = a[0].compareTo(b[0]);
      if (byDate != 0) return byDate;
      final byTime = a[1].compareTo(b[1]);
      if (byTime != 0) return byTime;
      // Tie-break on medicine name so two doses at the exact same date+time
      // (common — several medicines often share a slot) sort deterministically
      // instead of relying on Dart's List.sort, which is not stable.
      return a[2].compareTo(b[2]);
    });
    final buf =
        StringBuffer('Date,Time,Medicine,Status,SideEffects,Mood,Effectiveness\n');
    for (final r in rows) {
      buf.writeln(r.map(_csvField).join(','));
    }
    return buf.toString();
  }

  static String _csvField(String s) {
    var v = s;
    // Neutralize spreadsheet formula injection: a cell beginning with = + - @
    // (or a leading tab/CR) is executed as a formula by Excel/Sheets. Prefix a
    // single quote so the value is treated as literal text.
    if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) {
      v = "'$v";
    }
    return (v.contains(',') || v.contains('"') || v.contains('\n'))
        ? '"${v.replaceAll('"', '""')}"'
        : v;
  }

  static List<MedicineLog> _inWindow(
      List<MedicineLog> logs, DateTime? from, DateTime? to) {
    return logs.where((l) {
      final t = l.scheduledTime;
      if (from != null && t.isBefore(from)) return false;
      if (to != null && t.isAfter(to)) return false;
      return true;
    }).toList();
  }

  static String _medLabel(EnhancedMedicine m) {
    final strength =
        (m.strength != null && m.strength!.trim().isNotEmpty) ? ' ${m.strength}' : '';
    return '${m.name}$strength';
  }

  static pw.Widget _header(
      String? patient, DateTime? from, DateTime? to, DateTime now) {
    String fmt(DateTime d) =>
        '${d.year}-${_2(d.month)}-${_2(d.day)}';
    final range = (from != null && to != null)
        ? '${fmt(from)} to ${fmt(to)}'
        : 'All recorded doses';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Medication Adherence Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(AppStrings.productName, style: const pw.TextStyle(fontSize: 11, color: PdfColors.teal700)),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          if (patient != null && patient.trim().isNotEmpty)
            pw.Expanded(child: pw.Text('Patient: $patient', style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(child: pw.Text('Period: $range', style: const pw.TextStyle(fontSize: 10))),
          pw.Text('Generated: ${fmt(now)}', style: const pw.TextStyle(fontSize: 10)),
        ]),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400, thickness: .5),
      ],
    );
  }

  static pw.Widget _summary(int overall, int taken, int due) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('$overall%',
              style: pw.TextStyle(
                  fontSize: 34, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
          pw.SizedBox(width: 14),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Overall adherence',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('$taken of $due scheduled doses taken',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _table(List<List<String>> rows) {
    const headers = ['Medication', 'Schedule', 'Adherence', 'Taken', 'Missed', 'Skipped'];
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal600),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  static pw.Widget _symptomsTable(List<MedicineSymptomSummary> summaries) {
    const headers = ['Medication', 'Side effects reported', 'Avg mood', 'Avg effectiveness'];
    // Labels, not raw "X.X/5" numbers: mood (1=best) and effectiveness
    // (1=worst) run in OPPOSITE directions, so a bare number next to another
    // bare number would read as "higher is better" for both — see
    // MedicineSymptomSummary.moodLabel's doc.
    final rows = summaries
        .map((s) => [
              s.medicineLabel,
              s.sideEffectsLabel ?? '-',
              s.moodLabel ?? '-',
              s.effectivenessLabel ?? '-',
            ])
        .toList();
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal600),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  static pw.Widget _vitalsSummary({
    required double? avgSys,
    required double? avgDia,
    required int bpCount,
    required double? avgGlucose,
    required double? glucoseInRange,
    required int glucoseCount,
  }) {
    final boxes = <pw.Widget>[];
    if (avgSys != null && avgDia != null) {
      boxes.add(_vitalBox(
        big: '${avgSys.round()}/${avgDia.round()}',
        unit: 'mm Hg avg',
        caption: '$bpCount reading${bpCount == 1 ? '' : 's'}',
      ));
    }
    if (avgGlucose != null) {
      boxes.add(_vitalBox(
        big: avgGlucose.round().toString(),
        unit: 'mg/dL avg',
        caption: [
          '$glucoseCount reading${glucoseCount == 1 ? '' : 's'}',
          if (glucoseInRange != null) '${(glucoseInRange * 100).round()}% in range',
        ].join('  -  '),
      ));
    }
    if (boxes.isEmpty) return pw.SizedBox();
    return pw.Row(children: [
      for (int i = 0; i < boxes.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 12),
        pw.Expanded(child: boxes[i]),
      ],
    ]);
  }

  static pw.Widget _vitalBox(
      {required String big, required String unit, required String caption}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(big,
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
          pw.SizedBox(width: 6),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(unit, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ),
        ]),
        pw.SizedBox(height: 4),
        pw.Text(caption, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ]),
    );
  }

  static pw.Widget _interactionsTable(List<DrugInteraction> interactions) {
    const headers = ['Medications', 'Severity', 'Details'];
    final rows = interactions
        .map((i) => [
              '${i.drug1Name} + ${i.drug2Name}',
              i.severity.displayName,
              i.description,
            ])
        .toList();
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red600),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(3),
      },
    );
  }

  static String _2(int n) => n.toString().padLeft(2, '0');
}
