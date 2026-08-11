import 'package:flutter/foundation.dart';
import '../../../core/services/notification_service.dart';
import '../models/doctor_pharmacy.dart';

/// Schedules/cancels the one-time reminder notification for a single
/// appointment, firing [Appointment.reminderMinutesBefore] minutes ahead of
/// its [Appointment.dateTime]. A thin wiring layer over
/// [NotificationService.scheduleNotification] — id derivation is the only
/// logic here.
///
/// Unlike medicine reminders, appointments are one-off (not daily/repeating),
/// so this needs none of MedicationReminderService's slot/window machinery —
/// a single stable id per appointment is enough.
class AppointmentReminderService {
  AppointmentReminderService._();

  /// Stable per-appointment id, clamped into the 32-bit range
  /// NotificationService's Android path requires — mirrors its own private
  /// `_safeId`. Appointment ids are opaque record ids (not the dense
  /// per-medicine index scheme), so a plain hash is fine here, same as
  /// NotificationService's own generic/focus reminders.
  static int notificationIdFor(String appointmentId) =>
      appointmentId.hashCode & 0x7FFFFFFF;

  /// (Re)schedules [appointment]'s reminder, replacing any prior one for the
  /// same appointment. No-ops (after cancelling) when the reminder is off,
  /// the appointment is already marked done, or the fire time has passed.
  ///
  /// Best-effort — never throws. The appointment record itself is the source
  /// of truth; a notification-plugin hiccup must never surface as a failure
  /// to save/update/delete the appointment (matching VitalsStorageService's
  /// Health Connect sync, and NotificationService.cancelNotification's own
  /// unguarded plugin call, which does throw in a headless test environment).
  static Future<void> schedule(Appointment appointment) async {
    try {
      final id = notificationIdFor(appointment.id);
      await NotificationService().cancelNotification(id);
      if (!appointment.reminderEnabled || appointment.isCompleted) return;

      final fireAt = appointment.dateTime
          .subtract(Duration(minutes: appointment.reminderMinutesBefore));
      if (fireAt.isBefore(DateTime.now())) return;

      final locationSuffix =
          (appointment.location != null && appointment.location!.isNotEmpty)
              ? ' — ${appointment.location}'
              : '';
      await NotificationService().scheduleNotification(
        id: id,
        title: 'Upcoming appointment',
        body: '${appointment.doctorName} at ${_formatTime(appointment.dateTime)}'
            '$locationSuffix',
        scheduledDate: fireAt,
      );
    } catch (e) {
      debugPrint('⚠️ Appointment reminder scheduling failed: $e');
    }
  }

  /// See [schedule]'s doc — best-effort, never throws.
  static Future<void> cancelById(String appointmentId) async {
    try {
      await NotificationService()
          .cancelNotification(notificationIdFor(appointmentId));
    } catch (e) {
      debugPrint('⚠️ Appointment reminder cancel failed: $e');
    }
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
