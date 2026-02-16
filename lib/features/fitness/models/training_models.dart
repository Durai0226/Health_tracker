import 'package:hive/hive.dart';

part 'training_models.g.dart';

/// Heart Rate Zone - Custom configurable zones
@HiveType(typeId: 30)
class HeartRateZone extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int minBpm;

  @HiveField(3)
  final int maxBpm;

  @HiveField(4)
  final String color; // Hex color

  @HiveField(5)
  final String description;

  HeartRateZone({
    required this.id,
    required this.name,
    required this.minBpm,
    required this.maxBpm,
    required this.color,
    required this.description,
  });

  static List<HeartRateZone> getDefaultZones(int maxHr) {
    return [
      HeartRateZone(
        id: 'z1',
        name: 'Recovery',
        minBpm: (maxHr * 0.5).round(),
        maxBpm: (maxHr * 0.6).round(),
        color: '#90CAF9',
        description: 'Very light activity, active recovery',
      ),
      HeartRateZone(
        id: 'z2',
        name: 'Endurance',
        minBpm: (maxHr * 0.6).round(),
        maxBpm: (maxHr * 0.7).round(),
        color: '#81C784',
        description: 'Aerobic base building',
      ),
      HeartRateZone(
        id: 'z3',
        name: 'Tempo',
        minBpm: (maxHr * 0.7).round(),
        maxBpm: (maxHr * 0.8).round(),
        color: '#FFD54F',
        description: 'Moderate intensity, lactate threshold',
      ),
      HeartRateZone(
        id: 'z4',
        name: 'Threshold',
        minBpm: (maxHr * 0.8).round(),
        maxBpm: (maxHr * 0.9).round(),
        color: '#FF8A65',
        description: 'High intensity, anaerobic capacity',
      ),
      HeartRateZone(
        id: 'z5',
        name: 'VO2 Max',
        minBpm: (maxHr * 0.9).round(),
        maxBpm: maxHr,
        color: '#EF5350',
        description: 'Maximum effort, peak performance',
      ),
    ];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'minBpm': minBpm,
    'maxBpm': maxBpm,
    'color': color,
    'description': description,
  };

  factory HeartRateZone.fromJson(Map<String, dynamic> json) => HeartRateZone(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    minBpm: json['minBpm'] ?? 0,
    maxBpm: json['maxBpm'] ?? 0,
    color: json['color'] ?? '#FFFFFF',
    description: json['description'] ?? '',
  );
}

/// Relative Effort Score - Cardio workload calculation
@HiveType(typeId: 31)
class RelativeEffort extends HiveObject {
  @HiveField(0)
  final String activityId;

  @HiveField(1)
  final int score; // 0-300+ scale

  @HiveField(2)
  final int durationSeconds;

  @HiveField(3)
  final int avgHeartRate;

  @HiveField(4)
  final int maxHeartRate;

  @HiveField(5)
  final Map<String, int> timeInZones; // Zone ID -> seconds

  @HiveField(6)
  final DateTime calculatedAt;

  RelativeEffort({
    required this.activityId,
    required this.score,
    required this.durationSeconds,
    required this.avgHeartRate,
    required this.maxHeartRate,
    required this.timeInZones,
    required this.calculatedAt,
  });

  String get effortLevel {
    if (score < 25) return 'Light';
    if (score < 75) return 'Moderate';
    if (score < 150) return 'Hard';
    if (score < 250) return 'Very Hard';
    return 'Extreme';
  }

  String get effortEmoji {
    if (score < 25) return '😊';
    if (score < 75) return '💪';
    if (score < 150) return '🔥';
    if (score < 250) return '⚡';
    return '🏆';
  }

  static int calculateScore(int durationMinutes, int avgHr, int restingHr, int maxHr) {
    if (maxHr <= restingHr) return 0;
    final hrReserve = maxHr - restingHr;
    final intensity = (avgHr - restingHr) / hrReserve;
    return (intensity * durationMinutes * 2).round().clamp(0, 500);
  }

  Map<String, dynamic> toJson() => {
    'activityId': activityId,
    'score': score,
    'durationSeconds': durationSeconds,
    'avgHeartRate': avgHeartRate,
    'maxHeartRate': maxHeartRate,
    'timeInZones': timeInZones,
    'calculatedAt': calculatedAt.toIso8601String(),
  };

  factory RelativeEffort.fromJson(Map<String, dynamic> json) => RelativeEffort(
    activityId: json['activityId'] ?? '',
    score: json['score'] ?? 0,
    durationSeconds: json['durationSeconds'] ?? 0,
    avgHeartRate: json['avgHeartRate'] ?? 0,
    maxHeartRate: json['maxHeartRate'] ?? 0,
    timeInZones: Map<String, int>.from(json['timeInZones'] ?? {}),
    calculatedAt: DateTime.parse(json['calculatedAt'] ?? DateTime.now().toIso8601String()),
  );
}

/// Personal Record - Best Efforts tracking
@HiveType(typeId: 32)
class PersonalRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String activityType; // run, cycling, swimming, etc.

  @HiveField(2)
  final String recordType; // distance, time, pace, power, etc.

  @HiveField(3)
  final String distance; // "5K", "10K", "Half Marathon", etc.

  @HiveField(4)
  final double value; // Time in seconds, pace in min/km, etc.

  @HiveField(5)
  final DateTime achievedAt;

  @HiveField(6)
  final String? activityId;

  @HiveField(7)
  final double? previousValue;

  @HiveField(8)
  final DateTime? previousDate;

  PersonalRecord({
    required this.id,
    required this.activityType,
    required this.recordType,
    required this.distance,
    required this.value,
    required this.achievedAt,
    this.activityId,
    this.previousValue,
    this.previousDate,
  });

  String get formattedValue {
    if (recordType == 'time') {
      final duration = Duration(seconds: value.round());
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;
      if (hours > 0) {
        return '${hours}h ${minutes}m ${seconds}s';
      }
      return '${minutes}m ${seconds}s';
    } else if (recordType == 'pace') {
      final minutes = value.floor();
      final seconds = ((value - minutes) * 60).round();
      return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
    } else if (recordType == 'power') {
      return '${value.round()} W';
    }
    return value.toString();
  }

  double? get improvement {
    if (previousValue == null) return null;
    return ((previousValue! - value) / previousValue! * 100);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityType': activityType,
    'recordType': recordType,
    'distance': distance,
    'value': value,
    'achievedAt': achievedAt.toIso8601String(),
    'activityId': activityId,
    'previousValue': previousValue,
    'previousDate': previousDate?.toIso8601String(),
  };

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    id: json['id'] ?? '',
    activityType: json['activityType'] ?? '',
    recordType: json['recordType'] ?? '',
    distance: json['distance'] ?? '',
    value: (json['value'] ?? 0).toDouble(),
    achievedAt: DateTime.parse(json['achievedAt'] ?? DateTime.now().toIso8601String()),
    activityId: json['activityId'],
    previousValue: json['previousValue']?.toDouble(),
    previousDate: json['previousDate'] != null ? DateTime.parse(json['previousDate']) : null,
  );
}

/// Training Plan - Structured workout programs
@HiveType(typeId: 33)
class TrainingPlan extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String activityType; // run, cycling, etc.

  @HiveField(4)
  final String goal; // 5K, Marathon, General Fitness, etc.

  @HiveField(5)
  final int durationWeeks;

  @HiveField(6)
  final List<TrainingWeek> weeks;

  @HiveField(7)
  final DateTime startDate;

  @HiveField(8)
  final DateTime? endDate;

  @HiveField(9)
  final bool isActive;

  @HiveField(10)
  final int currentWeek;

  @HiveField(11)
  final String difficulty; // beginner, intermediate, advanced

  TrainingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.activityType,
    required this.goal,
    required this.durationWeeks,
    required this.weeks,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.currentWeek = 1,
    required this.difficulty,
  });

  double get completionPercentage {
    if (weeks.isEmpty) return 0;
    int totalWorkouts = 0;
    int completedWorkouts = 0;
    for (final week in weeks) {
      for (final workout in week.workouts) {
        totalWorkouts++;
        if (workout.isCompleted) completedWorkouts++;
      }
    }
    return totalWorkouts > 0 ? completedWorkouts / totalWorkouts * 100 : 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'activityType': activityType,
    'goal': goal,
    'durationWeeks': durationWeeks,
    'weeks': weeks.map((w) => w.toJson()).toList(),
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'isActive': isActive,
    'currentWeek': currentWeek,
    'difficulty': difficulty,
  };

  factory TrainingPlan.fromJson(Map<String, dynamic> json) => TrainingPlan(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    activityType: json['activityType'] ?? '',
    goal: json['goal'] ?? '',
    durationWeeks: json['durationWeeks'] ?? 0,
    weeks: (json['weeks'] as List<dynamic>?)
        ?.map((w) => TrainingWeek.fromJson(w))
        .toList() ?? [],
    startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    isActive: json['isActive'] ?? true,
    currentWeek: json['currentWeek'] ?? 1,
    difficulty: json['difficulty'] ?? 'beginner',
  );
}

@HiveType(typeId: 34)
class TrainingWeek extends HiveObject {
  @HiveField(0)
  final int weekNumber;

  @HiveField(1)
  final String focus; // Base building, Speed work, Recovery, etc.

  @HiveField(2)
  final List<PlannedWorkout> workouts;

  @HiveField(3)
  final String notes;

  TrainingWeek({
    required this.weekNumber,
    required this.focus,
    required this.workouts,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'weekNumber': weekNumber,
    'focus': focus,
    'workouts': workouts.map((w) => w.toJson()).toList(),
    'notes': notes,
  };

  factory TrainingWeek.fromJson(Map<String, dynamic> json) => TrainingWeek(
    weekNumber: json['weekNumber'] ?? 0,
    focus: json['focus'] ?? '',
    workouts: (json['workouts'] as List<dynamic>?)
        ?.map((w) => PlannedWorkout.fromJson(w))
        .toList() ?? [],
    notes: json['notes'] ?? '',
  );
}

@HiveType(typeId: 35)
class PlannedWorkout extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int dayOfWeek; // 1-7

  @HiveField(2)
  final String workoutType; // Easy Run, Tempo, Intervals, Long Run, Rest, etc.

  @HiveField(3)
  final String description;

  @HiveField(4)
  final int targetDurationMinutes;

  @HiveField(5)
  final double? targetDistanceKm;

  @HiveField(6)
  final String? targetPace; // e.g., "5:30-6:00"

  @HiveField(7)
  final String? targetHeartRateZone;

  @HiveField(8)
  final bool isCompleted;

  @HiveField(9)
  final String? completedActivityId;

  PlannedWorkout({
    required this.id,
    required this.dayOfWeek,
    required this.workoutType,
    required this.description,
    required this.targetDurationMinutes,
    this.targetDistanceKm,
    this.targetPace,
    this.targetHeartRateZone,
    this.isCompleted = false,
    this.completedActivityId,
  });

  String get dayName {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(dayOfWeek - 1) % 7];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dayOfWeek': dayOfWeek,
    'workoutType': workoutType,
    'description': description,
    'targetDurationMinutes': targetDurationMinutes,
    'targetDistanceKm': targetDistanceKm,
    'targetPace': targetPace,
    'targetHeartRateZone': targetHeartRateZone,
    'isCompleted': isCompleted,
    'completedActivityId': completedActivityId,
  };

  factory PlannedWorkout.fromJson(Map<String, dynamic> json) => PlannedWorkout(
    id: json['id'] ?? '',
    dayOfWeek: json['dayOfWeek'] ?? 1,
    workoutType: json['workoutType'] ?? '',
    description: json['description'] ?? '',
    targetDurationMinutes: json['targetDurationMinutes'] ?? 0,
    targetDistanceKm: json['targetDistanceKm']?.toDouble(),
    targetPace: json['targetPace'],
    targetHeartRateZone: json['targetHeartRateZone'],
    isCompleted: json['isCompleted'] ?? false,
    completedActivityId: json['completedActivityId'],
  );
}

/// Daily Readiness Score - Based on sleep, HRV, recovery
@HiveType(typeId: 36)
class ReadinessScore extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final int overallScore; // 0-100

  @HiveField(3)
  final int sleepScore;

  @HiveField(4)
  final int recoveryScore;

  @HiveField(5)
  final int activityBalance;

  @HiveField(6)
  final int hrvStatus; // Heart Rate Variability

  @HiveField(7)
  final int restingHr;

  @HiveField(8)
  final String recommendation;

  @HiveField(9)
  final String suggestedWorkoutIntensity; // rest, easy, moderate, hard

  ReadinessScore({
    required this.id,
    required this.date,
    required this.overallScore,
    required this.sleepScore,
    required this.recoveryScore,
    required this.activityBalance,
    required this.hrvStatus,
    required this.restingHr,
    required this.recommendation,
    required this.suggestedWorkoutIntensity,
  });

  String get scoreEmoji {
    if (overallScore >= 80) return '🟢';
    if (overallScore >= 60) return '🟡';
    if (overallScore >= 40) return '🟠';
    return '🔴';
  }

  String get scoreLabel {
    if (overallScore >= 80) return 'Excellent';
    if (overallScore >= 60) return 'Good';
    if (overallScore >= 40) return 'Fair';
    return 'Low';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'overallScore': overallScore,
    'sleepScore': sleepScore,
    'recoveryScore': recoveryScore,
    'activityBalance': activityBalance,
    'hrvStatus': hrvStatus,
    'restingHr': restingHr,
    'recommendation': recommendation,
    'suggestedWorkoutIntensity': suggestedWorkoutIntensity,
  };

  factory ReadinessScore.fromJson(Map<String, dynamic> json) => ReadinessScore(
    id: json['id'] ?? '',
    date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    overallScore: json['overallScore'] ?? 0,
    sleepScore: json['sleepScore'] ?? 0,
    recoveryScore: json['recoveryScore'] ?? 0,
    activityBalance: json['activityBalance'] ?? 0,
    hrvStatus: json['hrvStatus'] ?? 0,
    restingHr: json['restingHr'] ?? 0,
    recommendation: json['recommendation'] ?? '',
    suggestedWorkoutIntensity: json['suggestedWorkoutIntensity'] ?? 'moderate',
  );
}

/// Workout Analysis - Power, pace, splits
@HiveType(typeId: 37)
class WorkoutAnalysis extends HiveObject {
  @HiveField(0)
  final String activityId;

  @HiveField(1)
  final List<Split> splits;

  @HiveField(2)
  final double? averagePower;

  @HiveField(3)
  final double? normalizedPower;

  @HiveField(4)
  final double? intensityFactor;

  @HiveField(5)
  final int? trainingStressScore;

  @HiveField(6)
  final double? gradeAdjustedPace; // GAP for running

  @HiveField(7)
  final double? averageCadence;

  @HiveField(8)
  final double? verticalOscillation;

  @HiveField(9)
  final double? groundContactTime;

  @HiveField(10)
  final int? elevationGain;

  @HiveField(11)
  final int? elevationLoss;

  WorkoutAnalysis({
    required this.activityId,
    required this.splits,
    this.averagePower,
    this.normalizedPower,
    this.intensityFactor,
    this.trainingStressScore,
    this.gradeAdjustedPace,
    this.averageCadence,
    this.verticalOscillation,
    this.groundContactTime,
    this.elevationGain,
    this.elevationLoss,
  });

  String get formattedGAP {
    if (gradeAdjustedPace == null) return '-';
    final minutes = gradeAdjustedPace!.floor();
    final seconds = ((gradeAdjustedPace! - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  Map<String, dynamic> toJson() => {
    'activityId': activityId,
    'splits': splits.map((s) => s.toJson()).toList(),
    'averagePower': averagePower,
    'normalizedPower': normalizedPower,
    'intensityFactor': intensityFactor,
    'trainingStressScore': trainingStressScore,
    'gradeAdjustedPace': gradeAdjustedPace,
    'averageCadence': averageCadence,
    'verticalOscillation': verticalOscillation,
    'groundContactTime': groundContactTime,
    'elevationGain': elevationGain,
    'elevationLoss': elevationLoss,
  };

  factory WorkoutAnalysis.fromJson(Map<String, dynamic> json) => WorkoutAnalysis(
    activityId: json['activityId'] ?? '',
    splits: (json['splits'] as List<dynamic>?)
        ?.map((s) => Split.fromJson(s))
        .toList() ?? [],
    averagePower: json['averagePower']?.toDouble(),
    normalizedPower: json['normalizedPower']?.toDouble(),
    intensityFactor: json['intensityFactor']?.toDouble(),
    trainingStressScore: json['trainingStressScore'],
    gradeAdjustedPace: json['gradeAdjustedPace']?.toDouble(),
    averageCadence: json['averageCadence']?.toDouble(),
    verticalOscillation: json['verticalOscillation']?.toDouble(),
    groundContactTime: json['groundContactTime']?.toDouble(),
    elevationGain: json['elevationGain'],
    elevationLoss: json['elevationLoss'],
  );
}

@HiveType(typeId: 38)
class Split extends HiveObject {
  @HiveField(0)
  final int splitNumber;

  @HiveField(1)
  final double distanceKm;

  @HiveField(2)
  final int durationSeconds;

  @HiveField(3)
  final double pace; // min/km

  @HiveField(4)
  final int? avgHeartRate;

  @HiveField(5)
  final int? elevationChange;

  @HiveField(6)
  final double? power;

  Split({
    required this.splitNumber,
    required this.distanceKm,
    required this.durationSeconds,
    required this.pace,
    this.avgHeartRate,
    this.elevationChange,
    this.power,
  });

  String get formattedPace {
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'splitNumber': splitNumber,
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
    'pace': pace,
    'avgHeartRate': avgHeartRate,
    'elevationChange': elevationChange,
    'power': power,
  };

  factory Split.fromJson(Map<String, dynamic> json) => Split(
    splitNumber: json['splitNumber'] ?? 0,
    distanceKm: (json['distanceKm'] ?? 0).toDouble(),
    durationSeconds: json['durationSeconds'] ?? 0,
    pace: (json['pace'] ?? 0).toDouble(),
    avgHeartRate: json['avgHeartRate'],
    elevationChange: json['elevationChange'],
    power: json['power']?.toDouble(),
  );
}

/// Training Recommendation
class TrainingRecommendation {
  final String id;
  final String title;
  final String description;
  final String workoutType;
  final int suggestedDurationMinutes;
  final String intensity;
  final String reason;
  final DateTime createdAt;

  TrainingRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.workoutType,
    required this.suggestedDurationMinutes,
    required this.intensity,
    required this.reason,
    required this.createdAt,
  });

  String get intensityEmoji {
    switch (intensity.toLowerCase()) {
      case 'rest': return '😴';
      case 'easy': return '🚶';
      case 'moderate': return '🏃';
      case 'hard': return '🔥';
      case 'very hard': return '⚡';
      default: return '💪';
    }
  }
}
