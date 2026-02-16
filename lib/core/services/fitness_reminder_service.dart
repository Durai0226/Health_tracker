import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_settings.dart';
import '../../features/fitness/models/fitness_reminder.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'background_alarm_service.dart';

/// FitnessReminderService - Robust fitness reminder management
/// Inspired by best practices from Fitbit, Strava, and other fitness apps:
/// - Dynamic scheduling based on user preferences
/// - Non-blocking background operations
/// - Automatic retry and error recovery
/// - Support for various frequency patterns
class FitnessReminderService {
  static final FitnessReminderService _instance = FitnessReminderService._internal();
  
  factory FitnessReminderService() => _instance;
  
  FitnessReminderService._internal();
  
  final NotificationService _notificationService = NotificationService();
  final BackgroundAlarmService _alarmService = BackgroundAlarmService();
  
  bool _isInitialized = false;
  
  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      await _notificationService.init();
      await _alarmService.init();
      _isInitialized = true;
      debugPrint('✓ FitnessReminderService initialized');
    } catch (e) {
      debugPrint('⚠️ FitnessReminderService init error: $e');
      _isInitialized = true; // Prevent init loops
    }
  }
  
  /// Schedule a fitness reminder with retry logic
  /// Returns true if scheduled successfully
  Future<bool> scheduleReminder(FitnessReminder reminder, {int maxRetries = 3}) async {
    if (!reminder.isEnabled) {
      debugPrint('ℹ️ Reminder ${reminder.id} is disabled, skipping');
      return true;
    }
    
    await init();
    
    int attempts = 0;
    bool success = false;
    
    while (attempts < maxRetries && !success) {
      attempts++;
      try {
        success = await _scheduleReminderInternal(reminder);
        if (success) {
          debugPrint('✓ Fitness reminder scheduled: ${reminder.title} (attempt $attempts)');
        }
      } catch (e) {
        debugPrint('⚠️ Schedule attempt $attempts failed: $e');
        if (attempts < maxRetries) {
          // Exponential backoff
          await Future.delayed(Duration(milliseconds: 100 * attempts));
        }
      }
    }
    
    if (!success) {
      debugPrint('❌ Failed to schedule reminder after $maxRetries attempts');
    }
    
    return success;
  }
  
  Future<bool> _scheduleReminderInternal(FitnessReminder reminder) async {
    final notificationId = _generateNotificationId(reminder.id);
    final hour = reminder.reminderTime.hour;
    final minute = reminder.reminderTime.minute;
    
    // Get user settings for notification preferences
    UserSettings settings;
    try {
      settings = StorageService.getUserSettings();
    } catch (e) {
      settings = UserSettings();
    }
    
    final title = '${reminder.emoji} ${reminder.title}';
    final body = _generateReminderBody(reminder, settings);
    
    return await _notificationService.scheduleFitnessReminder(
      id: notificationId,
      title: title,
      body: body,
      hour: hour,
      minute: minute,
      frequency: reminder.frequency,
    );
  }
  
  /// Generate a unique notification ID from reminder ID
  int _generateNotificationId(String reminderId) {
    return reminderId.hashCode.abs() % 100000;
  }
  
  /// Generate reminder body text based on settings
  String _generateReminderBody(FitnessReminder reminder, UserSettings settings) {
    final duration = reminder.durationMinutes;
    final messages = [
      'Time for your $duration min ${reminder.title.toLowerCase()}! 💪',
      'Ready for $duration minutes of ${reminder.title.toLowerCase()}? Let\'s go!',
      'Your ${reminder.title.toLowerCase()} session awaits! ($duration min)',
    ];
    
    // Rotate messages based on day of week for variety
    final messageIndex = DateTime.now().weekday % messages.length;
    return messages[messageIndex];
  }
  
  /// Cancel a fitness reminder
  Future<bool> cancelReminder(FitnessReminder reminder) async {
    try {
      final notificationId = _generateNotificationId(reminder.id);
      await _notificationService.cancelFitnessNotification(notificationId, reminder.frequency);
      debugPrint('✓ Cancelled reminder: ${reminder.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to cancel reminder: $e');
      return false;
    }
  }
  
  /// Reschedule all enabled fitness reminders
  /// Call this after settings change or app restart
  Future<Map<String, bool>> rescheduleAllReminders() async {
    final results = <String, bool>{};
    
    try {
      final reminders = StorageService.getAllFitnessReminders();
      debugPrint('🔄 Rescheduling ${reminders.length} fitness reminders...');
      
      for (final reminder in reminders) {
        if (reminder.isEnabled) {
          // Run scheduling in parallel but don't block
          final success = await scheduleReminder(reminder);
          results[reminder.id] = success;
        } else {
          // Cancel disabled reminders
          await cancelReminder(reminder);
          results[reminder.id] = true;
        }
      }
      
      final successCount = results.values.where((v) => v).length;
      debugPrint('✓ Rescheduled $successCount/${reminders.length} reminders');
    } catch (e) {
      debugPrint('❌ Error rescheduling reminders: $e');
    }
    
    return results;
  }
  
  /// Update a single reminder (cancel old, schedule new)
  Future<bool> updateReminder(FitnessReminder oldReminder, FitnessReminder newReminder) async {
    try {
      // Cancel the old reminder first
      await cancelReminder(oldReminder);
      
      // Save the new reminder
      await StorageService.updateFitnessReminder(newReminder);
      
      // Schedule the new reminder if enabled
      if (newReminder.isEnabled) {
        return await scheduleReminder(newReminder);
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error updating reminder: $e');
      return false;
    }
  }
  
  /// Delete a reminder and cancel its notifications
  Future<bool> deleteReminder(FitnessReminder reminder) async {
    try {
      await cancelReminder(reminder);
      await StorageService.deleteFitnessReminder(reminder.id);
      debugPrint('✓ Deleted reminder: ${reminder.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting reminder: $e');
      return false;
    }
  }
  
  /// Check if a reminder should fire today based on frequency
  bool shouldFireToday(FitnessReminder reminder) {
    final today = DateTime.now().weekday;
    
    switch (reminder.frequency) {
      case 'daily':
        return true;
      case 'weekdays':
        return today >= DateTime.monday && today <= DateTime.friday;
      case 'weekends':
        return today == DateTime.saturday || today == DateTime.sunday;
      case 'custom':
        return reminder.customDays?.contains(today) ?? false;
      default:
        return true;
    }
  }
  
  /// Get next scheduled time for a reminder
  DateTime? getNextScheduledTime(FitnessReminder reminder) {
    if (!reminder.isEnabled) return null;
    
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.reminderTime.hour,
      reminder.reminderTime.minute,
    );
    
    // If time has passed today, start from tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Find next valid day based on frequency
    int attempts = 0;
    while (attempts < 7) {
      final tempReminder = FitnessReminder(
        id: reminder.id,
        type: reminder.type,
        title: reminder.title,
        reminderTime: scheduledDate,
        frequency: reminder.frequency,
        customDays: reminder.customDays,
      );
      
      if (shouldFireToday(tempReminder)) {
        return scheduledDate;
      }
      
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      attempts++;
    }
    
    return scheduledDate;
  }
  
  /// Get all active reminders sorted by next fire time
  List<FitnessReminder> getActiveRemindersSorted() {
    try {
      final reminders = StorageService.getAllFitnessReminders()
          .where((r) => r.isEnabled)
          .toList();
      
      reminders.sort((a, b) {
        final nextA = getNextScheduledTime(a);
        final nextB = getNextScheduledTime(b);
        if (nextA == null && nextB == null) return 0;
        if (nextA == null) return 1;
        if (nextB == null) return -1;
        return nextA.compareTo(nextB);
      });
      
      return reminders;
    } catch (e) {
      debugPrint('Error getting sorted reminders: $e');
      return [];
    }
  }
  
  /// Schedule a quick test notification for debugging
  Future<bool> scheduleTestNotification() async {
    try {
      await init();
      return await _notificationService.scheduleQuickTestNotification();
    } catch (e) {
      debugPrint('Error scheduling test: $e');
      return false;
    }
  }
}
