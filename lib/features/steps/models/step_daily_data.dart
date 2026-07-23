import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'step_manual_entry.dart';
import 'step_source.dart';

/// One day's step total (date-keyed `yyyy-MM-dd`).
///
/// [effectiveSteps] prefers the hardware [sensorSteps] and only falls back to
/// [manualSteps] when there's no sensor reading — so a Simulator/manual-only day
/// still reports and charts correctly.
class StepDailyData {
  final String id; // yyyy-MM-dd
  final DateTime date;
  final int goalSteps;
  final int? sensorSteps;
  final int manualSteps;
  final double distanceMeters;
  final double activeCalories;
  final StepSource source;

  /// 24 hourly buckets (indices 0..23). Empty when unknown.
  final List<int> hourly;

  final bool goalReached;
  final DateTime? goalReachedAt;
  final DateTime? lastSyncedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Individual manual adjustments backing [manualSteps] (loaded alongside the
  /// day, mirrors the water logs pattern).
  final List<StepManualEntry> manualEntries;

  const StepDailyData({
    required this.id,
    required this.date,
    this.goalSteps = 8000,
    this.sensorSteps,
    this.manualSteps = 0,
    this.distanceMeters = 0,
    this.activeCalories = 0,
    this.source = StepSource.manual,
    this.hourly = const [],
    this.goalReached = false,
    this.goalReachedAt,
    this.lastSyncedAt,
    this.createdAt,
    this.updatedAt,
    this.manualEntries = const [],
  });

  /// Sensor total when present, else the manual tally.
  int get effectiveSteps => sensorSteps ?? manualSteps;

  /// 0..(>1) progress toward the goal. Can exceed 1 (over-achievement).
  double get progress =>
      goalSteps > 0 ? effectiveSteps / goalSteps : 0.0;

  /// Progress clamped to 0..1 for a single-lap ring.
  double get clampedProgress => progress.clamp(0.0, 1.0);

  int get distanceKmWhole => (distanceMeters / 1000).floor();

  /// Distance in km with one decimal.
  double get distanceKm => distanceMeters / 1000.0;

  StepDailyData copyWith({
    String? id,
    DateTime? date,
    int? goalSteps,
    int? sensorSteps,
    bool clearSensor = false,
    int? manualSteps,
    double? distanceMeters,
    double? activeCalories,
    StepSource? source,
    List<int>? hourly,
    bool? goalReached,
    DateTime? goalReachedAt,
    DateTime? lastSyncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<StepManualEntry>? manualEntries,
  }) {
    return StepDailyData(
      id: id ?? this.id,
      date: date ?? this.date,
      goalSteps: goalSteps ?? this.goalSteps,
      sensorSteps: clearSensor ? null : (sensorSteps ?? this.sensorSteps),
      manualSteps: manualSteps ?? this.manualSteps,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      activeCalories: activeCalories ?? this.activeCalories,
      source: source ?? this.source,
      hourly: hourly ?? this.hourly,
      goalReached: goalReached ?? this.goalReached,
      goalReachedAt: goalReachedAt ?? this.goalReachedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      manualEntries: manualEntries ?? this.manualEntries,
    );
  }

  /// Decode a JSON `int[24]` hourly string into a fixed-length list.
  static List<int> parseHourly(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final out = List<int>.filled(24, 0);
        for (var i = 0; i < 24 && i < decoded.length; i++) {
          final v = decoded[i];
          out[i] = v is num ? v.toInt() : 0;
        }
        return out;
      }
    } catch (_) {}
    return const [];
  }

  static String? encodeHourly(List<int> hourly) =>
      hourly.isEmpty ? null : jsonEncode(hourly);

  /// Build the model from a persisted row (+ its manual entries).
  factory StepDailyData.fromRow(
    db.StepDayRow r, {
    List<StepManualEntry> manualEntries = const [],
  }) {
    return StepDailyData(
      id: r.id,
      date: r.date,
      goalSteps: r.goalSteps,
      sensorSteps: r.sensorSteps,
      manualSteps: r.manualSteps,
      distanceMeters: r.distanceMeters,
      activeCalories: r.activeCalories,
      source: StepSourceX.fromIndex(r.sourceIndex),
      hourly: parseHourly(r.hourlyJson),
      goalReached: r.goalReached,
      goalReachedAt: r.goalReachedAt,
      lastSyncedAt: r.lastSyncedAt,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      manualEntries: manualEntries,
    );
  }

  db.StepDailyDataCompanion toCompanion() {
    final now = DateTime.now();
    return db.StepDailyDataCompanion(
      id: Value(id),
      date: Value(date),
      goalSteps: Value(goalSteps),
      sensorSteps: Value(sensorSteps),
      manualSteps: Value(manualSteps),
      distanceMeters: Value(distanceMeters),
      activeCalories: Value(activeCalories),
      sourceIndex: Value(source.index),
      hourlyJson: Value(encodeHourly(hourly)),
      goalReached: Value(goalReached),
      goalReachedAt: Value(goalReachedAt),
      lastSyncedAt: Value(lastSyncedAt),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
      synced: const Value(false),
    );
  }
}
