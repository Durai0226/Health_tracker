import 'package:flutter/material.dart';
import 'clean_storage_service.dart';
import 'notification_service.dart';
import '../../features/medication/services/medication_reminder_service.dart';
import '../../features/medication/services/medicine_storage_service.dart';
import '../../features/water/services/water_service.dart';

class ReminderRescheduleService {
  static Future<void> rescheduleAllReminders() async {
    debugPrint('🔄 Rescheduling all reminders...');

    try {
      int successCount = 0;
      int failCount = 0;

      // Schedule medicine reminders using MedicationReminderService
      try {
        final medicines = await MedicineCleanStorageService.getAllMedicines();
        final reminderService = MedicationReminderService();
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
  /// - `respectQuietHours` → drop times outside the hydration profile's
  ///   wake → bedtime window.
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

    final profile = WaterService.getProfile();
    final times = config.effectiveReminderMinutes(
      wakeHour: profile.wakeUpHour ?? 7,
      bedHour: profile.bedtimeHour ?? 22,
    );
    return notif.scheduleWaterReminderTimes(times);
  }
}
