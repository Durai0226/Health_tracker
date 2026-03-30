import 'package:flutter/foundation.dart';
import '../../../core/services/notification_service.dart';
import '../models/mood_streak.dart';
import '../models/mood_insight.dart';
import 'mood_firestore_service.dart';

/// Notification service for mood tracking feature
/// Handles daily reminders, multiple check-ins, streak notifications, and smart alerts
class MoodNotificationService {
  static final MoodNotificationService _instance = MoodNotificationService._internal();
  factory MoodNotificationService() => _instance;
  MoodNotificationService._internal();

  final NotificationService _notificationService = NotificationService();
  final MoodFirestoreService _firestoreService = MoodFirestoreService();

  // Notification IDs
  static const int _dailyReminderId = 50000;
  static const int _morningCheckInId = 50001;
  static const int _afternoonCheckInId = 50002;
  static const int _eveningCheckInId = 50003;
  static const int _streakReminderId = 50010;
  static const int _trendAlertId = 50020;

  // Notification messages
  static const List<String> _morningMessages = [
    "Good morning! ☀️ How are you feeling today?",
    "Rise and shine! 🌅 Take a moment to check in with yourself",
    "Morning! 🌞 Start your day by logging your mood",
    "Hey there! 👋 How did you wake up feeling?",
  ];

  static const List<String> _afternoonMessages = [
    "Afternoon check! 🌤️ How's your day going?",
    "Mid-day pause 🧘 Take a breath and log your mood",
    "How are things going? 💭 Track your afternoon mood",
    "Quick check-in! ⏰ How are you feeling right now?",
  ];

  static const List<String> _eveningMessages = [
    "Evening reflection 🌙 How was your day?",
    "Wind down time 🌆 Reflect on your mood today",
    "Day's end check-in 🌃 How are you feeling?",
    "Time to reflect 💫 Log your evening mood",
  ];

  static const List<String> _streakMessages = [
    "🔥 Don't break your streak! Log your mood today",
    "💪 Keep the momentum going! Check in now",
    "⭐ You're doing great! Continue your streak",
    "🎯 Stay on track! Log your mood for today",
  ];

  /// Initialize notification service
  Future<void> init() async {
    await _notificationService.init();
    debugPrint('✓ MoodNotificationService initialized');
  }

  /// Schedule all mood notifications based on settings
  Future<void> scheduleNotifications() async {
    try {
      final settings = await _firestoreService.getSettings();
      
      // Cancel existing mood notifications first
      await cancelAllMoodNotifications();
      
      // Schedule daily reminder
      if (settings.dailyReminderEnabled) {
        await _scheduleDailyReminder(
          settings.dailyReminderHour,
          settings.dailyReminderMinute,
        );
      }
      
      // Schedule morning check-in
      if (settings.morningCheckInEnabled) {
        await _scheduleMorningCheckIn(settings.morningCheckInHour);
      }
      
      // Schedule afternoon check-in
      if (settings.afternoonCheckInEnabled) {
        await _scheduleAfternoonCheckIn(settings.afternoonCheckInHour);
      }
      
      // Schedule evening check-in
      if (settings.eveningCheckInEnabled) {
        await _scheduleEveningCheckIn(settings.eveningCheckInHour);
      }
      
      debugPrint('✓ Mood notifications scheduled');
    } catch (e) {
      debugPrint('❌ Error scheduling mood notifications: $e');
    }
  }

  /// Schedule daily reminder
  Future<void> _scheduleDailyReminder(int hour, int minute) async {
    final message = _getRandomMessage(_morningMessages);
    
    await _notificationService.scheduleFitnessReminder(
      id: _dailyReminderId,
      title: 'Mood Check-in 💭',
      body: message,
      hour: hour,
      minute: minute,
      frequency: 'daily',
    );
    
    debugPrint('✓ Daily mood reminder scheduled at $hour:$minute');
  }

  /// Schedule morning check-in
  Future<void> _scheduleMorningCheckIn(int hour) async {
    final message = _getRandomMessage(_morningMessages);
    
    await _notificationService.scheduleFitnessReminder(
      id: _morningCheckInId,
      title: 'Morning Check-in ☀️',
      body: message,
      hour: hour,
      minute: 0,
      frequency: 'daily',
    );
    
    debugPrint('✓ Morning check-in scheduled at $hour:00');
  }

  /// Schedule afternoon check-in
  Future<void> _scheduleAfternoonCheckIn(int hour) async {
    final message = _getRandomMessage(_afternoonMessages);
    
    await _notificationService.scheduleFitnessReminder(
      id: _afternoonCheckInId,
      title: 'Afternoon Check-in 🌤️',
      body: message,
      hour: hour,
      minute: 0,
      frequency: 'daily',
    );
    
    debugPrint('✓ Afternoon check-in scheduled at $hour:00');
  }

  /// Schedule evening check-in
  Future<void> _scheduleEveningCheckIn(int hour) async {
    final message = _getRandomMessage(_eveningMessages);
    
    await _notificationService.scheduleFitnessReminder(
      id: _eveningCheckInId,
      title: 'Evening Reflection 🌙',
      body: message,
      hour: hour,
      minute: 0,
      frequency: 'daily',
    );
    
    debugPrint('✓ Evening check-in scheduled at $hour:00');
  }

  /// Send streak milestone notification
  Future<void> sendStreakMilestoneNotification(int streakDays) async {
    String title;
    String body;
    
    if (streakDays == 7) {
      title = '🎉 One Week Streak!';
      body = 'Amazing! You\'ve logged your mood for 7 days straight!';
    } else if (streakDays == 14) {
      title = '🔥 Two Weeks Strong!';
      body = '14 days of tracking! You\'re building a great habit!';
    } else if (streakDays == 21) {
      title = '💪 Three Weeks!';
      body = '21 days! They say it takes 21 days to form a habit!';
    } else if (streakDays == 30) {
      title = '🏆 One Month Milestone!';
      body = '30 days of consistent mood tracking! Incredible!';
    } else if (streakDays == 50) {
      title = '🚀 50 Day Streak!';
      body = 'Half a century! You\'re unstoppable!';
    } else if (streakDays == 100) {
      title = '👑 100 Day Legend!';
      body = 'Triple digits! You\'re a mood tracking champion!';
    } else if (streakDays == 365) {
      title = '🎊 One Year Anniversary!';
      body = '365 days of tracking your mood! You\'re legendary!';
    } else if (streakDays % 100 == 0) {
      title = '🌟 ${streakDays} Day Milestone!';
      body = '$streakDays days of mood tracking! Keep shining!';
    } else {
      return; // Not a milestone
    }
    
    await _notificationService.showInstantNotification(
      id: _streakReminderId + streakDays,
      title: title,
      body: body,
    );
    
    debugPrint('✓ Streak milestone notification sent: $streakDays days');
  }

  /// Send streak at risk notification
  Future<void> sendStreakAtRiskNotification(MoodStreak streak) async {
    if (!streak.canContinueStreak || streak.hasEntryToday) return;
    
    final message = _getRandomMessage(_streakMessages);
    
    await _notificationService.showInstantNotification(
      id: _streakReminderId,
      title: '🔥 ${streak.currentStreak} Day Streak at Risk!',
      body: message,
    );
    
    debugPrint('✓ Streak at risk notification sent');
  }

  /// Send mood trend alert
  Future<void> sendMoodTrendAlert({
    required bool isNegative,
    required String message,
  }) async {
    final settings = await _firestoreService.getSettings();
    if (!settings.moodTrendAlertsEnabled) return;
    
    String title;
    String body;
    
    if (isNegative) {
      title = '💙 We\'re Here For You';
      body = message.isNotEmpty 
          ? message 
          : 'We noticed you\'ve been feeling down lately. Remember, it\'s okay to not be okay. Take care of yourself! 💙';
    } else {
      title = '🌟 You\'re Doing Great!';
      body = message.isNotEmpty 
          ? message 
          : 'Your mood has been positive lately! Keep up the great work! 🎉';
    }
    
    await _notificationService.showInstantNotification(
      id: _trendAlertId,
      title: title,
      body: body,
    );
    
    debugPrint('✓ Mood trend alert sent: isNegative=$isNegative');
  }

  /// Cancel all mood-related notifications
  Future<void> cancelAllMoodNotifications() async {
    await _notificationService.cancelNotification(_dailyReminderId);
    await _notificationService.cancelNotification(_morningCheckInId);
    await _notificationService.cancelNotification(_afternoonCheckInId);
    await _notificationService.cancelNotification(_eveningCheckInId);
    await _notificationService.cancelNotification(_streakReminderId);
    await _notificationService.cancelNotification(_trendAlertId);
    
    debugPrint('✓ All mood notifications cancelled');
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationService.cancelNotification(id);
  }

  /// Update notification settings
  Future<void> updateSettings(MoodSettings settings) async {
    await _firestoreService.saveSettings(settings);
    await scheduleNotifications();
  }

  /// Get random message from list
  String _getRandomMessage(List<String> messages) {
    final index = DateTime.now().millisecondsSinceEpoch % messages.length;
    return messages[index];
  }

  /// Check and send streak notifications
  Future<void> checkAndSendStreakNotifications() async {
    try {
      final settings = await _firestoreService.getSettings();
      if (!settings.streakNotificationsEnabled) return;
      
      final streak = await _firestoreService.getStreak();
      
      // Check for milestones
      if (MoodStreak.standardMilestones.contains(streak.currentStreak)) {
        if (!streak.milestones.contains(streak.currentStreak)) {
          await sendStreakMilestoneNotification(streak.currentStreak);
        }
      }
      
      // Check if streak is at risk (evening check)
      final now = DateTime.now();
      if (now.hour >= 20 && !streak.hasEntryToday && streak.currentStreak > 0) {
        await sendStreakAtRiskNotification(streak);
      }
    } catch (e) {
      debugPrint('❌ Error checking streak notifications: $e');
    }
  }

  /// Analyze mood trends and send alerts if needed
  Future<void> analyzeMoodTrendsAndAlert() async {
    try {
      final settings = await _firestoreService.getSettings();
      if (!settings.moodTrendAlertsEnabled) return;
      
      final insight = await _firestoreService.getWeeklyInsight();
      
      // Check for concerning patterns
      if (insight.trends.isNotEmpty) {
        for (final trend in insight.trends) {
          if (trend.type == TrendType.declining && trend.change < -1.0) {
            await sendMoodTrendAlert(
              isNegative: true,
              message: trend.description,
            );
            break;
          }
        }
      }
      
      // Check for prolonged negative moods
      if (insight.averagePositivity < 2.0 && insight.totalEntries >= 5) {
        await sendMoodTrendAlert(
          isNegative: true,
          message: 'We\'ve noticed your mood has been low this week. Remember to reach out if you need support. 💙',
        );
      }
    } catch (e) {
      debugPrint('❌ Error analyzing mood trends: $e');
    }
  }
}

// Extension for NotificationService to add missing method
extension MoodNotificationExtension on NotificationService {
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    // Use the existing notification service to show instant notification
    // This is a wrapper that uses the internal notification plugin
    try {
      await scheduleMedicineReminder(
        id: id,
        medicineName: body,
        hour: DateTime.now().hour,
        minute: DateTime.now().minute,
        frequency: 'once',
      );
    } catch (e) {
      debugPrint('❌ Error showing instant notification: $e');
    }
  }
}

