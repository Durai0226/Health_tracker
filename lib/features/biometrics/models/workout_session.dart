import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart' as db;
import 'biometric_metric.dart';

/// One exercise session imported from Health Connect / HealthKit.
class WorkoutSession {
  final String id; // hw_<startMillis>_<activityType>
  final String dateKey;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMinutes;

  /// `HealthWorkoutActivityType.name`, kept as the raw string the plugin gave
  /// us. Never an ordinal — that enum's order shifts between plugin releases.
  final String activityType;

  final int? energyKcal;
  final double? distanceMeters;
  final int? steps;

  /// Derived by intersecting the day's heart-rate samples with this session's
  /// window; the plugin's workout payload carries no heart rate.
  final int? avgHr;
  final int? maxHr;

  final String? sourceId;
  final BiometricSource source;
  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const WorkoutSession({
    required this.id,
    required this.dateKey,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.activityType,
    required this.createdAt,
    required this.updatedAt,
    this.energyKcal,
    this.distanceMeters,
    this.steps,
    this.avgHr,
    this.maxHr,
    this.sourceId,
    this.source = BiometricSource.manual,
    this.note,
    this.deletedAt,
  });

  /// `HIKING` → `Hiking`, `HIGH_INTENSITY_INTERVAL_TRAINING` → `High intensity
  /// interval training`. The plugin's enum names are SCREAMING_SNAKE and there
  /// are 80+ of them, so this beats a hand-maintained label map that would
  /// silently fall back to raw enum text every time the plugin adds a type.
  String get activityLabel {
    if (activityType.isEmpty) return 'Workout';
    final words = activityType.toLowerCase().replaceAll('_', ' ').trim();
    if (words.isEmpty) return 'Workout';
    return words[0].toUpperCase() + words.substring(1);
  }

  factory WorkoutSession.fromRow(db.WorkoutSessionRow r) => WorkoutSession(
        id: r.id,
        dateKey: r.dateKey,
        startedAt: r.startedAt,
        endedAt: r.endedAt,
        durationMinutes: r.durationMinutes,
        activityType: r.activityType,
        energyKcal: r.energyKcal,
        distanceMeters: r.distanceMeters,
        steps: r.steps,
        avgHr: r.avgHr,
        maxHr: r.maxHr,
        sourceId: r.sourceId,
        source: (r.sourceIndex >= 0 &&
                r.sourceIndex < BiometricSource.values.length)
            ? BiometricSource.values[r.sourceIndex]
            : BiometricSource.manual,
        note: r.note,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deletedAt: r.deletedAt,
      );

  db.WorkoutSessionsCompanion toCompanion() => db.WorkoutSessionsCompanion(
        id: Value(id),
        dateKey: Value(dateKey),
        startedAt: Value(startedAt),
        endedAt: Value(endedAt),
        durationMinutes: Value(durationMinutes),
        activityType: Value(activityType),
        energyKcal: Value(energyKcal),
        distanceMeters: Value(distanceMeters),
        steps: Value(steps),
        avgHr: Value(avgHr),
        maxHr: Value(maxHr),
        sourceId: Value(sourceId),
        sourceIndex: Value(source.index),
        note: Value(note),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        synced: const Value(false),
      );
}
