import 'package:flutter/material.dart';

class StudyGoal {
  final String id;
  final String examId;
  final String title;
  final GoalType type;
  final int targetValue;
  final int currentValue;
  final GoalPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final List<DateTime> completedDates;
  final bool isActive;

  StudyGoal({
    required this.id,
    required this.examId,
    required this.title,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.completedDates = const [],
    this.isActive = true,
  });

  double get progressPercent => targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => currentValue >= targetValue;
  int get remaining => (targetValue - currentValue).clamp(0, targetValue);

  int get daysRemaining => endDate.difference(DateTime.now()).inDays;
  bool get isOverdue => DateTime.now().isAfter(endDate) && !isCompleted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'examId': examId,
        'title': title,
        'type': type.index,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'period': period.index,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'completedDates': completedDates.map((d) => d.toIso8601String()).toList(),
        'isActive': isActive,
      };

  factory StudyGoal.fromJson(Map<String, dynamic> json) => StudyGoal(
        id: json['id'] ?? '',
        examId: json['examId'] ?? '',
        title: json['title'] ?? '',
        type: GoalType.values[json['type'] ?? 0],
        targetValue: json['targetValue'] ?? 0,
        currentValue: json['currentValue'] ?? 0,
        period: GoalPeriod.values[json['period'] ?? 0],
        startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
        endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
        completedDates: (json['completedDates'] as List?)
                ?.map((d) => DateTime.parse(d))
                .toList() ??
            [],
        isActive: json['isActive'] ?? true,
      );

  StudyGoal copyWith({
    String? id,
    String? examId,
    String? title,
    GoalType? type,
    int? targetValue,
    int? currentValue,
    GoalPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    List<DateTime>? completedDates,
    bool? isActive,
  }) {
    return StudyGoal(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      title: title ?? this.title,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      completedDates: completedDates ?? this.completedDates,
      isActive: isActive ?? this.isActive,
    );
  }
}

enum GoalType {
  studyHours,
  questionsPerDay,
  topicsCompleted,
  mockTests,
  revisionSessions,
  streakDays,
}

extension GoalTypeExtension on GoalType {
  String get name {
    switch (this) {
      case GoalType.studyHours:
        return 'Study Hours';
      case GoalType.questionsPerDay:
        return 'Questions/Day';
      case GoalType.topicsCompleted:
        return 'Topics Completed';
      case GoalType.mockTests:
        return 'Mock Tests';
      case GoalType.revisionSessions:
        return 'Revision Sessions';
      case GoalType.streakDays:
        return 'Study Streak';
    }
  }

  String get unit {
    switch (this) {
      case GoalType.studyHours:
        return 'hours';
      case GoalType.questionsPerDay:
        return 'questions';
      case GoalType.topicsCompleted:
        return 'topics';
      case GoalType.mockTests:
        return 'tests';
      case GoalType.revisionSessions:
        return 'sessions';
      case GoalType.streakDays:
        return 'days';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalType.studyHours:
        return Icons.timer_rounded;
      case GoalType.questionsPerDay:
        return Icons.quiz_rounded;
      case GoalType.topicsCompleted:
        return Icons.check_circle_rounded;
      case GoalType.mockTests:
        return Icons.assignment_rounded;
      case GoalType.revisionSessions:
        return Icons.replay_rounded;
      case GoalType.streakDays:
        return Icons.local_fire_department_rounded;
    }
  }
}

enum GoalPeriod {
  daily,
  weekly,
  monthly,
  custom,
}

extension GoalPeriodExtension on GoalPeriod {
  String get name {
    switch (this) {
      case GoalPeriod.daily:
        return 'Daily';
      case GoalPeriod.weekly:
        return 'Weekly';
      case GoalPeriod.monthly:
        return 'Monthly';
      case GoalPeriod.custom:
        return 'Custom';
    }
  }
}

class StudyReminder {
  final String id;
  final String examId;
  final String? subjectId;
  final String title;
  final String? description;
  final TimeOfDay time;
  final List<int> repeatDays; // 1-7, Monday-Sunday
  final bool isEnabled;
  final ReminderType type;

  StudyReminder({
    required this.id,
    required this.examId,
    this.subjectId,
    required this.title,
    this.description,
    required this.time,
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    this.isEnabled = true,
    this.type = ReminderType.study,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'examId': examId,
        'subjectId': subjectId,
        'title': title,
        'description': description,
        'timeHour': time.hour,
        'timeMinute': time.minute,
        'repeatDays': repeatDays,
        'isEnabled': isEnabled,
        'type': type.index,
      };

  factory StudyReminder.fromJson(Map<String, dynamic> json) => StudyReminder(
        id: json['id'] ?? '',
        examId: json['examId'] ?? '',
        subjectId: json['subjectId'],
        title: json['title'] ?? '',
        description: json['description'],
        time: TimeOfDay(hour: json['timeHour'] ?? 9, minute: json['timeMinute'] ?? 0),
        repeatDays: List<int>.from(json['repeatDays'] ?? [1, 2, 3, 4, 5, 6, 7]),
        isEnabled: json['isEnabled'] ?? true,
        type: ReminderType.values[json['type'] ?? 0],
      );

  StudyReminder copyWith({
    String? id,
    String? examId,
    String? subjectId,
    String? title,
    String? description,
    TimeOfDay? time,
    List<int>? repeatDays,
    bool? isEnabled,
    ReminderType? type,
  }) {
    return StudyReminder(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      repeatDays: repeatDays ?? this.repeatDays,
      isEnabled: isEnabled ?? this.isEnabled,
      type: type ?? this.type,
    );
  }
}

enum ReminderType {
  study,
  revision,
  mockTest,
  break_,
  custom,
}

extension ReminderTypeExtension on ReminderType {
  String get name {
    switch (this) {
      case ReminderType.study:
        return 'Study Session';
      case ReminderType.revision:
        return 'Revision';
      case ReminderType.mockTest:
        return 'Mock Test';
      case ReminderType.break_:
        return 'Take a Break';
      case ReminderType.custom:
        return 'Custom';
    }
  }

  String get emoji {
    switch (this) {
      case ReminderType.study:
        return '📚';
      case ReminderType.revision:
        return '🔄';
      case ReminderType.mockTest:
        return '📝';
      case ReminderType.break_:
        return '☕';
      case ReminderType.custom:
        return '🔔';
    }
  }
}
