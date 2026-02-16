import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/foundation.dart';
import '../models/cycle_log.dart';
import '../services/period_storage_service.dart';
import '../services/period_prediction_service.dart';
import '../services/period_health_tips_service.dart';

class PeriodNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _periodReminderId = 5000;
  static const int _ovulationReminderId = 5001;
  static const int _fertileWindowReminderId = 5002;
  static const int _pmsReminderId = 5003;
  static const int _dailyTipReminderId = 5004;

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    debugPrint('PeriodNotificationService initialized');
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('Period notification tapped: ${response.payload}');
  }

  static Future<void> scheduleAllReminders() async {
    final settings = PeriodStorageService.getSettings();
    final currentCycle = PeriodStorageService.getCurrentCycle();

    if (currentCycle == null) return;

    // Cancel existing reminders
    await cancelAllReminders();

    final nextPeriod = PeriodPredictionService.predictNextPeriod(
      currentCycle.startDate,
      currentCycle.cycleLength,
    );

    // Schedule period reminder
    if (settings.enablePeriodReminders) {
      await _schedulePeriodReminder(
        nextPeriod,
        settings.periodReminderDaysBefore,
        settings.reminderTime,
        settings.privacyMode,
        settings.showMotivationalMessages,
      );
    }

    // Schedule ovulation reminder
    if (settings.enableOvulationReminders) {
      final ovulation = PeriodPredictionService.predictOvulation(
        currentCycle.startDate,
        currentCycle.cycleLength,
      );
      await _scheduleOvulationReminder(ovulation, settings.reminderTime, settings.privacyMode);
    }

    // Schedule fertile window reminder
    if (settings.enableFertileWindowReminders) {
      final fertileWindow = PeriodPredictionService.predictFertileWindow(
        currentCycle.startDate,
        currentCycle.cycleLength,
      );
      await _scheduleFertileWindowReminder(
        fertileWindow['start']!,
        settings.reminderTime,
        settings.privacyMode,
      );
    }

    // Schedule PMS reminder
    if (settings.enablePMSReminders) {
      final pmsStart = nextPeriod.subtract(Duration(days: settings.pmsReminderDaysBefore));
      await _schedulePMSReminder(pmsStart, settings.reminderTime, settings.privacyMode);
    }

    debugPrint('Period reminders scheduled');
  }

  static Future<void> _schedulePeriodReminder(
    DateTime nextPeriod,
    int daysBefore,
    DateTime? reminderTime,
    bool privacyMode,
    bool showMotivation,
  ) async {
    final reminderDate = nextPeriod.subtract(Duration(days: daysBefore));
    final now = DateTime.now();

    if (reminderDate.isBefore(now)) return;

    final scheduledTime = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      reminderTime?.hour ?? 9,
      reminderTime?.minute ?? 0,
    );

    String title = privacyMode ? 'Health Reminder' : 'Period Coming Soon';
    String body = privacyMode
        ? 'Tap to check your health tracker'
        : 'Your period is expected in $daysBefore days. Time to prepare!';

    if (showMotivation && !privacyMode) {
      final messages = PeriodHealthTipsService.getMotivationalMessages(CyclePhase.pms);
      if (messages.isNotEmpty) {
        body = '$body\n${messages.first}';
      }
    }

    await _scheduleNotification(
      id: _periodReminderId,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      payload: 'period_reminder',
    );
  }

  static Future<void> _scheduleOvulationReminder(
    DateTime ovulationDate,
    DateTime? reminderTime,
    bool privacyMode,
  ) async {
    final now = DateTime.now();
    if (ovulationDate.isBefore(now)) return;

    final scheduledTime = DateTime(
      ovulationDate.year,
      ovulationDate.month,
      ovulationDate.day,
      reminderTime?.hour ?? 9,
      reminderTime?.minute ?? 0,
    );

    await _scheduleNotification(
      id: _ovulationReminderId,
      title: privacyMode ? 'Health Update' : 'Ovulation Day',
      body: privacyMode
          ? 'Check your health tracker for important updates'
          : 'Today is your predicted ovulation day. Peak fertility!',
      scheduledTime: scheduledTime,
      payload: 'ovulation_reminder',
    );
  }

  static Future<void> _scheduleFertileWindowReminder(
    DateTime fertileStart,
    DateTime? reminderTime,
    bool privacyMode,
  ) async {
    final now = DateTime.now();
    if (fertileStart.isBefore(now)) return;

    final scheduledTime = DateTime(
      fertileStart.year,
      fertileStart.month,
      fertileStart.day,
      reminderTime?.hour ?? 9,
      reminderTime?.minute ?? 0,
    );

    await _scheduleNotification(
      id: _fertileWindowReminderId,
      title: privacyMode ? 'Health Update' : 'Fertile Window Starting',
      body: privacyMode
          ? 'Check your health tracker'
          : 'Your fertile window is starting today. Plan accordingly!',
      scheduledTime: scheduledTime,
      payload: 'fertile_window_reminder',
    );
  }

  static Future<void> _schedulePMSReminder(
    DateTime pmsStart,
    DateTime? reminderTime,
    bool privacyMode,
  ) async {
    final now = DateTime.now();
    if (pmsStart.isBefore(now)) return;

    final scheduledTime = DateTime(
      pmsStart.year,
      pmsStart.month,
      pmsStart.day,
      reminderTime?.hour ?? 9,
      reminderTime?.minute ?? 0,
    );

    await _scheduleNotification(
      id: _pmsReminderId,
      title: privacyMode ? 'Wellness Reminder' : 'PMS Phase Starting',
      body: privacyMode
          ? 'Time for extra self-care this week'
          : 'PMS phase may begin. Practice self-care and be gentle with yourself.',
      scheduledTime: scheduledTime,
      payload: 'pms_reminder',
    );
  }

  static Future<void> scheduleDailyTipNotification(
    CyclePhase phase,
    int cycleDay,
    DateTime scheduledTime,
  ) async {
    final tip = PeriodHealthTipsService.getDailyTip(phase, cycleDay);

    await _scheduleNotification(
      id: _dailyTipReminderId,
      title: '${tip.icon} ${tip.title}',
      body: tip.description,
      scheduledTime: scheduledTime,
      payload: 'daily_tip',
    );
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'period_channel',
        'Period Tracking',
        channelDescription: 'Notifications for period tracking and reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFE91E63),
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      debugPrint('Scheduled period notification: $title at $scheduledTime');
    } catch (e) {
      debugPrint('Error scheduling period notification: $e');
    }
  }

  static Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'period_channel',
      'Period Tracking',
      channelDescription: 'Notifications for period tracking',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFE91E63),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> cancelAllReminders() async {
    await _notifications.cancel(_periodReminderId);
    await _notifications.cancel(_ovulationReminderId);
    await _notifications.cancel(_fertileWindowReminderId);
    await _notifications.cancel(_pmsReminderId);
    await _notifications.cancel(_dailyTipReminderId);
    debugPrint('All period reminders cancelled');
  }

  static Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
  }

  // Period start/end notifications with optional motivational messages
  static Future<void> notifyPeriodStarted({bool showMotivation = true}) async {
    String body = 'Your period has started. Take care of yourself!';
    if (showMotivation) {
      final messages = PeriodHealthTipsService.getMotivationalMessages(CyclePhase.menstrual);
      if (messages.isNotEmpty) {
        body = messages.first;
      }
    }

    await showInstantNotification(
      title: '🌸 Period Started',
      body: body,
      payload: 'period_started',
    );
  }

  static Future<void> notifyPeriodEnded({bool showMotivation = true}) async {
    String body = 'Your period has ended. You did great!';
    if (showMotivation) {
      final messages = PeriodHealthTipsService.getMotivationalMessages(CyclePhase.follicular);
      if (messages.isNotEmpty) {
        body = messages.first;
      }
    }

    await showInstantNotification(
      title: '✨ Period Ended',
      body: body,
      payload: 'period_ended',
    );
  }
}
