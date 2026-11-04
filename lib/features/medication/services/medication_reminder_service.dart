import 'dart:convert';
import 'dart:io' show Platform;
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show PendingNotificationRequest;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/health/adaptive_timing.dart';
import '../../../core/services/background_alarm_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/reminder_budget.dart';
import '../../../core/services/background_alarm_service.dart'
    show ReminderKind;
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import '../models/medicine_snooze.dart';
import '../../../core/utils/calendar_day.dart';
import '../models/medicine_log.dart';
import 'medicine_storage_service.dart';
import 'reminder_slot_grouping.dart';
import 'reminder_window_nudges.dart';
import 'critical_follow_up.dart';
import 'ios_dose_plan.dart';
import '../../reminders/models/reminder_sounds.dart';

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

  /// Forces the Android recompute path on a host that isn't Android.
  ///
  /// `Platform.isAndroid` is a dart:io constant — `debugDefaultTargetPlatform`
  /// does not move it — so a headless `flutter test` can only ever reach the
  /// iOS legacy branch, and every read this class makes lives on the other one.
  /// Forcing it is safe: the scheduling calls the recomputes make are
  /// themselves `Platform.isAndroid`-gated inside [NotificationService] and
  /// return false without touching a channel, so this changes which of OUR
  /// code runs, not which platform APIs it reaches.
  @visibleForTesting
  static bool debugForceAndroidPath = false;

  static bool get _useAndroidPath =>
      Platform.isAndroid || debugForceAndroidPath;

  /// Overridable so a test can count the alarm snapshots ONE recompute takes:
  /// [BackgroundAlarmService.getScheduledAlarms] re-reads and `jsonDecode`s
  /// every `alarm_*` preference, and the two recomputes below used to take one
  /// each. Production always gets the real reader.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> Function()? debugAlarmReader;

  Future<List<Map<String, dynamic>>> _readAlarms() =>
      (debugAlarmReader ?? BackgroundAlarmService().getScheduledAlarms)();

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
    if (_useAndroidPath) {
      final medicines = await _resolveMedicines(upsert: medicine);
      final slots = await _recomputeAll(medicines);
      return slots
          .where((s) => s.medicines.any((m) => m.medicineId == medicine.id))
          .map((s) => s.notificationId)
          .toList();
    }
    return _scheduleRemindersLegacy(medicine);
  }

  /// iOS legacy path: one `zonedSchedule` per planned dose (see [IosDosePlan]) —
  /// the per-medicine ids and one-notification-per-medicine shape are unchanged
  /// from before Phase 1 grouping existed; what each one repeats on is not.
  Future<List<int>> _scheduleRemindersLegacy(EnhancedMedicine medicine) async =>
      (await _armLegacy(medicine)).ids;

  /// [_scheduleRemindersLegacy], and how many of the doses it tried to arm the
  /// platform refused — which nothing throws for, and a caller that records "armed"
  /// needs to know.
  Future<({List<int> ids, int failed})> _armLegacy(
      EnhancedMedicine medicine) async {
    final scheduledIds = <int>[];
    var failed = 0;

    final firstId = await _notificationIdFor(medicine.id, 0);

    /// Withdraw this medicine's reminders from position [from] on: the ones an earlier
    /// arming left. Only ids that are pending — a pass over many medicines is
    /// otherwise 24 platform calls each for nothing — so [pendingNow], which the
    /// caller has read, is what it goes by.
    Future<void> withdrawFrom(
        int from, List<PendingNotificationRequest> pendingNow) async {
      final ids = [
        for (final p in pendingNow)
          if (p.id >= firstId + from && p.id < firstId + _maxSlotsPerMedicine) p.id
      ];
      for (final id in ids) {
        try {
          await _notificationService.cancelNotification(id);
        } catch (e) {
          debugPrint('⚠️ Error withdrawing reminder $id for ${medicine.name}: $e');
        }
      }
    }

    // A medicine that is not to be reminded of has nothing armed: whatever an earlier
    // arming left (a course's doses, say) is withdrawn here, because the callers that
    // switch reminders off or archive a medicine are not the only way to get here.
    // Best effort: when the phone cannot say what is pending there is nothing to go
    // by, and nothing was going to be armed anyway.
    Future<void> withdrawAll() async {
      try {
        await withdrawFrom(0, await _notificationService.getPendingNotifications());
      } catch (e) {
        debugPrint('⚠️ Could not list pending reminders to withdraw ${medicine.name}\'s: $e');
      }
    }

    if (!medicine.reminderEnabled || medicine.schedule.isPRN) {
      debugPrint('⏭️ Skipping reminders: enabled=${medicine.reminderEnabled}, isPRN=${medicine.schedule.isPRN}');
      await withdrawAll();
      return (ids: scheduledIds, failed: 0);
    }
    if (medicine.schedule.times.isEmpty) {
      debugPrint('⏭️ No reminder times set for ${medicine.name}');
      await withdrawAll();
      return (ids: scheduledIds, failed: 0);
    }
    if (medicine.isArchived || !medicine.isActive) {
      debugPrint('⏭️ Medicine ${medicine.name} is archived/inactive');
      await withdrawAll();
      return (ids: scheduledIds, failed: 0);
    }

    // What to arm is decided here, not when the notification fires: an iPhone runs
    // nothing at that moment, so it cannot ask whether the medicine is due today.
    // Every medicine used to be armed as "this time, every day", which reminded a
    // weekly medicine daily, an every-other-day one daily, a course that had ended
    // for ever, and a three-weeks-on cycle through its week off. See [IosDosePlan].
    final now = clock.now();
    final plan = IosDosePlan.plan(medicine.schedule,
        now: now, maxCount: _maxSlotsPerMedicine);

    debugPrint('📅 Scheduling ${plan.length} reminders for ${medicine.name}');

    // iOS keeps only the soonest-firing 64 pending requests and silently
    // discards the rest. This path arms one per planned dose — up to 24 each
    // — so three medicines on frequent schedules already overflow, and what gets
    // dropped is whatever is furthest out. A dose is never *pruned* by the
    // budget (see ReminderBudget.allocate), but it must know when the platform
    // is about to prune it for us, because that failure is otherwise invisible:
    // no error, no log, just a dose that never arrives.
    //
    // What is pending, NOT counting this medicine's own: arming again replaces them,
    // and counting them leaves room for none of the doses they are about to be
    // replaced by. (Counting them, with the withdrawing below, would cancel doses
    // that are still wanted whenever the phone is nearly full.)
    //
    // Not guarded: a phone that cannot say what is pending is not ready to be armed
    // either, and this has always failed here, for the caller to log, rather than
    // carry on into the rest of the platform.
    final pendingNow = await _notificationService.getPendingNotifications();
    final ownPending = pendingNow
        .where((p) => p.id >= firstId && p.id < firstId + _maxSlotsPerMedicine)
        .length;
    final pending = pendingNow.length - ownPending;
    final headroom =
        ReminderBudget.headroomFor(ReminderKind.dose, pending: pending);
    final wanted = plan.length;
    final limit = wanted < headroom ? wanted : headroom;
    ReminderBudget.reportTruncation(
      family: 'iOS dose reminders for ${medicine.name}',
      wanted: wanted,
      granted: limit,
    );

    final scheduleJson = jsonEncode(medicine.schedule.toJson());

    for (int i = 0; i < limit; i++) {
      final dose = plan[i];
      final time = ScheduledTime(hour: dose.hour, minute: dose.minute);
      final notificationId = firstId + i;

      try {
        final success = await _notificationService.scheduleMedicineReminder(
          id: notificationId,
          medicineName: buildMedicineReminderLine(medicine, time),
          hour: dose.hour,
          minute: dose.minute,
          frequency: _getFrequencyString(medicine.schedule),
          scheduleJson: scheduleJson,
          medicineId: medicine.id,
          planned: dose,
          sound: ReminderSounds.isKnown(medicine.reminderSound)
              ? medicine.reminderSound
              : null,
          snooze: MedicineSnooze.clean(medicine.snoozeOverrideMinutes),
        );

        if (success) {
          scheduledIds.add(notificationId);
          debugPrint('✓ Scheduled reminder #$i for ${medicine.name} at ${time.formattedTime}');
        } else {
          failed++;
          debugPrint('⚠️ Failed to schedule reminder #$i for ${medicine.name}');
        }
      } catch (e) {
        failed++;
        debugPrint('❌ Error scheduling reminder: $e');
      }
    }

    // Withdraw what an earlier arming left past the end of this plan.
    //
    // The ids are positions in the plan and the plan is recomputed from now every
    // time, so a dose can move to a lower id between two armings — and when the plan
    // gets shorter (a course nearing its end, a dose now past) the old, higher ids
    // still hold doses the new plan holds at lower ones. The phone would ring twice
    // for each. Arming first and withdrawing the rest after means no moment where
    // nothing is armed.
    await withdrawFrom(limit, pendingNow);

    return (ids: scheduledIds, failed: failed);
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

  /// One full Android recompute: both alarm families, from ONE alarm snapshot.
  ///
  /// The two recomputes prune disjoint id ranges — `[slotIdOffset, +1440)` and
  /// `[windowNudgeIdOffset, +100000)` — so they can share a snapshot, and each
  /// used to take its own. That is not free: every snapshot re-reads and
  /// `jsonDecode`s every `alarm_*` preference on the device.
  ///
  /// The snapshot is taken BEFORE either pass schedules anything, on purpose.
  /// A pass only ever schedules ids that are in its own `neededIds`, and the
  /// prune only cancels ids that are NOT — so an alarm armed during this
  /// recompute, and therefore missing from the snapshot, can never be pruned
  /// by it.
  Future<List<ReminderSlot>> _recomputeAll(
      List<EnhancedMedicine> medicines) async {
    final alarms = await _readAlarms();
    final slots = await _recomputeAndroidSlots(medicines, alarms);
    await _recomputeWindowNudges(medicines, alarms);
    return slots;
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
      List<EnhancedMedicine> medicines,
      List<Map<String, dynamic>> alarms) async {
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
  Future<void> _recomputeWindowNudges(List<EnhancedMedicine> medicines,
      List<Map<String, dynamic>> alarms) async {
    final neededIds = <int>{};

    // Dose history for every windowed medicine, read ONCE up front.
    //
    // [_adaptiveSuggestionMinutes] used to fetch it per (medicine, windowed
    // slot) from inside the two loops below, and `getLogsForMedicine` is an
    // unranged full select — so a user with three windowed doses paid three
    // whole-history reads to save one medicine.
    final takeMinutes = await _recentTakeMinutes(medicines);

    for (final medicine in medicines) {
      if (!medicine.reminderEnabled || medicine.schedule.isPRN) continue;
      if (medicine.isArchived || !medicine.isActive) continue;

      final medicineIndex = await _medicineIndex(medicine.id);
      final times = medicine.schedule.times;

      for (int timeIndex = 0;
          timeIndex < times.length && timeIndex < maxSlotsPerMedicinePerDay;
          timeIndex++) {
        final time = times[timeIndex];
        if (effectiveWindowMinutes(medicine, time) == null) continue;

        for (int n = 0; n < maxNudgesPerTime; n++) {
          neededIds.add(windowNudgeId(medicineIndex, timeIndex, n));
        }

        final nudgeMinutes = nudgeMinutesForDose(
          medicine,
          time,
          adaptiveSuggestedMinutes: time.hasWindow
              ? _adaptiveSuggestionMinutes(
                  takeMinutes[medicine.id] ?? const <int>[], time)
              : null,
        )!;
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

  /// Trailing window of dose history [AdaptiveTiming] learns from.
  ///
  /// Bounded so a whole recompute can take ONE ranged read of `medicine_logs`
  /// rather than an unranged per-medicine select for every windowed dose. Six
  /// months is far more than the four samples AdaptiveTiming needs to be
  /// confident, and a take-time habit that old should not still be moving
  /// today's alarm — so the bound is a behaviour change, in the direction of
  /// recency, not a pure refactor.
  static const int _adaptiveHistoryDays = 180;

  /// Real take-times (minutes since midnight) per medicine id, over the last
  /// [_adaptiveHistoryDays], for the medicines in [medicines] that actually
  /// have a windowed dose.
  ///
  /// Returns empty — issuing NO query at all — when no medicine has a window,
  /// which is the common case: the old per-dose read cost nothing then, and
  /// hoisting it must not turn "no windows" into a read.
  ///
  /// Unscoped: this runs while recomputing window nudges for the FULL,
  /// cross-profile medicine list (see [_recomputeWindowNudges]'s own doc), so
  /// a dependent's medicine must see ITS logs even while a different profile
  /// (e.g. self) is currently active — the log reads' default scoping would
  /// otherwise silently return zero logs for it and make AdaptiveTiming report
  /// "not confident" every time.
  Future<Map<String, List<int>>> _recentTakeMinutes(
      List<EnhancedMedicine> medicines) async {
    final windowed = <String>{};
    for (final m in medicines) {
      if (!m.reminderEnabled || m.schedule.isPRN) continue;
      if (m.isArchived || !m.isActive) continue;
      final times = m.schedule.times;
      for (int i = 0; i < times.length && i < maxSlotsPerMedicinePerDay; i++) {
        if (times[i].hasWindow) {
          windowed.add(m.id);
          break;
        }
      }
    }
    if (windowed.isEmpty) return const {};

    try {
      final now = clock.now();
      final logs = MedicineCleanStorageService.dedupeByDose(
          await MedicineCleanStorageService.getLogsForDateRange(
              dayOffset(now, -_adaptiveHistoryDays), dayOffset(now, 1),
              scopeToActiveProfile: false));
      final out = <String, List<int>>{};
      for (final MedicineLog l in logs) {
        if (!windowed.contains(l.medicineId)) continue;
        // Deliberately l.isTaken, NOT countsAsTaken: a pre-logged dose's
        // actionTime is an artificial early timestamp (the pre-log moment),
        // not a real "when do I actually take this dose" data point — folding
        // it in would corrupt this suggestion.
        if (!l.isTaken || l.actionTime == null) continue;
        (out[l.medicineId] ??= <int>[])
            .add(l.actionTime!.hour * 60 + l.actionTime!.minute);
      }
      return out;
    } catch (e) {
      debugPrint('⚠️ Adaptive take-time history unavailable: $e');
      return const {};
    }
  }

  /// The user's real median take-time for this dose, in minutes-of-day, if
  /// [AdaptiveTiming] is confident about it — null otherwise (too few doses
  /// logged, or the timing isn't consistent enough to trust).
  ///
  /// [actualMinutes] comes from [_recentTakeMinutes], which must run on the
  /// main isolate: it needs Drift, which is unavailable inside the background
  /// alarm isolate where a fired nudge actually runs — so the result is
  /// pre-computed at schedule time and carried in the persisted alarm data,
  /// not recomputed live.
  int? _adaptiveSuggestionMinutes(
      List<int> actualMinutes, ScheduledTime time) {
    final suggestion = AdaptiveTiming.suggest(
      scheduledMinutes: time.hour * 60 + time.minute,
      actualMinutes: actualMinutes,
    );
    return suggestion.confident ? suggestion.suggestedMinutes : null;
  }

  /// Cancel all reminders for a medicine.
  Future<void> cancelReminders(EnhancedMedicine medicine) async {
    debugPrint('🗑️ Canceling all reminders for ${medicine.name}');
    if (_useAndroidPath) {
      final medicines = await _resolveMedicines(excludeMedicineId: medicine.id);
      await _recomputeAll(medicines);
      return;
    }
    await _cancelRemindersLegacy(medicine.id);
  }

  /// Cancel reminders by medicine ID string.
  Future<void> cancelRemindersById(String medicineId) async {
    debugPrint('🗑️ Canceling reminders for medicine ID: $medicineId');
    if (_useAndroidPath) {
      final medicines = await _resolveMedicines(excludeMedicineId: medicineId);
      await _recomputeAll(medicines);
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
    if (_useAndroidPath) return scheduleReminders(medicine);
    await cancelReminders(medicine);
    return await scheduleReminders(medicine);
  }

  /// Schedule reminders for multiple medicines (e.g., on app startup).
  ///
  /// Returns how many doses the platform refused (always 0 on Android, whose
  /// recompute reports in its own way): nothing here throws for one, and a caller
  /// that records "armed" needs to tell a pass that armed everything from one that
  /// armed none.
  Future<int> scheduleAllReminders(List<EnhancedMedicine> medicines) async {
    debugPrint('📅 Scheduling reminders for ${medicines.length} medicines');

    if (_useAndroidPath) {
      final slots = await _recomputeAll(medicines);
      debugPrint('✓ Scheduled ${slots.length} medicine slot(s)');
      return 0;
    }

    int totalScheduled = 0;
    int totalFailed = 0;
    for (final medicine in medicines) {
      final armed = await _armLegacy(medicine);
      totalScheduled += armed.ids.length;
      totalFailed += armed.failed;
    }
    debugPrint('✓ Scheduled $totalScheduled total reminders');
    return totalFailed;
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
  Future<bool> snoozeReminder(
    int notificationId,
    int minutes, {
    String? title,
    String? body,
    String? medicineId,
    int? hour,
    int? minute,
    bool clearFired = true,
  }) async {
    try {
      await _notificationService.snoozeReminder(
        notificationId,
        minutes,
        title: title,
        body: body,
        medicineId: medicineId,
        hour: hour,
        minute: minute,
        clearFired: clearFired,
      );
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
    // The dose's IDENTITY has to travel with the snooze.
    //
    // Slot ids are not in `CleanStorageService.getReminders()`, so the lookup
    // inside `NotificationService.snoozeReminder` found nothing and the re-fire
    // was titled "⏰ Snoozed: Reminder / Time for your reminder" — no medicine
    // name — with `medicineId: null` in its payload. Tapping it opened the
    // AlarmScreen, whose `_payloadMedicineIds()` returned an empty list, so
    // Take looped over nothing: the notification closed, no dose was logged,
    // no stock was decremented, no error was shown, and at the grace cutoff
    // reconciliation marked the dose missed.
    final title = medicine.name;
    final body = 'Time to take ${medicine.name}';

    if (Platform.isAndroid) {
      final notificationId =
          slotNotificationId(scheduledTime.hour, scheduledTime.minute);
      return snoozeReminder(
        notificationId,
        minutes,
        title: title,
        body: body,
        medicineId: medicine.id,
        hour: scheduledTime.hour,
        minute: scheduledTime.minute,
      );
    }
    final timeIndex = _resolveTimeIndex(medicine, scheduledTime);
    final notificationId = await _notificationIdFor(medicine.id, timeIndex);
    return snoozeReminder(
      notificationId,
      minutes,
      title: title,
      body: body,
      medicineId: medicine.id,
      hour: scheduledTime.hour,
      minute: scheduledTime.minute,
      // The id is only a stable name for this dose's snooze count and its snooze
      // reminder. It is not where the reminder that fired is armed: the ids a
      // plan arms are positions in it (see [IosDosePlan]) and move between armings,
      // so cancelling it would withdraw some other dose's reminder — or, for a daily
      // one, the repeating reminder for every day after. A notification the person
      // tapped is taken down by the phone; one they snoozed from inside the app
      // without opening it stays in the tray until they clear it, which is the
      // lesser harm.
      clearFired: false,
    );
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
