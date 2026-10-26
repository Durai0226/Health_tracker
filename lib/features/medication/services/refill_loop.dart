import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/notification_service.dart';

/// Whether — and since when — a refill has been asked for.
///
/// One preference per medicine, kept out of the medicine row on purpose: it is
/// a short-lived fact about a pending errand, not part of the medicine, and a
/// column for it would be a schema change for something that lives a few days.
class RefillRequestState {
  const RefillRequestState._();

  static String _key(String medicineId) => 'refill_requested_$medicineId';

  static DateTime? requestedAt(String medicineId) {
    final v = CleanStorageService.getAppPreference(_key(medicineId), '');
    return v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
  }

  static Future<void> set(String medicineId, DateTime at) =>
      CleanStorageService.setAppPreference(
          _key(medicineId), at.toIso8601String());

  static Future<void> clear(String medicineId) =>
      CleanStorageService.setAppPreference(_key(medicineId), '');
}

/// The refill errand, end to end: the run-out reminder opens a sheet, the sheet
/// lets the person ask the pharmacy, and a follow-up reminder two days later
/// asks whether it was picked up — until stock is added, by any route.
///
/// Before this the run-out reminder said "Refill X" and stopped: the person had
/// to remember which pharmacy, find the number, and then remember again that
/// they had asked.
class RefillLoop {
  const RefillLoop._();

  /// Follow-up ids. The run-out reminders occupy 850000–850999
  /// (`refillReminderIdBase` + a 1000-wide hash); this block is the next 1000,
  /// still clear of the window-nudge block at 930000.
  static const int followUpIdBase = 851000;
  static const int followUpCapacity = 1000;

  static int followUpIdFor(String medicineId) =>
      followUpIdBase + (medicineId.hashCode.abs() % followUpCapacity);

  /// How long after asking before "did you pick it up?".
  static const int followUpDays = 2;

  /// The notification payload that opens the refill sheet for [medicineId].
  static String payloadFor(String medicineId) => 'refill:$medicineId';

  /// The medicine a [payloadFor] payload names, or null for anything else.
  static String? medicineIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith('refill:')) return null;
    final id = payload.substring('refill:'.length);
    return id.isEmpty ? null : id;
  }

  /// Set by a tapped refill notification (warm or cold start); the app shell
  /// shows the sheet, once the app lock allows, and clears it.
  static final ValueNotifier<String?> pendingOpen = ValueNotifier<String?>(null);

  /// 10:00 on the [followUpDays]th day after [requestedAt] — a pharmacy-open
  /// hour, built with the DateTime constructor so a DST change cannot shift it.
  static DateTime followUpAt(DateTime requestedAt) => DateTime(requestedAt.year,
      requestedAt.month, requestedAt.day + followUpDays, 10);

  /// Record that a refill of [medicineName] was asked for and arm the follow-up.
  static Future<void> markRequested(
    String medicineId,
    String medicineName, {
    DateTime? now,
  }) async {
    final at = now ?? clock.now();
    await RefillRequestState.set(medicineId, at);
    await NotificationService().scheduleNotification(
      id: followUpIdFor(medicineId),
      title: 'Picked up $medicineName?',
      body: 'You asked for a refill. Tap once you have it, so your supply '
          'count is right.',
      scheduledDate: followUpAt(at),
      payload: payloadFor(medicineId),
    );
  }

  /// Stock was added for [medicineId]: the errand is over. Called from
  /// `refillStock`, so every route that adds stock ends the loop.
  static Future<void> onRefilled(String medicineId) async {
    await RefillRequestState.clear(medicineId);
    await NotificationService().cancelNotification(followUpIdFor(medicineId));
  }
}
