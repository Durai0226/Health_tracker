import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_log.dart';
import 'dose_undo.dart';
import 'medicine_storage_service.dart';

/// What a person can change about a dose that is already in the history.
enum DoseCorrection {
  /// Taken, and at the minute it was due: "it was fine, I just did not tap".
  tookAtSlot,

  /// Taken at a time they name — or, for a dose already recorded as taken, a
  /// different time than the one written down.
  tookAt,

  /// Not taken after all. Written as skipped ("forgot"), which is what it was.
  didNotTake,

  /// Take the entry out of the history.
  remove,
}

/// A correction plus, for [DoseCorrection.tookAt], the instant named.
class DoseEdit {
  final DoseCorrection correction;
  final DateTime? at;
  const DoseEdit(this.correction, {this.at});
}

/// What a correction did, so it can be taken back: the row as it was and the row
/// as it is now (null once removed).
class DoseEditResult {
  final MedicineLog before;
  final MedicineLog? after;
  const DoseEditResult(this.before, this.after);
}

/// Correcting a dose in the history.
///
/// The history was a list of the last five doses with nothing to tap: a dose
/// logged as skipped that had been taken, a taken one logged at the wrong time, or
/// one logged twice stayed wrong. Every correction goes through the same writes a
/// dose is recorded with (`markMedicineTaken`, `markMedicineSkipped`, the Undo's
/// stock reversal), so the count of tablets left, the adherence figure and the
/// refill forecast follow it rather than disagreeing with the list.
class DoseHistoryEdit {
  const DoseHistoryEdit._();

  /// The corrections that make sense for [log], in the order to offer them.
  /// Nothing for a dose that has not happened yet.
  static List<DoseCorrection> optionsFor(MedicineLog log) {
    if (log.countsAsTaken) {
      return const [
        DoseCorrection.tookAt,
        DoseCorrection.didNotTake,
        DoseCorrection.remove,
      ];
    }
    if (log.isSkipped) {
      return const [
        DoseCorrection.tookAtSlot,
        DoseCorrection.tookAt,
        DoseCorrection.remove,
      ];
    }
    if (log.isMissed) {
      return const [
        DoseCorrection.tookAtSlot,
        DoseCorrection.tookAt,
        DoseCorrection.didNotTake,
      ];
    }
    return const [];
  }

  /// Units of the medicine a log used up: a dose counts when it was taken.
  static double _used(MedicineLog? log) =>
      log != null && log.countsAsTaken ? log.dosageTaken : 0;

  /// Apply [edit] to [log] and say what was written.
  ///
  /// A dose becoming taken is written by `markMedicineTaken` with the amount the
  /// schedule calls for on that day (titration included), exactly as a take from
  /// the sheet or a notification is: a default of one unit would under-count a
  /// two-tablet dose in the stock.
  static Future<DoseEditResult> apply(
    MedicineLog log,
    EnhancedMedicine medicine,
    DoseEdit edit,
  ) async {
    final slot = log.scheduledTime;
    switch (edit.correction) {
      case DoseCorrection.tookAt:
        final at = edit.at ?? slot;
        if (log.countsAsTaken) {
          // Only the time changes: the notes, ratings and amount stay, and the
          // stock is untouched because the dose was already counted.
          final updated = log.copyWith(actionTime: at);
          await MedicineCleanStorageService.updateLog(updated);
          return DoseEditResult(log, updated);
        }
        return DoseEditResult(
            log,
            await MedicineCleanStorageService.markMedicineTaken(
              medicineId: log.medicineId,
              scheduledTime: slot,
              takenAt: at,
              dosageTaken: _dose(medicine, slot),
            ));
      case DoseCorrection.tookAtSlot:
        return DoseEditResult(
            log,
            await MedicineCleanStorageService.markMedicineTaken(
              medicineId: log.medicineId,
              scheduledTime: slot,
              takenAt: slot,
              dosageTaken: _dose(medicine, slot),
            ));
      case DoseCorrection.didNotTake:
        // `markMedicineSkipped` hands the stock back when the dose had been
        // recorded as taken.
        return DoseEditResult(
            log,
            await MedicineCleanStorageService.markMedicineSkipped(
              medicineId: log.medicineId,
              scheduledTime: slot,
              reason: SkipReason.forgotToTake,
            ));
      case DoseCorrection.remove:
        await DoseUndo.revertLog(log);
        return DoseEditResult(log, null);
    }
  }

  static double _dose(EnhancedMedicine medicine, DateTime slot) =>
      medicine.schedule.effectiveDosageAmount(slot, medicine.dosageAmount);

  /// Put the dose back as it was before [result].
  ///
  /// The stock is moved by the difference between what the correction left used
  /// and what the original used — so undoing a change of time, which never
  /// touched it, leaves it alone, and undoing "I took it" gives the units back.
  static Future<void> undo(DoseEditResult result) async {
    final before = result.before;
    final delta = _used(result.after) - _used(before);
    if (delta > 0) {
      await MedicineCleanStorageService.restoreStock(before.medicineId, delta);
    } else if (delta < 0) {
      await MedicineCleanStorageService.reduceStock(before.medicineId, -delta);
    }
    await MedicineCleanStorageService.addLog(before);
  }
}
