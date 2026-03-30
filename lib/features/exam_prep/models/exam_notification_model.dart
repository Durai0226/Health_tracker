/// Exam Prep Notification Models
/// Supports 8 types of notifications for comprehensive exam preparation

import 'package:flutter/material.dart';

enum ExamNotificationType {
  dailyPractice,
  streakAlert,
  mockTestReminder,
  currentAffairs,
  examDateAlert,
  performanceAlert,
  weeklyProgress,
  achievement,
}

class ExamNotification {
  final String id;
  final ExamNotificationType type;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final Map<String, dynamic>? payload;
  final bool isRead;
  final bool isEnabled;

  const ExamNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.payload,
    this.isRead = false,
    this.isEnabled = true,
  });

  ExamNotification copyWith({
    String? id,
    ExamNotificationType? type,
    String? title,
    String? body,
    DateTime? scheduledTime,
    Map<String, dynamic>? payload,
    bool? isRead,
    bool? isEnabled,
  }) {
    return ExamNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'title': title,
    'body': body,
    'scheduledTime': scheduledTime.toIso8601String(),
    'payload': payload,
    'isRead': isRead,
    'isEnabled': isEnabled,
  };

  factory ExamNotification.fromJson(Map<String, dynamic> json) {
    return ExamNotification(
      id: json['id'] as String,
      type: ExamNotificationType.values[json['type'] as int],
      title: json['title'] as String,
      body: json['body'] as String,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      payload: json['payload'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}

class ExamNotificationSettings {
  final bool dailyPracticeEnabled;
  final TimeOfDay dailyPracticeTime;
  final bool streakAlertsEnabled;
  final TimeOfDay streakAlertTime;
  final bool mockTestRemindersEnabled;
  final int mockTestReminderMinutesBefore;
  final bool currentAffairsEnabled;
  final int currentAffairsDay; // 0 = Sunday, 6 = Saturday
  final bool examDateAlertsEnabled;
  final List<int> examDateAlertDaysBefore; // [30, 15, 7, 1]
  final bool performanceAlertsEnabled;
  final bool weeklyProgressEnabled;
  final int weeklyProgressDay;
  final TimeOfDay weeklyProgressTime;
  final bool achievementsEnabled;

  const ExamNotificationSettings({
    this.dailyPracticeEnabled = true,
    this.dailyPracticeTime = const TimeOfDay(hour: 9, minute: 0),
    this.streakAlertsEnabled = true,
    this.streakAlertTime = const TimeOfDay(hour: 20, minute: 0),
    this.mockTestRemindersEnabled = true,
    this.mockTestReminderMinutesBefore = 30,
    this.currentAffairsEnabled = true,
    this.currentAffairsDay = 0, // Sunday
    this.examDateAlertsEnabled = true,
    this.examDateAlertDaysBefore = const [30, 15, 7, 1],
    this.performanceAlertsEnabled = true,
    this.weeklyProgressEnabled = true,
    this.weeklyProgressDay = 0, // Sunday
    this.weeklyProgressTime = const TimeOfDay(hour: 10, minute: 0),
    this.achievementsEnabled = true,
  });

  ExamNotificationSettings copyWith({
    bool? dailyPracticeEnabled,
    TimeOfDay? dailyPracticeTime,
    bool? streakAlertsEnabled,
    TimeOfDay? streakAlertTime,
    bool? mockTestRemindersEnabled,
    int? mockTestReminderMinutesBefore,
    bool? currentAffairsEnabled,
    int? currentAffairsDay,
    bool? examDateAlertsEnabled,
    List<int>? examDateAlertDaysBefore,
    bool? performanceAlertsEnabled,
    bool? weeklyProgressEnabled,
    int? weeklyProgressDay,
    TimeOfDay? weeklyProgressTime,
    bool? achievementsEnabled,
  }) {
    return ExamNotificationSettings(
      dailyPracticeEnabled: dailyPracticeEnabled ?? this.dailyPracticeEnabled,
      dailyPracticeTime: dailyPracticeTime ?? this.dailyPracticeTime,
      streakAlertsEnabled: streakAlertsEnabled ?? this.streakAlertsEnabled,
      streakAlertTime: streakAlertTime ?? this.streakAlertTime,
      mockTestRemindersEnabled: mockTestRemindersEnabled ?? this.mockTestRemindersEnabled,
      mockTestReminderMinutesBefore: mockTestReminderMinutesBefore ?? this.mockTestReminderMinutesBefore,
      currentAffairsEnabled: currentAffairsEnabled ?? this.currentAffairsEnabled,
      currentAffairsDay: currentAffairsDay ?? this.currentAffairsDay,
      examDateAlertsEnabled: examDateAlertsEnabled ?? this.examDateAlertsEnabled,
      examDateAlertDaysBefore: examDateAlertDaysBefore ?? this.examDateAlertDaysBefore,
      performanceAlertsEnabled: performanceAlertsEnabled ?? this.performanceAlertsEnabled,
      weeklyProgressEnabled: weeklyProgressEnabled ?? this.weeklyProgressEnabled,
      weeklyProgressDay: weeklyProgressDay ?? this.weeklyProgressDay,
      weeklyProgressTime: weeklyProgressTime ?? this.weeklyProgressTime,
      achievementsEnabled: achievementsEnabled ?? this.achievementsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'dailyPracticeEnabled': dailyPracticeEnabled,
    'dailyPracticeTimeHour': dailyPracticeTime.hour,
    'dailyPracticeTimeMinute': dailyPracticeTime.minute,
    'streakAlertsEnabled': streakAlertsEnabled,
    'streakAlertTimeHour': streakAlertTime.hour,
    'streakAlertTimeMinute': streakAlertTime.minute,
    'mockTestRemindersEnabled': mockTestRemindersEnabled,
    'mockTestReminderMinutesBefore': mockTestReminderMinutesBefore,
    'currentAffairsEnabled': currentAffairsEnabled,
    'currentAffairsDay': currentAffairsDay,
    'examDateAlertsEnabled': examDateAlertsEnabled,
    'examDateAlertDaysBefore': examDateAlertDaysBefore,
    'performanceAlertsEnabled': performanceAlertsEnabled,
    'weeklyProgressEnabled': weeklyProgressEnabled,
    'weeklyProgressDay': weeklyProgressDay,
    'weeklyProgressTimeHour': weeklyProgressTime.hour,
    'weeklyProgressTimeMinute': weeklyProgressTime.minute,
    'achievementsEnabled': achievementsEnabled,
  };

  factory ExamNotificationSettings.fromJson(Map<String, dynamic> json) {
    return ExamNotificationSettings(
      dailyPracticeEnabled: json['dailyPracticeEnabled'] as bool? ?? true,
      dailyPracticeTime: TimeOfDay(
        hour: json['dailyPracticeTimeHour'] as int? ?? 9,
        minute: json['dailyPracticeTimeMinute'] as int? ?? 0,
      ),
      streakAlertsEnabled: json['streakAlertsEnabled'] as bool? ?? true,
      streakAlertTime: TimeOfDay(
        hour: json['streakAlertTimeHour'] as int? ?? 20,
        minute: json['streakAlertTimeMinute'] as int? ?? 0,
      ),
      mockTestRemindersEnabled: json['mockTestRemindersEnabled'] as bool? ?? true,
      mockTestReminderMinutesBefore: json['mockTestReminderMinutesBefore'] as int? ?? 30,
      currentAffairsEnabled: json['currentAffairsEnabled'] as bool? ?? true,
      currentAffairsDay: json['currentAffairsDay'] as int? ?? 0,
      examDateAlertsEnabled: json['examDateAlertsEnabled'] as bool? ?? true,
      examDateAlertDaysBefore: (json['examDateAlertDaysBefore'] as List<dynamic>?)
          ?.map((e) => e as int).toList() ?? [30, 15, 7, 1],
      performanceAlertsEnabled: json['performanceAlertsEnabled'] as bool? ?? true,
      weeklyProgressEnabled: json['weeklyProgressEnabled'] as bool? ?? true,
      weeklyProgressDay: json['weeklyProgressDay'] as int? ?? 0,
      weeklyProgressTime: TimeOfDay(
        hour: json['weeklyProgressTimeHour'] as int? ?? 10,
        minute: json['weeklyProgressTimeMinute'] as int? ?? 0,
      ),
      achievementsEnabled: json['achievementsEnabled'] as bool? ?? true,
    );
  }
}

class ExamDate {
  final String id;
  final String examId;
  final String examName;
  final DateTime date;
  final String? description;
  final bool reminderSet;

  const ExamDate({
    required this.id,
    required this.examId,
    required this.examName,
    required this.date,
    this.description,
    this.reminderSet = true,
  });

  int get daysUntil => date.difference(DateTime.now()).inDays;

  bool get isUpcoming => daysUntil > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'examId': examId,
    'examName': examName,
    'date': date.toIso8601String(),
    'description': description,
    'reminderSet': reminderSet,
  };

  factory ExamDate.fromJson(Map<String, dynamic> json) {
    return ExamDate(
      id: json['id'] as String,
      examId: json['examId'] as String,
      examName: json['examName'] as String,
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
      reminderSet: json['reminderSet'] as bool? ?? true,
    );
  }
}

class StudyStreak {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastPracticeDate;
  final int totalDaysPracticed;

  const StudyStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastPracticeDate,
    this.totalDaysPracticed = 0,
  });

  bool get practicedToday {
    if (lastPracticeDate == null) return false;
    final now = DateTime.now();
    return lastPracticeDate!.year == now.year &&
           lastPracticeDate!.month == now.month &&
           lastPracticeDate!.day == now.day;
  }

  StudyStreak recordPractice() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (practicedToday) return this;
    
    int newStreak = currentStreak;
    if (lastPracticeDate != null) {
      final lastDate = DateTime(
        lastPracticeDate!.year,
        lastPracticeDate!.month,
        lastPracticeDate!.day,
      );
      final daysDiff = today.difference(lastDate).inDays;
      if (daysDiff == 1) {
        newStreak++;
      } else if (daysDiff > 1) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }
    
    return StudyStreak(
      currentStreak: newStreak,
      longestStreak: newStreak > longestStreak ? newStreak : longestStreak,
      lastPracticeDate: now,
      totalDaysPracticed: totalDaysPracticed + 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastPracticeDate': lastPracticeDate?.toIso8601String(),
    'totalDaysPracticed': totalDaysPracticed,
  };

  factory StudyStreak.fromJson(Map<String, dynamic> json) {
    return StudyStreak(
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastPracticeDate: json['lastPracticeDate'] != null 
          ? DateTime.parse(json['lastPracticeDate'] as String)
          : null,
      totalDaysPracticed: json['totalDaysPracticed'] as int? ?? 0,
    );
  }
}

class WeeklyProgressReport {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int questionsAttempted;
  final int questionsCorrect;
  final int mockTestsTaken;
  final double averageScore;
  final Map<String, int> subjectWiseQuestions;
  final int studyMinutes;
  final int streakDays;

  const WeeklyProgressReport({
    required this.weekStart,
    required this.weekEnd,
    this.questionsAttempted = 0,
    this.questionsCorrect = 0,
    this.mockTestsTaken = 0,
    this.averageScore = 0.0,
    this.subjectWiseQuestions = const {},
    this.studyMinutes = 0,
    this.streakDays = 0,
  });

  double get accuracy => questionsAttempted > 0 
      ? (questionsCorrect / questionsAttempted) * 100 
      : 0.0;

  String get summaryText {
    final buffer = StringBuffer();
    buffer.writeln('📊 Weekly Progress Report');
    buffer.writeln('Questions: $questionsAttempted ($questionsCorrect correct)');
    buffer.writeln('Accuracy: ${accuracy.toStringAsFixed(1)}%');
    if (mockTestsTaken > 0) {
      buffer.writeln('Mock Tests: $mockTestsTaken (Avg: ${averageScore.toStringAsFixed(1)}%)');
    }
    buffer.writeln('Study Time: ${studyMinutes ~/ 60}h ${studyMinutes % 60}m');
    buffer.writeln('Streak: $streakDays days 🔥');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart.toIso8601String(),
    'weekEnd': weekEnd.toIso8601String(),
    'questionsAttempted': questionsAttempted,
    'questionsCorrect': questionsCorrect,
    'mockTestsTaken': mockTestsTaken,
    'averageScore': averageScore,
    'subjectWiseQuestions': subjectWiseQuestions,
    'studyMinutes': studyMinutes,
    'streakDays': streakDays,
  };

  factory WeeklyProgressReport.fromJson(Map<String, dynamic> json) {
    return WeeklyProgressReport(
      weekStart: DateTime.parse(json['weekStart'] as String),
      weekEnd: DateTime.parse(json['weekEnd'] as String),
      questionsAttempted: json['questionsAttempted'] as int? ?? 0,
      questionsCorrect: json['questionsCorrect'] as int? ?? 0,
      mockTestsTaken: json['mockTestsTaken'] as int? ?? 0,
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0.0,
      subjectWiseQuestions: (json['subjectWiseQuestions'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)) ?? {},
      studyMinutes: json['studyMinutes'] as int? ?? 0,
      streakDays: json['streakDays'] as int? ?? 0,
    );
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final DateTime? unlockedAt;
  final AchievementType type;
  final int? targetValue;
  final int currentValue;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.unlockedAt,
    required this.type,
    this.targetValue,
    this.currentValue = 0,
  });

  bool get isUnlocked => unlockedAt != null;

  double get progress => targetValue != null && targetValue! > 0 
      ? (currentValue / targetValue!).clamp(0.0, 1.0) 
      : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'type': type.index,
    'targetValue': targetValue,
    'currentValue': currentValue,
  };

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      unlockedAt: json['unlockedAt'] != null 
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
      type: AchievementType.values[json['type'] as int],
      targetValue: json['targetValue'] as int?,
      currentValue: json['currentValue'] as int? ?? 0,
    );
  }
}

enum AchievementType {
  questionsAnswered,
  mockTestsCompleted,
  streakDays,
  perfectScore,
  subjectMastery,
  dailyGoal,
  weeklyGoal,
}
