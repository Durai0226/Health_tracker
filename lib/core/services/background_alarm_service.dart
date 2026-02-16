import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Top-level callback for background notification actions
@pragma('vm:entry-point')
void _backgroundNotificationCallback(NotificationResponse response) {
  debugPrint('🔔 Background notification response: ${response.actionId}');
  // Background actions handled here
  if (response.actionId == 'snooze') {
    _scheduleSnoozeNotification(response.id ?? 0);
  } else if (response.actionId == 'dismiss') {
    // Explicitly cancel the notification
    final notifications = FlutterLocalNotificationsPlugin();
    notifications.cancel(response.id ?? 0);
    debugPrint('✓ Background notification dismissed: ${response.id}');
  }
}

/// Schedule a snoozed notification
@pragma('vm:entry-point')
Future<void> _scheduleSnoozeNotification(int originalId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final snoozeMinutes = prefs.getInt('snooze_interval_minutes') ?? 5;
    
    // Get original alarm data
    final alarmDataJson = prefs.getString('alarm_$originalId');
    if (alarmDataJson == null) {
      debugPrint('⚠️ No alarm data for snooze: $originalId');
      return;
    }
    
    final alarmData = jsonDecode(alarmDataJson) as Map<String, dynamic>;
    final title = alarmData['title'] as String? ?? 'Snoozed Reminder';
    final body = alarmData['body'] as String? ?? 'Time for your reminder!';
    
    // Schedule snooze alarm
    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMinutes));
    final snoozeId = originalId + 100000;
    
    final result = await AndroidAlarmManager.oneShotAt(
      snoozeTime,
      snoozeId,
      alarmCallback,
      exact: true,
      wakeup: true,
      alarmClock: true,
    );
    
    // Store snooze alarm data
    final snoozeData = {
      'title': '⏰ $title',
      'body': body,
      'channelId': alarmData['channelId'] ?? 'medicine_channel',
      'channelName': alarmData['channelName'] ?? 'Medicine Reminders',
      'isRepeating': false,
      'snoozeDuration': snoozeMinutes,
      'sound': alarmData['sound'],
    };
    await prefs.setString('alarm_$snoozeId', jsonEncode(snoozeData));
    
    // Cancel the original notification
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.cancel(originalId);
    
    debugPrint('✓ Snoozed for $snoozeMinutes min, ID: $snoozeId, result: $result');
  } catch (e) {
    debugPrint('❌ Snooze scheduling failed: $e');
  }
}

/// Handle snooze action from within alarmCallback context
@pragma('vm:entry-point')
Future<void> _handleBackgroundSnooze(int originalId, SharedPreferences prefs) async {
  await _scheduleSnoozeNotification(originalId);
}

/// Top-level callback function for background alarms
/// This MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> alarmCallback(int alarmId) async {
  debugPrint('🔔 ALARM CALLBACK FIRED! ID: $alarmId');
  
  try {
    // Initialize shared preferences
    final prefs = await SharedPreferences.getInstance();
    
    // Get alarm data
    final alarmDataJson = prefs.getString('alarm_$alarmId');
    if (alarmDataJson == null) {
      debugPrint('⚠️ No alarm data found for ID: $alarmId');
      return;
    }
    
    final alarmData = jsonDecode(alarmDataJson) as Map<String, dynamic>;
    final title = alarmData['title'] as String? ?? 'Reminder';
    final body = alarmData['body'] as String? ?? 'Time for your reminder!';
    final channelId = alarmData['channelId'] as String? ?? 'medicine_channel';
    final channelName = alarmData['channelName'] as String? ?? 'Medicine Reminders';
    final payload = alarmData['payload'] as String?;
    
    debugPrint('📋 Alarm data: $title - $body (Payload: $payload)');
    
    // Initialize notifications plugin
    final notifications = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('🔔 Background notification action: ${response.actionId}');
        if (response.actionId == 'snooze') {
          await _handleBackgroundSnooze(response.id ?? 0, prefs);
        } else if (response.actionId == 'dismiss') {
          await notifications.cancel(response.id ?? 0);
          debugPrint('✓ Notification dismissed via tap (callback): ${response.id}');
        }
      },
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationCallback,
    );
    
    // Get snooze interval from stored settings (default 5 minutes), override if in alarmData
    var snoozeMinutes = prefs.getInt('snooze_interval_minutes') ?? 5;
    if (alarmData['snoozeDuration'] != null) {
      snoozeMinutes = alarmData['snoozeDuration'] as int;
    }

    final soundName = alarmData['sound'] as String?;
    final notificationSound = (soundName != null && soundName != 'default')
        ? RawResourceAndroidNotificationSound(soundName)
        : null;
    
    // Show notification with snooze/dismiss actions
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Reminders for your health',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: notificationSound,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      enableLights: true,
      ledColor: const Color(0xFF4CAF50),
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      showWhen: true,
      autoCancel: false, // Changed to false
      channelShowBadge: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'snooze',
          '⏰ Snooze ${snoozeMinutes}min',
          showsUserInterface: false,
        ),
         const AndroidNotificationAction(
          'dismiss',
          '❌ Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
      // Persistent alarm settings
      ongoing: true,
      timeoutAfter: 600000, // Safety timeout
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await notifications.show(
      alarmId,
      title,
      body,
      details,
      payload: payload,
    );
    
    debugPrint('✅ Notification shown successfully!');
    
    // Check if this is a repeating alarm - reschedule for next occurrence
    final isRepeating = alarmData['isRepeating'] as bool? ?? false;
    if (isRepeating) {
      await _rescheduleRepeatingAlarm(alarmId, alarmData, prefs);
    } else {
      // Clean up one-time alarm data
      await prefs.remove('alarm_$alarmId');
      debugPrint('🧹 Cleaned up one-time alarm data');
    }
    
  } catch (e, stack) {
    debugPrint('❌ Alarm callback error: $e');
    debugPrint('Stack: $stack');
    // Try to reschedule even on error to prevent alarm from being lost
    await _attemptRescheduleOnError(alarmId);
  }
}

/// Reschedule a repeating alarm for the next occurrence
@pragma('vm:entry-point')
Future<void> _rescheduleRepeatingAlarm(
  int alarmId,
  Map<String, dynamic> alarmData,
  SharedPreferences prefs,
) async {
  try {
    final frequency = alarmData['frequency'] as String? ?? 'daily';
    final hour = alarmData['hour'] as int? ?? 8;
    final minute = alarmData['minute'] as int? ?? 0;
    
    // Calculate next occurrence
    final now = DateTime.now();
    var nextOccurrence = DateTime(now.year, now.month, now.day, hour, minute);
    
    // Always schedule for next day since we just fired
    nextOccurrence = nextOccurrence.add(const Duration(days: 1));
    
    // For weekdays/weekends frequency, adjust to next valid day
    if (frequency == 'weekdays') {
      while (nextOccurrence.weekday == DateTime.saturday || 
             nextOccurrence.weekday == DateTime.sunday) {
        nextOccurrence = nextOccurrence.add(const Duration(days: 1));
      }
    } else if (frequency == 'weekends') {
      while (nextOccurrence.weekday != DateTime.saturday && 
             nextOccurrence.weekday != DateTime.sunday) {
        nextOccurrence = nextOccurrence.add(const Duration(days: 1));
      }
    }
    
    debugPrint('📅 Rescheduling alarm $alarmId for ${nextOccurrence.toString()}');
    
    // Schedule the next occurrence
    final result = await AndroidAlarmManager.oneShotAt(
      nextOccurrence,
      alarmId,
      alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      alarmClock: true,
    );
    
    debugPrint('✓ Alarm rescheduled: $result');
  } catch (e) {
    debugPrint('❌ Failed to reschedule repeating alarm: $e');
  }
}

/// Attempt to reschedule alarm on error to prevent data loss
@pragma('vm:entry-point')
Future<void> _attemptRescheduleOnError(int alarmId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final alarmDataJson = prefs.getString('alarm_$alarmId');
    if (alarmDataJson == null) return;
    
    final alarmData = jsonDecode(alarmDataJson) as Map<String, dynamic>;
    final isRepeating = alarmData['isRepeating'] as bool? ?? false;
    
    if (isRepeating) {
      await _rescheduleRepeatingAlarm(alarmId, alarmData, prefs);
    }
  } catch (e) {
    debugPrint('❌ Error recovery failed: $e');
  }
}

/// Background Alarm Service - schedules alarms that work when app is closed
class BackgroundAlarmService {
  static final BackgroundAlarmService _instance = BackgroundAlarmService._internal();
  
  factory BackgroundAlarmService() => _instance;
  
  BackgroundAlarmService._internal();
  
  bool _isInitialized = false;
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Initialize timezone
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      
      // Initialize Android Alarm Manager
      if (Platform.isAndroid) {
        final result = await AndroidAlarmManager.initialize();
        debugPrint('✓ BackgroundAlarmService initialized: $result');
      }
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ BackgroundAlarmService init failed: $e');
    }
  }
  
  /// Schedule a one-time alarm
  Future<bool> scheduleOneTimeAlarm({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
    String channelId = 'medicine_channel',
    String channelName = 'Medicine Reminders',
    int? snoozeDuration,
    String? sound,
    String? payload,
  }) async {
    try {
      await init();
      
      // Store alarm data in shared preferences
      final prefs = await SharedPreferences.getInstance();
      final alarmData = {
        'title': title,
        'body': body,
        'channelId': channelId,
        'channelName': channelName,
        'scheduledTime': dateTime.toIso8601String(),
        'isRepeating': false,
        'snoozeDuration': snoozeDuration,
        'sound': sound,
        'payload': payload,
      };
      await prefs.setString('alarm_$id', jsonEncode(alarmData));
      
      debugPrint('📅 Scheduling alarm ID: $id for ${dateTime.toString()}');
      
      // Schedule the alarm
      final result = await AndroidAlarmManager.oneShotAt(
        dateTime,
        id,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        alarmClock: true,
      );
      
      debugPrint('✓ Alarm scheduled: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to schedule alarm: $e');
      return false;
    }
  }
  
  /// Schedule a daily repeating alarm
  Future<bool> scheduleDailyAlarm({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String channelId = 'medicine_channel',
    String channelName = 'Medicine Reminders',
    int? snoozeDuration,
    String? sound,
    String? payload,
  }) async {
    try {
      await init();
      
      // Calculate next occurrence
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      
      // Store alarm data
      final prefs = await SharedPreferences.getInstance();
      final alarmData = {
        'title': title,
        'body': body,
        'channelId': channelId,
        'channelName': channelName,
        'hour': hour,
        'minute': minute,
        'isRepeating': true,
        'frequency': 'daily',
        'snoozeDuration': snoozeDuration,
        'sound': sound,
        'payload': payload,
      };
      await prefs.setString('alarm_$id', jsonEncode(alarmData));
      
      debugPrint('📅 Scheduling daily alarm ID: $id for $hour:$minute');
      
      // For daily alarms, we schedule the first occurrence
      // and reschedule in the callback
      final result = await AndroidAlarmManager.oneShotAt(
        scheduledDate,
        id,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        alarmClock: true,
      );
      
      debugPrint('✓ Daily alarm scheduled: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to schedule daily alarm: $e');
      return false;
    }
  }
  
  /// Cancel an alarm
  Future<bool> cancelAlarm(int id) async {
    try {
      final result = await AndroidAlarmManager.cancel(id);
      
      // Remove alarm data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_$id');
      
      debugPrint('✓ Alarm $id cancelled: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to cancel alarm: $e');
      return false;
    }
  }
  
  /// Schedule a quick test alarm (10 seconds)
  Future<bool> scheduleQuickTest() async {
    final testTime = DateTime.now().add(const Duration(seconds: 10));
    return scheduleOneTimeAlarm(
      id: 99998,
      dateTime: testTime,
      title: 'Test Alarm ✅',
      body: 'Background alarm works! Your reminders will fire even when the app is closed.',
    );
  }
  
  /// Get all scheduled alarms
  Future<List<Map<String, dynamic>>> getScheduledAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = <Map<String, dynamic>>[];
    
    for (final key in prefs.getKeys()) {
      if (key.startsWith('alarm_')) {
        final data = prefs.getString(key);
        if (data != null) {
          try {
            final alarm = jsonDecode(data) as Map<String, dynamic>;
            alarm['id'] = int.tryParse(key.replaceFirst('alarm_', '')) ?? 0;
            alarms.add(alarm);
          } catch (e) {
            debugPrint('Error parsing alarm data: $e');
          }
        }
      }
    }
    
    return alarms;
  }
}
