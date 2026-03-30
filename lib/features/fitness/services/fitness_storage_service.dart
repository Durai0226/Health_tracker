import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/fitness_profile.dart';
import '../data/exercise_library.dart';
import '../data/workout_library.dart';
import '../models/workout_challenge.dart';

/// Weight entry for tracking weight history
class WeightEntry {
  final DateTime date;
  final double weight;

  WeightEntry({required this.date, required this.weight});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weight': weight,
  };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    date: DateTime.parse(json['date']),
    weight: (json['weight'] as num).toDouble(),
  );
}

/// Fitness Storage Service using SharedPreferences
/// Handles all local storage for fitness feature
class FitnessStorageService {
  static final FitnessStorageService _instance = FitnessStorageService._internal();
  factory FitnessStorageService() => _instance;
  FitnessStorageService._internal();

  static const String _profileKey = 'fitness_profile';
  static const String _customWorkoutsKey = 'fitness_custom_workouts';
  static const String _customExercisesKey = 'fitness_custom_exercises';
  static const String _workoutSessionsKey = 'fitness_workout_sessions';
  static const String _favoriteWorkoutsKey = 'fitness_favorite_workouts';
  static const String _workoutHistoryKey = 'fitness_workout_history';
  static const String _achievementsKey = 'fitness_achievements';
  static const String _statsKey = 'fitness_stats';
  static const String _remindersKey = 'fitness_reminders';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ============================================
  // PROFILE MANAGEMENT
  // ============================================

  Future<FitnessProfile> getProfile() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_profileKey);
      if (json != null) {
        return FitnessProfile.fromJsonString(json);
      }
    } catch (e) {
      debugPrint('Error loading fitness profile: $e');
    }
    return FitnessProfile.defaultProfile();
  }

  Future<bool> saveProfile(FitnessProfile profile) async {
    try {
      final prefs = await _preferences;
      final updated = profile.copyWith(updatedAt: DateTime.now());
      return prefs.setString(_profileKey, updated.toJsonString());
    } catch (e) {
      debugPrint('Error saving fitness profile: $e');
      return false;
    }
  }

  // ============================================
  // WORKOUT MANAGEMENT
  // ============================================

  /// Get all workouts (built-in + custom)
  Future<List<Workout>> getAllWorkouts() async {
    final builtIn = WorkoutLibrary().allWorkouts;
    final custom = await getCustomWorkouts();
    return [...builtIn, ...custom];
  }

  /// Get custom workouts only
  Future<List<Workout>> getCustomWorkouts() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_customWorkoutsKey);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list.map((e) => Workout.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading custom workouts: $e');
    }
    return [];
  }

  /// Save a custom workout
  Future<bool> saveCustomWorkout(Workout workout) async {
    try {
      final workouts = await getCustomWorkouts();
      final index = workouts.indexWhere((w) => w.id == workout.id);
      
      if (index >= 0) {
        workouts[index] = workout;
      } else {
        workouts.add(workout.copyWith(isCustom: true));
      }

      final prefs = await _preferences;
      final json = jsonEncode(workouts.map((w) => w.toJson()).toList());
      return prefs.setString(_customWorkoutsKey, json);
    } catch (e) {
      debugPrint('Error saving custom workout: $e');
      return false;
    }
  }

  /// Delete a custom workout
  Future<bool> deleteCustomWorkout(String workoutId) async {
    try {
      final workouts = await getCustomWorkouts();
      workouts.removeWhere((w) => w.id == workoutId);

      final prefs = await _preferences;
      final json = jsonEncode(workouts.map((w) => w.toJson()).toList());
      return prefs.setString(_customWorkoutsKey, json);
    } catch (e) {
      debugPrint('Error deleting custom workout: $e');
      return false;
    }
  }

  /// Get workout by ID (built-in or custom)
  Future<Workout?> getWorkoutById(String id) async {
    // Check built-in first
    final builtIn = WorkoutLibrary().getById(id);
    if (builtIn != null) return builtIn;

    // Check custom workouts
    final custom = await getCustomWorkouts();
    try {
      return custom.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  // ============================================
  // FAVORITE WORKOUTS
  // ============================================

  Future<Set<String>> getFavoriteWorkoutIds() async {
    try {
      final prefs = await _preferences;
      final list = prefs.getStringList(_favoriteWorkoutsKey);
      return list?.toSet() ?? {};
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      return {};
    }
  }

  Future<bool> toggleFavorite(String workoutId) async {
    try {
      final favorites = await getFavoriteWorkoutIds();
      if (favorites.contains(workoutId)) {
        favorites.remove(workoutId);
      } else {
        favorites.add(workoutId);
      }

      final prefs = await _preferences;
      return prefs.setStringList(_favoriteWorkoutsKey, favorites.toList());
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      return false;
    }
  }

  Future<bool> isFavorite(String workoutId) async {
    final favorites = await getFavoriteWorkoutIds();
    return favorites.contains(workoutId);
  }

  // ============================================
  // WORKOUT SESSIONS
  // ============================================

  Future<List<WorkoutSession>> getAllSessions() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_workoutSessionsKey);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list.map((e) => WorkoutSession.fromJson(e)).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      }
    } catch (e) {
      debugPrint('Error loading workout sessions: $e');
    }
    return [];
  }

  Future<bool> saveSession(WorkoutSession session) async {
    try {
      final sessions = await getAllSessions();
      final index = sessions.indexWhere((s) => s.id == session.id);
      
      if (index >= 0) {
        sessions[index] = session;
      } else {
        sessions.insert(0, session);
      }

      final prefs = await _preferences;
      final json = jsonEncode(sessions.map((s) => s.toJson()).toList());
      
      // Also update workout completion count
      await _updateWorkoutCompletionCount(session.workoutId);
      
      return prefs.setString(_workoutSessionsKey, json);
    } catch (e) {
      debugPrint('Error saving workout session: $e');
      return false;
    }
  }

  Future<void> _updateWorkoutCompletionCount(String workoutId) async {
    try {
      final prefs = await _preferences;
      final historyJson = prefs.getString(_workoutHistoryKey);
      Map<String, dynamic> history = {};
      
      if (historyJson != null) {
        history = jsonDecode(historyJson);
      }
      
      history[workoutId] = (history[workoutId] ?? 0) + 1;
      await prefs.setString(_workoutHistoryKey, jsonEncode(history));
    } catch (e) {
      debugPrint('Error updating completion count: $e');
    }
  }

  Future<int> getWorkoutCompletionCount(String workoutId) async {
    try {
      final prefs = await _preferences;
      final historyJson = prefs.getString(_workoutHistoryKey);
      if (historyJson != null) {
        final history = jsonDecode(historyJson) as Map<String, dynamic>;
        return history[workoutId] ?? 0;
      }
    } catch (e) {
      debugPrint('Error getting completion count: $e');
    }
    return 0;
  }

  /// Get sessions from a specific date range
  Future<List<WorkoutSession>> getSessionsInRange(DateTime start, DateTime end) async {
    final sessions = await getAllSessions();
    return sessions.where((s) => 
      s.startedAt.isAfter(start) && s.startedAt.isBefore(end)
    ).toList();
  }

  /// Get today's sessions
  Future<List<WorkoutSession>> getTodaySessions() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getSessionsInRange(startOfDay, endOfDay);
  }

  /// Get this week's sessions
  Future<List<WorkoutSession>> getThisWeekSessions() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return getSessionsInRange(start, now.add(const Duration(days: 1)));
  }

  // ============================================
  // STATISTICS
  // ============================================

  Future<WeeklyWorkoutSummary> getWeeklySummary() async {
    final sessions = await getThisWeekSessions();
    final completedSessions = sessions.where((s) => s.wasCompleted).toList();

    // Calculate body part frequency
    final bodyPartFrequency = <String, int>{};
    for (final session in completedSessions) {
      if (session.primaryBodyPart != null) {
        final name = session.primaryBodyPart!.displayName;
        bodyPartFrequency[name] = (bodyPartFrequency[name] ?? 0) + 1;
      }
    }

    // Calculate daily stats
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final dailyStats = <DailyWorkoutStats>[];

    for (int i = 0; i < 7; i++) {
      final date = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i);
      final daySessions = sessions.where((s) =>
        s.startedAt.year == date.year &&
        s.startedAt.month == date.month &&
        s.startedAt.day == date.day &&
        s.wasCompleted
      ).toList();

      dailyStats.add(DailyWorkoutStats(
        date: date,
        workoutsCompleted: daySessions.length,
        totalDurationMinutes: daySessions.fold(0, (sum, s) => sum + (s.durationSeconds ~/ 60)),
        totalCaloriesBurned: daySessions.fold(0, (sum, s) => sum + s.caloriesBurned),
        goalMet: daySessions.isNotEmpty,
      ));
    }

    return WeeklyWorkoutSummary(
      weekStartDate: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      totalWorkouts: completedSessions.length,
      totalMinutes: completedSessions.fold(0, (sum, s) => sum + (s.durationSeconds ~/ 60)),
      totalCalories: completedSessions.fold(0, (sum, s) => sum + s.caloriesBurned),
      currentStreak: await calculateStreak(),
      bodyPartFrequency: bodyPartFrequency,
      dailyStats: dailyStats,
    );
  }

  Future<int> calculateStreak() async {
    final sessions = await getAllSessions();
    if (sessions.isEmpty) return 0;

    int streak = 0;
    DateTime checkDate = DateTime.now();

    while (true) {
      final dayStart = DateTime(checkDate.year, checkDate.month, checkDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final hasWorkout = sessions.any((s) =>
        s.wasCompleted &&
        s.startedAt.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
        s.startedAt.isBefore(dayEnd)
      );

      if (hasWorkout) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (streak == 0 && checkDate.day == DateTime.now().day) {
        // Today hasn't been completed yet, check yesterday
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  Future<Map<String, dynamic>> getAllTimeStats() async {
    final sessions = await getAllSessions();
    final completedSessions = sessions.where((s) => s.wasCompleted).toList();

    return {
      'totalWorkouts': completedSessions.length,
      'totalMinutes': completedSessions.fold<int>(0, (sum, s) => sum + (s.durationSeconds ~/ 60)),
      'totalCalories': completedSessions.fold<int>(0, (sum, s) => sum + s.caloriesBurned),
      'longestStreak': await _getLongestStreak(),
      'currentStreak': await calculateStreak(),
    };
  }

  Future<int> _getLongestStreak() async {
    try {
      final prefs = await _preferences;
      final statsJson = prefs.getString(_statsKey);
      if (statsJson != null) {
        final stats = jsonDecode(statsJson);
        return stats['longestStreak'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error getting longest streak: $e');
    }
    return 0;
  }

  Future<void> updateLongestStreak(int streak) async {
    try {
      final prefs = await _preferences;
      final statsJson = prefs.getString(_statsKey);
      Map<String, dynamic> stats = {};
      
      if (statsJson != null) {
        stats = jsonDecode(statsJson);
      }
      
      final currentLongest = stats['longestStreak'] ?? 0;
      if (streak > currentLongest) {
        stats['longestStreak'] = streak;
        await prefs.setString(_statsKey, jsonEncode(stats));
      }
    } catch (e) {
      debugPrint('Error updating longest streak: $e');
    }
  }

  // ============================================
  // CUSTOM EXERCISES
  // ============================================

  Future<List<Exercise>> getCustomExercises() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_customExercisesKey);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list.map((e) => Exercise.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading custom exercises: $e');
    }
    return [];
  }

  Future<bool> saveCustomExercise(Exercise exercise) async {
    try {
      final exercises = await getCustomExercises();
      final index = exercises.indexWhere((e) => e.id == exercise.id);
      
      if (index >= 0) {
        exercises[index] = exercise;
      } else {
        exercises.add(exercise.copyWith(isCustom: true));
      }

      final prefs = await _preferences;
      final json = jsonEncode(exercises.map((e) => e.toJson()).toList());
      return prefs.setString(_customExercisesKey, json);
    } catch (e) {
      debugPrint('Error saving custom exercise: $e');
      return false;
    }
  }

  /// Get all exercises (built-in + custom)
  Future<List<Exercise>> getAllExercises() async {
    final builtIn = ExerciseLibrary().allExercises;
    final custom = await getCustomExercises();
    return [...builtIn, ...custom];
  }

  /// Get exercise by ID
  Exercise? getExerciseById(String id) {
    return ExerciseLibrary().getById(id);
  }

  // ============================================
  // WEIGHT TRACKING
  // ============================================

  static const String _weightHistoryKey = 'fitness_weight_history';
  static const String _goalWeightKey = 'fitness_goal_weight';

  Future<List<WeightEntry>> getWeightHistory() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_weightHistoryKey);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list.map((e) => WeightEntry.fromJson(e)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      }
    } catch (e) {
      debugPrint('Error loading weight history: $e');
    }
    return [];
  }

  Future<bool> logWeight(double weight) async {
    try {
      final history = await getWeightHistory();
      history.insert(0, WeightEntry(date: DateTime.now(), weight: weight));
      
      // Also update profile
      final profile = await getProfile();
      await saveProfile(profile.copyWith(weightKg: weight));
      
      final prefs = await _preferences;
      final json = jsonEncode(history.map((e) => e.toJson()).toList());
      return prefs.setString(_weightHistoryKey, json);
    } catch (e) {
      debugPrint('Error logging weight: $e');
      return false;
    }
  }

  Future<double?> getGoalWeight() async {
    try {
      final prefs = await _preferences;
      return prefs.getDouble(_goalWeightKey);
    } catch (e) {
      debugPrint('Error getting goal weight: $e');
      return null;
    }
  }

  Future<bool> setGoalWeight(double weight) async {
    try {
      final prefs = await _preferences;
      return prefs.setDouble(_goalWeightKey, weight);
    } catch (e) {
      debugPrint('Error setting goal weight: $e');
      return false;
    }
  }

  // ============================================
  // CHALLENGE PROGRESS
  // ============================================

  static const String _challengeProgressKey = 'fitness_challenge_progress';
  static const String _completedChallengesKey = 'fitness_completed_challenges';

  Future<ChallengeProgress?> getActiveChallengeProgress() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_challengeProgressKey);
      if (json != null) {
        final data = jsonDecode(json);
        final progress = ChallengeProgress.fromJson(data);
        if (progress.isActive) return progress;
      }
    } catch (e) {
      debugPrint('Error loading challenge progress: $e');
    }
    return null;
  }

  Future<bool> saveChallengeProgress(ChallengeProgress progress) async {
    try {
      final prefs = await _preferences;
      return prefs.setString(_challengeProgressKey, jsonEncode(progress.toJson()));
    } catch (e) {
      debugPrint('Error saving challenge progress: $e');
      return false;
    }
  }

  Future<List<ChallengeProgress>> getCompletedChallenges() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_completedChallengesKey);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list.map((e) => ChallengeProgress.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading completed challenges: $e');
    }
    return [];
  }

  Future<bool> completeChallenge(ChallengeProgress progress) async {
    try {
      final completed = progress.copyWith(
        isActive: false,
        completedAt: DateTime.now(),
      );
      
      final list = await getCompletedChallenges();
      list.add(completed);
      
      final prefs = await _preferences;
      await prefs.remove(_challengeProgressKey);
      return prefs.setString(_completedChallengesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Error completing challenge: $e');
      return false;
    }
  }

  // ============================================
  // REMINDERS
  // ============================================

  Future<List<Map<String, dynamic>>> getReminders() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_remindersKey);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error loading reminders: $e');
    }
    return [];
  }

  Future<bool> saveReminders(List<Map<String, dynamic>> reminders) async {
    try {
      final prefs = await _preferences;
      return prefs.setString(_remindersKey, jsonEncode(reminders));
    } catch (e) {
      debugPrint('Error saving reminders: $e');
      return false;
    }
  }

  // ============================================
  // ACHIEVEMENTS & STATS
  // ============================================

  static const String _unlockedAchievementsKey = 'fitness_unlocked_achievements';

  Future<Map<String, bool>> getUnlockedAchievements() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_unlockedAchievementsKey);
      if (json != null) {
        final Map<String, dynamic> data = jsonDecode(json);
        return data.map((k, v) => MapEntry(k, v as bool));
      }
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    }
    return {};
  }

  Future<bool> unlockAchievement(String achievementId) async {
    try {
      final achievements = await getUnlockedAchievements();
      achievements[achievementId] = true;
      final prefs = await _preferences;
      return prefs.setString(_unlockedAchievementsKey, jsonEncode(achievements));
    } catch (e) {
      debugPrint('Error unlocking achievement: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getLifetimeStats() async {
    try {
      final sessions = await getAllSessions();
      
      int totalWorkouts = sessions.length;
      int totalCalories = 0;
      int totalMinutes = 0;
      int currentStreak = 0;
      int longestStreak = 0;

      for (final session in sessions) {
        totalCalories += session.caloriesBurned;
        totalMinutes += session.durationSeconds ~/ 60;
      }

      // Calculate streaks
      if (sessions.isNotEmpty) {
        final sortedSessions = List.of(sessions)
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        
        final today = DateTime.now();
        var checkDate = DateTime(today.year, today.month, today.day);
        var streak = 0;
        
        for (final session in sortedSessions) {
          final sessionDate = DateTime(
            session.startedAt.year,
            session.startedAt.month,
            session.startedAt.day,
          );
          
          if (sessionDate == checkDate || 
              sessionDate == checkDate.subtract(const Duration(days: 1))) {
            streak++;
            checkDate = sessionDate.subtract(const Duration(days: 1));
          } else if (sessionDate.isBefore(checkDate)) {
            break;
          }
        }
        
        currentStreak = streak;
        longestStreak = streak; // Simplified - would need historical tracking for true longest
      }

      return {
        'totalWorkouts': totalWorkouts,
        'totalCalories': totalCalories,
        'totalMinutes': totalMinutes,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      };
    } catch (e) {
      debugPrint('Error getting lifetime stats: $e');
      return {
        'totalWorkouts': 0,
        'totalCalories': 0,
        'totalMinutes': 0,
        'currentStreak': 0,
        'longestStreak': 0,
      };
    }
  }

  // ============================================
  // CLEAR DATA
  // ============================================

  Future<void> clearAllData() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(_profileKey);
      await prefs.remove(_customWorkoutsKey);
      await prefs.remove(_customExercisesKey);
      await prefs.remove(_workoutSessionsKey);
      await prefs.remove(_favoriteWorkoutsKey);
      await prefs.remove(_workoutHistoryKey);
      await prefs.remove(_achievementsKey);
      await prefs.remove(_statsKey);
      await prefs.remove(_remindersKey);
      debugPrint('Fitness data cleared');
    } catch (e) {
      debugPrint('Error clearing fitness data: $e');
    }
  }
}
