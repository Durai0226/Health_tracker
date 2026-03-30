/// Exam Prep Notification Service
/// Handles 8 types of notifications for exam preparation

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_notification_model.dart';

class ExamNotificationService with ChangeNotifier {
  static const String _settingsKey = 'exam_notification_settings';
  static const String _notificationsKey = 'exam_notifications';
  static const String _streakKey = 'exam_study_streak';
  static const String _examDatesKey = 'exam_dates';
  static const String _achievementsKey = 'exam_achievements';

  ExamNotificationSettings _settings = const ExamNotificationSettings();
  List<ExamNotification> _notifications = [];
  StudyStreak _streak = const StudyStreak();
  List<ExamDate> _examDates = [];
  List<Achievement> _achievements = [];

  ExamNotificationSettings get settings => _settings;
  List<ExamNotification> get notifications => _notifications;
  StudyStreak get streak => _streak;
  List<ExamDate> get examDates => _examDates;
  List<Achievement> get achievements => _achievements;

  List<ExamNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  List<ExamDate> get upcomingExams =>
      _examDates.where((e) => e.isUpcoming).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  List<Achievement> get unlockedAchievements =>
      _achievements.where((a) => a.isUnlocked).toList();

  Future<void> initialize() async {
    await _loadSettings();
    await _loadNotifications();
    await _loadStreak();
    await _loadExamDates();
    await _loadAchievements();
    _initializeDefaultAchievements();
    notifyListeners();
  }

  // Settings Management
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_settingsKey);
    if (json != null) {
      _settings = ExamNotificationSettings.fromJson(jsonDecode(json));
    }
  }

  Future<void> updateSettings(ExamNotificationSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    _scheduleNotifications();
    notifyListeners();
  }

  // Notifications
  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_notificationsKey);
    if (json != null) {
      final list = jsonDecode(json) as List;
      _notifications = list.map((e) => ExamNotification.fromJson(e)).toList();
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationsKey,
      jsonEncode(_notifications.map((n) => n.toJson()).toList()),
    );
  }

  Future<void> addNotification(ExamNotification notification) async {
    _notifications.insert(0, notification);
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> clearAllNotifications() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }

  // Streak Management
  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_streakKey);
    if (json != null) {
      _streak = StudyStreak.fromJson(jsonDecode(json));
    }
  }

  Future<void> _saveStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streakKey, jsonEncode(_streak.toJson()));
  }

  Future<void> recordPracticeSession() async {
    final oldStreak = _streak.currentStreak;
    _streak = _streak.recordPractice();
    await _saveStreak();

    // Check for streak achievements
    if (_streak.currentStreak > oldStreak) {
      _checkStreakAchievements(_streak.currentStreak);
    }

    notifyListeners();
  }

  // Exam Dates
  Future<void> _loadExamDates() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_examDatesKey);
    if (json != null) {
      final list = jsonDecode(json) as List;
      _examDates = list.map((e) => ExamDate.fromJson(e)).toList();
    }
  }

  Future<void> _saveExamDates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _examDatesKey,
      jsonEncode(_examDates.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addExamDate(ExamDate examDate) async {
    _examDates.add(examDate);
    await _saveExamDates();
    if (examDate.reminderSet && _settings.examDateAlertsEnabled) {
      _scheduleExamDateReminders(examDate);
    }
    notifyListeners();
  }

  Future<void> removeExamDate(String examDateId) async {
    _examDates.removeWhere((e) => e.id == examDateId);
    await _saveExamDates();
    notifyListeners();
  }

  void _scheduleExamDateReminders(ExamDate examDate) {
    for (final daysBefore in _settings.examDateAlertDaysBefore) {
      final reminderDate = examDate.date.subtract(Duration(days: daysBefore));
      if (reminderDate.isAfter(DateTime.now())) {
        final notification = ExamNotification(
          id: 'exam_${examDate.id}_$daysBefore',
          type: ExamNotificationType.examDateAlert,
          title: '📅 ${examDate.examName} in $daysBefore days',
          body: daysBefore == 1 
              ? 'Your exam is tomorrow! Good luck!' 
              : 'Keep preparing! $daysBefore days left.',
          scheduledTime: reminderDate,
          payload: {'examId': examDate.examId, 'examDateId': examDate.id},
        );
        addNotification(notification);
      }
    }
  }

  // Achievements
  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_achievementsKey);
    if (json != null) {
      final list = jsonDecode(json) as List;
      _achievements = list.map((e) => Achievement.fromJson(e)).toList();
    }
  }

  Future<void> _saveAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _achievementsKey,
      jsonEncode(_achievements.map((a) => a.toJson()).toList()),
    );
  }

  void _initializeDefaultAchievements() {
    if (_achievements.isEmpty) {
      _achievements = [
        // Questions answered
        const Achievement(
          id: 'questions_100',
          title: 'Century Maker',
          description: 'Answer 100 questions',
          icon: '💯',
          type: AchievementType.questionsAnswered,
          targetValue: 100,
        ),
        const Achievement(
          id: 'questions_500',
          title: 'Question Master',
          description: 'Answer 500 questions',
          icon: '🎯',
          type: AchievementType.questionsAnswered,
          targetValue: 500,
        ),
        const Achievement(
          id: 'questions_1000',
          title: 'Knowledge Seeker',
          description: 'Answer 1000 questions',
          icon: '🏆',
          type: AchievementType.questionsAnswered,
          targetValue: 1000,
        ),
        // Streaks
        const Achievement(
          id: 'streak_7',
          title: 'Week Warrior',
          description: 'Maintain a 7-day streak',
          icon: '🔥',
          type: AchievementType.streakDays,
          targetValue: 7,
        ),
        const Achievement(
          id: 'streak_30',
          title: 'Month Master',
          description: 'Maintain a 30-day streak',
          icon: '⚡',
          type: AchievementType.streakDays,
          targetValue: 30,
        ),
        const Achievement(
          id: 'streak_100',
          title: 'Centurion',
          description: 'Maintain a 100-day streak',
          icon: '👑',
          type: AchievementType.streakDays,
          targetValue: 100,
        ),
        // Mock tests
        const Achievement(
          id: 'mock_5',
          title: 'Test Taker',
          description: 'Complete 5 mock tests',
          icon: '📝',
          type: AchievementType.mockTestsCompleted,
          targetValue: 5,
        ),
        const Achievement(
          id: 'mock_25',
          title: 'Mock Master',
          description: 'Complete 25 mock tests',
          icon: '📊',
          type: AchievementType.mockTestsCompleted,
          targetValue: 25,
        ),
        // Perfect scores
        const Achievement(
          id: 'perfect_1',
          title: 'Perfect Start',
          description: 'Get a perfect score in any test',
          icon: '⭐',
          type: AchievementType.perfectScore,
          targetValue: 1,
        ),
        const Achievement(
          id: 'perfect_5',
          title: 'Perfectionist',
          description: 'Get 5 perfect scores',
          icon: '🌟',
          type: AchievementType.perfectScore,
          targetValue: 5,
        ),
      ];
      _saveAchievements();
    }
  }

  void _checkStreakAchievements(int streakDays) {
    for (int i = 0; i < _achievements.length; i++) {
      final achievement = _achievements[i];
      if (achievement.type == AchievementType.streakDays &&
          !achievement.isUnlocked &&
          achievement.targetValue != null &&
          streakDays >= achievement.targetValue!) {
        _unlockAchievement(i);
      }
    }
  }

  Future<void> updateAchievementProgress(
    AchievementType type,
    int value, {
    bool increment = true,
  }) async {
    for (int i = 0; i < _achievements.length; i++) {
      final achievement = _achievements[i];
      if (achievement.type == type && !achievement.isUnlocked) {
        final newValue = increment ? achievement.currentValue + value : value;
        _achievements[i] = Achievement(
          id: achievement.id,
          title: achievement.title,
          description: achievement.description,
          icon: achievement.icon,
          type: achievement.type,
          targetValue: achievement.targetValue,
          currentValue: newValue,
          unlockedAt: achievement.targetValue != null && newValue >= achievement.targetValue!
              ? DateTime.now()
              : null,
        );

        if (_achievements[i].isUnlocked) {
          _sendAchievementNotification(_achievements[i]);
        }
      }
    }
    await _saveAchievements();
    notifyListeners();
  }

  void _unlockAchievement(int index) {
    final achievement = _achievements[index];
    _achievements[index] = Achievement(
      id: achievement.id,
      title: achievement.title,
      description: achievement.description,
      icon: achievement.icon,
      type: achievement.type,
      targetValue: achievement.targetValue,
      currentValue: achievement.targetValue ?? 0,
      unlockedAt: DateTime.now(),
    );
    _saveAchievements();
    _sendAchievementNotification(_achievements[index]);
    notifyListeners();
  }

  void _sendAchievementNotification(Achievement achievement) {
    if (_settings.achievementsEnabled) {
      final notification = ExamNotification(
        id: 'achievement_${achievement.id}_${DateTime.now().millisecondsSinceEpoch}',
        type: ExamNotificationType.achievement,
        title: '🎉 Achievement Unlocked!',
        body: '${achievement.icon} ${achievement.title}: ${achievement.description}',
        scheduledTime: DateTime.now(),
        payload: {'achievementId': achievement.id},
      );
      addNotification(notification);
    }
  }

  // Notification Scheduling
  void _scheduleNotifications() {
    // This would integrate with flutter_local_notifications
    // For now, we'll just prepare the notifications

    if (_settings.dailyPracticeEnabled) {
      _scheduleDailyPracticeReminder();
    }

    if (_settings.streakAlertsEnabled) {
      _scheduleStreakAlert();
    }

    if (_settings.weeklyProgressEnabled) {
      _scheduleWeeklyProgressReport();
    }
  }

  void _scheduleDailyPracticeReminder() {
    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _settings.dailyPracticeTime.hour,
      _settings.dailyPracticeTime.minute,
    );

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // In a real app, this would schedule with flutter_local_notifications
  }

  void _scheduleStreakAlert() {
    if (!_streak.practicedToday) {
      final now = DateTime.now();
      var scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        _settings.streakAlertTime.hour,
        _settings.streakAlertTime.minute,
      );

      if (scheduledTime.isBefore(now)) {
        return; // Don't schedule if time has passed
      }

      // Would schedule: "Don't break your X-day streak!"
    }
  }

  void _scheduleWeeklyProgressReport() {
    // Would schedule weekly report notification
  }

  // Notification Generation
  Future<void> sendDailyPracticeReminder() async {
    if (!_settings.dailyPracticeEnabled) return;

    final messages = [
      'Time for your daily practice! 📚',
      'Keep the momentum going! Practice now.',
      'A few questions a day keeps failure away! 💪',
      'Ready to sharpen your skills today?',
      'Your exam prep awaits! Let\'s go!',
    ];

    final notification = ExamNotification(
      id: 'daily_${DateTime.now().millisecondsSinceEpoch}',
      type: ExamNotificationType.dailyPractice,
      title: '📖 Daily Practice Reminder',
      body: messages[DateTime.now().day % messages.length],
      scheduledTime: DateTime.now(),
    );

    await addNotification(notification);
  }

  Future<void> sendStreakAlert() async {
    if (!_settings.streakAlertsEnabled) return;
    if (_streak.practicedToday) return;

    final notification = ExamNotification(
      id: 'streak_${DateTime.now().millisecondsSinceEpoch}',
      type: ExamNotificationType.streakAlert,
      title: '🔥 Protect Your Streak!',
      body: _streak.currentStreak > 0
          ? 'Don\'t lose your ${_streak.currentStreak}-day streak! Practice now.'
          : 'Start a new streak today! Every journey begins with a single step.',
      scheduledTime: DateTime.now(),
    );

    await addNotification(notification);
  }

  Future<void> sendCurrentAffairsUpdate(String headline) async {
    if (!_settings.currentAffairsEnabled) return;

    final notification = ExamNotification(
      id: 'ca_${DateTime.now().millisecondsSinceEpoch}',
      type: ExamNotificationType.currentAffairs,
      title: '📰 Current Affairs Update',
      body: headline,
      scheduledTime: DateTime.now(),
    );

    await addNotification(notification);
  }

  Future<void> sendPerformanceAlert({
    required String subject,
    required double accuracy,
    required String suggestion,
  }) async {
    if (!_settings.performanceAlertsEnabled) return;

    final notification = ExamNotification(
      id: 'perf_${DateTime.now().millisecondsSinceEpoch}',
      type: ExamNotificationType.performanceAlert,
      title: '📊 Performance Insight: $subject',
      body: 'Accuracy: ${accuracy.toStringAsFixed(1)}%. $suggestion',
      scheduledTime: DateTime.now(),
      payload: {'subject': subject, 'accuracy': accuracy},
    );

    await addNotification(notification);
  }

  Future<void> sendWeeklyProgressReport(WeeklyProgressReport report) async {
    if (!_settings.weeklyProgressEnabled) return;

    final notification = ExamNotification(
      id: 'weekly_${DateTime.now().millisecondsSinceEpoch}',
      type: ExamNotificationType.weeklyProgress,
      title: '📈 Your Weekly Progress',
      body: report.summaryText,
      scheduledTime: DateTime.now(),
      payload: report.toJson(),
    );

    await addNotification(notification);
  }

  Future<void> sendMockTestReminder({
    required String testName,
    required DateTime testTime,
  }) async {
    if (!_settings.mockTestRemindersEnabled) return;

    final notification = ExamNotification(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      type: ExamNotificationType.mockTestReminder,
      title: '⏰ Mock Test Reminder',
      body: '$testName starts in ${_settings.mockTestReminderMinutesBefore} minutes!',
      scheduledTime: testTime.subtract(
        Duration(minutes: _settings.mockTestReminderMinutesBefore),
      ),
      payload: {'testName': testName, 'testTime': testTime.toIso8601String()},
    );

    await addNotification(notification);
  }

  // Statistics
  int get totalQuestionsAnswered {
    int total = 0;
    for (final achievement in _achievements) {
      if (achievement.type == AchievementType.questionsAnswered) {
        total = achievement.currentValue > total ? achievement.currentValue : total;
      }
    }
    return total;
  }

  int get totalMockTestsCompleted {
    int total = 0;
    for (final achievement in _achievements) {
      if (achievement.type == AchievementType.mockTestsCompleted) {
        total = achievement.currentValue > total ? achievement.currentValue : total;
      }
    }
    return total;
  }
}
