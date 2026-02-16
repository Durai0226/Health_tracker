import 'package:hive/hive.dart';

part 'sleep_models.g.dart';

/// Sleep Session - Individual sleep record
@HiveType(typeId: 50)
class SleepSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime bedTime;

  @HiveField(2)
  final DateTime wakeTime;

  @HiveField(3)
  final int totalMinutes;

  @HiveField(4)
  final int deepSleepMinutes;

  @HiveField(5)
  final int lightSleepMinutes;

  @HiveField(6)
  final int remSleepMinutes;

  @HiveField(7)
  final int awakeMinutes;

  @HiveField(8)
  final int sleepScore; // 0-100

  @HiveField(9)
  final int? avgHeartRate;

  @HiveField(10)
  final int? lowestHeartRate;

  @HiveField(11)
  final int? respiratoryRate;

  @HiveField(12)
  final double? oxygenSaturation;

  @HiveField(13)
  final int? sleepLatencyMinutes; // Time to fall asleep

  @HiveField(14)
  final int awakenings;

  @HiveField(15)
  final String? notes;

  @HiveField(16)
  final List<String>? factors; // caffeine, alcohol, stress, exercise

  SleepSession({
    required this.id,
    required this.bedTime,
    required this.wakeTime,
    required this.totalMinutes,
    required this.deepSleepMinutes,
    required this.lightSleepMinutes,
    required this.remSleepMinutes,
    required this.awakeMinutes,
    required this.sleepScore,
    this.avgHeartRate,
    this.lowestHeartRate,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.sleepLatencyMinutes,
    this.awakenings = 0,
    this.notes,
    this.factors,
  });

  String get formattedDuration {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return '${hours}h ${mins}m';
  }

  double get sleepEfficiency {
    final totalBedTime = wakeTime.difference(bedTime).inMinutes;
    return totalBedTime > 0 ? (totalMinutes / totalBedTime * 100) : 0;
  }

  String get scoreLabel {
    if (sleepScore >= 85) return 'Excellent';
    if (sleepScore >= 70) return 'Good';
    if (sleepScore >= 50) return 'Fair';
    return 'Poor';
  }

  String get scoreEmoji {
    if (sleepScore >= 85) return '😴';
    if (sleepScore >= 70) return '🌙';
    if (sleepScore >= 50) return '😐';
    return '😩';
  }

  String get scoreColor {
    if (sleepScore >= 85) return '#10B981';
    if (sleepScore >= 70) return '#3B82F6';
    if (sleepScore >= 50) return '#F59E0B';
    return '#EF4444';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bedTime': bedTime.toIso8601String(),
    'wakeTime': wakeTime.toIso8601String(),
    'totalMinutes': totalMinutes,
    'deepSleepMinutes': deepSleepMinutes,
    'lightSleepMinutes': lightSleepMinutes,
    'remSleepMinutes': remSleepMinutes,
    'awakeMinutes': awakeMinutes,
    'sleepScore': sleepScore,
    'avgHeartRate': avgHeartRate,
    'lowestHeartRate': lowestHeartRate,
    'respiratoryRate': respiratoryRate,
    'oxygenSaturation': oxygenSaturation,
    'sleepLatencyMinutes': sleepLatencyMinutes,
    'awakenings': awakenings,
    'notes': notes,
    'factors': factors,
  };

  factory SleepSession.fromJson(Map<String, dynamic> json) => SleepSession(
    id: json['id'] ?? '',
    bedTime: DateTime.parse(json['bedTime'] ?? DateTime.now().toIso8601String()),
    wakeTime: DateTime.parse(json['wakeTime'] ?? DateTime.now().toIso8601String()),
    totalMinutes: json['totalMinutes'] ?? 0,
    deepSleepMinutes: json['deepSleepMinutes'] ?? 0,
    lightSleepMinutes: json['lightSleepMinutes'] ?? 0,
    remSleepMinutes: json['remSleepMinutes'] ?? 0,
    awakeMinutes: json['awakeMinutes'] ?? 0,
    sleepScore: json['sleepScore'] ?? 0,
    avgHeartRate: json['avgHeartRate'],
    lowestHeartRate: json['lowestHeartRate'],
    respiratoryRate: json['respiratoryRate'],
    oxygenSaturation: json['oxygenSaturation']?.toDouble(),
    sleepLatencyMinutes: json['sleepLatencyMinutes'],
    awakenings: json['awakenings'] ?? 0,
    notes: json['notes'],
    factors: (json['factors'] as List<dynamic>?)?.cast<String>(),
  );
}

/// Sleep Goal - Target sleep settings
@HiveType(typeId: 51)
class SleepGoal extends HiveObject {
  @HiveField(0)
  final int targetHours;

  @HiveField(1)
  final int targetMinutes;

  @HiveField(2)
  final TimeOfDayModel targetBedTime;

  @HiveField(3)
  final TimeOfDayModel targetWakeTime;

  @HiveField(4)
  final bool smartAlarmEnabled;

  @HiveField(5)
  final int smartAlarmWindowMinutes;

  @HiveField(6)
  final bool bedtimeReminderEnabled;

  @HiveField(7)
  final int reminderMinutesBefore;

  SleepGoal({
    this.targetHours = 8,
    this.targetMinutes = 0,
    required this.targetBedTime,
    required this.targetWakeTime,
    this.smartAlarmEnabled = false,
    this.smartAlarmWindowMinutes = 30,
    this.bedtimeReminderEnabled = true,
    this.reminderMinutesBefore = 30,
  });

  int get targetTotalMinutes => targetHours * 60 + targetMinutes;

  Map<String, dynamic> toJson() => {
    'targetHours': targetHours,
    'targetMinutes': targetMinutes,
    'targetBedTime': targetBedTime.toJson(),
    'targetWakeTime': targetWakeTime.toJson(),
    'smartAlarmEnabled': smartAlarmEnabled,
    'smartAlarmWindowMinutes': smartAlarmWindowMinutes,
    'bedtimeReminderEnabled': bedtimeReminderEnabled,
    'reminderMinutesBefore': reminderMinutesBefore,
  };

  factory SleepGoal.fromJson(Map<String, dynamic> json) => SleepGoal(
    targetHours: json['targetHours'] ?? 8,
    targetMinutes: json['targetMinutes'] ?? 0,
    targetBedTime: TimeOfDayModel.fromJson(json['targetBedTime'] ?? {'hour': 22, 'minute': 30}),
    targetWakeTime: TimeOfDayModel.fromJson(json['targetWakeTime'] ?? {'hour': 6, 'minute': 30}),
    smartAlarmEnabled: json['smartAlarmEnabled'] ?? false,
    smartAlarmWindowMinutes: json['smartAlarmWindowMinutes'] ?? 30,
    bedtimeReminderEnabled: json['bedtimeReminderEnabled'] ?? true,
    reminderMinutesBefore: json['reminderMinutesBefore'] ?? 30,
  );
}

@HiveType(typeId: 52)
class TimeOfDayModel extends HiveObject {
  @HiveField(0)
  final int hour;

  @HiveField(1)
  final int minute;

  TimeOfDayModel({required this.hour, required this.minute});

  String get formatted {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory TimeOfDayModel.fromJson(Map<String, dynamic> json) => TimeOfDayModel(
    hour: json['hour'] ?? 0,
    minute: json['minute'] ?? 0,
  );
}

/// Sleep Insights - Guided improvement recommendations
@HiveType(typeId: 53)
class SleepInsight extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String category; // consistency, duration, quality, environment

  @HiveField(4)
  final String priority; // high, medium, low

  @HiveField(5)
  final List<String> tips;

  @HiveField(6)
  final DateTime generatedAt;

  @HiveField(7)
  final bool isRead;

  SleepInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.tips,
    required this.generatedAt,
    this.isRead = false,
  });

  String get categoryEmoji {
    switch (category) {
      case 'consistency': return '🕐';
      case 'duration': return '⏱️';
      case 'quality': return '✨';
      case 'environment': return '🌙';
      default: return '💡';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority,
    'tips': tips,
    'generatedAt': generatedAt.toIso8601String(),
    'isRead': isRead,
  };

  factory SleepInsight.fromJson(Map<String, dynamic> json) => SleepInsight(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    category: json['category'] ?? '',
    priority: json['priority'] ?? 'medium',
    tips: List<String>.from(json['tips'] ?? []),
    generatedAt: DateTime.parse(json['generatedAt'] ?? DateTime.now().toIso8601String()),
    isRead: json['isRead'] ?? false,
  );
}

/// Wellness Report - Health trends summary
@HiveType(typeId: 54)
class WellnessReport extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startDate;

  @HiveField(2)
  final DateTime endDate;

  @HiveField(3)
  final String reportType; // weekly, monthly

  @HiveField(4)
  final int avgSleepScore;

  @HiveField(5)
  final int avgSleepDuration;

  @HiveField(6)
  final int avgRestingHr;

  @HiveField(7)
  final int avgStressLevel;

  @HiveField(8)
  final int avgActivityMinutes;

  @HiveField(9)
  final int avgSteps;

  @HiveField(10)
  final double avgHydration; // percentage of goal

  @HiveField(11)
  final Map<String, int> trendsComparedToPrevious;

  @HiveField(12)
  final List<String> highlights;

  @HiveField(13)
  final List<String> areasToImprove;

  @HiveField(14)
  final int overallWellnessScore;

  WellnessReport({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.reportType,
    required this.avgSleepScore,
    required this.avgSleepDuration,
    required this.avgRestingHr,
    required this.avgStressLevel,
    required this.avgActivityMinutes,
    required this.avgSteps,
    required this.avgHydration,
    required this.trendsComparedToPrevious,
    required this.highlights,
    required this.areasToImprove,
    required this.overallWellnessScore,
  });

  String get scoreEmoji {
    if (overallWellnessScore >= 80) return '🌟';
    if (overallWellnessScore >= 60) return '💪';
    if (overallWellnessScore >= 40) return '📈';
    return '🎯';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'reportType': reportType,
    'avgSleepScore': avgSleepScore,
    'avgSleepDuration': avgSleepDuration,
    'avgRestingHr': avgRestingHr,
    'avgStressLevel': avgStressLevel,
    'avgActivityMinutes': avgActivityMinutes,
    'avgSteps': avgSteps,
    'avgHydration': avgHydration,
    'trendsComparedToPrevious': trendsComparedToPrevious,
    'highlights': highlights,
    'areasToImprove': areasToImprove,
    'overallWellnessScore': overallWellnessScore,
  };

  factory WellnessReport.fromJson(Map<String, dynamic> json) => WellnessReport(
    id: json['id'] ?? '',
    startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
    endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
    reportType: json['reportType'] ?? 'weekly',
    avgSleepScore: json['avgSleepScore'] ?? 0,
    avgSleepDuration: json['avgSleepDuration'] ?? 0,
    avgRestingHr: json['avgRestingHr'] ?? 0,
    avgStressLevel: json['avgStressLevel'] ?? 0,
    avgActivityMinutes: json['avgActivityMinutes'] ?? 0,
    avgSteps: json['avgSteps'] ?? 0,
    avgHydration: (json['avgHydration'] ?? 0).toDouble(),
    trendsComparedToPrevious: Map<String, int>.from(json['trendsComparedToPrevious'] ?? {}),
    highlights: List<String>.from(json['highlights'] ?? []),
    areasToImprove: List<String>.from(json['areasToImprove'] ?? []),
    overallWellnessScore: json['overallWellnessScore'] ?? 0,
  );
}

/// Sleep Stage for detailed tracking
enum SleepStage { awake, light, deep, rem }

/// Sleep Summary - Aggregated stats
class SleepSummary {
  final int averageSleepScore;
  final int averageDurationMinutes;
  final int averageDeepSleep;
  final int averageRemSleep;
  final int consistencyScore;
  final int nightsLogged;
  final String bestNight;
  final String worstNight;
  final List<SleepSession> sessions;

  SleepSummary({
    required this.averageSleepScore,
    required this.averageDurationMinutes,
    required this.averageDeepSleep,
    required this.averageRemSleep,
    required this.consistencyScore,
    required this.nightsLogged,
    required this.bestNight,
    required this.worstNight,
    required this.sessions,
  });

  String get averageDurationFormatted {
    final hours = averageDurationMinutes ~/ 60;
    final mins = averageDurationMinutes % 60;
    return '${hours}h ${mins}m';
  }
}
