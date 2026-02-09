
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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

    final platform =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await platform?.requestNotificationsPermission();
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap if needed
  }

  Future<void> scheduleMedicineReminder({
    required int id,
    required String medicineName,
    required int hour,
    required int minute,
    required String frequency,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notifications.zonedSchedule(
      id,
      'Medicine Reminder',
      'Time to take $medicineName',
      tzScheduledDate,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: _getMatchComponents(frequency),
    );
  }

  Future<void> scheduleHealthCheckReminder({
    required int id,
    required String checkType, // 'sugar' or 'pressure'
    required int hour,
    required int minute,
    required String frequency,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    final title = checkType == 'sugar' ? 'Sugar Check' : 'BP Check';
    final body = checkType == 'sugar'
        ? 'Time to check your blood sugar 🩸'
        : 'Time to check your blood pressure ❤️';

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: _getMatchComponents(frequency),
    );
  }

  Future<void> scheduleFitnessReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String frequency,
  }) async {
    if (frequency == 'daily') {
      await _scheduleDaily(id, title, body, hour, minute, 'fitness_channel', 'Fitness Reminders');
    } else if (frequency == 'weekdays') {
      // Schedule for Mon(1) to Fri(5)
      for (int i = 1; i <= 5; i++) {
        // Create a unique ID for each day: id * 10 + day
        await _scheduleWeekly(id * 10 + i, title, body, hour, minute, i, 'fitness_channel', 'Fitness Reminders');
      }
    } else if (frequency == 'weekends') {
      // Schedule for Sat(6) and Sun(7)
      for (int i = 6; i <= 7; i++) {
        await _scheduleWeekly(id * 10 + i, title, body, hour, minute, i, 'fitness_channel', 'Fitness Reminders');
      }
    }
  }

  Future<void> _scheduleDaily(
    int id,
    String title,
    String body,
    int hour,
    int minute,
    String channelId,
    String channelName,
  ) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      _notificationDetails(channelId, channelName),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeekly(
    int id,
    String title,
    String body,
    int hour,
    int minute,
    int weekday,
    String channelId,
    String channelName,
  ) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Adjust to the next occurrence of the weekday
    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      _notificationDetails(channelId, channelName),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  NotificationDetails _notificationDetails([String? channelId, String? channelName]) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId ?? 'medicine_channel',
        channelName ?? 'Medicine Reminders',
        channelDescription: 'Reminders for medicines, health checks, and fitness',
        importance: Importance.max,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
      ),
      iOS: const DarwinNotificationDetails(
        sound: 'notification_sound.aiff',
      ),
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelFitnessNotification(int baseId, String frequency) async {
    if (frequency == 'daily') {
      await _notifications.cancel(baseId);
    } else if (frequency == 'weekdays') {
      for (int i = 1; i <= 5; i++) {
        await _notifications.cancel(baseId * 10 + i);
      }
    } else if (frequency == 'weekends') {
      for (int i = 6; i <= 7; i++) {
        await _notifications.cancel(baseId * 10 + i);
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Debug method to show immediate notification
  Future<void> showTestNotification() async {
    await _notifications.show(
      0,
      'Test Notification',
      'This is a test notification with custom sound',
      _notificationDetails(),
    );
  }
}
