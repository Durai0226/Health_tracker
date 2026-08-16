import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/biometrics_dao.dart';
import '../../../core/health/health_windows.dart';
import '../../../core/services/health_data_service.dart';
import '../models/biometric_day.dart';
import '../models/biometric_metric.dart';
import '../models/health_source.dart';
import '../models/workout_session.dart';
import 'health_source_registry.dart';

/// Wearable biometrics: heart rate, HRV, blood oxygen, breathing rate,
/// temperature and workouts, aggregated to one row per day.
///
/// Follows the Steps/Sleep contract exactly — all-static, private constructor,
/// idempotent [init], one `ValueNotifier<Map<dateKey, T>>` as the single
/// reactive source, optimistic in-memory update then an async Drift write
/// wrapped in try/catch.
///
/// ## Never throws
///
/// Same rule as [HealthDataService]: every path returns data-or-empty, because
/// this whole feature is additive. A user with no wearable must see a clean
/// empty state, not an error.
///
/// ## Two invariants worth stating out loud
///
/// 1. **One source per metric per day.** [aggregateDay] resolves a winner and
///    uses only that source's samples. Blending two devices' heart rate
///    produces a min/max range no device ever measured.
/// 2. **Nulls stay null.** A metric with no samples is absent, never zero. The
///    charts render absence as a gap; a zero would be a measured claim.
class BiometricsService {
  BiometricsService._();

  static BiometricsDao get _dao => db.AppDatabase.instance.biometricsDao;

  static bool _isInitialized = false;

  static final ValueNotifier<Map<String, BiometricDay>> _daysNotifier =
      ValueNotifier<Map<String, BiometricDay>>({});
  static final ValueNotifier<Map<String, List<WorkoutSession>>>
      _workoutsNotifier = ValueNotifier<Map<String, List<WorkoutSession>>>({});

  static ValueListenable<Map<String, BiometricDay>> listenToDays() =>
      _daysNotifier;
  static ValueListenable<Map<String, List<WorkoutSession>>> listenToWorkouts() =>
      _workoutsNotifier;

  /// How far back a routine sync looks. Matches Steps' 7-day window.
  static const int defaultSyncDays = 7;

  /// Days kept in memory. Enough for the 30-day trends without holding a year.
  static const int _memoryWindowDays = 35;

  // ============ LIFECYCLE ============

  static Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      await _loadFromDb();
    } catch (e) {
      debugPrint('BiometricsService.init load failed: $e');
    }
    // Fire-and-forget so first paint is never blocked, exactly as
    // StepService.init does.
    unawaited(syncFromHealth());
  }

  static Future<void> _loadFromDb() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - _memoryWindowDays);
    final to = nextDay(dayOnly(now));

    final dayRows = await _dao.getDayRange(from, to);
    _daysNotifier.value = {
      for (final r in dayRows) r.id: BiometricDay.fromRow(r),
    };

    final workoutRows = await _dao.getWorkoutsForRange(from, to);
    final byDay = <String, List<WorkoutSession>>{};
    for (final r in workoutRows) {
      (byDay[r.dateKey] ??= []).add(WorkoutSession.fromRow(r));
    }
    _workoutsNotifier.value = byDay;
  }

  static void clearInMemory() {
    _daysNotifier.value = {};
    _workoutsNotifier.value = {};
    _isInitialized = false;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    clearInMemory();
  }

  // ============ QUERIES ============

  static BiometricDay? getToday() => getForDate(DateTime.now());

  static BiometricDay? getForDate(DateTime date) =>
      _daysNotifier.value[dateKeyOf(date)];

  static List<WorkoutSession> workoutsForDate(DateTime date) =>
      _workoutsNotifier.value[dateKeyOf(date)] ?? const [];

  /// Loaded days in range, oldest first.
  static List<BiometricDay> getForRange(DateTime start, DateTime end) {
    final out = <BiometricDay>[];
    for (var d = dayOnly(start);
        !d.isAfter(dayOnly(end));
        d = nextDay(d)) {
      final row = _daysNotifier.value[dateKeyOf(d)];
      if (row != null) out.add(row);
    }
    return out;
  }

  /// Resting-heart-rate trend, oldest → newest. Days without a value are
  /// OMITTED, never zero-filled — a zero would be a measured claim of 0 bpm.
  static List<({DateTime date, int bpm, bool derived})> restingHrTrend(
      {int days = 30}) {
    final now = dayOnly(DateTime.now());
    final out = <({DateTime date, int bpm, bool derived})>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      final row = _daysNotifier.value[dateKeyOf(d)];
      final bpm = row?.restingHr;
      if (bpm != null) {
        out.add((date: d, bpm: bpm, derived: row!.restingHrDerived));
      }
    }
    return out;
  }

  /// HRV trend restricted to a SINGLE [HrvMetric].
  ///
  /// The metric is a parameter rather than an option because mixing RMSSD and
  /// SDNN in one series invents a step change out of a unit difference — this
  /// signature makes that impossible to do by accident. Defaults to whichever
  /// metric the most recent day carries.
  static List<({DateTime date, double ms})> hrvTrend(
      {int days = 30, HrvMetric? metric}) {
    final now = dayOnly(DateTime.now());
    final resolved = metric ?? _latestHrvMetric();
    if (resolved == null) return const [];

    final out = <({DateTime date, double ms})>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      final row = _daysNotifier.value[dateKeyOf(d)];
      final ms = row?.hrvNightlyMs;
      if (ms != null && row!.hrvMetric == resolved) {
        out.add((date: d, ms: ms));
      }
    }
    return out;
  }

  static HrvMetric? _latestHrvMetric() {
    final rows = _daysNotifier.value.values
        .where((r) => r.hrvMetric != null)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return rows.isEmpty ? null : rows.first.hrvMetric;
  }

  /// The user's own HRV baseline, plus how many nights back it.
  ///
  /// Null below [minNights]. Same honesty rule as `SleepService`'s
  /// regularity index: a "baseline" from two nights is noise wearing a
  /// number's clothes.
  static ({double? ms, HrvMetric? metric, int nights}) hrvBaseline(
      {int days = 14, int minNights = 5}) {
    final metric = _latestHrvMetric();
    if (metric == null) return (ms: null, metric: null, nights: 0);
    final points = hrvTrend(days: days, metric: metric);
    if (points.length < minNights) {
      return (ms: null, metric: metric, nights: points.length);
    }
    final sum = points.fold<double>(0, (a, p) => a + p.ms);
    return (ms: sum / points.length, metric: metric, nights: points.length);
  }

  // ============ IMPORT ============

  /// Pull the last [days] days from the platform and aggregate them.
  ///
  /// Returns the number of days written. Never throws.
  ///
  /// [samples] is the headless-test seam — a map of dateKey → the points that
  /// day's plugin reads WOULD have returned, used INSTEAD of touching the
  /// plugin (cf. `VitalsStorageService.importFromHealthConnect({samples})`).
  /// [now] makes the whole thing clock-free for tests.
  static Future<int> syncFromHealth({
    int days = defaultSyncDays,
    Map<String, List<HealthDataPoint>>? samples,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    try {
      final live = samples == null;
      if (live && !await HealthDataService.instance.hasBiometricPermission()) {
        return 0;
      }

      final today = dayOnly(clock);
      final from = DateTime(today.year, today.month, today.day - days);

      // Never resurrect a day the user deleted. Without this the next sync
      // rebuilds the row and the deleted data comes straight back — the bug
      // SleepService already guards with `deletedIdsInRange`.
      Set<String> tombstoned = const {};
      try {
        tombstoned = await _dao.deletedDateKeysInRange(from, nextDay(today));
      } catch (e) {
        debugPrint('BiometricsService tombstone lookup failed: $e');
      }

      final known = {
        for (final r in await _dao.getSources()) r.id: HealthSource.fromRow(r)
      };
      final sourceUpdates = <String, HealthSource>{};

      var written = 0;
      final updatedDays = Map<String, BiometricDay>.from(_daysNotifier.value);
      final updatedWorkouts =
          Map<String, List<WorkoutSession>>.from(_workoutsNotifier.value);

      for (var i = 0; i <= days; i++) {
        final day = DateTime(today.year, today.month, today.day - i);
        final dateKey = dateKeyOf(day);
        if (tombstoned.contains(dateKey)) continue;
        if (!_needsResync(dateKey, day, today)) continue;

        // ONE contiguous read per type per day: prev-18:00 → next-00:00, so the
        // pure aggregator can carve out BOTH the calendar-day and night windows
        // in Dart without extra plugin calls. The list goes out of scope at the
        // end of this iteration, which is what bounds peak memory to one day.
        final points = live
            ? await _readDay(dateKey)
            : (samples[dateKey] ?? const <HealthDataPoint>[]);
        if (points.isEmpty) continue;

        final result = aggregateDay(
          dateKey,
          points,
          known: known,
          now: clock,
        );
        if (result == null) continue;

        for (final entry in result.sourceTouches.entries) {
          final merged = HealthSourceRegistry.merge(
            candidate: entry.value.candidate,
            metricKey: entry.value.metricKey,
            now: clock,
            existing: sourceUpdates[entry.key] ?? known[entry.key],
          );
          sourceUpdates[entry.key] = merged;
        }

        await _dao.upsertDay(result.day.toCompanion());
        updatedDays[dateKey] = result.day;

        final workouts = aggregateWorkouts(dateKey, points, now: clock);
        if (workouts.isNotEmpty) {
          for (final w in workouts) {
            await _dao.upsertWorkout(w.toCompanion());
          }
          updatedWorkouts[dateKey] = workouts;
        }

        written++;
      }

      for (final s in sourceUpdates.values) {
        await _dao.upsertSource(s.toCompanion());
      }

      _daysNotifier.value = updatedDays;
      _workoutsNotifier.value = updatedWorkouts;
      return written;
    } catch (e) {
      debugPrint('BiometricsService.syncFromHealth failed: $e');
      return 0;
    }
  }

  /// Today and yesterday are always re-read: a night completes after midnight
  /// and a watch often syncs hours late. Older days settle once, which is what
  /// keeps a routine sync at two days of plugin work instead of eight.
  static bool _needsResync(String dateKey, DateTime day, DateTime today) {
    final ageDays = today.difference(dayOnly(day)).inDays;
    if (ageDays <= 1) return true;
    final existing = _daysNotifier.value[dateKey];
    if (existing == null || existing.hrSampleCount == 0) return true;
    final synced = existing.lastSyncedAt;
    return synced == null || !synced.isAfter(dayWindowFor(dateKey).end);
  }

  static Future<List<HealthDataPoint>> _readDay(String dateKey) async {
    final from = nightWindowFor(dateKey).start;
    final to = dayWindowFor(dateKey).end;
    final svc = HealthDataService.instance;
    final out = <HealthDataPoint>[];
    for (final t in HealthDataService.biometricTypes) {
      out.addAll(await svc.readBiometricSamples(t, from, to));
    }
    return out;
  }

  // ============ PURE AGGREGATION ============

  /// One day's raw points → one row. **Pure**: derives both windows from
  /// [dateKey] itself, so it reads no clock and no database.
  ///
  /// Returns null when nothing usable is present, so the caller can skip
  /// writing an empty row for a day the wearable simply was not worn.
  /// [android] selects the platform-split types (HRV, skin temperature) and
  /// defaults to the running platform. It is a parameter because
  /// `Platform.isAndroid` is false under `flutter test` on macOS — hard-coding
  /// it would silently make every HRV assertion here test the iOS branch and
  /// pass for the wrong reason.
  @visibleForTesting
  static AggregatedDay? aggregateDay(
    String dateKey,
    List<HealthDataPoint> points, {
    Map<String, HealthSource> known = const {},
    required DateTime now,
    bool? android,
  }) {
    final isAndroid = android ?? Platform.isAndroid;
    final dayWin = dayWindowFor(dateKey);
    final nightWin = nightWindowFor(dateKey);
    final sleepWin = sleepProxyWindowFor(dateKey);

    List<HealthDataPoint> inWindow(
            HealthDataType type, ({DateTime start, DateTime end}) w) =>
        points
            .where((p) =>
                p.type == type &&
                !p.dateFrom.isBefore(w.start) &&
                p.dateFrom.isBefore(w.end) &&
                (known[HealthSourceRegistry.keyFor(p)]?.enabled ?? true))
            .toList();

    final touches = <String, _SourceTouch>{};
    final sourceByMetric = <String, String>{};

    /// Resolve a winner, then keep ONLY that source's points. This is the
    /// no-mixing invariant; everything downstream depends on it.
    List<HealthDataPoint> winnerOnly(
        List<HealthDataPoint> pts, String metricKey) {
      if (pts.isEmpty) return const [];
      final candidates =
          HealthSourceRegistry.candidatesFrom(pts, known: known);
      final winner = HealthSourceRegistry.pickWinner(candidates.values);
      if (winner == null) return const [];
      sourceByMetric[metricKey] = winner.id;
      touches[winner.id] =
          _SourceTouch(candidate: winner, metricKey: metricKey);
      return pts
          .where((p) => HealthSourceRegistry.keyFor(p) == winner.id)
          .toList();
    }

    // ---- heart rate, calendar day ----
    final hrPts = winnerOnly(
        inWindow(HealthDataType.HEART_RATE, dayWin), BiometricMetricKey.hr);
    final hrValues = _numeric(hrPts);
    int? hrMin, hrMax, hrAvg;
    if (hrValues.isNotEmpty) {
      hrMin = hrValues.reduce((a, b) => a < b ? a : b).round();
      hrMax = hrValues.reduce((a, b) => a > b ? a : b).round();
      hrAvg = (hrValues.reduce((a, b) => a + b) / hrValues.length).round();
    }

    // ---- resting HR: measured if the platform gives it, else derived ----
    final restingPts = winnerOnly(
        inWindow(HealthDataType.RESTING_HEART_RATE, dayWin),
        BiometricMetricKey.restingHr);
    final restingValues = _numeric(restingPts);
    int? restingHr;
    var restingDerived = false;
    if (restingValues.isNotEmpty) {
      restingHr =
          (restingValues.reduce((a, b) => a + b) / restingValues.length)
              .round();
    } else {
      // 5th percentile of the NIGHT's heart rate. Needs enough samples to mean
      // anything — below that it is one stray low reading, not a resting rate.
      final nightHr = _numeric(points
          .where((p) =>
              p.type == HealthDataType.HEART_RATE &&
              !p.dateFrom.isBefore(sleepWin.start) &&
              p.dateFrom.isBefore(sleepWin.end))
          .toList());
      if (nightHr.length >= 20) {
        nightHr.sort();
        restingHr = nightHr[(nightHr.length * 0.05).floor()].round();
        restingDerived = true;
      }
    }

    // ---- HRV, night window; metric differs per platform ----
    final hrvType = isAndroid
        ? HealthDataService.hrvTypeAndroid
        : HealthDataService.hrvTypeIOS;
    final hrvPts =
        winnerOnly(inWindow(hrvType, nightWin), BiometricMetricKey.hrv);
    final hrvValues = _numeric(hrvPts);
    final hrvMs = hrvValues.isEmpty
        ? null
        : hrvValues.reduce((a, b) => a + b) / hrvValues.length;

    // ---- SpO2, calendar day ----
    final spo2Pts = winnerOnly(
        inWindow(HealthDataType.BLOOD_OXYGEN, dayWin),
        BiometricMetricKey.spo2);
    final spo2Values = _numeric(spo2Pts).map(_normaliseSpo2).toList();
    double? spo2Min, spo2Avg;
    if (spo2Values.isNotEmpty) {
      spo2Min = spo2Values.reduce((a, b) => a < b ? a : b);
      spo2Avg = spo2Values.reduce((a, b) => a + b) / spo2Values.length;
    }

    // ---- respiratory rate, calendar day ----
    final rrPts = winnerOnly(
        inWindow(HealthDataType.RESPIRATORY_RATE, dayWin),
        BiometricMetricKey.respiratoryRate);
    final rrValues = _numeric(rrPts);
    double? rrMin, rrAvg, rrMax;
    if (rrValues.isNotEmpty) {
      rrMin = rrValues.reduce((a, b) => a < b ? a : b);
      rrMax = rrValues.reduce((a, b) => a > b ? a : b);
      rrAvg = rrValues.reduce((a, b) => a + b) / rrValues.length;
    }

    // ---- temperature ----
    final bodyPts = winnerOnly(
        inWindow(HealthDataType.BODY_TEMPERATURE, dayWin),
        BiometricMetricKey.bodyTemp);
    final bodyValues = _numeric(bodyPts);
    final bodyTemp = bodyValues.isEmpty
        ? null
        : bodyValues.reduce((a, b) => a + b) / bodyValues.length;

    final skinType = isAndroid
        ? HealthDataService.skinTempTypeAndroid
        : HealthDataService.skinTempTypeIOS;
    final skinPts =
        winnerOnly(inWindow(skinType, nightWin), BiometricMetricKey.skinTemp);
    final skinValues = _skinTemp(skinPts);
    final skinTemp = skinValues.isEmpty
        ? null
        : skinValues.reduce((a, b) => a + b) / skinValues.length;

    final day = BiometricDay(
      id: dateKey,
      date: dayWin.start,
      restingHr: restingHr,
      restingHrDerived: restingDerived,
      hrMin: hrMin,
      hrAvg: hrAvg,
      hrMax: hrMax,
      hrSampleCount: hrValues.length,
      hourlyHr: hrValues.isEmpty ? const [] : _hourlyBuckets(hrPts, dayWin),
      hrvNightlyMs: hrvMs,
      hrvMetric: hrvMs == null
          ? null
          : (isAndroid ? HrvMetric.rmssd : HrvMetric.sdnn),
      hrvSampleCount: hrvValues.length,
      spo2Min: spo2Min,
      spo2Avg: spo2Avg,
      spo2SampleCount: spo2Values.length,
      respiratoryRateMin: rrMin,
      respiratoryRateAvg: rrAvg,
      respiratoryRateMax: rrMax,
      respiratoryRateSampleCount: rrValues.length,
      bodyTempAvgC: bodyTemp,
      skinTempC: skinTemp,
      skinTempMetric: skinTemp == null
          ? null
          : (isAndroid
              ? SkinTempMetric.deltaFromBaseline
              : SkinTempMetric.absolute),
      primarySourceId: _mostCommon(sourceByMetric.values),
      sourceByMetric: sourceByMetric,
      source: isAndroid
          ? BiometricSource.healthConnect
          : BiometricSource.healthKit,
      lastSyncedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    if (day.isEmpty) return null;
    return AggregatedDay(day: day, sourceTouches: touches);
  }

  /// Workout points → sessions, with heart rate filled from the SAME day's
  /// already-fetched HR samples. Never a second plugin read.
  @visibleForTesting
  static List<WorkoutSession> aggregateWorkouts(
    String dateKey,
    List<HealthDataPoint> points, {
    required DateTime now,
  }) {
    final hrPoints = points
        .where((p) => p.type == HealthDataType.HEART_RATE)
        .toList();

    final out = <WorkoutSession>[];
    for (final p in points.where((p) => p.type == HealthDataType.WORKOUT)) {
      final v = p.value;
      if (v is! WorkoutHealthValue) continue;

      final activity = v.workoutActivityType.name;
      final minutes = p.dateTo.difference(p.dateFrom).inMinutes;
      if (minutes <= 0) continue;

      final within = _numeric(hrPoints
          .where((h) =>
              !h.dateFrom.isBefore(p.dateFrom) && !h.dateFrom.isAfter(p.dateTo))
          .toList());

      out.add(WorkoutSession(
        // Deterministic, so a re-import upserts to a no-op. The activity type
        // is in the key because two sessions can share a start instant.
        id: 'hw_${p.dateFrom.millisecondsSinceEpoch}_$activity',
        dateKey: dateKey,
        startedAt: p.dateFrom,
        endedAt: p.dateTo,
        durationMinutes: minutes,
        activityType: activity,
        energyKcal: v.totalEnergyBurned,
        distanceMeters: v.totalDistance?.toDouble(),
        steps: v.totalSteps,
        avgHr: within.isEmpty
            ? null
            : (within.reduce((a, b) => a + b) / within.length).round(),
        maxHr: within.isEmpty
            ? null
            : within.reduce((a, b) => a > b ? a : b).round(),
        sourceId: HealthSourceRegistry.keyFor(p),
        source: Platform.isAndroid
            ? BiometricSource.healthConnect
            : BiometricSource.healthKit,
        createdAt: now,
        updatedAt: now,
      ));
    }
    return out;
  }

  // ============ helpers ============

  static List<double> _numeric(List<HealthDataPoint> pts) {
    final out = <double>[];
    for (final p in pts) {
      final v = p.value;
      if (v is NumericHealthValue) out.add(v.numericValue.toDouble());
    }
    return out;
  }

  /// Skin temperature is NOT a [NumericHealthValue] on Android — Health
  /// Connect returns a delta-plus-baseline structure. A copy-pasted
  /// `is NumericHealthValue` guard silently drops every sample, and the screen
  /// shows "no data" with nothing to debug.
  static List<double> _skinTemp(List<HealthDataPoint> pts) {
    final out = <double>[];
    for (final p in pts) {
      final v = p.value;
      if (v is NumericHealthValue) {
        out.add(v.numericValue.toDouble());
      } else {
        final delta = _tryTemperatureDelta(v);
        if (delta != null) out.add(delta);
      }
    }
    return out;
  }

  /// Reads the delta off Health Connect's skin-temperature value without
  /// naming the class, so a plugin rename degrades to "no reading" rather than
  /// a compile break in a file that must keep working on both platforms.
  static double? _tryTemperatureDelta(Object? v) {
    try {
      final dynamic dyn = v;
      final delta = dyn.temperatureDelta;
      if (delta is num) return delta.toDouble();
    } catch (_) {
      // Not a skin-temperature value; nothing to read.
    }
    return null;
  }

  /// HealthKit reports oxygen saturation as a FRACTION (0..1) while Health
  /// Connect reports a percentage (0..100), despite both being declared
  /// `PERCENT`. Without this an iOS reading renders as "0.97%".
  static double _normaliseSpo2(double v) => v <= 1.0 ? v * 100 : v;

  /// 24 hourly means, null for an hour with no sample — never zero.
  static List<int?> _hourlyBuckets(
      List<HealthDataPoint> pts, ({DateTime start, DateTime end}) dayWin) {
    final sums = List<double>.filled(24, 0);
    final counts = List<int>.filled(24, 0);
    for (final p in pts) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final h = p.dateFrom.difference(dayWin.start).inHours;
      if (h < 0 || h > 23) continue;
      sums[h] += v.numericValue.toDouble();
      counts[h]++;
    }
    return [
      for (var h = 0; h < 24; h++)
        counts[h] == 0 ? null : (sums[h] / counts[h]).round()
    ];
  }

  static String? _mostCommon(Iterable<String> ids) {
    if (ids.isEmpty) return null;
    final counts = <String, int>{};
    for (final id in ids) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) =>
          a.value == b.value ? a.key.compareTo(b.key) : b.value - a.value);
    return sorted.first.key;
  }
}

/// [BiometricsService.aggregateDay]'s result: the row, plus which sources
/// contributed which metric so the registry can be updated in one pass.
class AggregatedDay {
  final BiometricDay day;
  final Map<String, _SourceTouch> sourceTouches;

  const AggregatedDay({required this.day, required this.sourceTouches});
}

class _SourceTouch {
  final SourceCandidate candidate;
  final String metricKey;

  const _SourceTouch({required this.candidate, required this.metricKey});
}
