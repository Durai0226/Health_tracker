import 'package:flutter/material.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../models/medicine_log.dart';
import 'medicine_storage_service.dart';

/// Undo for dose writes — the single place that knows how to reverse one.
///
/// Undo used to live on the *callers* of the take/skip sheet, which meant every
/// new entry point silently shipped without it: the Today hero's 2-tap "Take",
/// the ➕ quick-log sheet, and the PRN "Log a dose" button all wrote a dose that
/// could not be taken back. Reversing a dose is also not a one-liner — deleting
/// the log alone loses inventory, because a taken dose has already decremented
/// stock — so duplicating it per caller is how that bug gets reintroduced.
///
/// [confirmSheetResult] is the entry point for anything that shows
/// `NunitoTakeMedicationSheet`: hand it the sheet's result map and it decides
/// whether a dose was recorded, phrases the confirmation, and wires Undo.
class DoseUndo {
  const DoseUndo._();

  /// Reverse one dose write: put the units back first (or Undo silently loses
  /// inventory), then delete the log.
  static Future<void> revertLog(MedicineLog log) async {
    if (log.countsAsTaken) {
      await MedicineCleanStorageService.restoreStock(
          log.medicineId, log.dosageTaken);
    }
    await MedicineCleanStorageService.deleteLog(log.id);
  }

  /// Same, for a caller that only kept the log id (e.g. the notification
  /// dose-action queue drain). The delete is unconditional so a log that can no
  /// longer be read still doesn't survive an Undo.
  static Future<void> revertLogId(String id) async {
    final log = await MedicineCleanStorageService.getLog(id);
    if (log != null && log.countsAsTaken) {
      await MedicineCleanStorageService.restoreStock(
          log.medicineId, log.dosageTaken);
    }
    await MedicineCleanStorageService.deleteLog(id);
  }

  /// One-line confirmation with Undo — a mis-tapped Take/Skip used to be
  /// permanent (the row simply became non-actionable with no way back).
  ///
  /// [afterUndo] is for screens holding their own copy of the data; surfaces
  /// that listen to [MedicineCleanStorageService.revision] need nothing, since
  /// both writes above bump it.
  static void confirm(
    BuildContext context,
    String message,
    MedicineLog log, {
    Future<void> Function()? afterUndo,
  }) {
    context.toastSuccess(
      message,
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          await revertLog(log);
          if (afterUndo != null) await afterUndo();
        },
      ),
    );
  }

  /// Undo for a batch of dose ids applied on the user's behalf (notification
  /// Take/Skip drained on resume), confirmed as one toast.
  static void confirmLogIds(
    BuildContext context,
    String message,
    List<String> logIds, {
    Future<void> Function()? afterUndo,
  }) {
    if (logIds.isEmpty) return;
    context.toastSuccess(
      message,
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          for (final id in logIds) {
            await revertLogId(id);
          }
          if (afterUndo != null) await afterUndo();
        },
      ),
    );
  }

  /// Confirm (with Undo) the result map popped by `NunitoTakeMedicationSheet`.
  ///
  /// The sheet pops `{'taken': true, 'log': …}` / `{'skipped': true, 'log': …}`,
  /// or a non-dose outcome (`preLoggedOther`, `snoozed`) / null on dismiss —
  /// those write nothing here, so there is nothing to confirm or undo.
  /// Returns true when a dose outcome was confirmed.
  static bool confirmSheetResult(
    BuildContext context,
    Map<String, dynamic>? result,
    String medicineName, {
    Future<void> Function()? afterUndo,
  }) {
    if (result == null) return false;
    final log = result['log'];
    if (log is! MedicineLog) return false;
    final taken = result['taken'] == true;
    final skipped = result['skipped'] == true;
    if (!taken && !skipped) return false;
    confirm(
      context,
      '$medicineName ${taken ? 'taken' : 'skipped'}',
      log,
      afterUndo: afterUndo,
    );
    return true;
  }
}
