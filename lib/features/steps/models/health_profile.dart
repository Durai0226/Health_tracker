import 'package:drift/drift.dart' show Value;
import 'package:tablet_remainder/core/database/app_database.dart' as db;

/// Body + schedule profile (single row, `id = 'profile'`). Shared with the Sleep
/// feature — Steps owns the read/write of this table, so this model carries the
/// sleep schedule fields verbatim and writes them back untouched.
class HealthProfile {
  final String id;
  final double? weightKg;
  final int? heightCm;
  final int? age;
  final bool isMale;
  final double? strideLengthCm;
  final int? customStepGoal;
  final bool useCustomStepGoal;

  // Sleep-owned fields — preserved on write so we never clobber the Sleep
  // feature's schedule.
  final int targetSleepMinutes;
  final int bedtimeHour;
  final int bedtimeMinute;
  final int wakeHour;
  final int wakeMinute;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HealthProfile({
    this.id = 'profile',
    this.weightKg,
    this.heightCm,
    this.age,
    this.isMale = true,
    this.strideLengthCm,
    this.customStepGoal,
    this.useCustomStepGoal = false,
    this.targetSleepMinutes = 480,
    this.bedtimeHour = 22,
    this.bedtimeMinute = 30,
    this.wakeHour = 7,
    this.wakeMinute = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Stride length in metres. Uses the explicit stride when set, else derives it
  /// from height (a standard ~0.415 factor), else a sane adult default.
  double get strideMeters {
    if (strideLengthCm != null && strideLengthCm! > 0) {
      return strideLengthCm! / 100.0;
    }
    if (heightCm != null && heightCm! > 0) {
      return heightCm! * 0.415 / 100.0;
    }
    return 0.72; // ~average adult stride when we know nothing yet
  }

  /// Estimated distance (metres) walked for [steps].
  double deriveDistanceMeters(int steps) {
    if (steps <= 0) return 0;
    return steps * strideMeters;
  }

  /// Estimated active calories burned for [steps] at [weight] kg (falls back to
  /// this profile's weight, then ~70 kg). Uses a simple ~0.0005 kcal per
  /// step-per-kg approximation (≈280 kcal for 8k steps at 70 kg).
  double deriveActiveCalories(int steps, {double? weight}) {
    if (steps <= 0) return 0;
    final w = weight ?? weightKg ?? 70.0;
    return steps * w * 0.0005;
  }

  HealthProfile copyWith({
    double? weightKg,
    bool clearWeight = false,
    int? heightCm,
    bool clearHeight = false,
    int? age,
    bool? isMale,
    double? strideLengthCm,
    bool clearStride = false,
    int? customStepGoal,
    bool? useCustomStepGoal,
    int? targetSleepMinutes,
    int? bedtimeHour,
    int? bedtimeMinute,
    int? wakeHour,
    int? wakeMinute,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthProfile(
      id: id,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      age: age ?? this.age,
      isMale: isMale ?? this.isMale,
      strideLengthCm: clearStride ? null : (strideLengthCm ?? this.strideLengthCm),
      customStepGoal: customStepGoal ?? this.customStepGoal,
      useCustomStepGoal: useCustomStepGoal ?? this.useCustomStepGoal,
      targetSleepMinutes: targetSleepMinutes ?? this.targetSleepMinutes,
      bedtimeHour: bedtimeHour ?? this.bedtimeHour,
      bedtimeMinute: bedtimeMinute ?? this.bedtimeMinute,
      wakeHour: wakeHour ?? this.wakeHour,
      wakeMinute: wakeMinute ?? this.wakeMinute,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory HealthProfile.fromRow(db.HealthProfileRow r) => HealthProfile(
        id: r.id,
        weightKg: r.weightKg,
        heightCm: r.heightCm,
        age: r.age,
        isMale: r.isMale,
        strideLengthCm: r.strideLengthCm,
        customStepGoal: r.customStepGoal,
        useCustomStepGoal: r.useCustomStepGoal,
        targetSleepMinutes: r.targetSleepMinutes,
        bedtimeHour: r.bedtimeHour,
        bedtimeMinute: r.bedtimeMinute,
        wakeHour: r.wakeHour,
        wakeMinute: r.wakeMinute,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  db.HealthProfilesCompanion toCompanion() {
    final now = DateTime.now();
    return db.HealthProfilesCompanion(
      id: const Value('profile'),
      weightKg: Value(weightKg),
      heightCm: Value(heightCm),
      age: Value(age),
      isMale: Value(isMale),
      strideLengthCm: Value(strideLengthCm),
      customStepGoal: Value(customStepGoal),
      useCustomStepGoal: Value(useCustomStepGoal),
      targetSleepMinutes: Value(targetSleepMinutes),
      bedtimeHour: Value(bedtimeHour),
      bedtimeMinute: Value(bedtimeMinute),
      wakeHour: Value(wakeHour),
      wakeMinute: Value(wakeMinute),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
      synced: const Value(false),
    );
  }
}
