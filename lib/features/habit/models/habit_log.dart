import 'dart:convert';

/// Mood rating for habit completion
enum HabitMood {
  great,
  good,
  okay,
  bad,
  terrible,
}

/// Status of a habit log entry
enum HabitLogStatus {
  completed,
  skipped,
  missed,
  partial,
}

/// Daily completion record for a habit
class HabitLog {
  final String id;
  final String habitId;
  final DateTime date;
  final HabitLogStatus status;
  final double? value; // For habits with targets (e.g., 30 mins, 2 km)
  final double? targetValue; // Target at time of logging
  final HabitMood? mood;
  final String? notes;
  final DateTime loggedAt;

  const HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    this.status = HabitLogStatus.completed,
    this.value,
    this.targetValue,
    this.mood,
    this.notes,
    required this.loggedAt,
  });

  bool get isCompleted => status == HabitLogStatus.completed;
  bool get isSkipped => status == HabitLogStatus.skipped;
  bool get isMissed => status == HabitLogStatus.missed;
  bool get isPartial => status == HabitLogStatus.partial;

  /// Calculate completion percentage for target-based habits
  double get completionPercentage {
    if (value == null || targetValue == null || targetValue == 0) {
      return isCompleted ? 1.0 : 0.0;
    }
    return (value! / targetValue!).clamp(0.0, 1.0);
  }

  /// Get mood emoji
  String get moodEmoji {
    switch (mood) {
      case HabitMood.great:
        return '😄';
      case HabitMood.good:
        return '🙂';
      case HabitMood.okay:
        return '😐';
      case HabitMood.bad:
        return '😕';
      case HabitMood.terrible:
        return '😢';
      case null:
        return '';
    }
  }

  HabitLog copyWith({
    String? id,
    String? habitId,
    DateTime? date,
    HabitLogStatus? status,
    double? value,
    double? targetValue,
    HabitMood? mood,
    String? notes,
    DateTime? loggedAt,
  }) {
    return HabitLog(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      date: date ?? this.date,
      status: status ?? this.status,
      value: value ?? this.value,
      targetValue: targetValue ?? this.targetValue,
      mood: mood ?? this.mood,
      notes: notes ?? this.notes,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habitId': habitId,
      'date': date.toIso8601String(),
      'status': status.index,
      'value': value,
      'targetValue': targetValue,
      'mood': mood?.index,
      'notes': notes,
      'loggedAt': loggedAt.toIso8601String(),
    };
  }

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      date: DateTime.parse(json['date'] as String),
      status: HabitLogStatus.values[json['status'] as int? ?? 0],
      value: (json['value'] as num?)?.toDouble(),
      targetValue: (json['targetValue'] as num?)?.toDouble(),
      mood: json['mood'] != null ? HabitMood.values[json['mood'] as int] : null,
      notes: json['notes'] as String?,
      loggedAt: DateTime.parse(json['loggedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitLog.fromJsonString(String jsonString) {
    return HabitLog.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitLog && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Daily summary for all habits
class DailyHabitSummary {
  final DateTime date;
  final int totalHabits;
  final int completedHabits;
  final int skippedHabits;
  final int missedHabits;

  const DailyHabitSummary({
    required this.date,
    required this.totalHabits,
    required this.completedHabits,
    this.skippedHabits = 0,
    this.missedHabits = 0,
  });

  double get completionRate {
    if (totalHabits == 0) return 0.0;
    return completedHabits / totalHabits;
  }

  int get completionPercentage => (completionRate * 100).round();

  bool get isAllCompleted => completedHabits == totalHabits && totalHabits > 0;
}
