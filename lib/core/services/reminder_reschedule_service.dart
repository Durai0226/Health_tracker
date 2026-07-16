import 'package:flutter/material.dart';
import 'clean_storage_service.dart';
import '../../features/medication/services/medication_reminder_service.dart';
import '../../features/medication/services/medicine_storage_service.dart';

class ReminderRescheduleService {
  static Future<void> rescheduleAllReminders() async {
    debugPrint('🔄 Rescheduling all reminders...');

    try {
      final waterReminder = CleanStorageService.getWaterReminder();

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

      // Water reminder scheduling - waterReminder is a Future
      final waterReminderData = await waterReminder;
      if (waterReminderData != null) {
        // TODO: Water reminder scheduling needs proper schema - temporarily disabled
        debugPrint('Water reminder scheduling temporarily disabled - schema needs update');
      }

      debugPrint('✓ Rescheduled $successCount reminders successfully');
      if (failCount > 0) {
        debugPrint('⚠️ Failed to reschedule $failCount reminders');
      }
    } catch (e) {
      debugPrint('❌ Failed to reschedule reminders: $e');
    }
  }
}
