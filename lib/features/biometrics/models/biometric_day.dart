import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart' as db;
import 'biometric_metric.dart';

/// One day's wearable biometrics, decoded from [db.BiometricDayRow].
///
/// The row stores raw ints and JSON; this adds the enum decoding and the two
/// JSON fields, so no screen has to know that `hrvMetricIndex` is an ordinal or
/// that `hourlyHrJson` is a 24-slot array.
///
/// Every metric is nullable and stays nullable all the way to the chart. A
/// missing hour is a genuine gap and must render as empty space — zero-filling
/// it would draw a measured zero that no device ever recorded.
class BiometricDay {
  final String id; // yyyy-MM-dd
  final DateTime date;

  final int? restingHr;

  /// True when [restingHr] was inferred from the night's heart-rate
  /// distribution rather than read from a RESTING_HEART_RATE record. The UI
  /// must say "estimated" when this is set.
  final bool restingHrDerived;
  final int? hrMin;
  final int? hrAvg;
  final int? hrMax;
  final int hrSampleCount;

  /// 24 entries, null where the hour had no sample.
  final List<int?> hourlyHr;

  final double? hrvNightlyMs;

  /// Which statistic [hrvNightlyMs] is. Null when there is no HRV.
  /// **Never plot two metrics in one series** — see [HrvMetric].
  final HrvMetric? hrvMetric;
  final int hrvSampleCount;

  final double? spo2Min;
  final double? spo2Avg;
  final int spo2SampleCount;

  final double? respiratoryRateMin;
  final double? respiratoryRateAvg;
  final double? respiratoryRateMax;
  final int respiratoryRateSampleCount;

  final double? bodyTempAvgC;
  final double? skinTempC;
  final SkinTempMetric? skinTempMetric;

  /// Reserved. `package:health` 13.3.2 exposes no VO2MAX type on either
  /// platform, so nothing writes this yet.
  final double? vo2Max;

  final String? primarySourceId;

  /// `{metricKey: sourceId}` — a day can draw heart rate from a watch and SpO2
  /// from a ring.
  final Map<String, String> sourceByMetric;
  final BiometricSource source;
  final DateTime? lastSyncedAt;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const BiometricDay({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.restingHr,
    this.restingHrDerived = false,
    this.hrMin,
    this.hrAvg,
    this.hrMax,
    this.hrSampleCount = 0,
    this.hourlyHr = const [],
    this.hrvNightlyMs,
    this.hrvMetric,
    this.hrvSampleCount = 0,
    this.spo2Min,
    this.spo2Avg,
    this.spo2SampleCount = 0,
    this.respiratoryRateMin,
    this.respiratoryRateAvg,
    this.respiratoryRateMax,
    this.respiratoryRateSampleCount = 0,
    this.bodyTempAvgC,
    this.skinTempC,
    this.skinTempMetric,
    this.vo2Max,
    this.primarySourceId,
    this.sourceByMetric = const {},
    this.source = BiometricSource.manual,
    this.lastSyncedAt,
    this.deletedAt,
  });

  /// True when the day carries nothing worth showing. Used to avoid writing
  /// empty rows for days the wearable simply was not worn.
  bool get isEmpty =>
      hrSampleCount == 0 &&
      hrvSampleCount == 0 &&
      spo2SampleCount == 0 &&
      respiratoryRateSampleCount == 0 &&
      restingHr == null &&
      bodyTempAvgC == null &&
      skinTempC == null;

  factory BiometricDay.fromRow(db.BiometricDayRow r) => BiometricDay(
        id: r.id,
        date: r.date,
        restingHr: r.restingHr,
        restingHrDerived: r.restingHrDerived,
        hrMin: r.hrMin,
        hrAvg: r.hrAvg,
        hrMax: r.hrMax,
        hrSampleCount: r.hrSampleCount,
        hourlyHr: _decodeHourly(r.hourlyHrJson),
        hrvNightlyMs: r.hrvNightlyMs,
        hrvMetric: _enumAt(HrvMetric.values, r.hrvMetricIndex),
        hrvSampleCount: r.hrvSampleCount,
        spo2Min: r.spo2Min,
        spo2Avg: r.spo2Avg,
        spo2SampleCount: r.spo2SampleCount,
        respiratoryRateMin: r.respiratoryRateMin,
        respiratoryRateAvg: r.respiratoryRateAvg,
        respiratoryRateMax: r.respiratoryRateMax,
        respiratoryRateSampleCount: r.respiratoryRateSampleCount,
        bodyTempAvgC: r.bodyTempAvgC,
        skinTempC: r.skinTempC,
        skinTempMetric: _enumAt(SkinTempMetric.values, r.skinTempMetricIndex),
        vo2Max: r.vo2Max,
        primarySourceId: r.primarySourceId,
        sourceByMetric: _decodeSources(r.sourceByMetricJson),
        source: _enumAt(BiometricSource.values, r.sourceIndex) ??
            BiometricSource.manual,
        lastSyncedAt: r.lastSyncedAt,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deletedAt: r.deletedAt,
      );

  db.BiometricDailyDataCompanion toCompanion() =>
      db.BiometricDailyDataCompanion(
        id: Value(id),
        date: Value(date),
        restingHr: Value(restingHr),
        restingHrDerived: Value(restingHrDerived),
        hrMin: Value(hrMin),
        hrAvg: Value(hrAvg),
        hrMax: Value(hrMax),
        hrSampleCount: Value(hrSampleCount),
        hourlyHrJson:
            Value(hourlyHr.isEmpty ? null : jsonEncode(hourlyHr)),
        hrvNightlyMs: Value(hrvNightlyMs),
        hrvMetricIndex: Value(hrvMetric?.index),
        hrvSampleCount: Value(hrvSampleCount),
        spo2Min: Value(spo2Min),
        spo2Avg: Value(spo2Avg),
        spo2SampleCount: Value(spo2SampleCount),
        respiratoryRateMin: Value(respiratoryRateMin),
        respiratoryRateAvg: Value(respiratoryRateAvg),
        respiratoryRateMax: Value(respiratoryRateMax),
        respiratoryRateSampleCount: Value(respiratoryRateSampleCount),
        bodyTempAvgC: Value(bodyTempAvgC),
        skinTempC: Value(skinTempC),
        skinTempMetricIndex: Value(skinTempMetric?.index),
        vo2Max: Value(vo2Max),
        primarySourceId: Value(primarySourceId),
        sourceByMetricJson: Value(
            sourceByMetric.isEmpty ? null : jsonEncode(sourceByMetric)),
        sourceIndex: Value(source.index),
        lastSyncedAt: Value(lastSyncedAt),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        // An import must clear any tombstone it is legitimately replacing —
        // but callers skip tombstoned days entirely, so this only ever applies
        // to a day the user did not delete.
        deletedAt: Value(deletedAt),
        synced: const Value(false),
      );

  /// Tolerant by design: a malformed blob yields "no data", never a crash. The
  /// column is ours, so bad JSON means a bug elsewhere — losing one day's
  /// chart is a better outcome than taking the screen down.
  static List<int?> _decodeHourly(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List;
      if (list.length != 24) return const [];
      return list.map((e) => e is num ? e.toInt() : null).toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, String> _decodeSources(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final map = jsonDecode(json) as Map;
      return map.map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return const {};
    }
  }

  /// Guards against an ordinal written by a newer build than this one.
  static T? _enumAt<T>(List<T> values, int? index) =>
      (index == null || index < 0 || index >= values.length)
          ? null
          : values[index];
}
