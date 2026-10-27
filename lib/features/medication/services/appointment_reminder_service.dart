import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import '../../../core/health/visit_brief.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/date_formats.dart';
import '../models/doctor_pharmacy.dart';
import 'visit_brief_link.dart';

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

  /// The id of the "your visit brief is ready" notice for the same
  /// appointment: its own, so cancelling or re-arming one never touches the
  /// other.
  static int briefNotificationIdFor(String appointmentId) =>
      'visit-brief:$appointmentId'.hashCode & 0x7FFFFFFF;

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
      await _scheduleBrief(appointment);
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

  /// The notice two days ahead that the visit brief is ready. Opt-out is the
  /// appointment's own reminder switch: with reminders off, so is this, and so
  /// is it for a visit marked done.
  ///
  /// The words name the doctor and the day, no more — the same as the reminder
  /// itself — and nothing about health.
  static Future<void> _scheduleBrief(Appointment appointment) async {
    final id = briefNotificationIdFor(appointment.id);
    await NotificationService().cancelNotification(id);
    if (!appointment.reminderEnabled || appointment.isCompleted) return;
    final fireAt =
        VisitBriefs.notifyAt(visitAt: appointment.dateTime, now: clock.now());
    if (fireAt == null) return;
    await NotificationService().scheduleNotification(
      id: id,
      title: 'Your visit brief is ready',
      body: '${appointment.doctorName}, '
          '${DateFormats.weekdayDayMonthShort.format(appointment.dateTime)}. '
          'A summary to read before you go.',
      scheduledDate: fireAt,
      payload: VisitBriefLink.payloadFor(appointment.id),
    );
  }

  /// See [schedule]'s doc — best-effort, never throws.
  static Future<void> cancelById(String appointmentId) async {
    try {
      await NotificationService()
          .cancelNotification(notificationIdFor(appointmentId));
      await NotificationService()
          .cancelNotification(briefNotificationIdFor(appointmentId));
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
