import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:uuid/uuid.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/database/daos/sleep_dao.dart';
import 'package:tablet_remainder/core/database/daos/steps_dao.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import '../models/sleep_session.dart';
import '../models/sleep_schedule.dart';
import '../models/sleep_stage.dart';

/// Reactive sleep tracking service — the single source of truth for sleep
/// sessions and the schedule.
///
/// Mirrors [WaterService] exactly: all-static, in-memory `Map` keyed by the
/// night's `dateKey`, exposed through a [ValueNotifier] so screens rebuild
/// reactively. Persists to Drift ([SleepDao]); the schedule lives on the shared
/// [HealthProfiles] row (read/written via [StepsDao]). Every read swallows
/// failures so the feature degrades gracefully to the manual path — the only
/// path available on the iOS Simulator (no HealthKit).
class SleepService {
  SleepService._();

  static const _uuid = Uuid();
  static bool _isInitialized = false;

  /// In-memory sessions keyed by [SleepSession.dateKey], wrapped for reactivity.
  static final ValueNotifier<Map<String, SleepSession>> _sessionsNotifier =
      ValueNotifier<Map<String, SleepSession>>({});

  static SleepSchedule _schedule = const SleepSchedule();

  static SleepDao get _dao => db.AppDatabase.instance.sleepDao;
  static StepsDao get _stepsDao => db.AppDatabase.instance.stepsDao;

  /// Listenable of all in-memory sessions (dashboard / history subscribe here).
  static ValueListenable<Map<String, SleepSession>> listenToSessions() =>
      _sessionsNotifier;

  // ============ INIT ============

  /// Loads ~30 nights from Drift + the schedule, then best-effort syncs from the
  /// device health store (no-op when health is unavailable, e.g. Simulator).
  static Future<void> init() async {
    if (_isInitialized) return;

    // Schedule (shared health profile).
    try {
      final row = await _stepsDao.getProfile();
      _schedule = SleepSchedule.fromProfile(row);
    } catch (e) {
      debugPrint('⚠️ SleepService schedule load failed: $e');
    }

    // Recent sessions.
    try {
      final now = DateTime.now();
      final rows = await _dao.getForRange(
        now.subtract(const Duration(days: 35)),
        now.add(const Duration(days: 1)),
      );
      final map = <String, SleepSession>{};
      for (final r in rows) {
        final s = SleepSession.fromRow(r);
        map.putIfAbsent(s.dateKey, () => s);
      }
      _sessionsNotifier.value = map;
      debugPrint('✓ SleepService loaded ${map.length} nights from Drift');
    } catch (e) {
      debugPrint('⚠️ SleepService load failed (using empty): $e');
    }

    _isInitialized = true;

    // Best-effort health import (safe no-op on Simulator / when denied).
    try {
      await syncFromHealth();
    } catch (e) {
      debugPrint('⚠️ SleepService initial health sync failed: $e');
    }
  }

  static void _notify() {
    _sessionsNotifier.value = Map.from(_sessionsNotifier.value);
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ============ QUERIES ============

  /// Most recent night by wake time, or null when nothing is logged.
  static SleepSession? getLastNight() {
    final list = _sessionsNotifier.value.values.toList()
      ..sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
    return list.isEmpty ? null : list.first;
  }

  /// All sessions, newest first.
  static List<SleepSession> getAllSessions() {
    return _sessionsNotifier.value.values.toList()
      ..sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
  }

  static SleepSession? getForDate(DateTime date) =>
      _sessionsNotifier.value[_dateKey(date)];

  /// The most-rested night on record (highest sleep score) across loaded
  /// history, or null. Self-referential — a personal best, never a comparison.
  static SleepSession? getBestNight() {
    SleepSession? best;
    for (final s in _sessionsNotifier.value.values) {
      if (s.sleepScore <= 0) continue;
      if (best == null || s.sleepScore > best.sleepScore) best = s;
    }
    return best;
  }

  /// The last 7 nights (oldest → newest) for the trend chart, with gaps as
  /// empty [SleepTrendDay]s.
  static List<SleepTrendDay> getWeeklyTrend() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final out = <SleepTrendDay>[];
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      out.add(SleepTrendDay(
        date: d,
        session: _sessionsNotifier.value[_dateKey(d)],
      ));
    }
    return out;
  }

  // ============ SCHEDULE ============

  static SleepSchedule getSchedule() => _schedule;

  static Future<void> saveSchedule(SleepSchedule schedule) async {
    _schedule = schedule;
    _notify();
    try {
      final existing = await _stepsDao.getProfile();
      await _stepsDao.saveProfile(schedule.toCompanion(existing));
      debugPrint('✓ SleepService saved schedule');
    } catch (e) {
      debugPrint('⚠️ SleepService saveSchedule failed: $e');
    }
  }

  // ============ ANALYTICS ============

  /// Bedtime-consistency index, 0..1 (1 = perfectly regular). Derived from the
  /// standard deviation of bedtimes over the recent history (a proxy for
  /// circadian stability). Neutral (0.75) until there are ≥3 nights.
  static double regularityIndex() {
    final sessions = getAllSessions().take(14).toList();
    if (sessions.length < 3) return 0.75;

    // Represent each bedtime as minutes-of-day, shifting pre-noon (after
    // midnight) times by +24h so late-evening and early-morning bedtimes
    // cluster instead of splitting across the 0/1440 boundary.
    final points = sessions.map((s) {
      var m = s.bedtime.hour * 60 + s.bedtime.minute;
      if (m < 12 * 60) m += 24 * 60;
      return m.toDouble();
    }).toList();

    final mean = points.reduce((a, b) => a + b) / points.length;
    final variance =
        points.map((p) => (p - mean) * (p - mean)).reduce((a, b) => a + b) /
            points.length;
    final std = math.sqrt(variance);

    // Map std-dev to 0..1: 0 min → 1.0, ≥90 min → 0.0.
    const threshold = 90.0;
    return (1 - (std / threshold)).clamp(0.0, 1.0);
  }

  /// How many recent nights currently feed [regularityIndex] (capped at 14).
  /// Below 3 the index is a neutral placeholder — surface a "building" state
  /// rather than a real consistency reading.
  static int regularitySampleSize() => getAllSessions().take(14).length;

  /// Cumulative sleep debt over the last 7 nights, in minutes
  /// (target×7 − asleep). Positive → under-slept; negative → surplus.
  static int sleepDebtMinutes() {
    final slept = getWeeklyTrend().fold<int>(0, (a, d) => a + d.asleepMinutes);
    return _schedule.targetMinutes * 7 - slept;
  }

  /// A gentle suggested bedtime to hit the wake goal: wake − (target + a short
  /// fall-asleep buffer), as minutes-of-day (0..1439). Never a hard prescription
  /// — the UI frames it as "aim for around". Drives the wind-down reminder time.
  static int suggestedBedtimeMinuteOfDay() {
    final s = _schedule;
    final target = s.targetMinutes <= 0 ? 480 : s.targetMinutes;
    const fallAsleepBuffer = 15;
    final wakeMin = s.wakeHour * 60 + s.wakeMinute;
    var bed = wakeMin - (target + fallAsleepBuffer);
    bed %= 24 * 60;
    if (bed < 0) bed += 24 * 60;
    return bed;
  }

  /// A 0..100 sleep score from duration-vs-target (60), efficiency (25) and
  /// bedtime regularity (15).
  static int computeScore(SleepSession session) {
    final target = _schedule.targetMinutes <= 0 ? 480 : _schedule.targetMinutes;
    final durationRatio = (session.asleepMinutes / target).clamp(0.0, 1.0);
    final efficiency = session.efficiencyFraction;
    final regularity = regularityIndex();

    final score =
        (durationRatio * 60) + (efficiency * 25) + (regularity * 15);
    return score.round().clamp(0, 100);
  }

  // ============ MANUAL LOGGING ============

  /// Logs a hand-entered session, estimating asleep/efficiency from the quality
  /// self-report (no measured stages). Recomputes the score and persists.
  static Future<SleepSession> logManualSession({
    required DateTime bedtime,
    required DateTime wakeTime,
    int quality = 4,
    String? note,
  }) async {
    var inBed = wakeTime.difference(bedtime).inMinutes;
    if (inBed <= 0) {
      // wake ≤ bedtime → assume the bedtime was the previous evening (an
      // overnight session) instead of silently recording a 1-minute night.
      // The manual sheet already shifts; other callers (quick-log, AI NL
      // logging) may pass same-day times.
      bedtime = bedtime.subtract(const Duration(days: 1));
      inBed = wakeTime.difference(bedtime).inMinutes;
    }
    if (inBed <= 0) inBed = 1; // final fallback for still-degenerate input

    // Estimated efficiency scales with the 1..5 quality rating.
    final q = quality.clamp(1, 5);
    final estEfficiency = (0.85 + (q - 3) * 0.03).clamp(0.60, 0.98);
    final asleep = (inBed * estEfficiency).round().clamp(0, inBed);
    final awake = inBed - asleep;

    final key = _dateKey(wakeTime);
    final now = DateTime.now();
    var session = SleepSession(
      id: _uuid.v4(),
      dateKey: key,
      bedtime: bedtime,
      wakeTime: wakeTime,
      inBedMinutes: inBed,
      asleepMinutes: asleep,
      awakeMinutes: awake,
      sleepScore: 0,
      efficiency: estEfficiency.toDouble(),
      qualityIndex: q,
      source: SleepSource.manual,
      note: (note != null && note.trim().isEmpty) ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    // Insert first so the score's regularity term sees this night, then score.
    _sessionsNotifier.value[key] = session;
    session = session.copyWith(sleepScore: computeScore(session));
    _sessionsNotifier.value[key] = session;
    _notify();

    try {
      await _dao.upsert(session.toCompanion());
    } catch (e) {
      debugPrint('⚠️ SleepService logManualSession persist failed: $e');
    }
    return session;
  }

  static Future<void> deleteSession(String id) async {
    _sessionsNotifier.value
        .removeWhere((_, session) => session.id == id);
    _notify();
    try {
      await _dao.deleteSession(id);
    } catch (e) {
      debugPrint('⚠️ SleepService deleteSession failed: $e');
    }
  }

  // ============ HEALTH IMPORT ============

  /// Imports measured sleep from HealthKit / Health Connect for the last ~7
  /// nights, aggregating raw stage segments into one session per 18:00→18:00
  /// window. No-op when health data is unavailable (Simulator / denied). Never
  /// overwrites a manually-logged night.
  /// Returns the number of nights imported (0 when unavailable / no data).
  static Future<int> syncFromHealth() async {
    final HealthAvailability avail;
    try {
      avail = await HealthDataService.instance.availability();
    } catch (e) {
      debugPrint('⚠️ SleepService availability check failed: $e');
      return 0;
    }
    if (avail != HealthAvailability.available) return 0;

    final now = DateTime.now();
    final from =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 8));

    final List<HealthDataPoint> segments;
    try {
      segments = await HealthDataService.instance.readSleepSegments(from, now);
    } catch (e) {
      debugPrint('⚠️ SleepService readSleepSegments failed: $e');
      return 0;
    }
    if (segments.isEmpty) return 0;

    // Bucket segments by their night's wake-morning date.
    final buckets = <String, List<HealthDataPoint>>{};
    for (final p in segments) {
      final f = p.dateFrom;
      final wakeMorning = f.hour >= 18
          ? DateTime(f.year, f.month, f.day).add(const Duration(days: 1))
          : DateTime(f.year, f.month, f.day);
      (buckets[_dateKey(wakeMorning)] ??= []).add(p);
    }

    final source =
        Platform.isIOS ? SleepSource.healthKit : SleepSource.healthConnect;
    var changed = false;
    var count = 0;

    for (final entry in buckets.entries) {
      // Never clobber a night the user entered by hand.
      final existing = _sessionsNotifier.value[entry.key];
      if (existing != null && existing.source == SleepSource.manual) continue;

      final session = _aggregate(entry.key, entry.value, source);
      if (session == null) continue;

      _sessionsNotifier.value[entry.key] = session;
      changed = true;
      count++;
      try {
        await _dao.upsert(session.toCompanion());
      } catch (e) {
        debugPrint('⚠️ SleepService sync upsert failed: $e');
      }
    }

    if (changed) _notify();
    return count;
  }

  /// Aggregate one night's raw [HealthDataPoint] segments into a [SleepSession].
  static SleepSession? _aggregate(
      String dateKey, List<HealthDataPoint> points, SleepSource source) {
    DateTime? bed;
    DateTime? wake;
    var light = 0, deep = 0, rem = 0, awake = 0, asleepGeneric = 0, inBedRaw = 0;
    // Whole-night span reported by Health Connect's SleepSessionRecord. Many
    // Android providers (and every phone-only tracker) write ONLY the session and
    // no stage breakdown, so without this fallback those nights aggregated to
    // zero asleep minutes and were silently dropped.
    var sessionMinutes = 0;

    for (final p in points) {
      final minutes = p.dateTo.difference(p.dateFrom).inMinutes;
      if (minutes <= 0) continue;
      bed = (bed == null || p.dateFrom.isBefore(bed)) ? p.dateFrom : bed;
      wake = (wake == null || p.dateTo.isAfter(wake)) ? p.dateTo : wake;
      switch (p.type) {
        case HealthDataType.SLEEP_DEEP:
          deep += minutes;
          break;
        case HealthDataType.SLEEP_LIGHT:
          light += minutes;
          break;
        case HealthDataType.SLEEP_REM:
          rem += minutes;
          break;
        case HealthDataType.SLEEP_AWAKE:
          awake += minutes;
          break;
        case HealthDataType.SLEEP_ASLEEP:
          asleepGeneric += minutes;
          break;
        case HealthDataType.SLEEP_IN_BED:
          inBedRaw += minutes;
          break;
        case HealthDataType.SLEEP_SESSION:
          // Fallback only — never added to the stage totals (Health Connect
          // returns the session *and* its stages, so summing would double count).
          sessionMinutes += minutes;
          break;
        default:
          break; // AWAKE_IN_BED / OUT_OF_BED / UNKNOWN ignored
      }
    }
    if (bed == null || wake == null) return null;

    final stagesTotal = light + deep + rem;
    final hasStages = stagesTotal > 0;
    // Prefer measured stages → generic "asleep" → the session span minus any
    // awake time, so a stage-less provider still yields an honest night.
    final asleep = hasStages
        ? stagesTotal
        : (asleepGeneric > 0
            ? asleepGeneric
            : (sessionMinutes > awake ? sessionMinutes - awake : sessionMinutes));
    if (asleep <= 0) return null;

    final windowMinutes = wake.difference(bed).inMinutes;
    final inBed = inBedRaw > 0
        ? inBedRaw
        : (windowMinutes > 0 ? windowMinutes : asleep + awake);
    final efficiency = inBed > 0 ? (asleep / inBed).clamp(0.0, 1.0) : 0.0;

    final now = DateTime.now();
    var session = SleepSession(
      // Stable per-night id so a re-sync upserts the same row (no duplicates).
      id: 'hk_$dateKey',
      dateKey: dateKey,
      bedtime: bed,
      wakeTime: wake,
      inBedMinutes: inBed,
      asleepMinutes: asleep,
      awakeMinutes: awake,
      lightMinutes: hasStages ? light : null,
      deepMinutes: hasStages ? deep : null,
      remMinutes: hasStages ? rem : null,
      sleepScore: 0,
      efficiency: efficiency.toDouble(),
      source: source,
      createdAt: now,
      updatedAt: now,
    );
    return session.copyWith(sleepScore: computeScore(session));
  }

  // ============ LIFECYCLE ============

  /// Clears all in-memory sleep state after a full data wipe (Drift rows are
  /// removed elsewhere). Lets the UI drop to empty without an app restart.
  static void clearInMemory() {
    _sessionsNotifier.value = {};
    _schedule = const SleepSchedule();
    _isInitialized = false;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    _isInitialized = false;
    _sessionsNotifier.value = {};
    _schedule = const SleepSchedule();
  }
}
