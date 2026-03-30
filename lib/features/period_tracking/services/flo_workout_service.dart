import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cycle_workout.dart';
import '../theme/flo_theme.dart';

/// Service for workout tracking and recommendations
class FloWorkoutService {
  static const String _workoutLogsKey = 'flo_workout_logs';
  static const String _workoutProgressKey = 'flo_workout_progress';
  static List<WorkoutLog>? _cachedLogs;
  static WorkoutProgress? _cachedProgress;

  /// Get all workout logs
  static Future<List<WorkoutLog>> getWorkoutLogs() async {
    if (_cachedLogs != null) return _cachedLogs!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_workoutLogsKey);
      if (json == null) return [];

      final List<dynamic> list = jsonDecode(json);
      _cachedLogs = list.map((e) => WorkoutLog.fromJson(e)).toList();
      return _cachedLogs!;
    } catch (e) {
      debugPrint('Error loading workout logs: $e');
      return [];
    }
  }

  /// Add workout log
  static Future<void> addWorkoutLog(WorkoutLog log) async {
    try {
      final logs = await getWorkoutLogs();
      logs.add(log);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _workoutLogsKey,
        jsonEncode(logs.map((l) => l.toJson()).toList()),
      );
      _cachedLogs = logs;

      // Update progress
      await _updateProgress(log);
    } catch (e) {
      debugPrint('Error adding workout log: $e');
    }
  }

  /// Get workout progress
  static Future<WorkoutProgress> getProgress() async {
    if (_cachedProgress != null) return _cachedProgress!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_workoutProgressKey);
      if (json == null) return WorkoutProgress();

      _cachedProgress = WorkoutProgress.fromJson(jsonDecode(json));
      return _cachedProgress!;
    } catch (e) {
      debugPrint('Error loading workout progress: $e');
      return WorkoutProgress();
    }
  }

  /// Update progress after completing a workout
  static Future<void> _updateProgress(WorkoutLog log) async {
    try {
      final progress = await getProgress();
      final logs = await getWorkoutLogs();

      // Calculate new totals
      final totalWorkouts = logs.length;
      final totalMinutes = logs.fold<int>(0, (sum, l) => sum + l.durationMinutes);
      final totalCalories = logs.fold<int>(0, (sum, l) => sum + l.caloriesBurned);

      // Calculate category counts
      final categoryCount = <WorkoutCategory, int>{};
      for (final l in logs) {
        final workout = PhaseWorkouts.allWorkouts.firstWhere(
          (w) => w.id == l.workoutId,
          orElse: () => PhaseWorkouts.allWorkouts.first,
        );
        categoryCount[workout.category] = (categoryCount[workout.category] ?? 0) + 1;
      }

      // Calculate streak
      final streak = _calculateStreak(logs);

      // Calculate weekly goal progress
      final weekStart = DateTime.now().subtract(
        Duration(days: DateTime.now().weekday - 1),
      );
      final thisWeekLogs = logs.where(
        (l) => l.completedAt.isAfter(weekStart),
      ).length;
      final weeklyGoal = 5; // 5 workouts per week goal
      final weeklyPercent = (thisWeekLogs / weeklyGoal * 100).clamp(0.0, 100.0).toDouble();

      final newProgress = WorkoutProgress(
        totalWorkoutsCompleted: totalWorkouts,
        totalMinutes: totalMinutes,
        totalCaloriesBurned: totalCalories,
        currentStreak: streak,
        longestStreak: streak > progress.longestStreak ? streak : progress.longestStreak,
        categoryCount: categoryCount,
        weeklyGoalPercent: weeklyPercent,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_workoutProgressKey, jsonEncode(newProgress.toJson()));
      _cachedProgress = newProgress;
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }
  }

  /// Calculate current workout streak
  static int _calculateStreak(List<WorkoutLog> logs) {
    if (logs.isEmpty) return 0;

    // Sort by date descending
    logs.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    int streak = 0;
    DateTime? lastDate;

    for (final log in logs) {
      final logDate = DateTime(
        log.completedAt.year,
        log.completedAt.month,
        log.completedAt.day,
      );

      if (lastDate == null) {
        // First log - check if it's today or yesterday
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final yesterday = todayDate.subtract(const Duration(days: 1));

        if (logDate == todayDate || logDate == yesterday) {
          streak = 1;
          lastDate = logDate;
        } else {
          break; // Streak broken
        }
      } else {
        final expectedDate = lastDate.subtract(const Duration(days: 1));
        if (logDate == expectedDate) {
          streak++;
          lastDate = logDate;
        } else if (logDate == lastDate) {
          // Multiple workouts on same day
          continue;
        } else {
          break; // Streak broken
        }
      }
    }

    return streak;
  }

  /// Get recommended workouts for current phase
  static List<CycleWorkout> getRecommendedWorkouts(CyclePhaseType phase) {
    return PhaseWorkouts.getForPhase(phase);
  }

  /// Get workouts by category
  static List<CycleWorkout> getWorkoutsByCategory(WorkoutCategory category) {
    return PhaseWorkouts.allWorkouts
        .where((w) => w.category == category)
        .toList();
  }

  /// Get workout by ID
  static CycleWorkout? getWorkoutById(String id) {
    try {
      return PhaseWorkouts.allWorkouts.firstWhere((w) => w.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get logs for specific date range
  static Future<List<WorkoutLog>> getLogsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final logs = await getWorkoutLogs();
    return logs.where((l) {
      return l.completedAt.isAfter(start.subtract(const Duration(days: 1))) &&
          l.completedAt.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get logs for specific phase
  static Future<List<WorkoutLog>> getLogsForPhase(CyclePhaseType phase) async {
    final logs = await getWorkoutLogs();
    return logs.where((l) => l.phaseWhenCompleted == phase).toList();
  }

  /// Get most common workout category
  static Future<WorkoutCategory?> getMostCommonCategory() async {
    final progress = await getProgress();
    if (progress.categoryCount.isEmpty) return null;

    return progress.categoryCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get weekly statistics
  static Future<Map<String, dynamic>> getWeeklyStats() async {
    final weekStart = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );
    final logs = await getLogsForDateRange(weekStart, DateTime.now());

    final totalMinutes = logs.fold<int>(0, (sum, l) => sum + l.durationMinutes);
    final totalCalories = logs.fold<int>(0, (sum, l) => sum + l.caloriesBurned);
    final avgRating = logs.isNotEmpty
        ? logs.where((l) => l.rating != null).fold<double>(
              0,
              (sum, l) => sum + l.rating!,
            ) / logs.where((l) => l.rating != null).length
        : 0.0;

    return {
      'workoutsCompleted': logs.length,
      'totalMinutes': totalMinutes,
      'totalCalories': totalCalories,
      'averageRating': avgRating,
    };
  }

  /// Clear all data
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_workoutLogsKey);
      await prefs.remove(_workoutProgressKey);
      _cachedLogs = null;
      _cachedProgress = null;
    } catch (e) {
      debugPrint('Error clearing workout data: $e');
    }
  }

  /// Clear cache
  static void clearCache() {
    _cachedLogs = null;
    _cachedProgress = null;
  }
}
