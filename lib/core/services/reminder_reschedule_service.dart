import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'fitness_reminder_service.dart';

class ReminderRescheduleService {
  static Future<void> rescheduleAllReminders() async {
    debugPrint('🔄 Rescheduling all reminders...');
    
    try {
      final medicines = StorageService.getAllMedicines();
      final healthChecks = StorageService.getAllHealthChecks();
      final waterReminder = StorageService.getWaterReminder();
      final periodReminder = StorageService.getPeriodReminder();
      
      int successCount = 0;
      int failCount = 0;
      
      // Schedule medicine reminders
      for (final medicine in medicines) {
        if (medicine.enableReminder) {
          try {
            final scheduled = await NotificationService().scheduleMedicineReminder(
              id: medicine.id.hashCode,
              medicineName: medicine.name,
              hour: medicine.time.hour,
              minute: medicine.time.minute,
              frequency: medicine.frequency,
            );
            scheduled ? successCount++ : failCount++;
          } catch (e) {
            debugPrint('Failed to schedule medicine reminder ${medicine.name}: $e');
            failCount++;
          }
        }
      }
      
      // Schedule health check reminders
      for (final check in healthChecks) {
        if (check.enableReminder) {
          try {
            final scheduled = await NotificationService().scheduleHealthCheckReminder(
              id: check.id.hashCode,
              checkType: check.type,
              hour: check.reminderTime.hour,
              minute: check.reminderTime.minute,
              frequency: check.frequency,
            );
            scheduled ? successCount++ : failCount++;
          } catch (e) {
            debugPrint('Failed to schedule health check reminder ${check.type}: $e');
            failCount++;
          }
        }
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
      
      if (waterReminder != null && waterReminder.isEnabled) {
        for (int i = 0; i < waterReminder.reminderTimes.length; i++) {
          try {
            final time = waterReminder.reminderTimes[i];
            final scheduled = await NotificationService().scheduleWaterReminder(
              id: 900000 + i,
              hour: time.hour,
              minute: time.minute,
            );
            scheduled ? successCount++ : failCount++;
          } catch (e) {
            debugPrint('Failed to schedule water reminder $i: $e');
            failCount++;
          }
        }
      }
      
      if (periodReminder != null && periodReminder.isEnabled) {
        try {
          final periodData = StorageService.getPeriodData();
          if (periodData != null) {
            final nextPeriod = periodData.nextPeriodDate;
            final reminderDate = nextPeriod.subtract(Duration(days: periodReminder.daysBefore));
            final reminderDateTime = DateTime(
              reminderDate.year,
              reminderDate.month,
              reminderDate.day,
              periodReminder.reminderTime.hour,
              periodReminder.reminderTime.minute,
            );
            
            final scheduled = await NotificationService().schedulePeriodReminder(
              id: 800000,
              reminderDate: reminderDateTime,
              daysBefore: periodReminder.daysBefore,
            );
            scheduled ? successCount++ : failCount++;
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
