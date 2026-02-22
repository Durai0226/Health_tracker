import 'package:hive/hive.dart';

part 'study_analytics_model.g.dart';

@HiveType(typeId: 270)
class DailyStudyStats {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final int totalMinutes;

  @HiveField(2)
  final int sessionCount;

  @HiveField(3)
  final int pomodoroCount;

  @HiveField(4)
  final Map<String, int> minutesBySubject;

  @HiveField(5)
  final double averageQuality;

  @HiveField(6)
  final int goalMinutes;

  DailyStudyStats({
    required this.date,
    this.totalMinutes = 0,
    this.sessionCount = 0,
    this.pomodoroCount = 0,
    this.minutesBySubject = const {},
    this.averageQuality = 0.0,
    this.goalMinutes = 120,
  });

  double get goalProgress {
    if (goalMinutes <= 0) return 0.0;
    return (totalMinutes / goalMinutes).clamp(0.0, 1.0);
  }

  bool get goalAchieved => totalMinutes >= goalMinutes;

  double get studyHours => totalMinutes / 60.0;

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalMinutes': totalMinutes,
      'sessionCount': sessionCount,
      'pomodoroCount': pomodoroCount,
      'minutesBySubject': minutesBySubject,
      'averageQuality': averageQuality,
      'goalMinutes': goalMinutes,
    };
  }

  factory DailyStudyStats.fromJson(Map<String, dynamic> json) {
    return DailyStudyStats(
      date: DateTime.parse(json['date']),
      totalMinutes: json['totalMinutes'] ?? 0,
      sessionCount: json['sessionCount'] ?? 0,
      pomodoroCount: json['pomodoroCount'] ?? 0,
      minutesBySubject: Map<String, int>.from(json['minutesBySubject'] ?? {}),
      averageQuality: (json['averageQuality'] ?? 0.0).toDouble(),
      goalMinutes: json['goalMinutes'] ?? 120,
    );
  }

  DailyStudyStats copyWith({
    DateTime? date,
    int? totalMinutes,
    int? sessionCount,
    int? pomodoroCount,
    Map<String, int>? minutesBySubject,
    double? averageQuality,
    int? goalMinutes,
  }) {
    return DailyStudyStats(
      date: date ?? this.date,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      sessionCount: sessionCount ?? this.sessionCount,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      minutesBySubject: minutesBySubject ?? this.minutesBySubject,
      averageQuality: averageQuality ?? this.averageQuality,
      goalMinutes: goalMinutes ?? this.goalMinutes,
    );
  }
}

@HiveType(typeId: 271)
class WeeklyStudyStats {
  @HiveField(0)
  final DateTime weekStart;

  @HiveField(1)
  final int totalMinutes;

  @HiveField(2)
  final int totalSessions;

  @HiveField(3)
  final int daysStudied;

  @HiveField(4)
  final int goalDays;

  @HiveField(5)
  final Map<String, int> minutesBySubject;

  @HiveField(6)
  final List<DailyStudyStats> dailyStats;

  @HiveField(7)
  final int topicsCompleted;

  @HiveField(8)
  final double averageSessionLength;

  WeeklyStudyStats({
    required this.weekStart,
    this.totalMinutes = 0,
    this.totalSessions = 0,
    this.daysStudied = 0,
    this.goalDays = 5,
    this.minutesBySubject = const {},
    this.dailyStats = const [],
    this.topicsCompleted = 0,
    this.averageSessionLength = 0.0,
  });

  double get studyHours => totalMinutes / 60.0;

  double get consistencyScore {
    if (goalDays <= 0) return 0.0;
    return (daysStudied / goalDays).clamp(0.0, 1.0);
  }

  int get bestDay {
    if (dailyStats.isEmpty) return 0;
    int maxMinutes = 0;
    for (final stat in dailyStats) {
      if (stat.totalMinutes > maxMinutes) {
        maxMinutes = stat.totalMinutes;
      }
    }
    return maxMinutes;
  }

  Map<String, dynamic> toJson() {
    return {
      'weekStart': weekStart.toIso8601String(),
      'totalMinutes': totalMinutes,
      'totalSessions': totalSessions,
      'daysStudied': daysStudied,
      'goalDays': goalDays,
      'minutesBySubject': minutesBySubject,
      'dailyStats': dailyStats.map((d) => d.toJson()).toList(),
      'topicsCompleted': topicsCompleted,
      'averageSessionLength': averageSessionLength,
    };
  }

  factory WeeklyStudyStats.fromJson(Map<String, dynamic> json) {
    return WeeklyStudyStats(
      weekStart: DateTime.parse(json['weekStart']),
      totalMinutes: json['totalMinutes'] ?? 0,
      totalSessions: json['totalSessions'] ?? 0,
      daysStudied: json['daysStudied'] ?? 0,
      goalDays: json['goalDays'] ?? 5,
      minutesBySubject: Map<String, int>.from(json['minutesBySubject'] ?? {}),
      dailyStats: (json['dailyStats'] as List<dynamic>?)
              ?.map(
                  (d) => DailyStudyStats.fromJson(Map<String, dynamic>.from(d)))
              .toList() ??
          [],
      topicsCompleted: json['topicsCompleted'] ?? 0,
      averageSessionLength: (json['averageSessionLength'] ?? 0.0).toDouble(),
    );
  }

  WeeklyStudyStats copyWith({
    DateTime? weekStart,
    int? totalMinutes,
    int? totalSessions,
    int? daysStudied,
    int? goalDays,
    Map<String, int>? minutesBySubject,
    List<DailyStudyStats>? dailyStats,
    int? topicsCompleted,
    double? averageSessionLength,
  }) {
    return WeeklyStudyStats(
      weekStart: weekStart ?? this.weekStart,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      totalSessions: totalSessions ?? this.totalSessions,
      daysStudied: daysStudied ?? this.daysStudied,
      goalDays: goalDays ?? this.goalDays,
      minutesBySubject: minutesBySubject ?? this.minutesBySubject,
      dailyStats: dailyStats ?? this.dailyStats,
      topicsCompleted: topicsCompleted ?? this.topicsCompleted,
      averageSessionLength: averageSessionLength ?? this.averageSessionLength,
    );
  }
}

@HiveType(typeId: 272)
class StudyAnalytics {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int totalLifetimeMinutes;

  @HiveField(2)
  final int totalLifetimeSessions;

  @HiveField(3)
  final int currentStreak;

  @HiveField(4)
  final int longestStreak;

  @HiveField(5)
  final DateTime? lastStudyDate;

  @HiveField(6)
  final int totalExamsCompleted;

  @HiveField(7)
  final int totalExamsPassed;

  @HiveField(8)
  final double averageGrade;

  @HiveField(9)
  final int totalTopicsCompleted;

  @HiveField(10)
  final int totalTopicsMastered;

  @HiveField(11)
  final Map<String, int> minutesBySubject;

  @HiveField(12)
  final Map<int, int> minutesByHour;

  @HiveField(13)
  final Map<int, int> minutesByDayOfWeek;

  @HiveField(14)
  final int dailyGoalMinutes;

  @HiveField(15)
  final int weeklyGoalDays;

  @HiveField(16)
  final List<String> achievementIds;

  @HiveField(17)
  final DateTime createdAt;

  @HiveField(18)
  final DateTime updatedAt;

  @HiveField(19)
  final bool isSynced;

  StudyAnalytics({
    required this.id,
    this.totalLifetimeMinutes = 0,
    this.totalLifetimeSessions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastStudyDate,
    this.totalExamsCompleted = 0,
    this.totalExamsPassed = 0,
    this.averageGrade = 0.0,
    this.totalTopicsCompleted = 0,
    this.totalTopicsMastered = 0,
    this.minutesBySubject = const {},
    this.minutesByHour = const {},
    this.minutesByDayOfWeek = const {},
    this.dailyGoalMinutes = 120,
    this.weeklyGoalDays = 5,
    this.achievementIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get totalLifetimeHours => totalLifetimeMinutes / 60.0;

  double get examPassRate {
    if (totalExamsCompleted <= 0) return 0.0;
    return totalExamsPassed / totalExamsCompleted;
  }

  double get topicMasteryRate {
    if (totalTopicsCompleted <= 0) return 0.0;
    return totalTopicsMastered / totalTopicsCompleted;
  }

  int get mostProductiveHour {
    if (minutesByHour.isEmpty) return 9;
    int maxHour = 0;
    int maxMinutes = 0;
    minutesByHour.forEach((hour, minutes) {
      if (minutes > maxMinutes) {
        maxMinutes = minutes;
        maxHour = hour;
      }
    });
    return maxHour;
  }

  int get mostProductiveDayOfWeek {
    if (minutesByDayOfWeek.isEmpty) return 1;
    int maxDay = 1;
    int maxMinutes = 0;
    minutesByDayOfWeek.forEach((day, minutes) {
      if (minutes > maxMinutes) {
        maxMinutes = minutes;
        maxDay = day;
      }
    });
    return maxDay;
  }

  String get productiveDayName {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final index = mostProductiveDayOfWeek - 1;
    if (index >= 0 && index < days.length) {
      return days[index];
    }
    return 'Monday';
  }

  StudyAnalytics copyWith({
    String? id,
    int? totalLifetimeMinutes,
    int? totalLifetimeSessions,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastStudyDate,
    int? totalExamsCompleted,
    int? totalExamsPassed,
    double? averageGrade,
    int? totalTopicsCompleted,
    int? totalTopicsMastered,
    Map<String, int>? minutesBySubject,
    Map<int, int>? minutesByHour,
    Map<int, int>? minutesByDayOfWeek,
    int? dailyGoalMinutes,
    int? weeklyGoalDays,
    List<String>? achievementIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return StudyAnalytics(
      id: id ?? this.id,
      totalLifetimeMinutes: totalLifetimeMinutes ?? this.totalLifetimeMinutes,
      totalLifetimeSessions:
          totalLifetimeSessions ?? this.totalLifetimeSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      totalExamsCompleted: totalExamsCompleted ?? this.totalExamsCompleted,
      totalExamsPassed: totalExamsPassed ?? this.totalExamsPassed,
      averageGrade: averageGrade ?? this.averageGrade,
      totalTopicsCompleted: totalTopicsCompleted ?? this.totalTopicsCompleted,
      totalTopicsMastered: totalTopicsMastered ?? this.totalTopicsMastered,
      minutesBySubject: minutesBySubject ?? this.minutesBySubject,
      minutesByHour: minutesByHour ?? this.minutesByHour,
      minutesByDayOfWeek: minutesByDayOfWeek ?? this.minutesByDayOfWeek,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      weeklyGoalDays: weeklyGoalDays ?? this.weeklyGoalDays,
      achievementIds: achievementIds ?? this.achievementIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'totalLifetimeMinutes': totalLifetimeMinutes,
      'totalLifetimeSessions': totalLifetimeSessions,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastStudyDate': lastStudyDate?.toIso8601String(),
      'totalExamsCompleted': totalExamsCompleted,
      'totalExamsPassed': totalExamsPassed,
      'averageGrade': averageGrade,
      'totalTopicsCompleted': totalTopicsCompleted,
      'totalTopicsMastered': totalTopicsMastered,
      'minutesBySubject': minutesBySubject,
      'minutesByHour':
          minutesByHour.map((k, v) => MapEntry(k.toString(), v)),
      'minutesByDayOfWeek':
          minutesByDayOfWeek.map((k, v) => MapEntry(k.toString(), v)),
      'dailyGoalMinutes': dailyGoalMinutes,
      'weeklyGoalDays': weeklyGoalDays,
      'achievementIds': achievementIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory StudyAnalytics.fromJson(Map<String, dynamic> json) {
    return StudyAnalytics(
      id: json['id'] ?? '',
      totalLifetimeMinutes: json['totalLifetimeMinutes'] ?? 0,
      totalLifetimeSessions: json['totalLifetimeSessions'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      lastStudyDate: json['lastStudyDate'] != null
          ? DateTime.parse(json['lastStudyDate'])
          : null,
      totalExamsCompleted: json['totalExamsCompleted'] ?? 0,
      totalExamsPassed: json['totalExamsPassed'] ?? 0,
      averageGrade: (json['averageGrade'] ?? 0.0).toDouble(),
      totalTopicsCompleted: json['totalTopicsCompleted'] ?? 0,
      totalTopicsMastered: json['totalTopicsMastered'] ?? 0,
      minutesBySubject: Map<String, int>.from(json['minutesBySubject'] ?? {}),
      minutesByHour: (json['minutesByHour'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), v as int)) ??
          {},
      minutesByDayOfWeek: (json['minutesByDayOfWeek'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), v as int)) ??
          {},
      dailyGoalMinutes: json['dailyGoalMinutes'] ?? 120,
      weeklyGoalDays: json['weeklyGoalDays'] ?? 5,
      achievementIds: List<String>.from(json['achievementIds'] ?? []),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isSynced: true,
    );
  }
}
