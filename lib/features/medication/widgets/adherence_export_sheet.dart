import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../services/adherence_report_service.dart';
import '../services/medicine_storage_service.dart';
import '../services/vitals_storage_service.dart';

/// "Share with your doctor": the last 30 days as a PDF or a spreadsheet.
///
/// Lived on the Medicines list alone, so the Adherence report, which is where
/// someone is looking at the numbers they would want to hand over, had no way to
/// share them. Both screens now open this.
///
/// Strictly local: the OS share sheet decides where it goes; nothing is uploaded
/// by the app.
class AdherenceExportSheet {
  const AdherenceExportSheet._();

  static void show(BuildContext context) {
    HapticService().light();
    final ext = AppColorsExt.of(context);
    AppBottomSheet.show<void>(
      context,
      title: 'Share with your doctor',
      icon: Symbols.ios_share_rounded,
      accent: ext.medicine,
      builder: (sheetCtx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppListTile(
            icon: Symbols.picture_as_pdf_rounded,
            title: 'Adherence report (PDF)',
            subtitle: 'A clean summary for a doctor visit',
            accent: ext.medicine,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              exportPdf(context);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(height: AppSpacing.sm),
          AppListTile(
            icon: Symbols.date_range_rounded,
            title: 'Last week (PDF)',
            subtitle: 'Seven days, to send to someone who looks out for you',
            accent: ext.medicine,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              exportPdf(context, days: weeklyDays);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppListTile(
            icon: Symbols.table_rows_rounded,
            title: 'Dose log (CSV)',
            subtitle: 'Every dose as a spreadsheet',
            accent: ext.medicine,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              exportCsv(context);
            },
          ),
        ],
      ),
    );
  }

  /// Test seam: a widget test has no share sheet.
  @visibleForTesting
  static Future<void> Function(Uint8List bytes, String filename)? shareOverride;

  static Future<void> sharePdf(Uint8List bytes, String filename) {
    final override = shareOverride;
    if (override != null) return override(bytes, filename);
    return Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Every active medicine with its dose log, or null (after saying so) when
  /// there is nothing to report.
  static Future<List<MedicineReportEntry>?> _entries(BuildContext context) async {
    final all = await MedicineCleanStorageService.getAllMedicines();
    final active = all.where((m) => m.isActive && !m.isArchived).toList();
    if (active.isEmpty) {
      if (context.mounted) {
        context.toastInfo('No active medicines to report yet.');
      }
      return null;
    }
    final entries = <MedicineReportEntry>[];
    for (final m in active) {
      final logs = await MedicineCleanStorageService.getLogsForMedicine(m.id);
      entries.add(MedicineReportEntry(medicine: m, logs: logs));
    }
    return entries;
  }

  /// The log line that tells whoever gets the bug report which step actually
  /// failed. The friendly toast used to be all there was: the exception was
  /// dropped on the floor.
  static void _logFailure(Object error) =>
      debugPrint('Report export failed: $error');

  static const String _failureMessage =
      'Could not create the report. Please try again.';

  /// A clinician-shareable adherence PDF over the last 30 days, with the same
  /// window's BP and glucose readings folded in (if any were logged) so a doctor
  /// gets adherence, symptoms AND vitals in one document instead of three.
  /// The short report to send to someone who looks out for you.
  static const int weeklyDays = 7;

  static Future<void> exportPdf(BuildContext context, {int days = 30}) async {
    HapticService().medium();
    // Inside the try: reading every medicine's dose log is the step most likely
    // to fail, and while it sat outside, a storage error escaped as an
    // unhandled exception rather than reaching the catch below.
    try {
      final entries = await _entries(context);
      if (entries == null) return;
      final now = DateTime.now();
      final from = now.subtract(Duration(days: days));
      final bpReadings = await VitalsStorageService.getBpForRange(from, now);
      final glucoseReadings =
          await VitalsStorageService.getGlucoseForRange(from, now);
      // The active dependent's name, or null for self: the PDF header omits the
      // "Patient:" line entirely when null. Without it two reports for two
      // different people were visually indistinguishable, an easy way to hand a
      // doctor the wrong child's report.
      final bytes = await AdherenceReportService.buildPdf(
        entries: entries,
        from: from,
        to: now,
        bpReadings: bpReadings,
        glucoseReadings: glucoseReadings,
        patientName: await MedicineCleanStorageService.activePatientName(),
      );
      await AdherenceExportSheet.sharePdf(bytes,
          days == 30 ? 'adherence-report.pdf' : 'adherence-report-$days-days.pdf');
    } catch (e) {
      _logFailure(e);
      if (context.mounted) context.toastError(_failureMessage);
    }
  }

  /// The last 30 days' dose log as a CSV via the OS share sheet.
  static Future<void> exportCsv(BuildContext context) async {
    HapticService().medium();
    // Inside the try, for the reason given in [exportPdf].
    try {
      final entries = await _entries(context);
      if (entries == null) return;
      if (entries.isEmpty) {
        if (context.mounted) {
          context.toastInfo('No doses logged in the last 30 days');
        }
        return;
      }
      final now = DateTime.now();
      final csv = AdherenceReportService.buildCsv(
        entries: entries,
        from: now.subtract(const Duration(days: 30)),
        to: now,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/medication-log.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Medicine log (last 30 days)',
      );
    } catch (e) {
      _logFailure(e);
      if (context.mounted) context.toastError(_failureMessage);
    }
  }
}
