import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/health/refill_predictor.dart';
import '../../../core/services/notification_service.dart';
import 'medicine_storage_service.dart';

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
    final notif = NotificationService();
    var armed = 0;
    try {
      final medicines = await MedicineCleanStorageService.getAllMedicines(
          scopeToActiveProfile: false);
      final now = clock.now();

      for (final m in medicines) {
        final id = notificationIdFor(m.id);
        // Always cancel first: stock changes, so yesterday's forecast date is
        // routinely wrong and an un-cancelled reminder would fire on it.
        await notif.cancelNotification(id);

        if (!m.refillReminderEnabled || m.isArchived || !m.isActive) continue;
        final stock = m.currentStock;
        if (stock == null || stock <= 0) continue;

        final taken = MedicineCleanStorageService.dedupeByDose(
                await MedicineCleanStorageService.getLogsForMedicine(m.id))
            .where((l) => l.countsAsTaken)
            .toList();
        if (taken.isEmpty) continue;

        final pred = RefillPredictor.predict(
          currentStock: stock,
          doseTimes: taken.map((l) => l.actionTime ?? l.scheduledTime).toList(),
          doseAmounts: taken.map((l) => l.dosageTaken).toList(),
          windowDays: 21,
          now: now,
        );
        final by = pred.refillByDate;
        // A date already past means they are on the edge or over it; the
        // low-stock alert on the next logged dose covers that case, and a
        // reminder scheduled in the past never fires anyway.
        if (by == null || !by.isAfter(now)) continue;

        // Mid-morning, not midnight: a refill reminder is only useful at an
        // hour when a pharmacy is open and the user can act on it.
        final at = DateTime(by.year, by.month, by.day, 10);
        final ok = await notif.scheduleNotification(
          id: id,
          title: 'Refill ${m.name}',
          body: pred.summary,
          scheduledDate: at.isAfter(now) ? at : now.add(const Duration(minutes: 5)),
        );
        if (ok) armed++;
      }
    } catch (e) {
      debugPrint('⚠️ Refill reminder scheduling failed: $e');
    }
    return armed;
  }
}
