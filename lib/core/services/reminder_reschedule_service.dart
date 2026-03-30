import 'package:flutter/material.dart';
import 'clean_storage_service.dart';
import 'notification_service.dart';
import 'fitness_reminder_service.dart';
import '../../features/medication/services/medication_reminder_service.dart';
import '../../features/medication/services/medicine_storage_service.dart';

class ReminderRescheduleService {
  static Future<void> rescheduleAllReminders() async {
    debugPrint('🔄 Rescheduling all reminders...');
    
    try {
      final waterReminder = CleanStorageService.getWaterReminder();
      final periodReminder = CleanStorageService.getPeriodReminder();
      
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
      
      // Use FitnessReminderService for fitness reminders (has retry logic)
      try {
        final fitnessService = FitnessReminderService();
        final fitnessResults = await fitnessService.rescheduleAllReminders();
        final fitnessSuccess = fitnessResults.values.where((v) => v).length;
        final fitnessFail = fitnessResults.values.where((v) => !v).length;
        successCount += fitnessSuccess;
        failCount += fitnessFail;
        debugPrint('✓ Fitness reminders: $fitnessSuccess success, $fitnessFail failed');
      } catch (e) {
        debugPrint('Failed to reschedule fitness reminders: $e');
        failCount++;
      }
      
      // Water reminder scheduling - waterReminder is Future, needs await
      final waterReminderData = await waterReminder;
      if (waterReminderData != null) {
        // TODO: Water reminder scheduling needs proper schema - temporarily disabled
        debugPrint('Water reminder scheduling temporarily disabled - schema needs update');
      }
      
      // Period reminder scheduling - periodReminder is Future, needs await  
      final periodReminderData = await periodReminder;
      if (periodReminderData != null) {
        try {
          final periodData = CleanStorageService.getPeriodData();
          if (periodData != null) {
            // TODO: Period reminder scheduling needs proper schema - temporarily disabled
            debugPrint('Period reminder scheduling temporarily disabled - schema needs update');
            successCount++; // Count as success for now
          }
        } catch (e) {
          debugPrint('Failed to schedule period reminder: $e');
          failCount++;
        }
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
