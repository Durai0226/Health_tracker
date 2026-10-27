import 'package:flutter/material.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../services/dose_history_edit.dart';
import 'dose_edit_sheet.dart';

/// Open a dose from the history, apply what the person chooses, and offer Undo.
///
/// One place for both the short list on the medicine's page and the full history,
/// so a correction is worded and undone the same way from either.
class DoseEditFlow {
  const DoseEditFlow._();

  /// What was said after each correction.
  static String confirmation(DoseCorrection c) => switch (c) {
        DoseCorrection.tookAtSlot || DoseCorrection.tookAt => 'Dose updated',
        DoseCorrection.didNotTake => 'Marked as not taken',
        DoseCorrection.remove => 'Entry removed',
      };

  /// Returns the result when something was changed, or null when the sheet was
  /// closed. A screen that shows doses listens to
  /// `MedicineCleanStorageService.revision`, which the correction and its Undo
  /// both bump, so nothing needs refreshing by hand.
  static Future<DoseEditResult?> run(
    BuildContext context, {
    required MedicineLog log,
    required EnhancedMedicine medicine,
  }) async {
    final edit = await DoseEditSheet.show(context, log, medicine);
    if (edit == null || !context.mounted) return null;

    final result = await DoseHistoryEdit.apply(log, medicine, edit);
    if (!context.mounted) return result;

    context.toastSuccess(
      confirmation(edit.correction),
      action: AppToastAction(
        label: 'Undo',
        onPressed: () => DoseHistoryEdit.undo(result),
      ),
    );
    return result;
  }
}
