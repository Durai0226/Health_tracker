import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:uuid/uuid.dart';
import 'package:tablet_remainder/core/health/bedtime_guidance.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/database/daos/sleep_dao.dart';
import 'package:tablet_remainder/core/database/daos/steps_dao.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import '../models/sleep_session.dart';
import '../models/sleep_schedule.dart';
import '../models/sleep_stage.dart';
import '../../../core/utils/calendar_day.dart';
import '../../../core/health/sleep_debt.dart';

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
    await reloadFromDb();
    _isInitialized = true;

    // Best-effort health import (safe no-op on Simulator / when denied) —
    // deliberately NOT awaited. `main.dart` awaits this init before `runApp`,
    // and [syncFromHealth] walks the entire Health Connect / HealthKit channel
    // chain (configure → SDK status → permissions → eight days of segments)
    // before it returns, so awaiting it held the very first frame behind a
    // platform round trip and the app opened on a blank screen. `StepService`
    // and `BiometricsService` already fire theirs off the critical path; the
    // dashboard rebuilds from the ValueNotifier when the nights land, so
    // nothing is lost by letting it finish after paint. A failure still stays
    // non-fatal (and never surfaces as an unhandled async error).
    unawaited(syncFromHealth().catchError((Object e) {
      debugPrint('⚠️ SleepService initial health sync failed: $e');
      return 0;
    }));
  }

  /// Re-read the schedule and the recent-nights window from Drift.
  ///
  /// Split out of [init] and deliberately NOT behind its `_isInitialized`
  /// guard: cloud sync applies downloaded nights straight to the Drift table,
  /// so without a reload the dashboard keeps showing the pre-sync nights until
  /// the next cold launch. Mirrors `BiometricsService.reloadFromDb`.
  static Future<void> reloadFromDb() async {
    // Schedule (shared health profile).
    try {
      final row = await _stepsDao.getProfile();
      _schedule = SleepSchedule.fromProfile(row);
    } catch (e) {
      debugPrint('⚠️ SleepService schedule load failed: $e');
    }

    // Recent sessions.
    try {
      final today = startOfDay(clock.now());
      final rows = await _dao.getForRange(
        dayOffset(today, -35),
        dayOffset(today, 1),
      );
      final map = <String, SleepSession>{};
      for (final r in rows) {
        final s = SleepSession.fromRow(r);
        final current = map[s.dateKey];
        if (current == null || _winsOver(s, current)) map[s.dateKey] = s;
      }
      _sessionsNotifier.value = map;
      debugPrint('✓ SleepService loaded ${map.length} nights from Drift');
    } catch (e) {
      debugPrint('⚠️ SleepService load failed (using empty): $e');
    }
  }

  static void _notify() {
    _sessionsNotifier.value = Map.from(_sessionsNotifier.value);
  }

  /// Which of two rows stored for the SAME night the app should show.
  ///
  /// A night can legitimately hold more than one row: a hand-logged session
  /// (random uuid) and an imported one (`hk_<dateKey>`). Loading used to keep
  /// whichever came first in the wake-time-descending scan, so an imported
  /// night with a later wake time shadowed the user's own entry — and because
  /// [syncFromHealth]'s "never clobber a manual night" guard reads this very
  /// map, the shadowed manual night then stayed buried on every later sync.
  ///
  /// Rule: a hand-logged session always beats an imported one (user-entered
  /// data is never displaced by an automatic import); between two of the same
  /// kind, the most recently updated wins.
  static bool _winsOver(SleepSession candidate, SleepSession current) {
    final candidateManual = candidate.source == SleepSource.manual;
    final currentManual = current.source == SleepSource.manual;
    if (candidateManual != currentManual) return candidateManual;
    return candidate.updatedAt.isAfter(current.updatedAt);
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// The night a sleep segment starting at [segmentStart] belongs to, as a
  /// `dateKey`.
  ///
  /// A night is named after the morning you wake up on, so anything that starts
  /// at or after 18:00 belongs to the NEXT calendar day. That "+1 day" is
  /// calendar arithmetic, not elapsed time: with
  /// `DateTime(y, m, d).add(const Duration(days: 1))` a segment that began at
  /// 23:00 on the day *before* a 25-hour civil day landed back on its own start
  /// date — so the night of Nov 1→2 was filed under Nov 1, on top of the night
  /// of Oct 31→1, and the two got aggregated into one session with a wake time
  /// 24 hours after its bedtime.
  ///
  /// Exposed for the DST probe: `syncFromHealth` can only be driven through the
  /// platform channel, which `flutter test` cannot reach.
  @visibleForTesting
  static String nightKeyFor(DateTime segmentStart) {
    final startDay = startOfDay(segmentStart);
    return _dateKey(
        segmentStart.hour >= 18 ? dayOffset(startDay, 1) : startDay);
  }

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

  /// The bedtime this user's best-scoring nights had in common.
  ///
  /// [getBestNight] returns the single top-scoring night, which is an anecdote —
  /// one good night tells you nothing you can act on. `BedtimeGuidance` looks at
  /// the best FIVE and reports what they shared, which is a pattern.
  ///
  /// Nights with no score are excluded rather than treated as zero: an
  /// unscored night is unmeasured, not bad, and scoring it zero would drag the
  /// "rest" average down and manufacture a gap that isn't there.
  ///
  /// Returns null whenever the engine has nothing trustworthy to say — under 7
  /// nights, a shift under 20 minutes, or best nights that are not measurably
  /// better than the others.
  static BedtimeSuggestion? bedtimeGuidance({int nights = 30}) {
    final scored = getAllSessions()
        .take(nights)
        .where((s) => s.sleepScore > 0)
        .map((s) => BedtimeNight(
              bedMinutes: s.bedtime.hour * 60 + s.bedtime.minute,
              score: s.sleepScore,
            ))
        .toList();
    return BedtimeGuidance.fromBestNights(scored);
  }

  /// The last 7 nights (oldest → newest) for the trend chart, with gaps as
  /// empty [SleepTrendDay]s.
  static List<SleepTrendDay> getWeeklyTrend() {
    final today = startOfDay(clock.now());
    final out = <SleepTrendDay>[];
    for (var i = 6; i >= 0; i--) {
      final d = dayOffset(today, -i);
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

  /// Average bedtime/wake time from real logged nights (most recent [nights],
  /// default 14 — same window [regularityIndex] uses), for callers that want
  /// the ACTUAL sleep pattern rather than the stated [getSchedule] target.
  /// Returns null below [minNights] (default 3) — too few nights for a
  /// trustworthy average — so the caller falls back to [getSchedule].
  static ({int wakeHour, int wakeMinute, int bedHour, int bedMinute})?
      averageActualSchedule({int nights = 14, int minNights = 3}) {
    final sessions = getAllSessions().take(nights).toList();
    if (sessions.length < minNights) return null;

    // Bedtime: shift pre-noon (after-midnight) times by +24h so late-evening
    // and early-morning bedtimes cluster instead of splitting across the
    // 0/1440 boundary — the same technique [regularityIndex] uses.
    final bedPoints = sessions.map((s) {
      var m = s.bedtime.hour * 60 + s.bedtime.minute;
      if (m < 12 * 60) m += 24 * 60;
      return m;
    }).toList();
    final bedMeanRaw =
        bedPoints.reduce((a, b) => a + b) / bedPoints.length;
    final bedOfDay = bedMeanRaw.round() % (24 * 60);

    // Wake times don't need the shift — they cluster in the morning, well
    // away from the midnight boundary.
    final wakePoints =
        sessions.map((s) => s.wakeTime.hour * 60 + s.wakeTime.minute).toList();
    final wakeMeanRaw =
        wakePoints.reduce((a, b) => a + b) / wakePoints.length;
    final wakeOfDay = wakeMeanRaw.round() % (24 * 60);

    return (
      wakeHour: wakeOfDay ~/ 60,
      wakeMinute: wakeOfDay % 60,
      bedHour: bedOfDay ~/ 60,
      bedMinute: bedOfDay % 60,
    );
  }

  /// Shortfall against target across the nights that were ACTUALLY LOGGED, in
  /// minutes (target × logged − asleep). Positive → under-slept; negative →
  /// surplus.
  ///
  /// This used to be `targetMinutes * 7 - slept`, summing over all seven days
  /// of the trend. A night with no session contributes `asleepMinutes == 0`, so
  /// every un-logged night silently added a full night's target to the
  /// "debt" — someone who logged three nights and slept perfectly well was told
  /// they were 32 hours behind. That is a fabricated health figure, the same
  /// class of defect as reporting 100% adherence against zero doses.
  ///
  /// Dividing by logged nights makes the claim true: "across the N nights you
  /// logged, you are X under". [loggedNightsThisWeek] lets the UI say N.
  static int sleepDebtMinutes() {
    final logged = getWeeklyTrend().where((d) => d.hasData).toList();
    if (logged.isEmpty) return 0;
    final slept = logged.fold<int>(0, (a, d) => a + d.asleepMinutes);
    return _schedule.targetMinutes * logged.length - slept;
  }

  /// Sleep debt over the last [SleepDebt.windowDays] nights with recent nights
  /// weighted more, a surplus night paying back at most an hour, and a plan to
  /// clear it. See [SleepDebt] for why, and for how it differs from
  /// [sleepDebtMinutes], which stays the plain seven-night figure that the
  /// "rest in credit" side reports honestly (a capped credit would understate
  /// how far ahead someone is).
  ///
  /// Only LOGGED nights count: an unlogged night is missing data, not zero sleep.
  static SleepDebtResult sleepDebt() {
    final today = startOfDay(clock.now());
    final nights = <LoggedNight>[];
    for (var i = 0; i < SleepDebt.windowDays; i++) {
      final s = _sessionsNotifier.value[_dateKey(dayOffset(today, -i))];
      if (s != null && s.asleepMinutes > 0) {
        nights.add((ageDays: i, asleepMinutes: s.asleepMinutes));
      }
    }
    return SleepDebt.compute(
        nights: nights, targetMinutes: _schedule.targetMinutes);
  }

  /// How many of the last seven nights have a session. The denominator behind
  /// [sleepDebtMinutes], so any copy quoting a debt can quote this too rather
  /// than claiming "the last 7 nights".
  static int loggedNightsThisWeek() =>
      getWeeklyTrend().where((d) => d.hasData).length;

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
      bedtime = shiftCalendarDays(bedtime, -1);
      inBed = wakeTime.difference(bedtime).inMinutes;
    }
    if (inBed <= 0) inBed = 1; // final fallback for still-degenerate input

    // Estimated efficiency scales with the 1..5 quality rating.
    final q = quality.clamp(1, 5);
    final estEfficiency = (0.85 + (q - 3) * 0.03).clamp(0.60, 0.98);
    final asleep = (inBed * estEfficiency).round().clamp(0, inBed);
    final awake = inBed - asleep;

    final key = _dateKey(wakeTime);
    final now = clock.now();

    // A second hand-logged night for a date that already has one is an EDIT of
    // that night, not a new row. Minting a fresh uuid every call left two rows
    // sharing the same `dateKey`: the reader ([_winsOver]) picked one and the
    // other became invisible — impossible to see, correct or delete — while
    // still occupying the database and cloud sync forever.
    final prior = _sessionsNotifier.value[key];
    final replacing = prior != null && prior.source == SleepSource.manual;

    var session = SleepSession(
      id: replacing ? prior.id : _uuid.v4(),
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
      createdAt: replacing ? prior.createdAt : now,
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

  /// Put [session] back exactly as it was — the other half of an Undo on a
  /// night that was replaced. Unlike [logManualSession] it re-scores nothing and
  /// re-stamps nothing: the night returns as it left.
  static Future<void> restoreSession(SleepSession session) async {
    _sessionsNotifier.value[session.dateKey] = session;
    _notify();
    try {
      await _dao.upsert(session.toCompanion());
    } catch (e) {
      debugPrint('⚠️ SleepService restoreSession failed: $e');
    }
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

    final now = clock.now();
    final from = dayOffset(now, -8);

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
      (buckets[nightKeyFor(p.dateFrom)] ??= []).add(p);
    }

    final source =
        Platform.isIOS ? SleepSource.healthKit : SleepSource.healthConnect;

    // Nights whose IMPORTED row the user deleted. Without this the very next
    // sync re-created `hk_<dateKey>` and the deleted night came straight back.
    // Keyed by row id, so deleting a hand-logged night does not also block the
    // device import for that date.
    Set<String> deletedIds = const {};
    try {
      deletedIds = await _dao.deletedIdsInRange(from, now);
    } catch (e) {
      debugPrint('⚠️ SleepService tombstone lookup failed: $e');
    }

    return _importBuckets(buckets, source, deletedIds);
  }

  /// The bucket-and-store half of [syncFromHealth], split out from the platform
  /// reads that precede it.
  ///
  /// Exposed through [importBucketsForTesting] because `flutter test` reaches
  /// neither Health Connect nor HealthKit: [syncFromHealth] returns 0 at its
  /// availability check long before any of this runs, so hand-built segments
  /// are the only way to exercise the import rules.
  static Future<int> _importBuckets(
    Map<String, List<HealthDataPoint>> buckets,
    SleepSource source,
    Set<String> deletedIds,
  ) async {
    var changed = false;
    var count = 0;

    for (final entry in buckets.entries) {
      // Never clobber a night the user entered by hand.
      final existing = _sessionsNotifier.value[entry.key];
      if (existing != null && existing.source == SleepSource.manual) continue;
      // …nor resurrect an imported night they deleted.
      if (deletedIds.contains('hk_${entry.key}')) continue;

      var session = _aggregate(entry.key, entry.value, source);
      if (session == null) continue;

      // A re-import of a night we already hold is an UPDATE of that row, not a
      // new one, so it keeps the original creation stamp — and when nothing
      // about the night changed it is not a write at all.
      //
      // This used to upsert every bucketed night unconditionally, and
      // `toCompanion()` stamps a fresh `updatedAt` on every write. The 8-day
      // window plus the `init()` sync meant up to eight untouched nights were
      // rewritten with a new modification time on every single launch. That is
      // not just churn: `updatedAt` is the last-write-wins key the cloud
      // syncer compares (`lww_collection_sync`, and [_winsOver] locally), so
      // re-stamping decouples it from "when the data changed" and reduces it
      // to "which device opened the app last". A phone whose health store held
      // a stale or partial copy of a night could therefore overwrite a newer,
      // more complete copy another device had already uploaded, purely by
      // being launched afterwards. Leaving an unchanged row alone keeps
      // `updatedAt` meaning what LWW needs it to mean.
      final prior =
          (existing != null && existing.id == session.id) ? existing : null;
      if (prior != null) {
        session = session.copyWith(createdAt: prior.createdAt);
        if (_sameNight(prior, session)) continue;
      }

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

  /// Test seam for the import rules (see [_importBuckets]).
  @visibleForTesting
  static Future<int> importBucketsForTesting(
    Map<String, List<HealthDataPoint>> buckets,
    SleepSource source, {
    Set<String> deletedIds = const {},
  }) =>
      _importBuckets(buckets, source, deletedIds);

  /// Whether a freshly aggregated night is, field for field, the night already
  /// stored — ignoring the timestamps, which are exactly what must not drive
  /// the decision.
  ///
  /// Spelled out rather than `prior == session`: [SleepSession] has no value
  /// equality, so `==` is identity and every re-import would compare unequal.
  /// Every column [SleepSession.toCompanion] writes is listed here apart from
  /// `createdAt` (equalised by the caller), `updatedAt` and `synced`; the list
  /// is pinned against that companion by
  /// `test/features/sleep/sleep_resync_is_idempotent_test.dart` so a column
  /// added later cannot be silently left out.
  static bool _sameNight(SleepSession a, SleepSession b) =>
      a.id == b.id &&
      a.dateKey == b.dateKey &&
      a.bedtime == b.bedtime &&
      a.wakeTime == b.wakeTime &&
      a.inBedMinutes == b.inBedMinutes &&
      a.asleepMinutes == b.asleepMinutes &&
      a.awakeMinutes == b.awakeMinutes &&
      a.lightMinutes == b.lightMinutes &&
      a.deepMinutes == b.deepMinutes &&
      a.remMinutes == b.remMinutes &&
      a.sleepScore == b.sleepScore &&
      a.efficiency == b.efficiency &&
      a.qualityIndex == b.qualityIndex &&
      a.source == b.source &&
      a.note == b.note;

  /// Longest gap between two segments that still counts as the SAME sleep
  /// episode. Three hours is comfortably longer than any ordinary mid-night
  /// wake (bathroom, feeding, insomnia stretch) and comfortably shorter than
  /// the gap between getting up in the morning and lying down for a nap.
  static const int _episodeGapMinutes = 180;

  /// Split one bucket's segments into separate sleep episodes.
  ///
  /// A bucket is a whole 18:00→18:00 window, so an afternoon nap lands in the
  /// same bucket as the night before it. Sorted by start, a gap longer than
  /// [_episodeGapMinutes] between one segment and the running end of the
  /// current episode starts a new one.
  static List<List<HealthDataPoint>> _splitEpisodes(
      List<HealthDataPoint> points) {
    final sorted = [...points]..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    final episodes = <List<HealthDataPoint>>[];
    DateTime? runningEnd;
    for (final p in sorted) {
      if (runningEnd == null ||
          p.dateFrom.difference(runningEnd).inMinutes > _episodeGapMinutes) {
        episodes.add(<HealthDataPoint>[p]);
        runningEnd = p.dateTo;
      } else {
        episodes.last.add(p);
        if (p.dateTo.isAfter(runningEnd)) runningEnd = p.dateTo;
      }
    }
    return episodes;
  }

  /// Total wall-clock span of one episode, in minutes.
  static int _episodeSpan(List<HealthDataPoint> episode) {
    var from = episode.first.dateFrom;
    var to = episode.first.dateTo;
    for (final p in episode) {
      if (p.dateFrom.isBefore(from)) from = p.dateFrom;
      if (p.dateTo.isAfter(to)) to = p.dateTo;
    }
    final m = to.difference(from).inMinutes;
    return m < 0 ? 0 : m;
  }

  /// Hours an episode must lie WHOLLY within to count as daytime sleep.
  ///
  /// A nap is defined by WHEN it happens, not by how short it is. The first
  /// version of this split picked the longest-spanning episode as the night,
  /// which is wrong twice over: a 4-hour afternoon nap beats a 3-hour night,
  /// and — much worse — a genuinely fragmented night (asleep 22:00–02:00, awake
  /// 3½ hours, asleep 05:30–08:00) was truncated to its longest fragment, so
  /// two hours of real sleep were discarded and the wake time moved six hours
  /// early. That feeds the sleep score, `sleepDebtMinutes` and the
  /// BedtimeGuidance averages, and it is worse than the nap bug it replaced.
  ///
  /// 11:00–19:00 local: late enough that a lie-in or a shift worker's morning
  /// sleep still belongs to the night, early enough that an evening bedtime
  /// never falls inside it.
  static const int _dayNapStartHour = 11;
  static const int _dayNapEndHour = 19;

  /// Whether every segment of [episode] falls inside the daytime window.
  ///
  /// Deliberately "wholly within": an episode that starts at 18:30 and runs
  /// into the night is the night beginning, not a nap ending.
  static bool _isDaytimeNap(List<HealthDataPoint> episode) {
    for (final p in episode) {
      if (p.dateFrom.hour < _dayNapStartHour ||
          p.dateFrom.hour >= _dayNapEndHour) {
        return false;
      }
      if (p.dateTo.hour < _dayNapStartHour || p.dateTo.hour >= _dayNapEndHour) {
        return false;
      }
      // A segment longer than the window cannot be contained by it.
      if (p.dateTo.difference(p.dateFrom).inHours >
          _dayNapEndHour - _dayNapStartHour) {
        return false;
      }
      if (!isSameCalendarDay(p.dateFrom, p.dateTo)) return false;
    }
    return true;
  }

  /// Aggregate one night's raw [HealthDataPoint] segments into a [SleepSession].
  ///
  /// Only the night itself is aggregated. This used to fold EVERY segment in
  /// the bucket into one session, so a 45-minute afternoon nap both inflated
  /// time-in-bed and moved the recorded wake time to the end of the nap —
  /// which shifted the sleep score, the sleep debt and the bedtime guidance for
  /// that night. Episodes that lie wholly inside the daytime window are kept
  /// out of the night's figures and recorded in the note rather than thrown
  /// away; everything else is the night, however fragmented.
  static SleepSession? _aggregate(
      String dateKey, List<HealthDataPoint> allPoints, SleepSource source) {
    final episodes = _splitEpisodes(allPoints);
    final nightEpisodes =
        episodes.where((e) => !_isDaytimeNap(e)).toList(growable: false);
    // Every episode looked like a nap (a bucket with nothing but daytime
    // sleep): report it as the session rather than losing the day entirely.
    final kept = nightEpisodes.isEmpty ? episodes : nightEpisodes;
    var points = kept.isEmpty
        ? allPoints
        : kept.expand((e) => e).toList(growable: false);
    var napMinutes = 0;
    for (final e in episodes) {
      if (!kept.contains(e)) napMinutes += _episodeSpan(e);
    }

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

    final now = clock.now();
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
      // Daytime sleep is excluded from the figures above, so say so instead of
      // dropping it silently.
      note: napMinutes > 0
          ? 'Excludes $napMinutes min of daytime sleep'
          : null,
      createdAt: now,
      updatedAt: now,
    );
    return session.copyWith(sleepScore: computeScore(session));
  }

  /// Test seam for the night/nap split (see [_aggregate]). The plugin has no
  /// platform channel under `flutter test`, so hand-built points are the only
  /// way to drive the import path.
  @visibleForTesting
  static SleepSession? aggregateForTesting(
          String dateKey, List<HealthDataPoint> points, SleepSource source) =>
      _aggregate(dateKey, points, source);

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
