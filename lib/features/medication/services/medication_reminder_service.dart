import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/background_alarm_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import 'medicine_storage_service.dart';

/// Service for managing medication reminder notifications
/// Handles scheduling, updating, and canceling push notifications for medicines
class MedicationReminderService {
  static final MedicationReminderService _instance = MedicationReminderService._internal();
  factory MedicationReminderService() => _instance;
  MedicationReminderService._internal();

  final NotificationService _notificationService = NotificationService();

  /// Base ID offset for medication notifications to avoid conflicts
  static const int _medicineIdOffset = 100000;

  /// Max dose slots scheduled/cancelled per medicine. "Every X hours" fans out
  /// to up to ~16 slots/day (interval 1h from 08:00), so this bound must cover
  /// the busiest schedule — and cancel/hasActive MUST iterate to the same bound
  /// or updates leave orphaned notifications firing forever.
  static const int _maxSlotsPerMedicine = 24;

  /// SharedPreferences key for the master medication-reminders toggle.
  static const String masterEnabledKey = 'medication_reminders_master_enabled';

  /// Prefs key for the medicine → dense-index map (collision-free IDs).
  static const String _indexMapKey = 'medicine_notif_index_map';

  /// Prefs flag: the one-time migration to the dense ID scheme has run.
  static const String _idSchemeV2Key = 'medicine_notif_id_scheme_v2';

  Map<String, int>? _indexCache;

  /// Reschedule reminders for all stored medicines.
  Future<void> rescheduleAll() async {
    final medicines = await MedicineCleanStorageService.getAllMedicines();
    await scheduleAllReminders(medicines);
  }

  Future<Map<String, int>> _loadIndexMap() async {
    if (_indexCache != null) return _indexCache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexMapKey);
    final map = <String, int>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        (jsonDecode(raw) as Map).forEach(
            (k, v) => map[k.toString()] = (v as num).toInt());
      } catch (_) {}
    }
    _indexCache = map;
    return map;
  }

  /// A stable, densely-allocated index per medicine (never reused), so
  /// notification IDs never overlap across medicines. Persisted in prefs.
  Future<int> _medicineIndex(String medicineId) async {
    final map = await _loadIndexMap();
    final existing = map[medicineId];
    if (existing != null) return existing;
    final next = map.isEmpty ? 0 : (map.values.reduce((a, b) => a > b ? a : b) + 1);
    map[medicineId] = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexMapKey, jsonEncode(map));
    return next;
  }

  /// Collision-free notification ID for a medicine + time slot:
  /// `offset + medIndex*maxSlots + timeIndex` — non-overlapping across meds.
  Future<int> _notificationIdFor(String medicineId, int timeIndex) async {
    final idx = await _medicineIndex(medicineId);
    return _medicineIdOffset + idx * _maxSlotsPerMedicine + timeIndex;
  }

  /// One-time migration to the dense ID scheme: cancels any medicine alarms
  /// left under the OLD hash-based IDs (matched by `medicine_channel`) so they
  /// don't orphan. Water/other alarms are untouched. Caller reschedules after.
  Future<void> migrateNotificationIdsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_idSchemeV2Key) == true) return;
    try {
      final bg = BackgroundAlarmService();
      final alarms = await bg.getScheduledAlarms();
      for (final a in alarms) {
        if (a['channelId'] == 'medicine_channel') {
          final id = a['id'];
          if (id is int) await bg.cancelAlarm(id);
        }
      }
      await prefs.setBool(_idSchemeV2Key, true);
      debugPrint('✓ Migrated medicine notification IDs to dense scheme');
    } catch (e) {
      debugPrint('⚠️ Notification-ID migration failed: $e');
    }
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

    // Build the concrete dose slots. "Every X hours" fans a single anchor time
    // out across the whole day (e.g. 08:00 / 14:00 / 20:00); every other
    // frequency uses the stored times verbatim. Each slot becomes its OWN
    // daily-repeating notification, so ALL doses fire — not just the first.
    final List<ScheduledTime> slots;
    final String frequency;
    if (medicine.schedule.frequencyType == FrequencyType.everyXHours) {
      slots = medicine.schedule
          .getScheduledTimesForDate(DateTime.now())
          .map((d) => ScheduledTime(hour: d.hour, minute: d.minute))
          .toList();
      frequency = 'daily'; // each fanned-out slot simply repeats every day
    } else {
      slots = medicine.schedule.times;
      frequency = _getFrequencyString(medicine.schedule);
    }

    debugPrint('📅 Scheduling ${slots.length} reminders for ${medicine.name}');

    // Serialized schedule — the Android alarm callback reconstructs it and gates
    // firing to active days (so specific-days / every-X-days / cyclical / ended
    // meds no longer alarm every day). Same descriptor for every slot.
    final scheduleJson = jsonEncode(medicine.schedule.toJson());

    // Schedule notification for each dose slot (bounded so a tight interval
    // can't blow past the cancel bound and orphan notifications).
    for (int i = 0; i < slots.length && i < _maxSlotsPerMedicine; i++) {
      final time = slots[i];
      final notificationId = await _notificationIdFor(medicine.id, i);

      try {
        final success = await _notificationService.scheduleMedicineReminder(
          id: notificationId,
          medicineName: _buildReminderTitle(medicine, time),
          hour: time.hour,
          minute: time.minute,
          frequency: frequency,
          scheduleJson: scheduleJson,
          medicineId: medicine.id,
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

    // Cancel notification for each possible time slot (must cover the same
    // bound as scheduling, else fanned-out "every X hours" slots are orphaned).
    for (int i = 0; i < _maxSlotsPerMedicine; i++) {
      final notificationId = await _notificationIdFor(medicine.id, i);
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

    for (int i = 0; i < _maxSlotsPerMedicine; i++) {
      final notificationId = await _notificationIdFor(medicineId, i);
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

    // Habit-anchor: tie the dose to a mealtime cue (implementation intention —
    // the highest-leverage, evidence-based adherence nudge).
    final meal = medicine.schedule.mealTiming;
    if (meal != MealTiming.anytime) {
      buffer.write(' · ${meal.displayName.toLowerCase()}');
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

  /// Check if a medicine has any scheduled reminders.
  ///
  /// On Android the real schedule lives in AndroidAlarmManager (not
  /// flutter_local_notifications), so we consult the actual scheduled-alarm
  /// records via [BackgroundAlarmService.getScheduledAlarms].
  Future<bool> hasActiveReminders(String medicineId) async {
    final alarms = await BackgroundAlarmService().getScheduledAlarms();
    final activeIds = alarms
        .map((a) => a['id'])
        .whereType<int>()
        .toSet();
    for (int i = 0; i < _maxSlotsPerMedicine; i++) {
      if (activeIds.contains(await _notificationIdFor(medicineId, i))) {
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

  /// Snooze the reminder for a specific dose of [medicine].
  ///
  /// Resolves [scheduledTime] to its time-slot index (matching the same
  /// notification-id scheme used when the reminder was originally scheduled)
  /// and reschedules that notification [minutes] into the future.
  Future<bool> snoozeReminderForDose(
    EnhancedMedicine medicine,
    DateTime scheduledTime,
    int minutes,
  ) async {
    final timeIndex = _resolveTimeIndex(medicine, scheduledTime);
    final notificationId = await _notificationIdFor(medicine.id, timeIndex);
    return snoozeReminder(notificationId, minutes);
  }

  /// Find the index of the schedule time slot matching [scheduledTime].
  /// Falls back to 0 if no exact hour/minute match is found.
  int _resolveTimeIndex(EnhancedMedicine medicine, DateTime scheduledTime) {
    final times = medicine.schedule.times;
    for (int i = 0; i < times.length; i++) {
      if (times[i].hour == scheduledTime.hour &&
          times[i].minute == scheduledTime.minute) {
        return i;
      }
    }
    return 0;
  }
}
