import 'package:flutter/material.dart';
import 'clean_storage_service.dart';
import 'notification_service.dart';
import '../../features/medication/services/appointment_reminder_service.dart';
import '../../features/medication/services/medication_reminder_service.dart';
import '../../features/medication/services/medicine_storage_service.dart';
import '../../features/sleep/services/sleep_service.dart';
import '../../features/water/services/water_service.dart';

class ReminderRescheduleService {
  static Future<void> rescheduleAllReminders() async {
    debugPrint('🔄 Rescheduling all reminders...');

    try {
      int successCount = 0;
      int failCount = 0;

      // Schedule medicine reminders using MedicationReminderService
      try {
        // Unscoped: every profile's reminders must be (re)scheduled, not just
        // whichever one happens to be active — see
        // MedicationReminderService.rescheduleAll's doc for why.
        final medicines = await MedicineCleanStorageService.getAllMedicines(
            scopeToActiveProfile: false);
        final reminderService = MedicationReminderService();
        // One-time: clear any medicine alarms left under the old hash-based IDs
        // before we reschedule with the new dense (collision-free) scheme.
        await reminderService.migrateNotificationIdsIfNeeded();
        await reminderService.scheduleAllReminders(medicines);
        successCount += medicines.where((m) => m.reminderEnabled).length;
        debugPrint('✓ Medicine reminders scheduled: ${medicines.length} medicines');
      } catch (e) {
        debugPrint('⚠️ Medicine reminder scheduling failed: $e');
        failCount++;
      }

      // Re-establish interval water reminders from the persisted config so they
      // survive a restart, honouring the adaptive quiet-hours / goal-reached
      // toggles (mirrors how medicine reminders are rebuilt above).
      try {
        successCount += await rescheduleWaterReminders();
      } catch (e) {
        debugPrint('⚠️ Water reminder scheduling failed: $e');
        failCount++;
      }

      // Re-establish appointment reminders the same way — a device reboot or
      // app update can lose AndroidAlarmManager's pending alarms, and unlike
      // medicine/water reminders (rebuilt from a full recompute above),
      // nothing else re-schedules these.
      try {
        final upcoming = await MedicineCleanStorageService.getUpcomingAppointments(
            scopeToActiveProfile: false);
        for (final appointment in upcoming) {
          await AppointmentReminderService.schedule(appointment);
        }
        successCount += upcoming.where((a) => a.reminderEnabled).length;
        debugPrint('✓ Appointment reminders scheduled: ${upcoming.length} appointments');
      } catch (e) {
        debugPrint('⚠️ Appointment reminder scheduling failed: $e');
        failCount++;
      }

      debugPrint('✓ Rescheduled $successCount reminders successfully');
      if (failCount > 0) {
        debugPrint('⚠️ Failed to reschedule $failCount reminders');
      }
    } catch (e) {
      debugPrint('❌ Failed to reschedule reminders: $e');
    }
  }

  /// (Re)schedule interval water reminders from the persisted config.
  ///
  /// Applies the adaptive behaviour:
  /// - disabled config → cancel everything.
  /// - `pauseWhenGoalReached` + today's goal already reached → cancel (they are
  ///   re-established next app start / next day when the goal is not yet met).
  /// - `respectQuietHours` → drop times outside the wake → bedtime window,
  ///   via the shared `QuietHours` primitive (core/utils/quiet_hours.dart) —
  ///   see its doc for why this is applied here and not to
  ///   medicine/vitals/generic/focus reminders, which are all user-time-picked
  ///   rather than auto-generated. The window itself defaults to the
  ///   hydration profile's fixed wake/bed hours, or — when
  ///   `useSleepSchedule` is on — a Sleep-feature-derived window: a real
  ///   average of logged nights when there's enough history, falling back to
  ///   the stated sleep schedule, falling back to the hydration profile hours.
  ///
  /// Returns the number of reminders actually scheduled.
  static Future<int> rescheduleWaterReminders() async {
    final notif = NotificationService();
    final config = CleanStorageService.getWaterReminderConfig();

    if (config == null || !config.enabled) {
      await notif.cancelAllWaterReminders();
      return 0;
    }

    final goalReached = WaterService.getTodayData().goalReached;
    if (config.pauseWhenGoalReached && goalReached) {
      await notif.cancelAllWaterReminders();
      debugPrint('💧 Water reminders paused — goal already reached today');
      return 0;
    }

    int wakeHour, wakeMinute, bedHour, bedMinute;
    if (config.useSleepSchedule) {
      final avg = SleepService.averageActualSchedule();
      if (avg != null) {
        wakeHour = avg.wakeHour;
        wakeMinute = avg.wakeMinute;
        bedHour = avg.bedHour;
        bedMinute = avg.bedMinute;
      } else {
        final schedule = SleepService.getSchedule();
        wakeHour = schedule.wakeHour;
        wakeMinute = schedule.wakeMinute;
        bedHour = schedule.bedtimeHour;
        bedMinute = schedule.bedtimeMinute;
      }
    } else {
      final profile = WaterService.getProfile();
      wakeHour = profile.wakeUpHour ?? 7;
      wakeMinute = 0;
      bedHour = profile.bedtimeHour ?? 22;
      bedMinute = 0;
    }

    final times = config.effectiveReminderMinutes(
      wakeHour: wakeHour,
      wakeMinute: wakeMinute,
      bedHour: bedHour,
      bedMinute: bedMinute,
    );
    return notif.scheduleWaterReminderTimes(times);
  }
}
