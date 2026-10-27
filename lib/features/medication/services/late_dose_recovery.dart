import 'package:clock/clock.dart';

import '../../../core/utils/calendar_day.dart' show isSameCalendarDay;
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_log.dart';
import 'medicine_storage_service.dart';

/// A dose that went past its grace window with no outcome, and the medicine it
/// belongs to.
class MissedDose {
  final MedicineLog log;
  final EnhancedMedicine medicine;
  const MissedDose(this.log, this.medicine);

  DateTime get scheduledTime => log.scheduledTime;
}

/// What the person says happened to a dose the app wrote down as missed.
enum LateOutcome {
  /// Swallowed at the scheduled minute — "it was fine, I just did not tap".
  tookOnTime,

  /// Swallowed at a time they name.
  tookAt,

  /// Swallowing it now.
  takeNow,

  /// Not taking it.
  skipped,
}

/// A choice plus, for [LateOutcome.tookAt], the instant they named.
class LateChoice {
  final LateOutcome outcome;
  final DateTime? at;
  const LateChoice(this.outcome, {this.at});
}

/// The three states a row in the next-morning tidy-up can be in. [missed] is
/// "leave it as the app wrote it down".
enum TidyChoice { taken, skipped, missed }

/// Recovering doses the reconcile sweep wrote down as `missed`.
///
/// `reconcileMissedDoses` marks a slot missed three hours after it was due, and
/// until now that was final: the row rendered as a grey "Missed" badge, could
/// not be tapped, and counted against adherence even when the dose had been
/// swallowed on time and simply never logged. That is the commonest way an
/// honest adherence figure ends up wrong — so the badge is now a way back in.
class LateDoseRecovery {
  const LateDoseRecovery._();

  /// The clock time [hour]:[minute] the person says they took the dose at, as a
  /// real instant — or null when that instant has not happened yet.
  ///
  /// The time is read on the scheduled day, and a time earlier than the
  /// schedule rolls to the next day: a 23:00 dose taken "at 00:30" was taken
  /// after midnight, not 22.5 hours before it was due. Built with the DateTime
  /// constructor, not Duration arithmetic, so a DST change cannot shift it.
  static DateTime? takenAtFor({
    required DateTime scheduled,
    required int hour,
    required int minute,
    DateTime? now,
  }) {
    var at = DateTime(scheduled.year, scheduled.month, scheduled.day, hour, minute);
    if (at.isBefore(scheduled)) {
      at = DateTime(scheduled.year, scheduled.month, scheduled.day + 1, hour, minute);
    }
    return at.isAfter(now ?? clock.now()) ? null : at;
  }

  /// The missed doses among [logs] that fell on [day], earliest first.
  ///
  /// A log whose medicine is not in [medicines] (deleted, or another profile's)
  /// is left out: there is nothing to take.
  static List<MissedDose> missedOn(
    DateTime day,
    List<MedicineLog> logs,
    List<EnhancedMedicine> medicines,
  ) {
    final byId = {for (final m in medicines) m.id: m};
    final out = <MissedDose>[];
    for (final l in logs) {
      if (!l.isMissed || !isSameCalendarDay(l.scheduledTime, day)) continue;
      final m = byId[l.medicineId];
      if (m != null) out.add(MissedDose(l, m));
    }
    out.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return out;
  }

  /// Record [choice] for [dose], returning the log it wrote.
  ///
  /// Taking runs through `markMedicineTaken`, so the stock is decremented and
  /// the nudge-resolved flag set exactly as for any other take. The id is the
  /// slot's own, so the row replaces the `missed` one rather than sitting beside
  /// it.
  static Future<MedicineLog> apply(MissedDose dose, LateChoice choice) {
    final id = dose.medicine.id;
    final slot = dose.scheduledTime;
    // The amount the schedule calls for that day, as a take from the sheet or a
    // notification records it. The default of one unit under-counted a
    // two-tablet dose in the stock every time it was recovered.
    final amount =
        dose.medicine.schedule.effectiveDosageAmount(slot, dose.medicine.dosageAmount);
    switch (choice.outcome) {
      case LateOutcome.tookOnTime:
        return MedicineCleanStorageService.markMedicineTaken(
            medicineId: id, scheduledTime: slot, takenAt: slot, dosageTaken: amount);
      case LateOutcome.tookAt:
        return MedicineCleanStorageService.markMedicineTaken(
            medicineId: id,
            scheduledTime: slot,
            takenAt: choice.at ?? slot,
            dosageTaken: amount);
      case LateOutcome.takeNow:
        return MedicineCleanStorageService.markMedicineTaken(
            medicineId: id,
            scheduledTime: slot,
            takenAt: clock.now(),
            dosageTaken: amount);
      case LateOutcome.skipped:
        // This path exists for a dose that was never actioned, so "I forgot" is
        // the honest reason; the person who skipped on purpose does that from
        // the take sheet at the time.
        return MedicineCleanStorageService.markMedicineSkipped(
            medicineId: id,
            scheduledTime: slot,
            reason: SkipReason.forgotToTake);
    }
  }

  /// Apply a tidy-up: each dose the person moved off [TidyChoice.missed] is
  /// recorded — "took it" at the scheduled minute, since no other time is known
  /// — and the logs written are returned, for one Undo. Doses left as missed are
  /// untouched.
  static Future<List<MedicineLog>> applyTidy(
    List<MissedDose> doses,
    Map<String, TidyChoice> changes,
  ) async {
    final written = <MedicineLog>[];
    for (final d in doses) {
      final c = changes[d.log.id];
      if (c == null || c == TidyChoice.missed) continue;
      written.add(await apply(
        d,
        LateChoice(c == TidyChoice.taken
            ? LateOutcome.tookOnTime
            : LateOutcome.skipped),
      ));
    }
    return written;
  }

  /// Undo [log] and put the slot back to missed.
  ///
  /// Deleting the row is enough: the next reconcile finds a past-due slot with
  /// no terminal outcome and writes `missed` again — which is exactly the state
  /// being returned to. Stock is handed back first, as every other Undo does.
  static Future<void> undo(MedicineLog log) async {
    if (log.countsAsTaken) {
      await MedicineCleanStorageService.restoreStock(
          log.medicineId, log.dosageTaken);
    }
    await MedicineCleanStorageService.deleteLog(log.id);
  }
}
