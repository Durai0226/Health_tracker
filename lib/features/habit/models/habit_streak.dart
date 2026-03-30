import 'dart:convert';

/// Streak statistics for a habit
class HabitStreak {
  final String habitId;
  final int currentStreak;
  final int bestStreak;
  final int totalCompletions;
  final int totalScheduled;
  final DateTime? lastCompletedDate;
  final DateTime? streakStartDate;

  const HabitStreak({
    required this.habitId,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalCompletions = 0,
    this.totalScheduled = 0,
    this.lastCompletedDate,
    this.streakStartDate,
  });

  /// Overall completion rate as percentage
  double get completionRate {
    if (totalScheduled == 0) return 0.0;
    return totalCompletions / totalScheduled;
  }

  int get completionPercentage => (completionRate * 100).round();

  /// Check if streak is active (completed yesterday or today)
  bool get isStreakActive {
    if (lastCompletedDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastDate = DateTime(
      lastCompletedDate!.year,
      lastCompletedDate!.month,
      lastCompletedDate!.day,
    );
    return lastDate == today || lastDate == yesterday;
  }

  HabitStreak copyWith({
    String? habitId,
    int? currentStreak,
    int? bestStreak,
    int? totalCompletions,
    int? totalScheduled,
    DateTime? lastCompletedDate,
    DateTime? streakStartDate,
  }) {
    return HabitStreak(
      habitId: habitId ?? this.habitId,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      totalScheduled: totalScheduled ?? this.totalScheduled,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      streakStartDate: streakStartDate ?? this.streakStartDate,
    );
  }

  /// Update streak after completion
  HabitStreak recordCompletion(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final lastDate = lastCompletedDate != null
        ? DateTime(lastCompletedDate!.year, lastCompletedDate!.month, lastCompletedDate!.day)
        : null;

    int newCurrentStreak = currentStreak;
    DateTime? newStreakStart = streakStartDate;

    if (lastDate == null) {
      // First completion
      newCurrentStreak = 1;
      newStreakStart = normalizedDate;
    } else if (normalizedDate == lastDate) {
      // Same day, no change to streak
    } else if (normalizedDate.difference(lastDate).inDays == 1) {
      // Consecutive day
      newCurrentStreak = currentStreak + 1;
    } else if (normalizedDate.difference(lastDate).inDays > 1) {
      // Streak broken, start new
      newCurrentStreak = 1;
      newStreakStart = normalizedDate;
    }

    return copyWith(
      currentStreak: newCurrentStreak,
      bestStreak: newCurrentStreak > bestStreak ? newCurrentStreak : bestStreak,
      totalCompletions: totalCompletions + 1,
      totalScheduled: totalScheduled + 1,
      lastCompletedDate: normalizedDate,
      streakStartDate: newStreakStart,
    );
  }

  /// Record a missed day (breaks streak)
  HabitStreak recordMissed() {
    return copyWith(
      currentStreak: 0,
      totalScheduled: totalScheduled + 1,
      streakStartDate: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habitId': habitId,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalCompletions': totalCompletions,
      'totalScheduled': totalScheduled,
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
      'streakStartDate': streakStartDate?.toIso8601String(),
    };
  }

  factory HabitStreak.fromJson(Map<String, dynamic> json) {
    return HabitStreak(
      habitId: json['habitId'] as String,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      totalCompletions: json['totalCompletions'] as int? ?? 0,
      totalScheduled: json['totalScheduled'] as int? ?? 0,
      lastCompletedDate: json['lastCompletedDate'] != null
          ? DateTime.parse(json['lastCompletedDate'] as String)
          : null,
      streakStartDate: json['streakStartDate'] != null
          ? DateTime.parse(json['streakStartDate'] as String)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitStreak.fromJsonString(String jsonString) {
    return HabitStreak.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

/// Overall habit statistics
class HabitStats {
  final int totalHabits;
  final int activeHabits;
  final int completedToday;
  final int scheduledToday;
  final int currentOverallStreak;
  final int bestOverallStreak;
  final double weeklyCompletionRate;
  final double monthlyCompletionRate;

  const HabitStats({
    this.totalHabits = 0,
    this.activeHabits = 0,
    this.completedToday = 0,
    this.scheduledToday = 0,
    this.currentOverallStreak = 0,
    this.bestOverallStreak = 0,
    this.weeklyCompletionRate = 0.0,
    this.monthlyCompletionRate = 0.0,
  });

  int get todayCompletionPercentage {
    if (scheduledToday == 0) return 0;
    return ((completedToday / scheduledToday) * 100).round();
  }

  int get weeklyPercentage => (weeklyCompletionRate * 100).round();
  int get monthlyPercentage => (monthlyCompletionRate * 100).round();

  HabitStats copyWith({
    int? totalHabits,
    int? activeHabits,
    int? completedToday,
    int? scheduledToday,
    int? currentOverallStreak,
    int? bestOverallStreak,
    double? weeklyCompletionRate,
    double? monthlyCompletionRate,
  }) {
    return HabitStats(
      totalHabits: totalHabits ?? this.totalHabits,
      activeHabits: activeHabits ?? this.activeHabits,
      completedToday: completedToday ?? this.completedToday,
      scheduledToday: scheduledToday ?? this.scheduledToday,
      currentOverallStreak: currentOverallStreak ?? this.currentOverallStreak,
      bestOverallStreak: bestOverallStreak ?? this.bestOverallStreak,
      weeklyCompletionRate: weeklyCompletionRate ?? this.weeklyCompletionRate,
      monthlyCompletionRate: monthlyCompletionRate ?? this.monthlyCompletionRate,
    );
  }
}
