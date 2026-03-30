import 'dart:convert';
import 'package:flutter/material.dart';

/// Repeat type for habits
enum RepeatType {
  daily,
  weekly,
  monthly,
  everyXDays,
}

/// Time of day preference
enum HabitTimeOfDay {
  anytime,
  morning,
  afternoon,
  evening,
}

/// Habit type
enum HabitType {
  regular,
  breakBad,
}

/// Habit model based on Habit Land design
class Habit {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final HabitType habitType;
  final RepeatType repeatType;
  final List<int> repeatDays; // 0-6 for Mon-Sun
  final int repeatXDays; // For everyXDays type
  final int daysPerWeek; // For weekly type (e.g., 4 days per week)
  final HabitTimeOfDay timeOfDay;
  final bool hasTarget;
  final double? targetValue;
  final String? targetUnit; // e.g., "mins", "km", "glasses"
  final String? groupId;
  final String? notes;
  final bool isArchived;
  final bool isPaused;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;

  const Habit({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.habitType = HabitType.regular,
    this.repeatType = RepeatType.daily,
    this.repeatDays = const [0, 1, 2, 3, 4, 5, 6],
    this.repeatXDays = 1,
    this.daysPerWeek = 7,
    this.timeOfDay = HabitTimeOfDay.anytime,
    this.hasTarget = false,
    this.targetValue,
    this.targetUnit,
    this.groupId,
    this.notes,
    this.isArchived = false,
    this.isPaused = false,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  bool get isBreakBad => habitType == HabitType.breakBad;

  /// Check if habit should be done on a specific day
  bool shouldDoOnDay(DateTime date) {
    if (isPaused || isArchived) return false;
    
    switch (repeatType) {
      case RepeatType.daily:
        return repeatDays.contains((date.weekday - 1) % 7);
      case RepeatType.weekly:
        return repeatDays.contains((date.weekday - 1) % 7);
      case RepeatType.monthly:
        // TODO: Implement monthly logic
        return date.day == createdAt.day;
      case RepeatType.everyXDays:
        final daysDiff = date.difference(createdAt).inDays;
        return daysDiff >= 0 && daysDiff % repeatXDays == 0;
    }
  }

  /// Get repeat description text
  String get repeatDescription {
    switch (repeatType) {
      case RepeatType.daily:
        if (repeatDays.length == 7) return 'Daily';
        return '${repeatDays.length} days/week';
      case RepeatType.weekly:
        return '$daysPerWeek days per week';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.everyXDays:
        return 'Every $repeatXDays days';
    }
  }

  /// Get time of day label
  String get timeOfDayLabel {
    switch (timeOfDay) {
      case HabitTimeOfDay.anytime:
        return 'Anytime';
      case HabitTimeOfDay.morning:
        return 'Morning';
      case HabitTimeOfDay.afternoon:
        return 'Afternoon';
      case HabitTimeOfDay.evening:
        return 'Evening';
    }
  }

  Habit copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    HabitType? habitType,
    RepeatType? repeatType,
    List<int>? repeatDays,
    int? repeatXDays,
    int? daysPerWeek,
    HabitTimeOfDay? timeOfDay,
    bool? hasTarget,
    double? targetValue,
    String? targetUnit,
    String? groupId,
    String? notes,
    bool? isArchived,
    bool? isPaused,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      habitType: habitType ?? this.habitType,
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatXDays: repeatXDays ?? this.repeatXDays,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      hasTarget: hasTarget ?? this.hasTarget,
      targetValue: targetValue ?? this.targetValue,
      targetUnit: targetUnit ?? this.targetUnit,
      groupId: groupId ?? this.groupId,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'habitType': habitType.index,
      'repeatType': repeatType.index,
      'repeatDays': repeatDays,
      'repeatXDays': repeatXDays,
      'daysPerWeek': daysPerWeek,
      'timeOfDay': timeOfDay.index,
      'hasTarget': hasTarget,
      'targetValue': targetValue,
      'targetUnit': targetUnit,
      'groupId': groupId,
      'notes': notes,
      'isArchived': isArchived,
      'isPaused': isPaused,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      habitType: HabitType.values[json['habitType'] as int? ?? 0],
      repeatType: RepeatType.values[json['repeatType'] as int? ?? 0],
      repeatDays: (json['repeatDays'] as List<dynamic>?)?.cast<int>() ?? [0, 1, 2, 3, 4, 5, 6],
      repeatXDays: json['repeatXDays'] as int? ?? 1,
      daysPerWeek: json['daysPerWeek'] as int? ?? 7,
      timeOfDay: HabitTimeOfDay.values[json['timeOfDay'] as int? ?? 0],
      hasTarget: json['hasTarget'] as bool? ?? false,
      targetValue: (json['targetValue'] as num?)?.toDouble(),
      targetUnit: json['targetUnit'] as String?,
      groupId: json['groupId'] as String?,
      notes: json['notes'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      isPaused: json['isPaused'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Habit.fromJsonString(String jsonString) {
    return Habit.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Habit && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
