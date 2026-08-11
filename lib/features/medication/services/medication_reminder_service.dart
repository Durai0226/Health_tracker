import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/health/adaptive_timing.dart';
import '../../../core/services/background_alarm_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import 'medicine_storage_service.dart';
import 'reminder_slot_grouping.dart';
import 'reminder_window_nudges.dart';

/// Service for managing medication reminder notifications
/// Handles scheduling, updating, and canceling push notifications for medicines
///
/// Android and iOS use two different id/grouping schemes:
///  - **Android**: one notification per exact (hour, minute) SLOT, shared by
///    every medicine due at that clock time (Phase 1 grouping — "4 medicines
///    at 8am" is one InboxStyle notification, not four). Ids are a pure
///    function of the clock time ([slotNotificationId]), so scheduling one
///    medicine recomputes and re-diffs every Android medicine alarm.
///  - **iOS**: `zonedSchedule` has no grouping mechanism, so it keeps the
///    original one-notification-per-medicine scheme with densely-allocated
///    per-medicine ids, unchanged.
class MedicationReminderService {
  static final MedicationReminderService _instance = MedicationReminderService._internal();
  factory MedicationReminderService() => _instance;
  MedicationReminderService._internal();

  final NotificationService _notificationService = NotificationService();

  /// Base ID offset for medication notifications to avoid conflicts (iOS
  /// legacy per-medicine scheme only — Android uses [slotIdOffset]).
  static const int _medicineIdOffset = 100000;

  /// Max dose slots scheduled/cancelled per medicine (iOS legacy scheme). "Every
  /// X hours" fans out to up to ~16 slots/day (interval 1h from 08:00), so this
  /// bound must cover the busiest schedule — and cancel/hasActive MUST iterate
  /// to the same bound or updates leave orphaned notifications firing forever.
  static const int _maxSlotsPerMedicine = 24;

  /// SharedPreferences key for the master medication-reminders toggle.
  static const String masterEnabledKey = 'medication_reminders_master_enabled';

  /// Prefs key for the medicine → dense-index map (iOS legacy scheme).
  static const String _indexMapKey = 'medicine_notif_index_map';

  /// Prefs flags: one-time migrations, run in order. v2 predates this service
  /// (hash-based ids → dense per-medicine ids); v3 is Phase 1's Android-only
  /// move from dense per-medicine ids to per-slot ids.
  static const String _idSchemeV2Key = 'medicine_notif_id_scheme_v2';
  static const String _idSchemeV3Key = 'medicine_notif_id_scheme_v3';

  Map<String, int>? _indexCache;

  /// Reschedule reminders for all stored medicines.
  ///
  /// Unscoped (`scopeToActiveProfile: false`): reminders must keep firing for
  /// every profile's medicines regardless of which one happens to be active
  /// in the UI — a caregiver's dependent's alarms can't silently stop just
  /// because a different profile is currently selected.
  Future<void> rescheduleAll() async {
    final medicines = await MedicineCleanStorageService.getAllMedicines(
        scopeToActiveProfile: false);
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
  /// iOS legacy scheme only.
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

  /// Collision-free notification ID for a medicine + time slot (iOS legacy
  /// scheme): `offset + medIndex*maxSlots + timeIndex` — non-overlapping
  /// across meds.
  Future<int> _notificationIdFor(String medicineId, int timeIndex) async {
    final idx = await _medicineIndex(medicineId);
    return _medicineIdOffset + idx * _maxSlotsPerMedicine + timeIndex;
  }

  /// Runs every pending one-time id-scheme migration, in order. Each cancels
  /// any medicine alarms left under the OLD scheme (matched by
  /// `medicine_channel`) so they don't orphan; the caller reschedules after.
  /// Water/other alarms are untouched.
  Future<void> migrateNotificationIdsIfNeeded() async {
    await _wipeMedicineChannelAlarmsOnce(
        _idSchemeV2Key, 'v2 (dense per-medicine ids)');
    // v3 (per-slot ids) only changes Android's scheme — iOS keeps the dense
    // per-medicine scheme forever, so there's nothing to migrate there.
    if (Platform.isAndroid) {
      await _wipeMedicineChannelAlarmsOnce(
          _idSchemeV3Key, 'v3 (per-slot Android ids)');
    }
  }

  Future<void> _wipeMedicineChannelAlarmsOnce(
      String versionKey, String label) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(versionKey) == true) return;
    try {
      final bg = BackgroundAlarmService();
      final alarms = await bg.getScheduledAlarms();
      for (final a in alarms) {
        if (a['channelId'] == 'medicine_channel') {
          final id = a['id'];
          if (id is int) await bg.cancelAlarm(id);
        }
      }
      await prefs.setBool(versionKey, true);
      debugPrint('✓ Migrated medicine notification IDs to $label');
    } catch (e) {
      debugPrint('⚠️ Notification-ID migration ($label) failed: $e');
    }
  }

  /// Schedule all reminders for a medicine.
  /// Returns the notification id(s) now covering this medicine.
  Future<List<int>> scheduleReminders(EnhancedMedicine medicine) async {
    if (Platform.isAndroid) {
      final medicines = await _resolveMedicines(upsert: medicine);
      final slots = await _recomputeAndroidSlots(medicines);
      await _recomputeWindowNudges(medicines);
      return slots
          .where((s) => s.medicines.any((m) => m.medicineId == medicine.id))
          .map((s) => s.notificationId)
          .toList();
    }
    return _scheduleRemindersLegacy(medicine);
  }

  /// iOS legacy path: one `zonedSchedule` per (medicine, slot) — unchanged
  /// from before Phase 1 grouping existed.
  Future<List<int>> _scheduleRemindersLegacy(EnhancedMedicine medicine) async {
    final scheduledIds = <int>[];

    if (!medicine.reminderEnabled || medicine.schedule.isPRN) {
      debugPrint('⏭️ Skipping reminders: enabled=${medicine.reminderEnabled}, isPRN=${medicine.schedule.isPRN}');
      return scheduledIds;
    }
    if (medicine.schedule.times.isEmpty) {
      debugPrint('⏭️ No reminder times set for ${medicine.name}');
      return scheduledIds;
    }
    if (medicine.isArchived || !medicine.isActive) {
      debugPrint('⏭️ Medicine ${medicine.name} is archived/inactive');
      return scheduledIds;
    }

    final List<ScheduledTime> slots;
    final String frequency;
    if (medicine.schedule.frequencyType == FrequencyType.everyXHours) {
      slots = medicine.schedule
          .getScheduledTimesForDate(DateTime.now())
          .map((d) => ScheduledTime(hour: d.hour, minute: d.minute))
          .toList();
      frequency = 'daily';
    } else {
      slots = medicine.schedule.times;
      frequency = _getFrequencyString(medicine.schedule);
    }

    debugPrint('📅 Scheduling ${slots.length} reminders for ${medicine.name}');

    final scheduleJson = jsonEncode(medicine.schedule.toJson());

    for (int i = 0; i < slots.length && i < _maxSlotsPerMedicine; i++) {
      final time = slots[i];
      final notificationId = await _notificationIdFor(medicine.id, i);

      try {
        final success = await _notificationService.scheduleMedicineReminder(
          id: notificationId,
          medicineName: buildMedicineReminderLine(medicine, time),
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

  /// Resolves the full medicine list a recompute should act on: unscoped
  /// (every profile, regardless of which is active — see the two recompute
  /// methods below for why), with [upsert] overriding whatever storage holds
  /// for that medicine's id (needed when the caller schedules before/without
  /// a prior save) and/or [excludeMedicineId] removing a medicine regardless
  /// of what storage currently says (needed when cancelling BEFORE a delete,
  /// while the row is still in storage).
  Future<List<EnhancedMedicine>> _resolveMedicines({
    List<EnhancedMedicine>? allMedicines,
    EnhancedMedicine? upsert,
    String? excludeMedicineId,
  }) async {
    var medicines = allMedicines ??
        await MedicineCleanStorageService.getAllMedicines(
            scopeToActiveProfile: false);
    if (excludeMedicineId != null) {
      medicines = medicines.where((m) => m.id != excludeMedicineId).toList();
    }
    if (upsert != null) {
      medicines = [
        for (final m in medicines) if (m.id != upsert.id) m,
        upsert,
      ];
    }
    return medicines;
  }

  /// Recomputes every Android medicine-slot alarm from [medicines] (the full
  /// list, already resolved by [_resolveMedicines]), (re)schedules each
  /// slot's alarm, then cancels any previously-scheduled slot that's no
  /// longer needed (its only occupant was deleted/archived/retimed away).
  /// Full recompute rather than tracking per-medicine deltas: correctness
  /// over cleverness, and this only runs on medicine CRUD — not a hot path.
  ///
  /// [medicines] must be the FULL list (every profile): this method's own
  /// diff-cancel step treats any currently-scheduled slot id NOT in its
  /// medicines list as orphaned and cancels it, so a partial list would read
  /// every excluded medicine's alarm as orphaned and cancel it.
  Future<List<ReminderSlot>> _recomputeAndroidSlots(
      List<EnhancedMedicine> medicines) async {
    final slots = groupRemindersBySlot(medicines, DateTime.now());
    final neededIds = <int>{};
    for (final slot in slots) {
      neededIds.add(slot.notificationId);
      try {
        await _notificationService.scheduleMedicineSlotReminder(slot);
      } catch (e) {
        debugPrint('❌ Error scheduling slot ${slot.hour}:${slot.minute}: $e');
      }
    }

    try {
      final alarms = await BackgroundAlarmService().getScheduledAlarms();
      for (final a in alarms) {
        if (a['channelId'] != 'medicine_channel') continue;
        final id = a['id'];
        if (id is int &&
            id >= slotIdOffset &&
            id < slotIdOffset + 1440 &&
            !neededIds.contains(id)) {
          await BackgroundAlarmService().cancelAlarm(id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error pruning stale medicine slots: $e');
    }

    return slots;
  }

  /// Recomputes every Android window-nudge alarm from [medicines] — the same
  /// "full recompute, diff-cancel" approach as [_recomputeAndroidSlots], for
  /// the same reason. A window-enabled dose gets up to 3 nudge alarms (start/
  /// middle/end); [_recomputeAndroidSlots] already skips these doses entirely
  /// (see [groupRemindersBySlot]), so the two recomputations partition the
  /// same medicine list without overlapping.
  ///
  /// Only nudge index 0 (the window's start) is (re)scheduled directly here.
  /// It's a self-rescheduling "isRepeating" alarm that chains nudges 1 and 2
  /// itself each time it fires (see background_alarm_service.dart's
  /// window-nudge branch) — this recompute never touches their ids directly,
  /// but DOES protect them from being pruned as "orphaned" by adding their
  /// ids to [neededIds] too, since their lifecycle is owned by the chain, not
  /// by this periodic recompute.
  Future<void> _recomputeWindowNudges(List<EnhancedMedicine> medicines) async {
    final neededIds = <int>{};

    for (final medicine in medicines) {
      if (!medicine.reminderEnabled || medicine.schedule.isPRN) continue;
      if (medicine.isArchived || !medicine.isActive) continue;

      final medicineIndex = await _medicineIndex(medicine.id);
      final times = medicine.schedule.times;

      for (int timeIndex = 0;
          timeIndex < times.length && timeIndex < maxSlotsPerMedicinePerDay;
          timeIndex++) {
        final time = times[timeIndex];
        if (!time.hasWindow) continue;

        for (int n = 0; n < maxNudgesPerTime; n++) {
          neededIds.add(windowNudgeId(medicineIndex, timeIndex, n));
        }

        final adaptiveMinutes = await _adaptiveSuggestionMinutes(medicine, time);
        final nudgeMinutes = windowNudgeMinutes(
          startMinuteOfDay: time.hour * 60 + time.minute,
          windowMinutes: time.windowMinutes!,
          adaptiveSuggestedMinutes: adaptiveMinutes,
        );
        final scheduleJson = jsonEncode(medicine.schedule.toJson());
        final id = windowNudgeId(medicineIndex, timeIndex, 0);
        try {
          await _notificationService.scheduleMedicineWindowNudge(
            id: id,
            medicine: medicine,
            time: time,
            nudgeMinutes: nudgeMinutes,
            scheduleJson: scheduleJson,
          );
        } catch (e) {
          debugPrint(
              '❌ Error scheduling window nudge for ${medicine.name}: $e');
        }
      }
    }

    try {
      final alarms = await BackgroundAlarmService().getScheduledAlarms();
      for (final a in alarms) {
        if (a['channelId'] != 'medicine_channel') continue;
        final id = a['id'];
        // Upper-bound excludes the +100000 snooze range, mirroring
        // _recomputeAndroidSlots's `id < slotIdOffset + 1440` — a live
        // window-nudge snooze alarm isn't in neededIds (its lifecycle is
        // self-contained: it fires once, or is replaced by a fresh snooze),
        // so without this bound the very next recompute would cancel it.
        if (id is int &&
            id >= windowNudgeIdOffset &&
            id < windowNudgeIdOffset + 100000 &&
            !neededIds.contains(id)) {
          await BackgroundAlarmService().cancelAlarm(id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error pruning stale window nudges: $e');
    }
  }

  /// The user's real median take-time for this dose, in minutes-of-day, if
  /// [AdaptiveTiming] is confident about it — null otherwise (too few doses
  /// logged, or the timing isn't consistent enough to trust). Must run here,
  /// on the main isolate: it needs Drift (via `getLogsForMedicine`), which is
  /// unavailable inside the background alarm isolate where a fired nudge
  /// actually runs — so the result is pre-computed at schedule time and
  /// carried in the persisted alarm data, not recomputed live.
  Future<int?> _adaptiveSuggestionMinutes(
      EnhancedMedicine medicine, ScheduledTime time) async {
    try {
      // Unscoped: this runs while recomputing window nudges for the FULL,
      // cross-profile medicine list (see _recomputeWindowNudges's own doc),
      // so a dependent's medicine must see ITS logs even while a different
      // profile (e.g. self) is currently active — getLogsForMedicine's
      // default scoping would otherwise silently return zero logs for it and
      // make AdaptiveTiming report "not confident" every time.
      final logs = MedicineCleanStorageService.dedupeByDose(
          await MedicineCleanStorageService.getLogsForMedicine(medicine.id,
              scopeToActiveProfile: false));
      // Deliberately l.isTaken, NOT countsAsTaken: a pre-logged dose's
      // actionTime is an artificial early timestamp (the pre-log moment),
      // not a real "when do I actually take this dose" data point — folding
      // it in would corrupt this suggestion.
      final actualMinutes = logs
          .where((l) => l.isTaken && l.actionTime != null)
          .map((l) => l.actionTime!.hour * 60 + l.actionTime!.minute)
          .toList();
      final suggestion = AdaptiveTiming.suggest(
        scheduledMinutes: time.hour * 60 + time.minute,
        actualMinutes: actualMinutes,
      );
      return suggestion.confident ? suggestion.suggestedMinutes : null;
    } catch (e) {
      debugPrint('⚠️ Adaptive suggestion failed for ${medicine.name}: $e');
      return null;
    }
  }

  /// Cancel all reminders for a medicine.
  Future<void> cancelReminders(EnhancedMedicine medicine) async {
    debugPrint('🗑️ Canceling all reminders for ${medicine.name}');
    if (Platform.isAndroid) {
      final medicines = await _resolveMedicines(excludeMedicineId: medicine.id);
      await _recomputeAndroidSlots(medicines);
      await _recomputeWindowNudges(medicines);
      return;
    }
    await _cancelRemindersLegacy(medicine.id);
  }

  /// Cancel reminders by medicine ID string.
  Future<void> cancelRemindersById(String medicineId) async {
    debugPrint('🗑️ Canceling reminders for medicine ID: $medicineId');
    if (Platform.isAndroid) {
      final medicines = await _resolveMedicines(excludeMedicineId: medicineId);
      await _recomputeAndroidSlots(medicines);
      await _recomputeWindowNudges(medicines);
      return;
    }
    await _cancelRemindersLegacy(medicineId);
  }

  Future<void> _cancelRemindersLegacy(String medicineId) async {
    for (int i = 0; i < _maxSlotsPerMedicine; i++) {
      final notificationId = await _notificationIdFor(medicineId, i);
      try {
        await _notificationService.cancelNotification(notificationId);
      } catch (e) {
        debugPrint('⚠️ Error canceling notification $notificationId: $e');
      }
    }
  }

  /// Update reminders for a medicine (cancel old, schedule new).
  Future<List<int>> updateReminders(EnhancedMedicine medicine) async {
    // Android: scheduleReminders' upsert-and-recompute already prunes any
    // slot this medicine no longer occupies — a separate cancel pass would
    // just redo the same recompute twice.
    if (Platform.isAndroid) return scheduleReminders(medicine);
    await cancelReminders(medicine);
    return await scheduleReminders(medicine);
  }

  /// Schedule reminders for multiple medicines (e.g., on app startup).
  Future<void> scheduleAllReminders(List<EnhancedMedicine> medicines) async {
    debugPrint('📅 Scheduling reminders for ${medicines.length} medicines');

    if (Platform.isAndroid) {
      final slots = await _recomputeAndroidSlots(medicines);
      await _recomputeWindowNudges(medicines);
      debugPrint('✓ Scheduled ${slots.length} medicine slot(s)');
      return;
    }

    int totalScheduled = 0;
    for (final medicine in medicines) {
      final ids = await _scheduleRemindersLegacy(medicine);
      totalScheduled += ids.length;
    }
    debugPrint('✓ Scheduled $totalScheduled total reminders');
  }

  /// Get frequency string for notification matching (iOS legacy scheme only).
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
    if (Platform.isAndroid) {
      for (final a in alarms) {
        if (a['channelId'] != 'medicine_channel') continue;
        final medicines = (a['medicines'] as List?) ?? const [];
        if (medicines.any(
            (m) => (m as Map)['medicineId']?.toString() == medicineId)) {
          return true;
        }
      }
      return false;
    }

    final activeIds = alarms.map((a) => a['id']).whereType<int>().toSet();
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
  /// On Android the notification id is a pure function of the slot's clock
  /// time, shared by every co-slotted medicine, so no per-medicine index is
  /// needed. iOS keeps resolving the legacy per-medicine + time-index id.
  Future<bool> snoozeReminderForDose(
    EnhancedMedicine medicine,
    DateTime scheduledTime,
    int minutes,
  ) async {
    if (Platform.isAndroid) {
      final notificationId =
          slotNotificationId(scheduledTime.hour, scheduledTime.minute);
      return snoozeReminder(notificationId, minutes);
    }
    final timeIndex = _resolveTimeIndex(medicine, scheduledTime);
    final notificationId = await _notificationIdFor(medicine.id, timeIndex);
    return snoozeReminder(notificationId, minutes);
  }

  /// Find the index of the schedule time slot matching [scheduledTime]
  /// (iOS legacy scheme only). Falls back to 0 if no exact hour/minute match
  /// is found.
  ///
  /// Resolves against the EXPANDED per-day slots (not the raw anchor list), so
  /// 'every X hours' meds — whose single anchor fans out to many daily slots —
  /// map a fired dose to the correct slot index instead of always 0.
  int _resolveTimeIndex(EnhancedMedicine medicine, DateTime scheduledTime) {
    final slots = medicine.schedule.getScheduledTimesForDate(scheduledTime);
    for (int i = 0; i < slots.length; i++) {
      if (slots[i].hour == scheduledTime.hour &&
          slots[i].minute == scheduledTime.minute) {
        return i;
      }
    }
    return 0;
  }
}
