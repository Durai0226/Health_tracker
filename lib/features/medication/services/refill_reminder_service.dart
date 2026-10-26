import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/health/refill_predictor.dart';
import '../../../core/services/notification_service.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import 'medicine_storage_service.dart';
import 'refill_loop.dart';

/// Reserved notification-id block for refill reminders.
///
/// Chosen well below the window-nudge block at 930000. Those are allocated as
/// `930000 + medicineIndex * 72`, so a block just above it would put a ceiling
/// on how many medicines a user may have before ids collide. There is nothing
/// between the medicine snooze twins (201439) and the legacy water block
/// (900000), so this is clear with room to spare.
const int refillReminderIdBase = 850000;

/// How many medicines can have a refill reminder armed at once.
const int refillReminderCapacity = 1000;

/// "You will run out of X on Thursday — reorder now."
///
/// `RefillPredictor` has computed `refillByDate` and a one-line `summary` all
/// along, and its own docstring describes that summary as *"suitable for a card
/// **or notification**"*. It only ever became a card. Running out of medication
/// is a total adherence failure that no reminder can rescue after the fact, and
/// it is entirely predictable — which makes it one of the cheapest wins here.
///
/// Deliberately `gentle`: a refill is not time-critical to the minute. It needs
/// to arrive with enough lead time to act on, not to take over the screen.
class RefillReminderService {
  const RefillReminderService._();

  /// Stable per-medicine id, so re-arming replaces rather than duplicates.
  ///
  /// Hashed into the block rather than allocated, because unlike generic
  /// reminders these are derived state — recomputed wholesale on every pass, so
  /// a rare hash collision costs one merged reminder for one cycle rather than a
  /// permanently wrong id. The alternative, a stored column, is not worth a
  /// schema migration for something regenerated every app start.
  static int notificationIdFor(String medicineId) =>
      refillReminderIdBase + (medicineId.hashCode.abs() % refillReminderCapacity);

  /// Re-arm every medicine's refill reminder from its real consumption rate.
  ///
  /// Registered as a [ReminderFamily] so it rides the same pass as everything
  /// else and inherits its error isolation.
  static Future<int> rescheduleAll() async {
    var armed = 0;
    try {
      final medicines = await MedicineCleanStorageService.getAllMedicines(
          scopeToActiveProfile: false);
      final now = clock.now();
      final logs = await _recentLogs(now);
      for (final m in medicines) {
        if (await _arm(m, now, logs)) armed++;
      }
    } catch (e) {
      debugPrint('⚠️ Refill reminder scheduling failed: $e');
    }
    return armed;
  }

  /// Re-arm just [medicineId]'s reminder.
  ///
  /// The full sweep only runs at app start and on the shared reschedule pass, so
  /// until now a dose taken at noon, or stock added at four, left the run-out
  /// date from the morning's numbers: "refill on Thursday" when the refill had
  /// since made it the following Tuesday. This is called after a dose is taken
  /// and after stock is added, and costs one medicine, not all of them.
  static Future<bool> rescheduleFor(String medicineId) async {
    try {
      final m = await MedicineCleanStorageService.getMedicine(medicineId);
      if (m == null) {
        await NotificationService().cancelNotification(notificationIdFor(medicineId));
        return false;
      }
      final now = clock.now();
      return await _arm(m, now, await _recentLogs(now));
    } catch (e) {
      debugPrint('⚠️ Refill reminder re-arm failed: $e');
      return false;
    }
  }

  /// Dose history for the predictor, as ONE ranged read.
  ///
  /// The predictor only looks back [_windowDays], so reading each medicine's
  /// whole history (as this used to) was cost with no effect on the answer.
  ///
  /// Unscoped, like the medicine list: this runs over EVERY profile's
  /// medicines, so a dependent's medicine must see its own logs while the
  /// carer's own profile is active. With the default scoping those logs are all
  /// filtered out, `taken` is empty, and a parent's refill reminder never arms
  /// at all — see getLogsForMedicine's doc and
  /// MedicationReminderService._adaptiveSuggestionMinutes, which had to override
  /// the same default for the same reason.
  static Future<List<MedicineLog>> _recentLogs(DateTime now) async {
    final from = DateTime(now.year, now.month, now.day - (_windowDays + 1));
    return MedicineCleanStorageService.dedupeByDose(
        await MedicineCleanStorageService.getLogsForDateRange(
            from, now.add(const Duration(days: 1)),
            scopeToActiveProfile: false));
  }

  static const int _windowDays = 21;

  /// Cancel and, when it still applies, re-arm one medicine's reminder.
  static Future<bool> _arm(
      EnhancedMedicine m, DateTime now, List<MedicineLog> logs) async {
    final notif = NotificationService();
    final id = notificationIdFor(m.id);
    // Always cancel first: stock changes, so yesterday's forecast date is
    // routinely wrong and an un-cancelled reminder would fire on it.
    await notif.cancelNotification(id);

    if (!m.refillReminderEnabled || m.isArchived || !m.isActive) return false;
    // Already asked for: the follow-up ("did you pick it up?") is the reminder
    // now, and a second "refill X" would read as the app not having noticed.
    if (RefillRequestState.requestedAt(m.id) != null) return false;
    final stock = m.currentStock;
    if (stock == null || stock <= 0) return false;

    final taken = [
      for (final l in logs)
        if (l.medicineId == m.id && l.countsAsTaken) l,
    ];
    if (taken.isEmpty) return false;

    final pred = RefillPredictor.predict(
      currentStock: stock,
      doseTimes: taken.map((l) => l.actionTime ?? l.scheduledTime).toList(),
      doseAmounts: taken.map((l) => l.dosageTaken).toList(),
      windowDays: _windowDays,
      now: now,
    );
    final by = pred.refillByDate;
    // A date already past means they are on the edge or over it; the
    // low-stock alert on the next logged dose covers that case, and a
    // reminder scheduled in the past never fires anyway.
    if (by == null || !by.isAfter(now)) return false;

    // Mid-morning, not midnight: a refill reminder is only useful at an
    // hour when a pharmacy is open and the user can act on it.
    final at = DateTime(by.year, by.month, by.day, 10);
    return notif.scheduleNotification(
      id: id,
      title: 'Refill ${m.name}',
      body: pred.summary,
      scheduledDate: at.isAfter(now) ? at : now.add(const Duration(minutes: 5)),
      payload: RefillLoop.payloadFor(m.id),
    );
  }
}
