import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:uuid/uuid.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/streak_engine.dart';
import 'package:tablet_remainder/core/database/daos/steps_dao.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import '../models/health_profile.dart';
import '../models/step_daily_data.dart';
import '../models/step_manual_entry.dart';
import '../models/step_source.dart';

/// Reactive step-count service, mirroring the water service contract: all-static,
/// a single [ValueNotifier] of the date-keyed day map for the UI to listen on,
/// idempotent [init], optimistic in-memory update → notify (copied map) → Drift
/// persist, and [clearInMemory] for a data wipe.
///
/// Works fully offline / permission-free: with no health access the manual path
/// (add/adjust steps) still tracks, charts, streaks and adapts the goal — which
/// is the only path available on the iOS Simulator.
class StepService {
  StepService._();

  static const int _defaultGoal = 8000;
  static const _uuid = Uuid();

  static bool _isInitialized = false;

  /// Date-keyed (yyyy-MM-dd) day map, exposed reactively.
  static final ValueNotifier<Map<String, StepDailyData>> _dailyNotifier =
      ValueNotifier<Map<String, StepDailyData>>({});

  static HealthProfile _profile = const HealthProfile();

  // ---- Live pedometer tracking state -------------------------------------
  static StreamSubscription<StepCount>? _liveSub;
  static int? _liveBaseline; // cumulative-since-boot at first event
  static int _liveStartSteps = 0; // today's sensor steps when tracking began
  static String? _liveDayKey;

  static StepsDao get _dao => db.AppDatabase.instance.stepsDao;

  /// Listen to the day map for reactive rebuilds.
  static ValueListenable<Map<String, StepDailyData>>? listenToDailyData() =>
      _dailyNotifier;

  // ============ INIT ============

  /// Load the profile + ~30 days of history from Drift, then kick off a
  /// best-effort health sync (a no-op when health data is unavailable).
  static Future<void> init() async {
    if (_isInitialized) return;

    // Profile first — adaptive goal + distance/calorie math depend on it.
    try {
      final row = await _dao.getProfile();
      if (row != null) {
        _profile = HealthProfile.fromRow(row);
        debugPrint('✓ StepService loaded health profile from Drift');
      }
    } catch (e) {
      debugPrint('⚠️ StepService profile load failed: $e');
    }

    try {
      final now = DateTime.now();
      final rows = await _dao.getDayRange(
        now.subtract(const Duration(days: 35)),
        now.add(const Duration(days: 1)),
      );
      final map = <String, StepDailyData>{};
      for (final r in rows) {
        final entryRows = await _dao.getManualEntriesForDay(r.id);
        map[r.id] = StepDailyData.fromRow(
          r,
          manualEntries: entryRows.map(StepManualEntry.fromRow).toList(),
        );
      }
      _dailyNotifier.value = map;
      debugPrint('✓ StepService loaded ${map.length} days from Drift');
    } catch (e) {
      debugPrint('⚠️ StepService load failed (using empty): $e');
    }

    _isInitialized = true;

    // Fire-and-forget: pull sensor data if available; the notifier updates the
    // UI reactively when it lands, so first paint isn't blocked on health reads.
    unawaited(syncFromHealth());
  }

  // ============ READ ============

  static HealthProfile getProfile() => _profile;

  /// Today's day, creating (in-memory) a fresh one if absent.
  static StepDailyData getTodayData() {
    final key = _dateKey(DateTime.now());
    final existing = _dailyNotifier.value[key];
    if (existing != null) return existing;
    final day = _newDay(DateTime.now());
    _dailyNotifier.value[key] = day;
    return day;
  }

  static StepDailyData? getDataForDate(DateTime date) =>
      _dailyNotifier.value[_dateKey(date)];

  /// All persisted days in [start]..[end] (inclusive), oldest first.
  static List<StepDailyData> getDataForRange(DateTime start, DateTime end) {
    final results = <StepDailyData>[];
    var cursor = _dayOnly(start);
    final last = _dayOnly(end);
    while (!cursor.isAfter(last)) {
      final d = _dailyNotifier.value[_dateKey(cursor)];
      if (d != null) results.add(d);
      cursor = cursor.add(const Duration(days: 1));
    }
    return results;
  }

  /// Manual entries logged for [date] (from the in-memory day).
  static List<StepManualEntry> manualEntriesForDate(DateTime date) =>
      _dailyNotifier.value[_dateKey(date)]?.manualEntries ?? const [];

  // ============ MANUAL PATH ============

  /// Add (or, with a negative [steps], trim) manual steps to today. Returns the
  /// updated day. Works with zero health permissions.
  static Future<StepDailyData> addManualSteps(int steps, {String? note}) async {
    if (steps == 0) return getTodayData();
    final now = DateTime.now();
    final key = _dateKey(now);
    var day = _dailyNotifier.value[key] ?? _newDay(now);

    final entry = StepManualEntry(
      id: _uuid.v4(),
      dailyDataId: key,
      time: now,
      steps: steps,
      note: note,
      createdAt: now,
    );

    day = day.copyWith(
      manualEntries: [...day.manualEntries, entry],
      source: day.sensorSteps != null ? StepSource.mixed : StepSource.manual,
    );
    day = _recompute(day);

    _dailyNotifier.value[key] = day;
    _notifyListeners();

    await _persistDay(day);
    await _persistEntry(entry);
    return day;
  }

  /// Add manual steps to a specific recent day — for the phone-on-the-charger
  /// day. Bounded to the last [maxDaysBack] days and never the future; today
  /// routes to [addManualSteps]. Recomputes goal-reached (so the WeekDotStrip /
  /// streak repair retroactively) and persists. Returns null if out of range.
  static Future<StepDailyData?> addManualStepsForDate(
    DateTime date,
    int steps, {
    String? note,
    int maxDaysBack = 7,
  }) async {
    if (steps == 0) return getDataForDate(date);
    final today = _dayOnly(DateTime.now());
    final day0 = _dayOnly(date);
    if (day0.isAfter(today)) return null; // no future days
    if (today.difference(day0).inDays > maxDaysBack) return null; // bounded
    if (day0 == today) return addManualSteps(steps, note: note);

    final key = _dateKey(day0);
    var day = _dailyNotifier.value[key] ?? _newDay(day0);
    // Stamp the entry at noon of that day so it clearly belongs to it.
    final entry = StepManualEntry(
      id: _uuid.v4(),
      dailyDataId: key,
      time: DateTime(day0.year, day0.month, day0.day, 12),
      steps: steps,
      note: note,
      createdAt: DateTime.now(),
    );
    day = day.copyWith(
      manualEntries: [...day.manualEntries, entry],
      source: day.sensorSteps != null ? StepSource.mixed : StepSource.manual,
    );
    day = _recompute(day);

    _dailyNotifier.value[key] = day;
    _notifyListeners();

    await _persistDay(day);
    await _persistEntry(entry);
    return day;
  }

  /// Remove a manual entry from today and re-tally.
  static Future<void> removeManualEntry(String entryId) async {
    final key = _dateKey(DateTime.now());
    final day = _dailyNotifier.value[key];
    if (day == null) return;
    final entries = day.manualEntries.where((e) => e.id != entryId).toList();
    if (entries.length == day.manualEntries.length) return; // nothing removed

    var updated = day.copyWith(
      manualEntries: entries,
      source: day.sensorSteps != null
          ? (entries.isNotEmpty ? StepSource.mixed : day.source)
          : StepSource.manual,
    );
    updated = _recompute(updated);

    _dailyNotifier.value[key] = updated;
    _notifyListeners();

    try {
      await _dao.deleteManualEntry(entryId);
    } catch (e) {
      debugPrint('⚠️ delete manual entry failed: $e');
    }
    await _persistDay(updated);
  }

  // ============ PROFILE ============

  /// Persist the profile and refresh today's goal from it.
  static Future<void> saveProfile(HealthProfile profile) async {
    _profile = profile;
    await _persistProfile(profile);

    final key = _dateKey(DateTime.now());
    final newGoal = computeAdaptiveGoal();
    final today = _dailyNotifier.value[key];
    if (today != null && today.goalSteps != newGoal) {
      var updated = today.copyWith(goalSteps: newGoal);
      updated = _recompute(updated);
      _dailyNotifier.value[key] = updated;
      await _persistDay(updated);
    }
    _notifyListeners();
  }

  // ============ STATS ============

  static const _kBestDaySteps = 'steps.bestDaySteps';
  static const _kBestDayDate = 'steps.bestDayDate';

  /// The all-time best day on record — the max of the persisted record and any
  /// day currently in memory. Self-referential (never a comparison to others).
  /// Null until at least one day has steps.
  static ({int steps, DateTime date})? getBestDay() {
    var steps = (CleanStorageService.getAppPreference(_kBestDaySteps, 0) as int?) ?? 0;
    final raw = (CleanStorageService.getAppPreference(_kBestDayDate, '') as String?) ?? '';
    DateTime? date = raw.isEmpty ? null : DateTime.tryParse(raw);
    for (final d in _dailyNotifier.value.values) {
      if (d.effectiveSteps > steps) {
        steps = d.effectiveSteps;
        date = d.date;
      }
    }
    if (steps <= 0 || date == null) return null;
    return (steps: steps, date: date);
  }

  /// True when today strictly beats every other day on record (a genuine new
  /// personal best). Excludes today from the comparison so it can't beat itself.
  static bool isTodayNewBest() {
    final today = getTodayData();
    if (today.effectiveSteps <= 0) return false;
    final todayKey = _dateKey(DateTime.now());
    var prev = 0;
    final storedRaw =
        (CleanStorageService.getAppPreference(_kBestDayDate, '') as String?) ?? '';
    final storedDate = storedRaw.isEmpty ? null : DateTime.tryParse(storedRaw);
    if (storedDate != null && _dateKey(storedDate) != todayKey) {
      prev = (CleanStorageService.getAppPreference(_kBestDaySteps, 0) as int?) ?? 0;
    }
    for (final e in _dailyNotifier.value.entries) {
      if (e.key == todayKey) continue;
      if (e.value.effectiveSteps > prev) prev = e.value.effectiveSteps;
    }
    return today.effectiveSteps > prev;
  }

  /// This calendar week (Mon→today) aggregates.
  static Map<String, dynamic> getWeeklyStats() {
    final now = DateTime.now();
    final weekStart = _dayOnly(now).subtract(Duration(days: now.weekday - 1));
    int total = 0, daysTracked = 0, daysGoalMet = 0, best = 0;
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      if (date.isAfter(now)) break;
      final d = getDataForDate(date);
      if (d == null) continue;
      total += d.effectiveSteps;
      if (d.effectiveSteps > 0) daysTracked++;
      if (d.goalReached) daysGoalMet++;
      if (d.effectiveSteps > best) best = d.effectiveSteps;
    }
    return {
      'totalSteps': total,
      'averageSteps': daysTracked > 0 ? (total / daysTracked).round() : 0,
      'daysTracked': daysTracked,
      'daysGoalMet': daysGoalMet,
      'completionRate': daysTracked > 0 ? daysGoalMet / daysTracked : 0.0,
      'bestDaySteps': best,
    };
  }

  /// Days (in loaded history) whose step goal was reached — the input to the
  /// forgiving [StreakEngine].
  static Set<DateTime> _completedDays() {
    final out = <DateTime>{};
    for (final d in _dailyNotifier.value.values) {
      if (d.goalReached) {
        out.add(DateTime(d.date.year, d.date.month, d.date.day));
      }
    }
    return out;
  }

  /// Forgiving streak (grace days) + longest run, via the shared [StreakEngine].
  /// Replaces the old naive hard-reset walk so a single missed day no longer
  /// wipes the streak. The `atRisk` flag is intentionally never surfaced to the
  /// user (no streak-anxiety), but it's here for internal logic if ever needed.
  static StreakResult getStreakResult() => StreakEngine.compute(
        completedDays: _completedDays(),
        today: DateTime.now(),
      );

  /// Consecutive (grace-forgiven) goal-reached days. Kept as an int for existing
  /// callers (insights / assistant); now sourced from [StreakEngine].
  static int getCurrentStreak() => getStreakResult().current;

  // ============ EVENING REMINDER (opt-in) ============

  static const _kReminderEnabled = 'steps.reminderEnabled';
  static const _kReminderMinute = 'steps.reminderMinute';

  /// Whether the opt-in evening step reminder is on (default off).
  static bool getReminderEnabled() =>
      CleanStorageService.getAppPreference(_kReminderEnabled, false) == true;

  /// Reminder time as minutes-of-day (default 19:00 = 1140).
  static int getReminderMinuteOfDay() =>
      (CleanStorageService.getAppPreference(_kReminderMinute, 1140) as int?) ??
      1140;

  static Future<void> setReminder(bool enabled, int minuteOfDay) async {
    await CleanStorageService.setAppPreference(_kReminderEnabled, enabled);
    await CleanStorageService.setAppPreference(_kReminderMinute, minuteOfDay);
  }

  // ============ ADAPTIVE GOAL ============

  /// The goal to aim for today: the user's custom goal when set, otherwise the
  /// last-14-day median effective steps nudged up ~10% and clamped 4,000–15,000.
  /// Falls back to [_defaultGoal] until there's enough history.
  static int computeAdaptiveGoal() {
    if (_profile.useCustomStepGoal &&
        _profile.customStepGoal != null &&
        _profile.customStepGoal! > 0) {
      return _profile.customStepGoal!;
    }
    final samples = _recentEffectiveSamples(14);
    if (samples.length < 3) return _defaultGoal;
    final sorted = [...samples]..sort();
    final median = _median(sorted);
    final nudged = (median * 1.1).round();
    return nudged.clamp(4000, 15000);
  }

  /// Plain-language "why this goal" explainer for the settings screen.
  static String goalExplanation() {
    if (_profile.useCustomStepGoal &&
        _profile.customStepGoal != null &&
        _profile.customStepGoal! > 0) {
      return 'Using your custom goal of ${_fmt(_profile.customStepGoal!)} steps.';
    }
    final samples = _recentEffectiveSamples(14);
    if (samples.length < 3) {
      return 'Starting at ${_fmt(_defaultGoal)} steps while we learn your routine. '
          'Log a few days and your goal adapts automatically.';
    }
    final sorted = [...samples]..sort();
    final median = _median(sorted);
    final goal = computeAdaptiveGoal();
    return 'Adapted from your ${samples.length}-day median of ${_fmt(median)} steps, '
        'nudged up ~10% to keep you progressing — kept within 4,000–15,000. '
        "Today's goal: ${_fmt(goal)}.";
  }

  static List<int> _recentEffectiveSamples(int days) {
    final out = <int>[];
    final today = _dayOnly(DateTime.now());
    for (int i = 1; i <= days; i++) {
      final date = today.subtract(Duration(days: i));
      final d = _dailyNotifier.value[_dateKey(date)];
      if (d != null && d.effectiveSteps > 0) out.add(d.effectiveSteps);
    }
    return out;
  }

  // ============ LIVE TRACKING (pedometer) ============

  /// Subscribe to the live step sensor. On the first event we snapshot the
  /// cumulative-since-boot baseline; subsequent events add the delta to today's
  /// sensor total optimistically. Silently no-ops where the sensor is missing
  /// (Simulator) — errors are swallowed.
  static Future<void> startLiveTracking() async {
    if (_liveSub != null) return; // idempotent
    try {
      _liveSub = HealthDataService.instance.stepCountStream.listen(
        _onStepCount,
        onError: (Object e) =>
            debugPrint('⚠️ StepService live tracking error: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('⚠️ StepService.startLiveTracking failed: $e');
    }
  }

  static Future<void> stopLiveTracking() async {
    await _liveSub?.cancel();
    _liveSub = null;
    _liveBaseline = null;
    _liveDayKey = null;
    _liveStartSteps = 0;
  }

  static void _onStepCount(StepCount event) {
    final key = _dateKey(DateTime.now());
    // (Re)baseline at first event or a midnight rollover.
    if (_liveBaseline == null || _liveDayKey != key) {
      _liveBaseline = event.steps;
      _liveDayKey = key;
      final existing = _dailyNotifier.value[key];
      // Baseline against the RAW reading, not the stored combined total, or the
      // day's manual adjustments would be counted again on every live tick.
      _liveStartSteps = existing == null ? 0 : (_rawSensorSteps(existing) ?? 0);
      return;
    }
    final delta = event.steps - _liveBaseline!;
    if (delta <= 0) return;

    final liveRawSteps = _liveStartSteps + delta;
    var day = _dailyNotifier.value[key] ?? _newDay(DateTime.now());
    if (liveRawSteps <= (_rawSensorSteps(day) ?? 0)) return; // never regress

    day = day.copyWith(
      source: day.manualEntries.isNotEmpty
          ? StepSource.mixed
          : StepSource.pedometer,
    );
    day = _recompute(day, rawSensorSteps: liveRawSteps);
    _dailyNotifier.value[key] = day;
    _notifyListeners();
    unawaited(_persistDay(day));
  }

  // ============ HEALTH SYNC ============

  /// Best-effort pull of recent days from HealthKit / Health Connect. No-op when
  /// health data isn't available (e.g. Simulator, permissions not granted).
  /// Returns the number of days imported (0 when unavailable / no data).
  static Future<int> syncFromHealth() async {
    var count = 0;
    try {
      final svc = HealthDataService.instance;
      final avail = await svc.availability();
      if (avail != HealthAvailability.available) return 0;

      final source =
          Platform.isIOS ? StepSource.healthKit : StepSource.healthConnect;
      final now = DateTime.now();
      var changed = false;

      for (int i = 0; i < 7; i++) {
        final date = _dayOnly(now).subtract(Duration(days: i));
        final isToday = i == 0;
        final key = _dateKey(date);
        final start = date;
        final end = isToday ? now : start.add(const Duration(days: 1));

        final steps = await svc.readStepsForDay(date, end: isToday ? now : null);
        if (steps == null) continue;

        final energy = await svc.readActiveEnergy(start, end);
        final distance = await svc.readDistanceMeters(start, end);
        final hourly = isToday ? await svc.readHourlySteps(date) : const <int>[];

        final existing = _dailyNotifier.value[key];
        final entries = existing?.manualEntries ?? const <StepManualEntry>[];

        var day = (existing ?? _newDay(date)).copyWith(
          // 0 → "not measured": _recompute derives it from the merged total
          // (raw sensor + this day's manual adjustments) via the profile.
          distanceMeters: distance ?? 0.0,
          activeCalories: energy ?? 0.0,
          hourly: hourly.isNotEmpty ? hourly : (existing?.hourly ?? const []),
          source: entries.isNotEmpty ? StepSource.mixed : source,
          lastSyncedAt: now,
          manualEntries: entries,
        );
        // `steps` is the RAW device reading; _recompute layers this day's manual
        // entries on top of it so a hand-typed count is never overwritten.
        day = _recompute(day, rawSensorSteps: steps);

        _dailyNotifier.value[key] = day;
        await _persistDay(day);
        changed = true;
        count++;
      }

      if (changed) _notifyListeners();
    } catch (e) {
      debugPrint('⚠️ StepService.syncFromHealth failed: $e');
    }
    return count;
  }

  // ============ WIPE ============

  /// Reset all in-memory state after a full data wipe (Drift rows removed
  /// elsewhere). Stops live tracking and drops the reactive map to empty.
  static void clearInMemory() {
    unawaited(stopLiveTracking());
    _dailyNotifier.value = {};
    _profile = const HealthProfile();
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    _isInitialized = false;
    await stopLiveTracking();
    _dailyNotifier.value = {};
    _profile = const HealthProfile();
  }

  // ============ INTERNALS ============

  static void _notifyListeners() {
    _dailyNotifier.value = Map.from(_dailyNotifier.value);
  }

  static StepDailyData _newDay(DateTime date) => StepDailyData(
        id: _dateKey(date),
        date: _dayOnly(date),
        goalSteps: computeAdaptiveGoal(),
        createdAt: DateTime.now(),
      );

  /// The day's *raw* device reading, backed out of the stored combined total —
  /// see the invariant documented on [_recompute]. Null when the day has no
  /// sensor reading at all (manual-only / Simulator).
  static int? _rawSensorSteps(StepDailyData day) =>
      day.sensorSteps == null ? null : day.sensorSteps! - day.manualSteps;

  /// Recompute totals, derived distance/calories, and goal state from the day's
  /// manual entries + sensor value. Health-provided distance/calories are kept
  /// when a sensor reading is present; otherwise both are derived from the
  /// profile's stride/weight.
  ///
  /// ## Merge rule (manual + sensor)
  ///
  /// Manual entries are *adjustments layered on top of* the device reading —
  /// that is precisely what [addManualStepsForDate] exists for ("the
  /// phone-on-the-charger day"), and why a day carrying both is tagged
  /// [StepSource.mixed]. So the day's effective total is
  /// `rawSensor + manualTotal`, **never the sensor alone**. Previously this
  /// computed `day.sensorSteps ?? manualTotal`, which silently threw away every
  /// step the user typed on any day the sensor also reported.
  ///
  /// A net-negative manual tally is a deliberate "trim" (see [addManualSteps]);
  /// it lowers the total but can never take the day below zero steps.
  ///
  /// ## Storage invariant
  ///
  /// [StepDailyData.effectiveSteps] is `sensorSteps ?? manualSteps` (shared
  /// model), so the merged figure has to live in `sensorSteps` for the UI,
  /// insights and streaks to see it. This method therefore stores the combined
  /// total there and maintains:
  ///
  ///     stored sensorSteps == rawSensor + stored manualSteps
  ///
  /// which keeps the raw reading recoverable ([_rawSensorSteps]) and makes
  /// repeated recomputes idempotent. Callers holding a fresh device reading
  /// pass it as [rawSensorSteps] rather than writing `sensorSteps` themselves.
  static StepDailyData _recompute(StepDailyData day, {int? rawSensorSteps}) {
    final int? raw = rawSensorSteps ?? _rawSensorSteps(day);

    final manualTotal = day.manualEntries.fold<int>(0, (s, e) => s + e.steps);
    // Floor the adjustment so a day can never report negative steps: with no
    // sensor there is nothing to trim from, with one we trim at most all of it.
    final manual = raw == null
        ? (manualTotal < 0 ? 0 : manualTotal)
        : (manualTotal < -raw ? -raw : manualTotal);

    final int? combined = raw == null ? null : raw + manual;
    final effective = combined ?? manual;
    final hasSensor = combined != null;

    final distance = hasSensor && day.distanceMeters > 0
        ? day.distanceMeters
        : _profile.deriveDistanceMeters(effective);
    final calories = hasSensor && day.activeCalories > 0
        ? day.activeCalories
        : _profile.deriveActiveCalories(effective);

    final reached = day.goalSteps > 0 && effective >= day.goalSteps;
    final reachedAt =
        reached && !day.goalReached ? DateTime.now() : day.goalReachedAt;

    return day.copyWith(
      sensorSteps: combined,
      manualSteps: manual,
      distanceMeters: distance,
      activeCalories: calories,
      goalReached: reached,
      goalReachedAt: reachedAt,
    );
  }

  /// Test seam for the manual+sensor merge rule (see [_recompute]).
  @visibleForTesting
  static StepDailyData recomputeForTesting(StepDailyData day,
          {int? rawSensorSteps}) =>
      _recompute(day, rawSensorSteps: rawSensorSteps);

  static Future<void> _persistDay(StepDailyData d) async {
    try {
      await _dao.saveDay(d.toCompanion());
    } catch (e) {
      debugPrint('⚠️ persist step day failed: $e');
    }
    await _bumpBestDay(d);
  }

  /// Keep the all-time best-day record current so a great day survives even
  /// after it scrolls out of the ~35-day in-memory window.
  static Future<void> _bumpBestDay(StepDailyData d) async {
    if (d.effectiveSteps <= 0) return;
    final cur = (CleanStorageService.getAppPreference(_kBestDaySteps, 0) as int?) ?? 0;
    if (d.effectiveSteps > cur) {
      await CleanStorageService.setAppPreference(_kBestDaySteps, d.effectiveSteps);
      await CleanStorageService.setAppPreference(
          _kBestDayDate, d.date.toIso8601String());
    }
  }

  static Future<void> _persistEntry(StepManualEntry e) async {
    try {
      await _dao.addManualEntry(e.toCompanion());
    } catch (err) {
      debugPrint('⚠️ persist manual entry failed: $err');
    }
  }

  static Future<void> _persistProfile(HealthProfile p) async {
    try {
      await _dao.saveProfile(p.toCompanion());
    } catch (e) {
      debugPrint('⚠️ persist health profile failed: $e');
    }
  }

  static int _median(List<int> sorted) {
    if (sorted.isEmpty) return 0;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  static String _fmt(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}$buf';
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
