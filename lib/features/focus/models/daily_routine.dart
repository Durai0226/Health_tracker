import 'meditation_activity.dart';

/// Represents a scheduled activity within a daily routine
class RoutineActivity {
  final String id;
  final WellnessActivityType activityType;
  final int hour;
  final int minute;
  final int durationMinutes;
  final bool isCompleted;
  final DateTime? completedAt;

  const RoutineActivity({
    required this.id,
    required this.activityType,
    required this.hour,
    required this.minute,
    required this.durationMinutes,
    this.isCompleted = false,
    this.completedAt,
  });

  String get timeString {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get timeDisplay {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$displayHour:$m $period';
  }

  DateTime getScheduledTime(DateTime date) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  RoutineActivity copyWith({
    String? id,
    WellnessActivityType? activityType,
    int? hour,
    int? minute,
    int? durationMinutes,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return RoutineActivity(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityType': activityType.id,
    'hour': hour,
    'minute': minute,
    'durationMinutes': durationMinutes,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory RoutineActivity.fromJson(Map<String, dynamic> json) {
    return RoutineActivity(
      id: json['id'] as String,
      activityType: WellnessActivityTypeExtension.fromString(json['activityType'] as String),
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      durationMinutes: json['durationMinutes'] as int,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  factory RoutineActivity.create({
    required WellnessActivityType activityType,
    required int hour,
    required int minute,
    int? durationMinutes,
  }) {
    final now = DateTime.now();
    return RoutineActivity(
      id: 'routine_activity_${now.millisecondsSinceEpoch}',
      activityType: activityType,
      hour: hour,
      minute: minute,
      durationMinutes: durationMinutes ?? activityType.defaultDuration,
    );
  }
}

/// Model representing a daily wellness routine
class DailyRoutine {
  final String id;
  final String name;
  final String? description;
  final List<RoutineActivity> activities;
  final List<int> activeDays;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyRoutine({
    required this.id,
    required this.name,
    this.description,
    required this.activities,
    this.activeDays = const [1, 2, 3, 4, 5, 6, 7],
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalMinutes => activities.fold(0, (sum, a) => sum + a.durationMinutes);
  
  int get activityCount => activities.length;
  
  int get completedCount => activities.where((a) => a.isCompleted).length;
  
  double get completionRate => activityCount > 0 ? completedCount / activityCount : 0.0;

  bool isActiveOn(int weekday) => activeDays.contains(weekday);

  List<RoutineActivity> get sortedActivities {
    final sorted = List<RoutineActivity>.from(activities);
    sorted.sort((a, b) {
      final aTime = a.hour * 60 + a.minute;
      final bTime = b.hour * 60 + b.minute;
      return aTime.compareTo(bTime);
    });
    return sorted;
  }

  RoutineActivity? getNextActivity(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final sorted = sortedActivities;
    
    for (final activity in sorted) {
      final activityMinutes = activity.hour * 60 + activity.minute;
      if (activityMinutes > currentMinutes && !activity.isCompleted) {
        return activity;
      }
    }
    return null;
  }

  RoutineActivity? getCurrentActivity(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    
    for (final activity in activities) {
      final startMinutes = activity.hour * 60 + activity.minute;
      final endMinutes = startMinutes + activity.durationMinutes;
      
      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        return activity;
      }
    }
    return null;
  }

  DailyRoutine copyWith({
    String? id,
    String? name,
    String? description,
    List<RoutineActivity>? activities,
    List<int>? activeDays,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      activities: activities ?? this.activities,
      activeDays: activeDays ?? this.activeDays,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  DailyRoutine markActivityCompleted(String activityId) {
    final updatedActivities = activities.map((a) {
      if (a.id == activityId) {
        return a.copyWith(isCompleted: true, completedAt: DateTime.now());
      }
      return a;
    }).toList();
    
    return copyWith(
      activities: updatedActivities,
      updatedAt: DateTime.now(),
    );
  }

  DailyRoutine resetCompletions() {
    final resetActivities = activities.map((a) {
      return a.copyWith(isCompleted: false, completedAt: null);
    }).toList();
    
    return copyWith(
      activities: resetActivities,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'activities': activities.map((a) => a.toJson()).toList(),
    'activeDays': activeDays,
    'isEnabled': isEnabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DailyRoutine.fromJson(Map<String, dynamic> json) {
    return DailyRoutine(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      activities: (json['activities'] as List)
          .map((a) => RoutineActivity.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
      activeDays: List<int>.from(json['activeDays'] ?? [1, 2, 3, 4, 5, 6, 7]),
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  factory DailyRoutine.create({
    required String name,
    String? description,
    List<RoutineActivity>? activities,
    List<int>? activeDays,
  }) {
    final now = DateTime.now();
    return DailyRoutine(
      id: 'routine_${now.millisecondsSinceEpoch}',
      name: name,
      description: description,
      activities: activities ?? [],
      activeDays: activeDays ?? [1, 2, 3, 4, 5, 6, 7],
      createdAt: now,
      updatedAt: now,
    );
  }

  static DailyRoutine createMorningRoutine() {
    return DailyRoutine.create(
      name: 'Morning Wellness',
      description: 'Start your day with mindfulness',
      activities: [
        RoutineActivity.create(
          activityType: WellnessActivityType.breathing,
          hour: 6,
          minute: 30,
          durationMinutes: 5,
        ),
        RoutineActivity.create(
          activityType: WellnessActivityType.meditation,
          hour: 6,
          minute: 40,
          durationMinutes: 10,
        ),
        RoutineActivity.create(
          activityType: WellnessActivityType.yoga,
          hour: 7,
          minute: 0,
          durationMinutes: 15,
        ),
      ],
    );
  }

  static DailyRoutine createEveningRoutine() {
    return DailyRoutine.create(
      name: 'Evening Wind Down',
      description: 'Relax and prepare for restful sleep',
      activities: [
        RoutineActivity.create(
          activityType: WellnessActivityType.journaling,
          hour: 20,
          minute: 0,
          durationMinutes: 10,
        ),
        RoutineActivity.create(
          activityType: WellnessActivityType.breathing,
          hour: 20,
          minute: 15,
          durationMinutes: 5,
        ),
        RoutineActivity.create(
          activityType: WellnessActivityType.meditation,
          hour: 20,
          minute: 25,
          durationMinutes: 15,
        ),
      ],
    );
  }

  static DailyRoutine createWorkdayRoutine() {
    return DailyRoutine.create(
      name: 'Workday Focus',
      description: 'Stay productive and balanced',
      activeDays: [1, 2, 3, 4, 5],
      activities: [
        RoutineActivity.create(
          activityType: WellnessActivityType.meditation,
          hour: 7,
          minute: 0,
          durationMinutes: 10,
        ),
        RoutineActivity.create(
          activityType: WellnessActivityType.focus,
          hour: 9,
          minute: 0,
          durationMinutes: 25,
        ),
        RoutineActivity.create(
          activityType: WellnessActivityType.breathing,
          hour: 12,
          minute: 0,
          durationMinutes: 5,
        ),
        RoutineActivity.create(
          activityType: WellnessActivityType.walking,
          hour: 15,
          minute: 0,
          durationMinutes: 15,
        ),
        RoutineActivity.create(
          activityType: WellnessActivityType.focus,
          hour: 16,
          minute: 0,
          durationMinutes: 25,
        ),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRoutine &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model for tracking daily routine progress
class DailyRoutineProgress {
  final String routineId;
  final DateTime date;
  final List<String> completedActivityIds;
  final int totalActivities;
  final int totalMinutesCompleted;
  final DateTime? lastUpdated;

  const DailyRoutineProgress({
    required this.routineId,
    required this.date,
    this.completedActivityIds = const [],
    this.totalActivities = 0,
    this.totalMinutesCompleted = 0,
    this.lastUpdated,
  });

  int get completedCount => completedActivityIds.length;
  
  double get completionRate => 
      totalActivities > 0 ? completedCount / totalActivities : 0.0;
  
  bool get isFullyCompleted => completedCount >= totalActivities;

  String get dateKey => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DailyRoutineProgress copyWith({
    String? routineId,
    DateTime? date,
    List<String>? completedActivityIds,
    int? totalActivities,
    int? totalMinutesCompleted,
    DateTime? lastUpdated,
  }) {
    return DailyRoutineProgress(
      routineId: routineId ?? this.routineId,
      date: date ?? this.date,
      completedActivityIds: completedActivityIds ?? this.completedActivityIds,
      totalActivities: totalActivities ?? this.totalActivities,
      totalMinutesCompleted: totalMinutesCompleted ?? this.totalMinutesCompleted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
    'routineId': routineId,
    'date': date.toIso8601String(),
    'completedActivityIds': completedActivityIds,
    'totalActivities': totalActivities,
    'totalMinutesCompleted': totalMinutesCompleted,
    'lastUpdated': lastUpdated?.toIso8601String(),
  };

  factory DailyRoutineProgress.fromJson(Map<String, dynamic> json) {
    return DailyRoutineProgress(
      routineId: json['routineId'] as String,
      date: DateTime.parse(json['date'] as String),
      completedActivityIds: List<String>.from(json['completedActivityIds'] ?? []),
      totalActivities: json['totalActivities'] as int? ?? 0,
      totalMinutesCompleted: json['totalMinutesCompleted'] as int? ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  factory DailyRoutineProgress.create({
    required DailyRoutine routine,
    required DateTime date,
  }) {
    return DailyRoutineProgress(
      routineId: routine.id,
      date: DateTime(date.year, date.month, date.day),
      totalActivities: routine.activityCount,
      lastUpdated: DateTime.now(),
    );
  }
}
