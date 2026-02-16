import 'focus_plant.dart';
import 'ambient_sound.dart';

enum FocusActivityType {
  work,
  study,
  reading,
  meditation,
  creative,
  exercise,
  coding,
  writing,
  other,
}

extension FocusActivityTypeExtension on FocusActivityType {
  String get name {
    switch (this) {
      case FocusActivityType.work:
        return 'Work';
      case FocusActivityType.study:
        return 'Study';
      case FocusActivityType.reading:
        return 'Reading';
      case FocusActivityType.meditation:
        return 'Meditation';
      case FocusActivityType.creative:
        return 'Creative';
      case FocusActivityType.exercise:
        return 'Exercise';
      case FocusActivityType.coding:
        return 'Coding';
      case FocusActivityType.writing:
        return 'Writing';
      case FocusActivityType.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case FocusActivityType.work:
        return '💼';
      case FocusActivityType.study:
        return '📚';
      case FocusActivityType.reading:
        return '📖';
      case FocusActivityType.meditation:
        return '🧘';
      case FocusActivityType.creative:
        return '🎨';
      case FocusActivityType.exercise:
        return '💪';
      case FocusActivityType.coding:
        return '💻';
      case FocusActivityType.writing:
        return '✍️';
      case FocusActivityType.other:
        return '⭐';
    }
  }
}

class FocusSession {
  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int targetMinutes;
  final int actualMinutes;
  final bool wasCompleted;
  final bool wasAbandoned;
  final FocusActivityType activityType;
  final PlantType plantType;
  final AmbientSoundType? soundUsed;
  final String? note;

  FocusSession({
    required this.id,
    required this.startedAt,
    this.completedAt,
    required this.targetMinutes,
    this.actualMinutes = 0,
    this.wasCompleted = false,
    this.wasAbandoned = false,
    required this.activityType,
    required this.plantType,
    this.soundUsed,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'targetMinutes': targetMinutes,
        'actualMinutes': actualMinutes,
        'wasCompleted': wasCompleted,
        'wasAbandoned': wasAbandoned,
        'activityType': activityType.index,
        'plantType': plantType.index,
        'soundUsed': soundUsed?.index,
        'note': note,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] ?? '',
        startedAt: DateTime.parse(json['startedAt']),
        completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
        targetMinutes: json['targetMinutes'] ?? 0,
        actualMinutes: json['actualMinutes'] ?? 0,
        wasCompleted: json['wasCompleted'] ?? false,
        wasAbandoned: json['wasAbandoned'] ?? false,
        activityType: FocusActivityType.values[json['activityType'] ?? 0],
        plantType: PlantType.values[json['plantType'] ?? 0],
        soundUsed: json['soundUsed'] != null ? AmbientSoundType.values[json['soundUsed']] : null,
        note: json['note'],
      );

  FocusSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? completedAt,
    int? targetMinutes,
    int? actualMinutes,
    bool? wasCompleted,
    bool? wasAbandoned,
    FocusActivityType? activityType,
    PlantType? plantType,
    AmbientSoundType? soundUsed,
    String? note,
  }) {
    return FocusSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      wasCompleted: wasCompleted ?? this.wasCompleted,
      wasAbandoned: wasAbandoned ?? this.wasAbandoned,
      activityType: activityType ?? this.activityType,
      plantType: plantType ?? this.plantType,
      soundUsed: soundUsed ?? this.soundUsed,
      note: note ?? this.note,
    );
  }
}

class FocusStats {
  final int totalMinutes;
  final int totalSessions;
  final int completedSessions;
  final int abandonedSessions;
  final int currentStreak;
  final int longestStreak;
  final int totalPlants;
  final int deadPlants;
  final Map<FocusActivityType, int> minutesByActivity;
  final Map<PlantType, int> plantCounts;
  final DateTime? lastSessionDate;

  const FocusStats({
    this.totalMinutes = 0,
    this.totalSessions = 0,
    this.completedSessions = 0,
    this.abandonedSessions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPlants = 0,
    this.deadPlants = 0,
    this.minutesByActivity = const {},
    this.plantCounts = const {},
    this.lastSessionDate,
  });

  int get totalHours => totalMinutes ~/ 60;
  double get completionRate => totalSessions > 0 ? completedSessions / totalSessions : 0.0;
  int get alivePlants => totalPlants - deadPlants;

  Map<String, dynamic> toJson() => {
        'totalMinutes': totalMinutes,
        'totalSessions': totalSessions,
        'completedSessions': completedSessions,
        'abandonedSessions': abandonedSessions,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalPlants': totalPlants,
        'deadPlants': deadPlants,
        'minutesByActivity': minutesByActivity.map((k, v) => MapEntry(k.index.toString(), v)),
        'plantCounts': plantCounts.map((k, v) => MapEntry(k.index.toString(), v)),
        'lastSessionDate': lastSessionDate?.toIso8601String(),
      };

  factory FocusStats.fromJson(Map<String, dynamic> json) {
    Map<FocusActivityType, int> minutesByActivity = {};
    if (json['minutesByActivity'] != null) {
      (json['minutesByActivity'] as Map).forEach((key, value) {
        minutesByActivity[FocusActivityType.values[int.parse(key)]] = value;
      });
    }

    Map<PlantType, int> plantCounts = {};
    if (json['plantCounts'] != null) {
      (json['plantCounts'] as Map).forEach((key, value) {
        plantCounts[PlantType.values[int.parse(key)]] = value;
      });
    }

    return FocusStats(
      totalMinutes: json['totalMinutes'] ?? 0,
      totalSessions: json['totalSessions'] ?? 0,
      completedSessions: json['completedSessions'] ?? 0,
      abandonedSessions: json['abandonedSessions'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      totalPlants: json['totalPlants'] ?? 0,
      deadPlants: json['deadPlants'] ?? 0,
      minutesByActivity: minutesByActivity,
      plantCounts: plantCounts,
      lastSessionDate: json['lastSessionDate'] != null ? DateTime.parse(json['lastSessionDate']) : null,
    );
  }

  FocusStats copyWith({
    int? totalMinutes,
    int? totalSessions,
    int? completedSessions,
    int? abandonedSessions,
    int? currentStreak,
    int? longestStreak,
    int? totalPlants,
    int? deadPlants,
    Map<FocusActivityType, int>? minutesByActivity,
    Map<PlantType, int>? plantCounts,
    DateTime? lastSessionDate,
  }) {
    return FocusStats(
      totalMinutes: totalMinutes ?? this.totalMinutes,
      totalSessions: totalSessions ?? this.totalSessions,
      completedSessions: completedSessions ?? this.completedSessions,
      abandonedSessions: abandonedSessions ?? this.abandonedSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalPlants: totalPlants ?? this.totalPlants,
      deadPlants: deadPlants ?? this.deadPlants,
      minutesByActivity: minutesByActivity ?? this.minutesByActivity,
      plantCounts: plantCounts ?? this.plantCounts,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
    );
  }
}
