import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// Core service for habit tracking functionality
class HabitService extends ChangeNotifier {
  static final HabitService _instance = HabitService._internal();
  factory HabitService() => _instance;
  HabitService._internal();

  static const String _habitsKey = 'habit_tracker_habits';
  static const String _tasksKey = 'habit_tracker_tasks';
  static const String _logsKey = 'habit_tracker_logs';
  static const String _groupsKey = 'habit_tracker_groups';
  static const String _streaksKey = 'habit_tracker_streaks';
  static const String _characterKey = 'habit_tracker_character';

  final _uuid = const Uuid();
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Data
  List<Habit> _habits = [];
  List<HabitTask> _tasks = [];
  List<HabitLog> _logs = [];
  List<HabitGroup> _groups = [];
  Map<String, HabitStreak> _streaks = {};
  HabitCharacter? _character;
  DateTime _selectedDate = DateTime.now();

  // Getters
  bool get isInitialized => _isInitialized;
  List<Habit> get habits => List.unmodifiable(_habits);
  List<HabitTask> get tasks => List.unmodifiable(_tasks);
  List<HabitLog> get logs => List.unmodifiable(_logs);
  List<HabitGroup> get groups => List.unmodifiable(_groups);
  Map<String, HabitStreak> get streaks => Map.unmodifiable(_streaks);
  HabitCharacter? get character => _character;
  DateTime get selectedDate => _selectedDate;

  // Filtered lists
  List<Habit> get activeHabits => _habits.where((h) => !h.isArchived && !h.isPaused).toList();
  List<Habit> get archivedHabits => _habits.where((h) => h.isArchived).toList();
  List<HabitTask> get incompleteTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<HabitTask> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    await _loadData();
    _isInitialized = true;
    debugPrint('✓ HabitService initialized');
    notifyListeners();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadHabits(),
      _loadTasks(),
      _loadLogs(),
      _loadGroups(),
      _loadStreaks(),
      _loadCharacter(),
    ]);
  }

  // ==========================================
  // HABITS CRUD
  // ==========================================

  Future<void> _loadHabits() async {
    final json = _prefs?.getString(_habitsKey);
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _habits = list.map((e) => Habit.fromJson(e)).toList();
    }
  }

  Future<void> _saveHabits() async {
    final json = jsonEncode(_habits.map((h) => h.toJson()).toList());
    await _prefs?.setString(_habitsKey, json);
  }

  /// Create a new habit
  Future<Habit> createHabit({
    required String name,
    required int iconCodePoint,
    required int colorValue,
    HabitType habitType = HabitType.regular,
    RepeatType repeatType = RepeatType.daily,
    List<int> repeatDays = const [0, 1, 2, 3, 4, 5, 6],
    int repeatXDays = 1,
    int daysPerWeek = 7,
    HabitTimeOfDay timeOfDay = HabitTimeOfDay.anytime,
    bool hasTarget = false,
    double? targetValue,
    String? targetUnit,
    String? groupId,
    String? notes,
  }) async {
    final now = DateTime.now();
    final habit = Habit(
      id: _uuid.v4(),
      name: name,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      habitType: habitType,
      repeatType: repeatType,
      repeatDays: repeatDays,
      repeatXDays: repeatXDays,
      daysPerWeek: daysPerWeek,
      timeOfDay: timeOfDay,
      hasTarget: hasTarget,
      targetValue: targetValue,
      targetUnit: targetUnit,
      groupId: groupId,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      sortOrder: _habits.length,
    );

    _habits.add(habit);
    _streaks[habit.id] = HabitStreak(habitId: habit.id);
    
    await _saveHabits();
    await _saveStreaks();
    notifyListeners();
    
    return habit;
  }

  /// Update a habit
  Future<void> updateHabit(Habit habit) async {
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index != -1) {
      _habits[index] = habit.copyWith(updatedAt: DateTime.now());
      await _saveHabits();
      notifyListeners();
    }
  }

  /// Delete a habit
  Future<void> deleteHabit(String habitId) async {
    _habits.removeWhere((h) => h.id == habitId);
    _logs.removeWhere((l) => l.habitId == habitId);
    _streaks.remove(habitId);
    
    await _saveHabits();
    await _saveLogs();
    await _saveStreaks();
    notifyListeners();
  }

  /// Archive/unarchive a habit
  Future<void> toggleArchiveHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index != -1) {
      _habits[index] = _habits[index].copyWith(
        isArchived: !_habits[index].isArchived,
        updatedAt: DateTime.now(),
      );
      await _saveHabits();
      notifyListeners();
    }
  }

  /// Pause/unpause a habit
  Future<void> togglePauseHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index != -1) {
      _habits[index] = _habits[index].copyWith(
        isPaused: !_habits[index].isPaused,
        updatedAt: DateTime.now(),
      );
      await _saveHabits();
      notifyListeners();
    }
  }

  /// Get habit by ID
  Habit? getHabit(String habitId) {
    try {
      return _habits.firstWhere((h) => h.id == habitId);
    } catch (_) {
      return null;
    }
  }

  /// Get habits for a specific date
  List<Habit> getHabitsForDate(DateTime date) {
    return activeHabits.where((h) => h.shouldDoOnDay(date)).toList();
  }

  /// Get habits by time of day
  List<Habit> getHabitsByTimeOfDay(HabitTimeOfDay timeOfDay, DateTime date) {
    return getHabitsForDate(date).where((h) => h.timeOfDay == timeOfDay).toList();
  }

  /// Get habits by group
  List<Habit> getHabitsByGroup(String? groupId) {
    if (groupId == null || groupId == 'all') return activeHabits;
    return activeHabits.where((h) => h.groupId == groupId).toList();
  }

  // ==========================================
  // TASKS CRUD
  // ==========================================

  Future<void> _loadTasks() async {
    final json = _prefs?.getString(_tasksKey);
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _tasks = list.map((e) => HabitTask.fromJson(e)).toList();
    }
  }

  Future<void> _saveTasks() async {
    final json = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await _prefs?.setString(_tasksKey, json);
  }

  /// Create a new task
  Future<HabitTask> createTask({
    required String name,
    required int iconCodePoint,
    required int colorValue,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? dueTime,
    String? notes,
    String? groupId,
  }) async {
    final task = HabitTask(
      id: _uuid.v4(),
      name: name,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      priority: priority,
      dueDate: dueDate,
      dueTime: dueTime,
      notes: notes,
      groupId: groupId,
      createdAt: DateTime.now(),
      sortOrder: _tasks.length,
    );

    _tasks.add(task);
    await _saveTasks();
    notifyListeners();
    
    return task;
  }

  /// Complete/uncomplete a task
  Future<void> toggleTaskComplete(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(
        isCompleted: !task.isCompleted,
        completedAt: !task.isCompleted ? DateTime.now() : null,
      );
      await _saveTasks();
      notifyListeners();
    }
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    await _saveTasks();
    notifyListeners();
  }

  /// Get tasks for today
  List<HabitTask> getTasksForDate(DateTime date) {
    return _tasks.where((t) {
      if (t.dueDate == null) return true; // No due date = show always
      return t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day;
    }).toList();
  }

  // ==========================================
  // HABIT LOGS
  // ==========================================

  Future<void> _loadLogs() async {
    final json = _prefs?.getString(_logsKey);
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _logs = list.map((e) => HabitLog.fromJson(e)).toList();
    }
  }

  Future<void> _saveLogs() async {
    final json = jsonEncode(_logs.map((l) => l.toJson()).toList());
    await _prefs?.setString(_logsKey, json);
  }

  /// Log a habit completion
  Future<HabitLog> logHabitCompletion({
    required String habitId,
    required DateTime date,
    HabitLogStatus status = HabitLogStatus.completed,
    double? value,
    HabitMood? mood,
    String? notes,
  }) async {
    final habit = getHabit(habitId);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    // Check if already logged for this date
    final existingIndex = _logs.indexWhere(
      (l) => l.habitId == habitId && 
             l.date.year == normalizedDate.year &&
             l.date.month == normalizedDate.month &&
             l.date.day == normalizedDate.day,
    );

    final log = HabitLog(
      id: existingIndex != -1 ? _logs[existingIndex].id : _uuid.v4(),
      habitId: habitId,
      date: normalizedDate,
      status: status,
      value: value,
      targetValue: habit?.targetValue,
      mood: mood,
      notes: notes,
      loggedAt: DateTime.now(),
    );

    if (existingIndex != -1) {
      _logs[existingIndex] = log;
    } else {
      _logs.add(log);
    }

    // Update streak
    if (status == HabitLogStatus.completed) {
      _updateStreak(habitId, normalizedDate);
    }

    await _saveLogs();
    await _saveStreaks();
    notifyListeners();
    
    return log;
  }

  /// Toggle habit completion for a date
  Future<void> toggleHabitCompletion(String habitId, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final existingLog = getLogForDate(habitId, normalizedDate);

    if (existingLog != null && existingLog.isCompleted) {
      // Remove the log (uncomplete)
      _logs.removeWhere((l) => l.id == existingLog.id);
      await _saveLogs();
      notifyListeners();
    } else {
      // Log completion
      await logHabitCompletion(habitId: habitId, date: normalizedDate);
    }
  }

  /// Get log for a specific habit and date
  HabitLog? getLogForDate(String habitId, DateTime date) {
    try {
      return _logs.firstWhere(
        (l) => l.habitId == habitId &&
               l.date.year == date.year &&
               l.date.month == date.month &&
               l.date.day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get all logs for a date
  List<HabitLog> getLogsForDate(DateTime date) {
    return _logs.where(
      (l) => l.date.year == date.year &&
             l.date.month == date.month &&
             l.date.day == date.day,
    ).toList();
  }

  /// Get logs for a habit within date range
  List<HabitLog> getLogsForHabitInRange(String habitId, DateTime start, DateTime end) {
    return _logs.where(
      (l) => l.habitId == habitId &&
             l.date.isAfter(start.subtract(const Duration(days: 1))) &&
             l.date.isBefore(end.add(const Duration(days: 1))),
    ).toList();
  }

  /// Check if habit is completed for a date
  bool isHabitCompletedForDate(String habitId, DateTime date) {
    final log = getLogForDate(habitId, date);
    return log != null && log.isCompleted;
  }

  // ==========================================
  // STREAKS
  // ==========================================

  Future<void> _loadStreaks() async {
    final json = _prefs?.getString(_streaksKey);
    if (json != null) {
      final Map<String, dynamic> map = jsonDecode(json);
      _streaks = map.map((key, value) => MapEntry(key, HabitStreak.fromJson(value)));
    }
  }

  Future<void> _saveStreaks() async {
    final json = jsonEncode(_streaks.map((key, value) => MapEntry(key, value.toJson())));
    await _prefs?.setString(_streaksKey, json);
  }

  void _updateStreak(String habitId, DateTime date) {
    final currentStreak = _streaks[habitId] ?? HabitStreak(habitId: habitId);
    _streaks[habitId] = currentStreak.recordCompletion(date);
  }

  /// Get streak for a habit
  HabitStreak getStreak(String habitId) {
    return _streaks[habitId] ?? HabitStreak(habitId: habitId);
  }

  // ==========================================
  // GROUPS
  // ==========================================

  Future<void> _loadGroups() async {
    final json = _prefs?.getString(_groupsKey);
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _groups = list.map((e) => HabitGroup.fromJson(e)).toList();
    } else {
      // Initialize with default groups
      _groups = HabitGroup.defaultGroups;
      await _saveGroups();
    }
  }

  Future<void> _saveGroups() async {
    final json = jsonEncode(_groups.map((g) => g.toJson()).toList());
    await _prefs?.setString(_groupsKey, json);
  }

  /// Create a custom group
  Future<HabitGroup> createGroup({
    required String name,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    final group = HabitGroup(
      id: _uuid.v4(),
      name: name,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      type: HabitGroupType.custom,
      sortOrder: _groups.length,
      createdAt: DateTime.now(),
    );

    _groups.add(group);
    await _saveGroups();
    notifyListeners();
    
    return group;
  }

  // ==========================================
  // CHARACTER
  // ==========================================

  Future<void> _loadCharacter() async {
    final json = _prefs?.getString(_characterKey);
    if (json != null) {
      _character = HabitCharacter.fromJson(jsonDecode(json));
    } else {
      _character = HabitCharacter.defaultCharacter();
      await _saveCharacter();
    }
  }

  Future<void> _saveCharacter() async {
    if (_character != null) {
      final json = jsonEncode(_character!.toJson());
      await _prefs?.setString(_characterKey, json);
    }
  }

  /// Update character customization
  Future<void> updateCharacter({
    int? headIndex,
    int? topIndex,
    int? bottomIndex,
  }) async {
    if (_character == null) return;
    
    _character = _character!.copyWith(
      headIndex: headIndex ?? _character!.headIndex,
      topIndex: topIndex ?? _character!.topIndex,
      bottomIndex: bottomIndex ?? _character!.bottomIndex,
      updatedAt: DateTime.now(),
    );
    
    await _saveCharacter();
    notifyListeners();
  }

  // ==========================================
  // DATE SELECTION
  // ==========================================

  /// Set selected date
  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  // ==========================================
  // STATISTICS
  // ==========================================

  /// Get daily summary
  DailyHabitSummary getDailySummary(DateTime date) {
    final habitsForDay = getHabitsForDate(date);
    final logsForDay = getLogsForDate(date);
    
    int completed = 0;
    int skipped = 0;
    
    for (final habit in habitsForDay) {
      final log = logsForDay.firstWhere(
        (l) => l.habitId == habit.id,
        orElse: () => HabitLog(
          id: '',
          habitId: habit.id,
          date: date,
          status: HabitLogStatus.missed,
          loggedAt: date,
        ),
      );
      
      if (log.isCompleted) {
        completed++;
      } else if (log.isSkipped) {
        skipped++;
      }
    }
    
    return DailyHabitSummary(
      date: date,
      totalHabits: habitsForDay.length,
      completedHabits: completed,
      skippedHabits: skipped,
      missedHabits: habitsForDay.length - completed - skipped,
    );
  }

  /// Get overall stats
  HabitStats getOverallStats() {
    final today = DateTime.now();
    final todaySummary = getDailySummary(today);
    
    // Calculate weekly completion rate
    double weeklyRate = 0.0;
    int weekDays = 0;
    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final summary = getDailySummary(date);
      if (summary.totalHabits > 0) {
        weeklyRate += summary.completionRate;
        weekDays++;
      }
    }
    if (weekDays > 0) weeklyRate /= weekDays;

    // Calculate monthly completion rate
    double monthlyRate = 0.0;
    int monthDays = 0;
    for (int i = 0; i < 30; i++) {
      final date = today.subtract(Duration(days: i));
      final summary = getDailySummary(date);
      if (summary.totalHabits > 0) {
        monthlyRate += summary.completionRate;
        monthDays++;
      }
    }
    if (monthDays > 0) monthlyRate /= monthDays;

    // Calculate overall streak
    int overallStreak = 0;
    for (int i = 0; i < 365; i++) {
      final date = today.subtract(Duration(days: i));
      final summary = getDailySummary(date);
      if (summary.totalHabits > 0 && summary.isAllCompleted) {
        overallStreak++;
      } else if (i > 0) {
        break;
      }
    }

    return HabitStats(
      totalHabits: _habits.length,
      activeHabits: activeHabits.length,
      completedToday: todaySummary.completedHabits,
      scheduledToday: todaySummary.totalHabits,
      currentOverallStreak: overallStreak,
      weeklyCompletionRate: weeklyRate,
      monthlyCompletionRate: monthlyRate,
    );
  }

  /// Get completion data for chart (last 7 days)
  List<Map<String, dynamic>> getWeeklyChartData() {
    final today = DateTime.now();
    final data = <Map<String, dynamic>>[];
    
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final summary = getDailySummary(date);
      data.add({
        'date': date,
        'dayLabel': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1],
        'completed': summary.completedHabits,
        'total': summary.totalHabits,
        'rate': summary.completionRate,
      });
    }
    
    return data;
  }

  // ==========================================
  // SETTINGS: GOALS
  // ==========================================

  static const String _goalSettingsKey = 'habit_goal_settings';

  Future<Map<String, dynamic>> getGoalSettings() async {
    _prefs ??= await SharedPreferences.getInstance();
    final json = _prefs?.getString(_goalSettingsKey);
    if (json != null) {
      return Map<String, dynamic>.from(jsonDecode(json));
    }
    return {
      'dailyTarget': 3,
      'weeklyTarget': 5,
      'streakGoal': 30,
      'showStreakReminders': true,
    };
  }

  Future<void> saveGoalSettings(Map<String, dynamic> settings) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_goalSettingsKey, jsonEncode(settings));
    notifyListeners();
  }

  // ==========================================
  // SETTINGS: REMINDERS
  // ==========================================

  static const String _reminderSettingsKey = 'habit_reminder_settings';

  Future<Map<String, dynamic>> getReminderSettings() async {
    _prefs ??= await SharedPreferences.getInstance();
    final json = _prefs?.getString(_reminderSettingsKey);
    if (json != null) {
      return Map<String, dynamic>.from(jsonDecode(json));
    }
    return {
      'morningReminder': true,
      'afternoonReminder': false,
      'eveningReminder': true,
      'morningTime': '8:00',
      'afternoonTime': '14:00',
      'eveningTime': '20:00',
      'streakAtRisk': true,
      'weeklyProgress': true,
    };
  }

  Future<void> saveReminderSettings(Map<String, dynamic> settings) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_reminderSettingsKey, jsonEncode(settings));
    notifyListeners();
  }

  // ==========================================
  // ACHIEVEMENTS
  // ==========================================

  Future<List<HabitAchievementData>> getAchievements() async {
    final stats = getOverallStats();
    final achievements = <HabitAchievementData>[];

    // Define all achievements
    final allAchievements = [
      _checkAchievement('first_habit', 'First Step', 'Create your first habit', '🌱', 
          _habits.isNotEmpty),
      _checkAchievement('streak_7', 'Week Warrior', 'Maintain a 7-day streak', '🔥', 
          stats.currentOverallStreak >= 7, stats.currentOverallStreak >= 7 ? DateTime.now() : null),
      _checkAchievement('streak_30', 'Monthly Master', 'Maintain a 30-day streak', '⚡', 
          stats.currentOverallStreak >= 30, stats.currentOverallStreak >= 30 ? DateTime.now() : null),
      _checkAchievement('streak_100', 'Century Club', 'Maintain a 100-day streak', '💯', 
          stats.currentOverallStreak >= 100, stats.currentOverallStreak >= 100 ? DateTime.now() : null),
      _checkAchievement('habits_5', 'Habit Builder', 'Create 5 habits', '🏗️', 
          _habits.length >= 5),
      _checkAchievement('habits_10', 'Habit Master', 'Create 10 habits', '🎯', 
          _habits.length >= 10),
      _checkAchievement('perfect_week', 'Perfect Week', 'Complete all habits for 7 days', '🌟', 
          stats.weeklyCompletionRate >= 1.0),
      _checkAchievement('early_bird', 'Early Bird', 'Complete morning habits 5 days in a row', '🌅', 
          _checkMorningStreak(5)),
      _checkAchievement('night_owl', 'Night Owl', 'Complete evening habits 5 days in a row', '🌙', 
          _checkEveningStreak(5)),
      _checkAchievement('completionist', 'Completionist', 'Log 100 habit completions', '🏆', 
          _logs.where((l) => l.isCompleted).length >= 100),
    ];

    achievements.addAll(allAchievements);
    return achievements;
  }

  HabitAchievementData _checkAchievement(String id, String title, String description, 
      String emoji, bool isEarned, [DateTime? earnedAt]) {
    return HabitAchievementData(
      id: id,
      title: title,
      description: description,
      emoji: emoji,
      isEarned: isEarned,
      earnedAt: isEarned ? (earnedAt ?? DateTime.now()) : null,
    );
  }

  bool _checkMorningStreak(int days) {
    final morningHabits = _habits.where((h) => h.timeOfDay == HabitTimeOfDay.morning).toList();
    if (morningHabits.isEmpty) return false;
    
    final today = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      for (final habit in morningHabits) {
        if (!isHabitCompletedForDate(habit.id, date)) {
          return false;
        }
      }
    }
    return true;
  }

  bool _checkEveningStreak(int days) {
    final eveningHabits = _habits.where((h) => h.timeOfDay == HabitTimeOfDay.evening).toList();
    if (eveningHabits.isEmpty) return false;
    
    final today = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      for (final habit in eveningHabits) {
        if (!isHabitCompletedForDate(habit.id, date)) {
          return false;
        }
      }
    }
    return true;
  }
}

/// Achievement data model for service
class HabitAchievementData {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool isEarned;
  final DateTime? earnedAt;

  const HabitAchievementData({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.isEarned = false,
    this.earnedAt,
  });
}
