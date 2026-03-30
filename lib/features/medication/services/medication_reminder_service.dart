import 'package:flutter/foundation.dart';
import '../../../core/services/notification_service.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';

/// Service for managing medication reminder notifications
/// Handles scheduling, updating, and canceling push notifications for medicines
class MedicationReminderService {
  static final MedicationReminderService _instance = MedicationReminderService._internal();
  factory MedicationReminderService() => _instance;
  MedicationReminderService._internal();

  final NotificationService _notificationService = NotificationService();

  /// Base ID offset for medication notifications to avoid conflicts
  static const int _medicineIdOffset = 100000;

  /// Generate unique notification ID for a medicine + time slot
  int _generateNotificationId(String medicineId, int timeIndex) {
    // Use hashCode of medicineId + timeIndex to generate unique ID
    return _medicineIdOffset + (medicineId.hashCode.abs() % 90000) + timeIndex;
  }

  /// Schedule all reminders for a medicine
  /// Returns list of notification IDs that were scheduled
  Future<List<int>> scheduleReminders(EnhancedMedicine medicine) async {
    final scheduledIds = <int>[];

    // Don't schedule if reminders are disabled or it's PRN (as-needed)
    if (!medicine.reminderEnabled || medicine.schedule.isPRN) {
      debugPrint('⏭️ Skipping reminders: enabled=${medicine.reminderEnabled}, isPRN=${medicine.schedule.isPRN}');
      return scheduledIds;
    }

    // Don't schedule if no times are set
    if (medicine.schedule.times.isEmpty) {
      debugPrint('⏭️ No reminder times set for ${medicine.name}');
      return scheduledIds;
    }

    // Don't schedule for archived or inactive medicines
    if (medicine.isArchived || !medicine.isActive) {
      debugPrint('⏭️ Medicine ${medicine.name} is archived/inactive');
      return scheduledIds;
    }

    debugPrint('📅 Scheduling ${medicine.schedule.times.length} reminders for ${medicine.name}');

    // Schedule notification for each time slot
    for (int i = 0; i < medicine.schedule.times.length; i++) {
      final time = medicine.schedule.times[i];
      final notificationId = _generateNotificationId(medicine.id, i);

      try {
        final success = await _notificationService.scheduleMedicineReminder(
          id: notificationId,
          medicineName: _buildReminderTitle(medicine, time),
          hour: time.hour,
          minute: time.minute,
          frequency: _getFrequencyString(medicine.schedule),
        );

        if (success) {
          scheduledIds.add(notificationId);
          debugPrint('✓ Scheduled reminder #$i for ${medicine.name} at ${time.formattedTime}');
        } else {
          debugPrint('⚠️ Failed to schedule reminder #$i for ${medicine.name}');
        }
      } catch (e) {
        debugPrint('❌ Error scheduling reminder: $e');
      }
    }

    return scheduledIds;
  }

  /// Cancel all reminders for a medicine
  Future<void> cancelReminders(EnhancedMedicine medicine) async {
    debugPrint('🗑️ Canceling all reminders for ${medicine.name}');

    // Cancel notification for each possible time slot
    // We cancel up to 10 possible time slots per medicine
    for (int i = 0; i < 10; i++) {
      final notificationId = _generateNotificationId(medicine.id, i);
      try {
        await _notificationService.cancelNotification(notificationId);
      } catch (e) {
        debugPrint('⚠️ Error canceling notification $notificationId: $e');
      }
    }
  }

  /// Cancel reminders by medicine ID string
  Future<void> cancelRemindersById(String medicineId) async {
    debugPrint('🗑️ Canceling reminders for medicine ID: $medicineId');

    for (int i = 0; i < 10; i++) {
      final notificationId = _generateNotificationId(medicineId, i);
      try {
        await _notificationService.cancelNotification(notificationId);
      } catch (e) {
        debugPrint('⚠️ Error canceling notification $notificationId: $e');
      }
    }
  }

  /// Update reminders for a medicine (cancel old, schedule new)
  Future<List<int>> updateReminders(EnhancedMedicine medicine) async {
    await cancelReminders(medicine);
    return await scheduleReminders(medicine);
  }

  /// Schedule reminders for multiple medicines (e.g., on app startup)
  Future<void> scheduleAllReminders(List<EnhancedMedicine> medicines) async {
    debugPrint('📅 Scheduling reminders for ${medicines.length} medicines');

    int totalScheduled = 0;
    for (final medicine in medicines) {
      final ids = await scheduleReminders(medicine);
      totalScheduled += ids.length;
    }

    debugPrint('✓ Scheduled $totalScheduled total reminders');
  }

  /// Build reminder title with medicine name and dosage info
  String _buildReminderTitle(EnhancedMedicine medicine, ScheduledTime time) {
    final buffer = StringBuffer(medicine.name);

    // Add strength if available
    if (medicine.strength != null && medicine.strength!.isNotEmpty) {
      buffer.write(' ${medicine.strength}');
    }

    // Add dosage amount
    buffer.write(' - ${medicine.displayDosage}');

    // Add time label if available
    if (time.label != null && time.label!.isNotEmpty) {
      buffer.write(' (${time.label})');
    }

    return buffer.toString();
  }

  /// Get frequency string for notification matching
  String _getFrequencyString(MedicineSchedule schedule) {
    switch (schedule.frequencyType) {
      case FrequencyType.onceDaily:
      case FrequencyType.twiceDaily:
      case FrequencyType.thriceDaily:
      case FrequencyType.fourTimesDaily:
        return 'daily';
      case FrequencyType.specificDays:
        return 'weekly'; // Will match specific days
      case FrequencyType.everyXDays:
        return 'interval';
      case FrequencyType.everyXHours:
        return 'hourly';
      case FrequencyType.cyclical:
        return 'cyclical';
      case FrequencyType.asNeeded:
        return 'prn';
    }
  }

  /// Check if a medicine has any scheduled reminders
  Future<bool> hasActiveReminders(String medicineId) async {
    // Check if any notification IDs exist for this medicine
    final pendingNotifications = await _notificationService.getPendingNotifications();
    
    for (int i = 0; i < 10; i++) {
      final notificationId = _generateNotificationId(medicineId, i);
      if (pendingNotifications.any((n) => n.id == notificationId)) {
        return true;
      }
    }
    return false;
  }

  /// Get next scheduled reminder time for a medicine
  DateTime? getNextReminderTime(EnhancedMedicine medicine) {
    if (!medicine.reminderEnabled || medicine.schedule.times.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final todaySchedule = medicine.schedule.getScheduledTimesForDate(now);

    // Find next upcoming time today
    for (final time in todaySchedule) {
      if (time.isAfter(now)) {
        return time;
      }
    }

    // If no time today, get first time tomorrow
    final tomorrowSchedule = medicine.schedule.getScheduledTimesForDate(
      now.add(const Duration(days: 1)),
    );

    if (tomorrowSchedule.isNotEmpty) {
      return tomorrowSchedule.first;
    }

    return null;
  }

  /// Snooze a specific reminder
  Future<bool> snoozeReminder(int notificationId, int minutes) async {
    try {
      await _notificationService.snoozeReminder(notificationId, minutes);
      debugPrint('✓ Snoozed reminder $notificationId for $minutes minutes');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to snooze reminder: $e');
      return false;
    }
  }
}

/// Extension to add pending notifications getter
extension NotificationServiceExtension on NotificationService {
  Future<List<PendingNotificationInfo>> getPendingNotifications() async {
    // This would need to be implemented in NotificationService
    // For now, return empty list
    return [];
  }
}

/// Info about a pending notification
class PendingNotificationInfo {
  final int id;
  final String? title;
  final String? body;
  final DateTime? scheduledTime;

  PendingNotificationInfo({
    required this.id,
    this.title,
    this.body,
    this.scheduledTime,
  });
}
