import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui; // IsolateNameServer — stop a ringing AlarmScreen
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'clean_storage_service.dart';
import '../../features/medication/models/enhanced_medicine.dart';
import '../../features/medication/models/medicine_schedule.dart' show ScheduledTime;
import '../../features/medication/services/reminder_slot_grouping.dart';
import '../../features/reminders/models/reminder_model.dart';
import '../models/user_settings.dart';
import 'background_alarm_service.dart';
import '../../main.dart';
import '../widgets/toast/toast.dart';

// Top-level function for background notification handling
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('🔔 Background notification action: ${response.actionId}');
  if (response.actionId == 'snooze') {
    _handleBackgroundSnoozeAction(response.id ?? 0, response.payload);
  } else if (response.actionId == 'dismiss') {
    // Explicitly cancel the notification
    final notifications = FlutterLocalNotificationsPlugin();
    notifications.cancel(response.id ?? 0);
    debugPrint('✓ Background notification dismissed: ${response.id}');
  }
}

/// Handle snooze action when app is in background
@pragma('vm:entry-point')
Future<void> _handleBackgroundSnoozeAction(int notificationId, String? payload) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final snoozeMinutes = prefs.getInt('snooze_interval_minutes') ?? 5;
    
    // Initialize timezone. Snooze uses a RELATIVE offset (now + minutes) so the
    // absolute instant is correct regardless, but keep tz.local honest instead
    // of the old hardcoded IST.
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    
    // Calculate snooze time
    final now = tz.TZDateTime.now(tz.local);
    final snoozeTime = now.add(Duration(minutes: snoozeMinutes));
    final snoozeId = notificationId + 100000;

    // Parse the rich `alarm:{json}` payload for a clean title/body — otherwise
    // the raw JSON would be shown as the notification body.
    var snoozeTitle = '⏰ Snoozed Reminder';
    var snoozeBody = 'Time for your reminder!';
    Map<String, dynamic>? decodedPayload;
    if (payload != null && payload.startsWith('alarm:')) {
      try {
        final decoded = jsonDecode(payload.substring('alarm:'.length));
        if (decoded is Map) {
          decodedPayload = Map<String, dynamic>.from(decoded);
          snoozeTitle = '⏰ Snoozed: ${decoded['title'] ?? 'Reminder'}';
          snoozeBody = (decoded['body'] ?? snoozeBody).toString();
        }
      } catch (_) {}
    }

    // Same stable-id + SharedPreferences counter as snoozeReminder (below) —
    // NOT a payload-embedded count. This handler and snoozeReminder register
    // on the SAME plugin instance for the SAME notifications (this one fires
    // when the app is dead at tap time, snoozeReminder when it's alive), so a
    // separate counter here would let alternating foreground/background
    // snooze taps bypass the cap entirely. 'baseId' rides in the payload
    // (falling back to notificationId for a payload that predates this field,
    // i.e. a never-yet-snoozed notification) so this stays correct across any
    // number of hops without needing the CleanStorageService.getReminders()
    // lookup snoozeReminder uses — unsafe to call from this background isolate.
    final baseId = (decodedPayload?['baseId'] as num?)?.toInt() ?? notificationId;
    final isFreshFire = notificationId == baseId;
    final snoozeCountKey = 'snooze_count_$baseId';
    final snoozeCount = isFreshFire ? 0 : (prefs.getInt(snoozeCountKey) ?? 0);

    // See background_alarm_service.dart's _scheduleSnoozeNotification for why
    // this reads the raw pref key rather than CleanStorageService.
    final maxSnoozeCount = prefs.getInt('max_snooze_count') ?? 3;
    if (snoozeCount >= maxSnoozeCount) {
      // The tapped notification is ALREADY gone by this point (Android's
      // ActionBroadcastReceiver auto-cancels for a showsUserInterface:false
      // action) — show a final, snooze-less one rather than lose the
      // reminder entirely. See background_alarm_service.dart's identical fix.
      debugPrint(
          '⏹️ Snooze cap ($maxSnoozeCount) reached for notification $notificationId — showing a final reminder with no snooze option');
      await _showFinalCappedBackgroundNotification(notificationId, snoozeTitle, snoozeBody, payload);
      return;
    }
    await prefs.setInt(snoozeCountKey, snoozeCount + 1);
    final nextPayload = decodedPayload == null
        ? payload
        : 'alarm:${jsonEncode({...decodedPayload, 'baseId': baseId})}';

    // Initialize notifications plugin for background
    final notifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await notifications.initialize(initSettings);

    // Schedule snoozed notification using alarm channel
    await notifications.zonedSchedule(
      snoozeId,
      snoozeTitle,
      snoozeBody,
      snoozeTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel', // Use alarm channel for proper alarm sound
          'Alarm Reminders',
          channelDescription: 'High priority alarm reminders',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: null, // Use system default alarm sound
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          autoCancel: false,
          ongoing: true,
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
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: nextPayload,
    );

    // Cancel the original notification
    await notifications.cancel(notificationId);
    
    debugPrint('✓ Background snooze scheduled for $snoozeMinutes min (ID: $snoozeId)');
  } catch (e) {
    debugPrint('❌ Background snooze failed: $e');
  }
}

/// See background_alarm_service.dart's identical helper — shown once the
/// snooze cap is reached, since the OS already removed the tapped
/// notification by the time this handler runs.
@pragma('vm:entry-point')
Future<void> _showFinalCappedBackgroundNotification(
    int id, String title, String body, String? payload) async {
  try {
    final notifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await notifications.initialize(initSettings);
    await notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarm Reminders',
          channelDescription: 'Reminder (snooze limit reached)',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          autoCancel: true,
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction('dismiss', '❌ Dismiss',
                showsUserInterface: false, cancelNotification: true),
          ],
        ),
      ),
      payload: payload,
    );
  } catch (e) {
    debugPrint('❌ Final capped background notification failed: $e');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  bool _permissionsGranted = false;
  bool _isAppInForeground = true;

  /// Set app foreground state - call from app lifecycle observer
  void setAppForegroundState(bool inForeground) {
    _isAppInForeground = inForeground;
    debugPrint('📱 App foreground state: $inForeground');
  }

  /// Show in-app toast when app is in foreground instead of system notification
  void showInAppToast({
    required String title,
    String? body,
    ToastType type = ToastType.reminder,
    ToastFeature feature = ToastFeature.general,
    VoidCallback? onAction,
    String? actionLabel,
    int? snoozeMinutes,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('⚠️ No context available for in-app toast');
      return;
    }

    // Show premium toast
    if (type == ToastType.reminder) {
      ReminderToast.triggered(
        context,
        title: title,
        body: body,
        snoozeMinutes: snoozeMinutes ?? 5,
        onSnooze: onAction,
      );
    } else {
      ToastService.show(
        context,
        type: type,
        feature: feature,
        title: title,
        message: body,
        action: onAction != null && actionLabel != null
            ? ToastAction(label: actionLabel, onPressed: onAction)
            : null,
      );
    }
    debugPrint('✓ Showed in-app toast: $title');
  }

  /// Check if should show in-app toast instead of system notification
  bool get shouldShowInAppToast => _isAppInForeground;

  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('✓ NotificationService already initialized');
      return;
    }
    
    try {
      // Initialize timezone from the REAL device zone (never hardcode — that
      // fires every reminder at the wrong wall-clock time for users abroad).
      try {
        tz_data.initializeTimeZones();
        final String timeZoneName = await _resolveDeviceTimeZone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('✓ Timezone set to: $timeZoneName');
      } catch (e) {
        debugPrint('⚠️ Timezone init failed, using UTC: $e');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      // Do NOT request permission at plugin init — that fires the iOS system
      // prompt at cold start, before the user has seen the app (kills grant
      // rates and defeats the welcome "Turn on reminders" priming pane). The
      // welcome pane requests it explicitly via requestPermissionsIfNeeded().
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        requestCriticalPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      
      debugPrint('📱 Notification plugin initialized: $initialized');

      _isInitialized = true;
      
      // Defer heavy operations to background
      _initializeBackground();
      
      debugPrint('✓ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ NotificationService init failed: $e');
      _isInitialized = true; // Mark as initialized to prevent loops
    }
  }
  
  /// Initialize heavy operations in background after app startup
  void _initializeBackground() {
    Future(() async {
      try {
        // Initialize Android Alarm Manager
        if (Platform.isAndroid) {
          try {
            await AndroidAlarmManager.initialize();
            debugPrint('✓ AndroidAlarmManager initialized');
          } catch (e) {
            debugPrint('⚠️ AndroidAlarmManager init failed: $e');
          }
        }
        
        // Create notification channels
        await _createNotificationChannels();

        // Request permissions — but NOT at cold start on first launch. The
        // welcome "Turn on reminders" pane primes and requests it there (correct
        // permission-priming UX; an OS prompt before the user sees the app kills
        // grant rates). Returning users already decided, so this stays a
        // harmless re-check for them.
        if (!CleanStorageService.isFirstLaunch) {
          await _requestPermissions();
        }

        debugPrint('✓ Background notification setup complete');
      } catch (e) {
        debugPrint('⚠️ Background notification setup failed: $e');
      }
    });
  }
  
  /// Resolves the device's real IANA timezone (e.g. "America/New_York").
  /// Falls back to UTC on any failure so scheduling never crashes. NEVER
  /// hardcode a zone — that would fire every reminder at the wrong wall-clock
  /// time for any user outside that zone.
  Future<String> _resolveDeviceTimeZone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      return name.trim().isEmpty ? 'UTC' : name;
    } catch (e) {
      debugPrint('⚠️ Could not resolve device timezone: $e');
      return 'UTC';
    }
  }
  
  Future<void> _createNotificationChannels() async {
    try {
      if (Platform.isAndroid) {
        final androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        // Create alarm channel with USAGE_ALARM audio attributes for proper alarm sound
        const alarmChannel = AndroidNotificationChannel(
          'alarm_channel',
          'Alarm Reminders',
          description: 'High priority alarm reminders that ring like real alarms',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
          // This makes it use alarm audio stream - rings even in DND
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );
        
        await androidImplementation?.createNotificationChannel(alarmChannel);
        debugPrint('✓ Created alarm channel with USAGE_ALARM audio');

        final channels = [
          const AndroidNotificationChannel(
            'medicine_channel',
            'Medicine Reminders',
            description: 'Reminders for taking medicines on time',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          const AndroidNotificationChannel(
            'health_channel',
            'Health Check Reminders',
            description: 'Reminders for health check-ups',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          const AndroidNotificationChannel(
            'fitness_channel',
            'Fitness Reminders',
            description: 'Reminders for fitness activities',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          const AndroidNotificationChannel(
            'water_channel',
            'Water Reminders',
            description: 'Reminders to stay hydrated',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          const AndroidNotificationChannel(
            'period_channel',
            'Period Reminders',
            description: 'Reminders for menstrual cycle tracking',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          const AndroidNotificationChannel(
            'reminders_channel',
            'General Reminders',
            description: 'General reminders',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          const AndroidNotificationChannel(
            'mood_channel',
            'Mood Tracker Reminders',
            description: 'Reminders for mood check-ins and streak alerts',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
          ),
          const AndroidNotificationChannel(
            'steps_channel',
            'Step Reminders',
            description: 'Nudges to reach your daily step goal',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
          ),
          const AndroidNotificationChannel(
            'sleep_channel',
            'Sleep & Bedtime',
            description: 'Bedtime and wind-down reminders',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
          ),
        ];

        for (final channel in channels) {
          await androidImplementation?.createNotificationChannel(channel);
        }
        
        debugPrint('✓ Created ${channels.length + 1} notification channels with alarm audio');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to create notification channels: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        // Request notification permission
        final granted = await androidImplementation?.requestNotificationsPermission();
        _permissionsGranted = granted ?? false;
        debugPrint('📱 Android notification permission: $_permissionsGranted');
        
        // CRITICAL: Request exact alarm permission for Android 12+
        // This is required for scheduled notifications to work!
        try {
          final exactAlarmGranted = await androidImplementation?.requestExactAlarmsPermission();
          debugPrint('⏰ Exact alarm permission: $exactAlarmGranted');
          
          // Check if we can schedule exact alarms
          final canSchedule = await androidImplementation?.canScheduleExactNotifications();
          debugPrint('📅 Can schedule exact notifications: $canSchedule');
          
          if (canSchedule == false) {
            debugPrint('⚠️ EXACT ALARMS NOT ALLOWED - Notifications may not fire on time!');
          }
        } catch (e) {
          debugPrint('⚠️ Exact alarm permission check failed: $e');
        }

        // Full-screen intent permission (Android 14+). Without it the reminder
        // is downgraded from the full-screen AlarmScreen to a heads-up banner.
        try {
          final fsi =
              await androidImplementation?.requestFullScreenIntentPermission();
          debugPrint('🖥️ Full-screen intent permission: $fsi');
        } catch (e) {
          debugPrint('⚠️ Full-screen intent permission request failed: $e');
        }

        return _permissionsGranted;
      } else if (Platform.isIOS) {
        final iosImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        
        final granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );
        _permissionsGranted = granted ?? false;
        debugPrint('✓ iOS permissions granted: $_permissionsGranted');
        
        return _permissionsGranted;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Permission request failed: $e');
      return false;
    }
  }
  
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final enabled = await androidImplementation?.areNotificationsEnabled();
        debugPrint('📱 areNotificationsEnabled API returned: $enabled');
        // If null or false, still try to proceed - the API can be unreliable
        return enabled ?? true;
      } else if (Platform.isIOS) {
        return _permissionsGranted;
      }
      return true; // Default to true to allow scheduling attempt
    } catch (e) {
      debugPrint('❌ Check notifications enabled failed: $e');
      return true; // Allow scheduling attempt even if check fails
    }
  }
  
  Future<bool> checkPermissions() async {
    try {
      if (!_isInitialized) {
        debugPrint('⚠️ NotificationService not initialized, initializing...');
        await init();
      }
      
      // Quick permission check without blocking
      if (Platform.isAndroid) {
        try {
          final androidImpl = _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          final enabled = await androidImpl?.areNotificationsEnabled();
          _permissionsGranted = enabled ?? true;
          debugPrint('📱 Android notifications enabled: $_permissionsGranted');
        } catch (e) {
          debugPrint('⚠️ Permission check error: $e');
          _permissionsGranted = true;
        }
      } else {
        _permissionsGranted = true;
      }
      
      return _permissionsGranted;
    } catch (e) {
      debugPrint('❌ Permission check failed: $e');
      return true;
    }
  }
  
  Future<bool> requestPermissionsIfNeeded() async {
    try {
      if (!_isInitialized) {
        await init();
      }
      
      // Always request to make sure
      debugPrint('🔔 Requesting notification permissions...');
      await _requestPermissions();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to request permissions: $e');
      return true; // Try anyway - user may have granted via settings
    }
  }

  /// Tell a live full-screen [AlarmScreen] (same isolate) to stop ringing and
  /// close, when the user acts from the NOTIFICATION instead of the on-screen
  /// buttons. No-op when no alarm screen is showing.
  void _signalStopAlarmScreen(int? id) {
    try {
      ui.IsolateNameServer.lookupPortByName('db_alarm_stop_${id ?? 'default'}')
          ?.send('stop');
    } catch (_) {}
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Notification response: ${response.actionId}');
    // Any action from the notification should also silence + close a ringing
    // full-screen AlarmScreen (its looping player lives in the foreground).
    if (response.actionId != null && response.actionId!.isNotEmpty) {
      _signalStopAlarmScreen(response.id);
    }

    // Handle actions
    if (response.actionId == 'snooze') {
      final settings = CleanStorageService.getUserSettings();
      String? t, b;
      final p = response.payload;
      if (p != null && p.startsWith('alarm:')) {
        final m = parseAlarmPayload(p, response.id);
        t = m['title']?.toString();
        b = m['body']?.toString();
      }
      snoozeReminder(response.id ?? 0, settings.snoozeIntervalMinutes,
          title: t, body: b);
    } else if (response.actionId == 'dismiss') {
       _notifications.cancel(response.id ?? 0);
       debugPrint('✓ Notification dismissed via tap: ${response.id}');
    } else {
      // Normal body-tap → open the full-screen alarm when this is an alarm
      // payload. This makes the redesigned AlarmScreen reachable while the app
      // is already alive (cold-launch is handled separately in main()).
      final p = response.payload;
      if (p != null && p.startsWith('alarm:')) {
        final args = parseAlarmPayload(p, response.id);
        navigatorKey.currentState?.pushNamed('/alarm', arguments: args);
      }
    }
  }
  


  Future<bool> scheduleMedicineReminder({
    required int id,
    required String medicineName,
    required int hour,
    required int minute,
    required String frequency,
    String? scheduleJson,
    String? medicineId,
  }) async {
    try {
      debugPrint('🔔 Attempting to schedule medicine reminder at $hour:$minute');
      
      // Ensure initialized
      if (!_isInitialized) {
        debugPrint('⚠️ NotificationService not initialized, initializing now...');
        try {
          await init();
        } catch (e) {
          debugPrint('❌ Init failed: $e - continuing anyway');
        }
      }
      
      // Request permissions but don't block on failure
      await checkPermissions();
      
      debugPrint('✓ Proceeding with scheduling');

      // Use BackgroundAlarmService for Android (works when app is closed)
      if (Platform.isAndroid) {
        final alarmService = BackgroundAlarmService();
        final result = await alarmService.scheduleDailyAlarm(
          id: id,
          hour: hour,
          minute: minute,
          title: 'Medicine Reminder 💊',
          body: 'Time to take $medicineName',
          channelId: 'medicine_channel',
          // Route the full-screen alarm to the AlarmScreen with the real name.
          payload: _buildAlarmPayload(
              id, 'Time for your $medicineName', 'Medicine reminder', null,
              medicineId: medicineId, hour: hour, minute: minute),
          // Serialized schedule → the alarm callback gates firing to active days
          // (fixes non-daily regimens alarming every day).
          scheduleJson: scheduleJson,
        );
        debugPrint('✓ Background alarm scheduled for medicine reminder');
        return result;
      }

      // Fallback for iOS - use zonedSchedule
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
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
        'Medicine Reminder 💊',
        'Time to take $medicineName',
        scheduledDate,
        _notificationDetails(priority: ReminderPriority.high),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: _getMatchComponents(frequency),
        // Route to the full-screen AlarmScreen with the real medicine name
        // (was `medicine:$name`, which never opened the alarm).
        payload: _buildAlarmPayload(
            id, 'Time for your $medicineName', 'Medicine reminder', null,
            medicineId: medicineId, hour: hour, minute: minute),
      );

      debugPrint('✓ Scheduled medicine reminder at ${scheduledDate.hour}:${scheduledDate.minute}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule medicine reminder: $e');
      return false;
    }
  }

  /// Schedule ONE Android alarm for every medicine due at [slot]'s exact clock
  /// time (Phase 1 grouping — see reminder_slot_grouping.dart). Android-only:
  /// `zonedSchedule` (the iOS fallback) has no grouping mechanism, so iOS
  /// keeps scheduling one medicine at a time via [scheduleMedicineReminder].
  /// The notification's actual title/body/InboxStyle/payload are resolved at
  /// FIRE time (`alarmCallback`), since which medicines are due can change
  /// day to day (specific-days / cyclical regimens) even though the slot id
  /// (a pure function of hour:minute) never does.
  Future<bool> scheduleMedicineSlotReminder(ReminderSlot slot) async {
    if (!Platform.isAndroid) return false;
    try {
      if (!_isInitialized) {
        try {
          await init();
        } catch (e) {
          debugPrint('❌ Init failed: $e - continuing anyway');
        }
      }
      await checkPermissions();

      final solo = slot.medicines.length == 1;
      final title = 'Medicine Reminder 💊';
      final body = solo
          ? 'Time to take ${slot.medicines.single.name}'
          : '${slot.medicines.length} medicines due now';

      final result = await BackgroundAlarmService().scheduleDailyAlarm(
        id: slot.notificationId,
        hour: slot.hour,
        minute: slot.minute,
        title: title,
        body: body,
        channelId: 'medicine_channel',
        medicines: slot.medicines.map((m) => m.toJson()).toList(),
      );
      debugPrint(
          '✓ Background alarm scheduled for medicine slot ${slot.hour}:${slot.minute} (${slot.medicines.length} medicine(s))');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to schedule medicine slot reminder: $e');
      return false;
    }
  }

  /// Schedules the first nudge of an opt-in reminder window (Phase 4) for
  /// one medicine's dose. Android-only, like [scheduleMedicineSlotReminder] —
  /// windowed doses are excluded from slot grouping entirely (see
  /// `groupRemindersBySlot`), so this is a structurally separate path, not a
  /// variant of the slot scheduler.
  Future<bool> scheduleMedicineWindowNudge({
    required int id,
    required EnhancedMedicine medicine,
    required ScheduledTime time,
    required List<int> nudgeMinutes,
    required String scheduleJson,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      if (!_isInitialized) {
        try {
          await init();
        } catch (e) {
          debugPrint('❌ Init failed: $e - continuing anyway');
        }
      }
      await checkPermissions();

      final result = await BackgroundAlarmService().scheduleWindowNudge(
        id: id,
        medicineId: medicine.id,
        medicineName: buildMedicineReminderLine(medicine, time),
        hour: time.hour,
        minute: time.minute,
        nudgeMinutes: nudgeMinutes,
        scheduleJson: scheduleJson,
      );
      debugPrint(
          '✓ Background alarm scheduled for window nudge ${medicine.name} at ${time.hour}:${time.minute}');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to schedule medicine window nudge: $e');
      return false;
    }
  }

  /// Reserved id for the sleep/bedtime reminder — kept well clear of medicine
  /// and water (900000-block) ids so it can never clobber a critical reminder.
  static const int bedtimeReminderId = 910000;

  /// Schedule (or cancel) a gentle daily wind-down reminder on the dedicated
  /// [sleep_channel].
  ///
  /// Deliberately NON-alarm and safe next to the medicine core: Importance.high
  /// (not max), **inexact** scheduling (the exact-alarm budget is reserved for
  /// medicine), no full-screen intent, a reminder category, and its own reserved
  /// id — so it can never hide, replace, or out-rank a medicine reminder. Fires
  /// daily at [minuteOfDay]. Passing `enabled: false` just cancels it.
  Future<void> scheduleBedtimeReminder({
    required bool enabled,
    required int minuteOfDay,
  }) async {
    try {
      await _notifications.cancel(bedtimeReminderId);
      if (!enabled) {
        debugPrint('✓ Bedtime reminder cancelled');
        return;
      }
      if (!_isInitialized) {
        try {
          await init();
        } catch (_) {}
      }
      if (!await checkPermissions()) {
        debugPrint('❌ Bedtime reminder: notifications not permitted');
        return;
      }

      final hour = (minuteOfDay ~/ 60) % 24;
      final minute = minuteOfDay % 60;
      final now = tz.TZDateTime.now(tz.local);
      var when =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'sleep_channel',
          'Sleep & Bedtime',
          channelDescription: 'Bedtime and wind-down reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          // Intentionally NOT full-screen and NOT on the alarm channel.
        ),
      );

      await _notifications.zonedSchedule(
        bedtimeReminderId,
        'Wind-down time 🌙',
        'A calm moment now helps you sleep better tonight.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('✓ Bedtime reminder at $hour:$minute (inexact, sleep_channel)');
    } catch (e) {
      debugPrint('❌ Bedtime reminder schedule failed: $e');
    }
  }

  /// Reserved id for the optional daily wake alarm (own block, clear of medicine).
  static const int wakeAlarmId = 910002;

  /// Schedule (or cancel) a plain daily wake alarm at [hour]:[minute].
  ///
  /// Unlike the gentle bedtime/step reminders, a wake alarm legitimately uses
  /// the exact-alarm + full-screen path (the user asked to be woken), routed
  /// through the same reliable [BackgroundAlarmService] the medicine core uses —
  /// but with its OWN reserved id so it never collides with a dose alarm. This
  /// is the plain-window tier only; no sleep-stage detection is claimed.
  Future<void> scheduleWakeAlarm({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    try {
      if (Platform.isAndroid) {
        await BackgroundAlarmService().cancelAlarm(wakeAlarmId);
      }
      await _notifications.cancel(wakeAlarmId);
      if (!enabled) {
        debugPrint('✓ Wake alarm cancelled');
        return;
      }
      if (!_isInitialized) {
        try {
          await init();
        } catch (_) {}
      }
      if (!await checkPermissions()) {
        debugPrint('❌ Wake alarm: notifications not permitted');
        return;
      }

      const title = 'Wake up ☀️';
      const body = 'Good morning — time to start your day.';
      final payload = _buildAlarmPayload(wakeAlarmId, title, body, null);

      if (Platform.isAndroid) {
        await BackgroundAlarmService().scheduleDailyAlarm(
          id: wakeAlarmId,
          hour: hour,
          minute: minute,
          title: title,
          body: body,
          channelId: 'alarm_channel',
          channelName: 'Alarm Reminders',
          payload: payload,
        );
        debugPrint('✓ Wake alarm scheduled at $hour:$minute');
        return;
      }

      // iOS fallback (dev only — release is Android): exact daily zonedSchedule.
      final now = tz.TZDateTime.now(tz.local);
      var when =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      await _notifications.zonedSchedule(
        wakeAlarmId,
        title,
        body,
        when,
        _notificationDetails(priority: ReminderPriority.high),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      debugPrint('✓ Wake alarm scheduled (iOS) at $hour:$minute');
    } catch (e) {
      debugPrint('❌ Wake alarm schedule failed: $e');
    }
  }

  /// Reserved id for the evening step reminder (own block, clear of medicine).
  static const int stepReminderId = 910001;

  /// Schedule (or cancel) a gentle daily evening step reminder on [steps_channel].
  ///
  /// Deliberately NOT the data-aware "X steps to go" variant (that would need a
  /// cold background isolate to re-open Drift at fire time, and could show a
  /// stale number). This is a calm, generic, opt-in nudge at a user-set time —
  /// Importance.high (not max), inexact, no full-screen, its own id — so it can
  /// never crowd out or clobber a medicine reminder.
  Future<void> scheduleStepReminder({
    required bool enabled,
    required int minuteOfDay,
  }) async {
    try {
      await _notifications.cancel(stepReminderId);
      if (!enabled) {
        debugPrint('✓ Step reminder cancelled');
        return;
      }
      if (!_isInitialized) {
        try {
          await init();
        } catch (_) {}
      }
      if (!await checkPermissions()) {
        debugPrint('❌ Step reminder: notifications not permitted');
        return;
      }

      final hour = (minuteOfDay ~/ 60) % 24;
      final minute = minuteOfDay % 60;
      final now = tz.TZDateTime.now(tz.local);
      var when =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'steps_channel',
          'Step Reminders',
          channelDescription: 'Nudges to reach your daily step goal',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
      );

      await _notifications.zonedSchedule(
        stepReminderId,
        'A little movement? 🚶',
        'A short walk now could close today\'s step goal.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('✓ Step reminder at $hour:$minute (inexact, steps_channel)');
    } catch (e) {
      debugPrint('❌ Step reminder schedule failed: $e');
    }
  }

  Future<bool> scheduleHealthCheckReminder({
    required int id,
    required String checkType,
    required int hour,
    required int minute,
    required String frequency,
  }) async {
    try {
      if (!await checkPermissions()) {
        debugPrint('❌ Cannot schedule: Permissions not granted');
        return false;
      }

      final title = checkType == 'sugar' ? 'Sugar Check 🩸' : 'BP Check ❤️';
      final body = checkType == 'sugar'
          ? 'Time to check your blood sugar'
          : 'Time to check your blood pressure';

      // Use BackgroundAlarmService for Android
      if (Platform.isAndroid) {
        final alarmService = BackgroundAlarmService();
        final result = await alarmService.scheduleDailyAlarm(
          id: id,
          hour: hour,
          minute: minute,
          title: title,
          body: body,
          channelId: 'health_channel',
          channelName: 'Health Check Reminders',
          payload: _buildAlarmPayload(id, title, body, null),
        );
        debugPrint('✓ Background health alarm scheduled: $result');
        return result;
      }

      // Fallback for iOS
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
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
        scheduledDate,
        _notificationDetails(priority: ReminderPriority.high),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: _getMatchComponents(frequency),
        payload: _buildAlarmPayload(id, title, body, null),
      );

      debugPrint('✓ Scheduled health check: $title at ${scheduledDate.hour}:${scheduledDate.minute}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule health check: $e');
      return false;
    }
  }

  Future<bool> scheduleFitnessReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String frequency,
  }) async {
    try {
      if (!await checkPermissions()) {
        debugPrint('❌ Cannot schedule: Permissions not granted');
        return false;
      }

      // Use BackgroundAlarmService for Android
      if (Platform.isAndroid) {
        final alarmService = BackgroundAlarmService();
        final result = await alarmService.scheduleDailyAlarm(
          id: id,
          hour: hour,
          minute: minute,
          title: title,
          body: body,
          channelId: 'fitness_channel',
          channelName: 'Fitness Reminders',
          payload: _buildAlarmPayload(id, title, body, null),
        );
        debugPrint('✓ Background fitness alarm scheduled: $result');
        return result;
      }

      // Fallback for iOS
      if (frequency == 'daily') {
        await _scheduleDaily(id, title, body, hour, minute, 'fitness_channel', 'Fitness Reminders', payload: _buildAlarmPayload(id, title, body, null));
      } else if (frequency == 'weekdays') {
        for (int i = 1; i <= 5; i++) {
          await _scheduleWeeklyFitness(id * 10 + i, title, body, hour, minute, i, 'fitness_channel', 'Fitness Reminders', payload: _buildAlarmPayload(id * 10 + i, title, body, null));
        }
      } else if (frequency == 'weekends') {
        for (int i = 6; i <= 7; i++) {
          await _scheduleWeeklyFitness(id * 10 + i, title, body, hour, minute, i, 'fitness_channel', 'Fitness Reminders', payload: _buildAlarmPayload(id * 10 + i, title, body, null));
        }
      }
      
      debugPrint('✓ Scheduled fitness reminder: $title at $hour:$minute ($frequency)');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule fitness reminder: $e');
      return false;
    }
  }

  Future<bool> scheduleGenericReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required RepeatType repeatType,
    ReminderPriority priority = ReminderPriority.high,
    List<int>? customDays,
    int? snoozeDuration,
    String? sound,
    String? payload,
  }) async {
    try {
      if (!await checkPermissions()) {
        debugPrint('❌ Cannot schedule: Permissions not granted');
        return false;
      }

      // Clamp the base id into the 32-bit range (hashCode can overflow) — done
      // identically here + in cancelGenericReminder so schedule/cancel stay
      // symmetric.
      id = _safeId(id);

      // Clear ANY prior schedule for this reminder — base + every weekday/custom
      // sub-id — so editing the repeat type/days never leaves orphan
      // notifications firing forever. cancelNotification also tears down the
      // Android AlarmManager alarm for the base (none/daily) case.
      await cancelNotification(id);
      for (int day = 1; day <= 7; day++) {
        await cancelNotification(_generateId(id, day));
      }

      // Rich alarm payload (title/body/sound) unless the caller supplied its own
      // — built up-front so BOTH the Android AlarmManager branch and the
      // cross-platform branch route to the full-screen AlarmScreen, which loops
      // the user's chosen sound.
      final basePayload = payload ??
          _buildAlarmPayload(id, title, body, snoozeDuration, sound: sound);

      if (Platform.isAndroid) {
        final alarmService = BackgroundAlarmService();
        // Android implementation for repeating alarms needs to be handled carefully
        // For simplicity in this iteration, we use the same ID for single/daily
        // But for custom days, we might need multiple IDs.
        // Strategy: Base ID + offset for custom days.
        
        switch (repeatType) {
          case RepeatType.none:
             await alarmService.scheduleOneTimeAlarm(
              id: id,
              dateTime: scheduledTime,
              title: title,
              body: body,
              channelId: 'reminders_channel',
              channelName: 'General Reminders',
              snoozeDuration: snoozeDuration,
              sound: sound,
              payload: basePayload,
            );
            return true;

          case RepeatType.daily:
            await alarmService.scheduleDailyAlarm(
              id: id,
              hour: scheduledTime.hour,
              minute: scheduledTime.minute,
              title: title,
              body: body,
              channelId: 'reminders_channel',
              channelName: 'General Reminders',
              snoozeDuration: snoozeDuration,
              sound: sound,
              payload: basePayload,
            );
            return true;
            
          case RepeatType.weekly:
             // AndroidAlarmManager doesn't have native weekly, we might need to use recurring
             // or schedule for next occurrence and use StorageService to reschedule
             // For now, simpler to use local_notifications for recurring if possible,
             // or stick to daily/one-time for AlarmManager.
             // fallback to daily for now or implement weekly logic in AlarmService
             // Implementation plan noted: "Daily: standard repeating daily".
             // For Weekly, we can schedule a periodic alarm every 7 days?
             // AlarmManager.periodic is an option.
             // Let's use `scheduleDailyAlarm` for daily, and for others we might need
             // separate logic.
             // Given BackgroundAlarmService limitations shown in viewed file (only one-time and daily),
             // advanced repeating might be better handled by flutter_local_notifications if app is alive,
             // or by adding more features to BackgroundAlarmService.
             // However, strictly following the plan:
             // "Daily: standard repeating daily."
             
             // For this implementation, I will assume basic support and log warning for complex types
             // on Android if BackgroundAlarmService isn't updated.
             // Actually, I should probably stick to `flutter_local_notifications` for complex schedules
             // as it supports `zonedSchedule` with `matchDateTimeComponents`.
             
             // Let's use flutter_local_notifications for EVERYTHING except maybe exact alarms if needed.
             // But existing code used AlarmManager for Android.
             // Let's defer to `_notifications` for complex repeats.
             
             break; 
             
          default:
             break;
        }
        
        // If complex repeat, use flutter_local_notifications (it works on Android too)
        // But we want to use AlarmManager for exactness?
        // Let's use the cross-platform `_notifications` for complex schedules.
      }

      // Unified Logic using flutter_local_notifications for consistency and complex schedules
      // (AlarmManager is great for exact background, but `zonedSchedule` is also good)

      // Use alarm_channel for proper alarm sound behavior
      // The channel has audioAttributesUsage: alarm configured
      final androidDetails = AndroidNotificationDetails(
        'alarm_channel', // Use dedicated alarm channel
        'Alarm Reminders',
        channelDescription: 'High priority alarm reminders',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: null, // Use system default alarm sound from channel
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        // Always request full-screen intent on the alarm channel so the
        // AlarmScreen (which loops the chosen sound) launches when the device is
        // locked/idle — the whole point of a reminder alarm.
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze',
            '⏰ Snooze ${snoozeDuration ?? 5}min',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'dismiss',
            '❌ Dismiss',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
        // Persistent alarm settings - stays until user interacts
        ongoing: priority == ReminderPriority.high, 
        autoCancel: priority != ReminderPriority.high, 
        timeoutAfter: priority == ReminderPriority.high ? 300000 : null,
      );

      final iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: priority != ReminderPriority.low,
        interruptionLevel: _getIOSInterruptionLevel(priority),
      );

      final details = NotificationDetails(android: androidDetails, iOS: iOSDetails);
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

      switch (repeatType) {
        case RepeatType.none:
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            tzTime,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: basePayload,
          );
          break;

        case RepeatType.daily:
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            _nextInstanceOfTime(scheduledTime),
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: basePayload,
          );
          break;

        case RepeatType.weekly:
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            // Seed on the CHOSEN weekday (was _nextInstanceOfTime → today's
            // weekday, so a "weekly on Tuesday" fired on whatever day it was
            // created). dayOfWeekAndTime then repeats on that correct day.
            _nextInstanceOfDay(scheduledTime.weekday, scheduledTime),
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: basePayload,
          );
          break;

        case RepeatType.weekdays:
          // Schedule 5 notifications, one for each weekday
          for (int day = 1; day <= 5; day++) { // Mon=1 to Fri=5
             final nid = _generateId(id, day);
             await _scheduleWeekly(
               id: nid,
               title: title,
               body: body,
               time: scheduledTime,
               dayOfWeek: day,
               details: details,
               payload: payload ?? _buildAlarmPayload(nid, title, body, snoozeDuration),
             );
          }
          break;

        case RepeatType.weekends:
           // Sat=6, Sun=7
           for (final day in const [6, 7]) {
             final nid = _generateId(id, day);
             await _scheduleWeekly(id: nid, title: title, body: body, time: scheduledTime, dayOfWeek: day, details: details, payload: payload ?? _buildAlarmPayload(nid, title, body, snoozeDuration));
           }
          break;

        case RepeatType.custom:
          if (customDays != null) {
            for (final day in customDays) {
              final nid = _generateId(id, day);
              await _scheduleWeekly(
               id: nid,
               title: title,
               body: body,
               time: scheduledTime,
               dayOfWeek: day,
               details: details,
               payload: payload ?? _buildAlarmPayload(nid, title, body, snoozeDuration),
             );
            }
          }
          break;
      }
      
      debugPrint('✓ Scheduled generic reminder: $title (Repeat: $repeatType)');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule generic reminder: $e');
      return false;
    }
  }

  int _generateId(int baseId, int dayOffset) {
    // Unique ID generation strategy: valid range is int32.
    // Ensure baseId allows room.
    // Simple strategy: baseId + dayOffset (if baseId is large, might overflow/conflict)
    // Better: Helper method to combine.
    // Assuming baseId is hashCode of UUID string, collision risk exists but low for personal app.
    // We modify the ID slightly for each day.
    // Using simple addition for now, assuming baseId logic in AddReminderScreen accounts for this or is random enough.
    // A better approach would be `baseId ^ dayOffset` or similar, but `_generateId` logic
    // depends on how we want to cancel them later.
    // To cancel all, we need to know all IDs.
    // If we use `baseId` for the main record, we need a way to reconstruct these IDs.
    return _safeId(baseId + dayOffset);
  }

  /// Clamps a notification id into the positive 32-bit range that
  /// flutter_local_notifications / Android require. A `String.hashCode` can
  /// exceed 32 bits (or be negative), which would make `zonedSchedule` throw or
  /// silently drop the notification. Masking keeps ids valid + deterministic.
  int _safeId(int id) => id & 0x7FFFFFFF;

  /// Builds the launch payload for the full-screen alarm. The `alarm:` prefix is
  /// the gate `main.dart` uses to route to [AlarmScreen]; the JSON after it
  /// carries the real title/body/id so the alarm shows the actual reminder (was
  /// just `alarm:$id`, which made the screen show a generic "Reminder"). The
  /// notifId encoded here is the ACTUAL firing notification id so dismiss/snooze
  /// act on the right one.
  String _buildAlarmPayload(int notifId, String title, String body, int? snooze,
          {String? sound,
          String? medicineId,
          int? hour,
          int? minute,
          int? baseId}) =>
      'alarm:${jsonEncode({
            'id': notifId,
            'title': title,
            'body': body,
            if (snooze != null) 'snoozeDuration': snooze,
            if (sound != null) 'sound': sound,
            // Dose identity for 1-tap Take/Skip from the notification. hour/minute
            // let the action handler reconstruct today's dose time at fire time.
            if (medicineId != null) 'medicineId': medicineId,
            if (hour != null) 'hour': hour,
            if (minute != null) 'minute': minute,
            // Stable identity for maxSnoozeCount's shared 'snooze_count_$baseId'
            // counter — defaults to notifId, correct at ORIGINAL scheduling time
            // since nothing has been snoozed yet. snoozeReminder passes its own
            // resolved baseId explicitly when rebuilding a snoozed re-fire's
            // payload, so _handleBackgroundSnoozeAction (which can't do
            // snoozeReminder's CleanStorageService-based lookup) can still key
            // the SAME counter regardless of which handler processes any given
            // snooze tap.
            'baseId': baseId ?? notifId,
          })}';

  // Cancel Generic Reminder and all its potential sub-notifications
  Future<void> cancelGenericReminder(int id, RepeatType repeatType, List<int>? customDays) async {
      id = _safeId(id); // match the clamp used when scheduling
      await cancelNotification(id);
      
      // Cancel sub-notifications for complex types
      if (repeatType == RepeatType.weekdays) {
         for (int i=1; i<=5; i++) await cancelNotification(_generateId(id, i));
      } else if (repeatType == RepeatType.weekends) {
         await cancelNotification(_generateId(id, 6));
         await cancelNotification(_generateId(id, 7));
      } else if (repeatType == RepeatType.custom && customDays != null) {
         for (final day in customDays) await cancelNotification(_generateId(id, day));
      }
  }


  Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required DateTime time,
    required int dayOfWeek,
    required NotificationDetails details,
    String? payload,
  }) async {
      var scheduledDate = _nextInstanceOfDay(dayOfWeek, time);
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
  }

  tz.TZDateTime _nextInstanceOfDay(int dayOfWeek, DateTime time) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(time);
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
  
  tz.TZDateTime _nextInstanceOfTime(DateTime time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> _scheduleDaily(
    int id,
    String title,
    String body,
    int hour,
    int minute,
    String channelId,
    String channelName,
    {String? payload}
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
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
      scheduledDate,
      _notificationDetails(channelId: channelId, channelName: channelName),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
    debugPrint('✓ Scheduled daily fitness reminder at $hour:$minute');
  }

  Future<void> snoozeReminder(int notificationId, int minutes,
      {String? title,
      String? body,
      String? medicineId,
      int? hour,
      int? minute}) async {
    try {
      final reminders = CleanStorageService.getReminders();
      // Match the fired notification (or its snoozed `+100000` variant) to a
      // reminder WITHOUT throwing: the old nested firstWhere had no final
      // orElse, so any medicine/water/fitness/recurring notification (not in
      // this reminders list) threw a StateError that was swallowed — the snooze
      // silently no-op'd and the reminder was lost. Now we degrade gracefully.
      Reminder? reminder;
      var baseId = notificationId;
      for (final r in reminders) {
        final h = r.id.hashCode;
        if (h == notificationId) {
          reminder = r;
          baseId = notificationId;
          break;
        }
        if (h == notificationId - 100000) {
          reminder = r;
          baseId = notificationId - 100000; // this was already a snoozed id
          break;
        }
      }

      // Cap repeat snoozing. baseId == notificationId means this is the
      // original (never-snoozed) firing — always start counting from 0 there,
      // so a stale count from a past occurrence of this same reminder can't
      // leak forward; there's no separate reset step needed because of that.
      final isFreshFire = notificationId == baseId;
      final snoozeCountKey = 'snooze_count_$baseId';
      final prefs = await SharedPreferences.getInstance();
      final priorSnoozeCount =
          isFreshFire ? 0 : (prefs.getInt(snoozeCountKey) ?? 0);
      // NOT CleanStorageService.getUserSettings().maxSnoozeCount — that
      // getter never actually reads a persisted value for this field (see
      // clean_storage_service.dart's getUserSettings/saveUserSettings, which
      // wire up only 11 of UserSettings' 21 fields), so it always silently
      // returns the model's hardcoded default regardless of anything a
      // future settings screen might try to save. The other two snooze paths
      // (background_alarm_service.dart, _handleBackgroundSnoozeAction above)
      // already read this same raw key directly for that exact reason; doing
      // it here too keeps all three paths consistent so a future fix to
      // actually persist this setting only has to change one thing.
      final maxSnoozeCount = prefs.getInt('max_snooze_count') ?? 3;
      final cleanTitle = title ?? reminder?.title ?? 'Reminder';
      final cleanBody = body ?? reminder?.body ?? 'Time for your reminder';
      if (priorSnoozeCount >= maxSnoozeCount) {
        // The tapped notification is ALREADY gone by this point — the same
        // native auto-cancel background_alarm_service.dart's identical fix
        // documents — so show a final, snooze-less one rather than lose the
        // reminder entirely.
        debugPrint(
            '⏹️ Snooze cap ($maxSnoozeCount) reached for reminder $baseId — showing a final reminder with no snooze option');
        await _showFinalCappedNotification(notificationId, cleanTitle, cleanBody);
        return;
      }
      await prefs.setInt(snoozeCountKey, priorSnoozeCount + 1);

      final now = tz.TZDateTime.now(tz.local);
      final snoozeTime = now.add(Duration(minutes: minutes));
      // Prefer the title/body the caller already knows (e.g. the AlarmScreen
      // holds it in the payload) — medicine/health/water aren't in the generic
      // reminders list, so the lookup can't recover their names.
      final priority = reminder?.priority ?? ReminderPriority.high;

      // Clear the fired notification first, then reschedule at a STABLE snooze id
      // (baseId + 100000) so repeated snoozes reuse the same id instead of
      // drifting upward. The rescheduled notification carries a RICH alarm
      // payload so re-firing still opens the AlarmScreen with the real content.
      final snoozeId = _safeId(baseId + 100000);
      await _notifications.cancel(notificationId);
      await _notifications.zonedSchedule(
        snoozeId,
        '⏰ Snoozed: $cleanTitle',
        cleanBody,
        snoozeTime,
        _notificationDetails(priority: priority),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: _buildAlarmPayload(snoozeId, cleanTitle, cleanBody, minutes,
            medicineId: medicineId, hour: hour, minute: minute, baseId: baseId),
      );
      debugPrint('✓ Reminder snoozed for $minutes minutes');
    } catch (e) {
      debugPrint('❌ Failed to snooze: $e');
    }
  }

  /// Shown once the snooze cap is reached in the foreground path — see the
  /// top-level `_showFinalCappedBackgroundNotification` for why (the OS has
  /// already removed the tapped notification by the time this runs).
  Future<void> _showFinalCappedNotification(
      int id, String title, String body) async {
    try {
      await _notifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_channel',
            'Alarm Reminders',
            channelDescription: 'Reminder (snooze limit reached)',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            autoCancel: true,
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction('dismiss', '❌ Dismiss',
                  showsUserInterface: false, cancelNotification: true),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Final capped notification failed: $e');
    }
  }

  Future<void> _scheduleWeeklyFitness(
    int id,
    String title,
    String body,
    int hour,
    int minute,
    int weekday,
    String channelId,
    String channelName,
    {String? payload}
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      _notificationDetails(channelId: channelId, channelName: channelName),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
    debugPrint('✓ Scheduled weekly fitness reminder');
  }

  NotificationDetails _notificationDetails({
    String? channelId,
    String? channelName,
    ReminderPriority priority = ReminderPriority.high,
  }) {
    // Get user settings for notification preferences
    final settings = CleanStorageService.getUserSettings();
    
    // Always use alarm_channel for proper alarm sound behavior
    // The channel has audioAttributesUsage: alarm configured
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_channel', // Use dedicated alarm channel for all reminders
        'Alarm Reminders',
        channelDescription: 'High priority alarm reminders',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: null, // Use system default alarm sound
        enableVibration: settings.vibrationEnabled,
        vibrationPattern: settings.vibrationEnabled 
            ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000])
            : null,
        enableLights: true,
        ledColor: const Color(0xFF4CAF50),
        ledOnMs: 1000,
        ledOffMs: 500,
        fullScreenIntent: settings.fullScreenNotification,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: settings.showOnLockScreen 
            ? NotificationVisibility.public 
            : NotificationVisibility.private,
        showWhen: true,
        autoCancel: !settings.persistentNotification,
        ongoing: settings.persistentNotification,
        channelShowBadge: true,
        timeoutAfter: settings.alarmRingDurationSeconds * 1000,
        actions: settings.snoozeEnabled ? [
          AndroidNotificationAction(
            'snooze',
            '⏰ Snooze ${settings.snoozeIntervalMinutes}min',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'dismiss',
            '❌ Dismiss',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ] : [
          const AndroidNotificationAction(
            'dismiss',
            '❌ Dismiss',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: settings.soundEnabled,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }
  
  /// Get current notification settings for display
  UserSettings getNotificationSettings() {
    return CleanStorageService.getUserSettings();
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    // On Android many reminders (generic none/daily, medicine, health, water)
    // are AndroidAlarmManager alarms, which flutter_local_notifications' cancel
    // does NOT touch. Tear that down too so cancelling/editing never leaves an
    // orphan alarm firing forever. (No-op for ids that were never AlarmManager.)
    if (Platform.isAndroid) {
      try {
        await BackgroundAlarmService().cancelAlarm(id);
      } catch (_) {}
    }
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
    try {
      // Ensure initialized
      if (!_isInitialized) {
        await init();
      }
      
      // Use a unique ID for test notifications
      final testId = DateTime.now().millisecondsSinceEpoch % 100000;
      
      await _notifications.show(
        testId,
        'Test Notification 🔔',
        'Your reminders are working! Time: ${DateTime.now().toString().substring(11, 19)}',
        _notificationDetails(priority: ReminderPriority.high),
      );
      debugPrint('✓ Test notification shown with ID: $testId');
    } catch (e) {
      debugPrint('❌ Failed to show test notification: $e');
      rethrow;
    }
  }
  
  // Show immediate notification (for testing reminders work)
  Future<bool> showImmediateNotification({
    required String title,
    required String body,
    String? channelId,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }
      
      final id = DateTime.now().millisecondsSinceEpoch % 100000;
      
      await _notifications.show(
        id,
        title,
        body,
        _notificationDetails(channelId: channelId, channelName: channelId, priority: ReminderPriority.high),
      );
      debugPrint('✓ Immediate notification shown: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to show immediate notification: $e');
      return false;
    }
  }
  
  /// A plain, non-alarm heads-up notification on the medicine channel — for
  /// caregiver-facing pings (e.g. "X missed a dose") that must NOT ring like
  /// a patient alarm. [_notificationDetails] always hardcodes `alarm_channel`
  /// regardless of the `channelId` it's given, so this builds its own
  /// `AndroidNotificationDetails` directly rather than going through it.
  ///
  /// [dedupeKey] must vary per subject (e.g. the dependent's id) — NOT the
  /// title, which is typically a constant like "Missed dose" for every
  /// caller. Two alerts for two different dependents in the same
  /// reconciliation sweep must land as two distinct notifications, not
  /// silently overwrite each other because they shared an id.
  Future<bool> showCaregiverAlert({
    required String title,
    required String body,
    required String dedupeKey,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      const androidDetails = AndroidNotificationDetails(
        'medicine_channel',
        'Medicine Reminders',
        channelDescription: 'Reminders for taking medicines on time',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      final id = 920000 + (dedupeKey.hashCode.abs() % 1000);
      await _notifications.show(id, title, body, details);
      debugPrint('✓ Caregiver alert shown: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to show caregiver alert: $e');
      return false;
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
  
  Future<int> getPendingNotificationCount() async {
    final pending = await getPendingNotifications();
    return pending.length;
  }

  Future<bool> scheduleWaterReminder({
    required int id,
    required int hour,
    required int minute,
  }) async {
    try {
      if (!await checkPermissions()) {
        debugPrint('❌ Cannot schedule: Permissions not granted');
        return false;
      }

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
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
        'Water Reminder 💧',
        'Time to drink water! Stay hydrated',
        scheduledDate,
        _notificationDetails(channelId: 'water_channel', channelName: 'Water Reminders', priority: ReminderPriority.high),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _buildAlarmPayload(
            id, 'Water Reminder 💧', 'Time to drink water — stay hydrated', null),
      );

      debugPrint('✓ Scheduled water reminder at $hour:$minute');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule water reminder: $e');
      return false;
    }
  }

  Future<bool> schedulePeriodReminder({
    required int id,
    required DateTime reminderDate,
    required int daysBefore,
  }) async {
    try {
      if (!await checkPermissions()) {
        debugPrint('❌ Cannot schedule: Permissions not granted');
        return false;
      }

      final scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);

      await _notifications.zonedSchedule(
        id,
        'Period Reminder 🌸',
        'Your period is expected in $daysBefore days',
        scheduledDate,
        _notificationDetails(channelId: 'period_channel', channelName: 'Period Reminders', priority: ReminderPriority.low),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'period:reminder',
      );
      
      debugPrint('✓ Scheduled period reminder for ${reminderDate.toString().substring(0, 16)}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule period reminder: $e');
      return false;
    }
  }

  Future<void> cancelWaterReminders(List<int> ids) async {
    for (final id in ids) {
      await _notifications.cancel(id);
    }
    debugPrint('✓ Cancelled ${ids.length} water reminders');
  }

  /// Base notification id for interval water reminders. Each computed time uses
  /// [waterReminderBaseId] + index, capped at [maxWaterReminders] slots.
  static const int waterReminderBaseId = 900000;
  static const int maxWaterReminders = 100;

  /// Cancel every interval water reminder in the reserved id range.
  Future<void> cancelAllWaterReminders() async {
    await cancelWaterReminders(
      List.generate(maxWaterReminders, (i) => waterReminderBaseId + i),
    );
  }

  /// Schedule a set of daily-repeating water reminders at the given
  /// [minutesSinceMidnight] times. Stale reminders in the reserved id range are
  /// cancelled first so re-saving/rescheduling never leaves orphans. Returns the
  /// number of reminders successfully scheduled.
  Future<int> scheduleWaterReminderTimes(List<int> minutesSinceMidnight) async {
    await cancelAllWaterReminders();
    int count = 0;
    for (int i = 0;
        i < minutesSinceMidnight.length && i < maxWaterReminders;
        i++) {
      final m = minutesSinceMidnight[i];
      final ok = await scheduleWaterReminder(
        id: waterReminderBaseId + i,
        hour: m ~/ 60,
        minute: m % 60,
      );
      if (ok) count++;
    }
    debugPrint('✓ Scheduled $count interval water reminders');
    return count;
  }

  DateTimeComponents _getMatchComponents(String frequency) {
    if (frequency == 'Every week') {
      return DateTimeComponents.dayOfWeekAndTime;
    }
    return DateTimeComponents.time;
  }
  
  /// Schedule a quick test notification (10 seconds) to verify alarms work
  Future<bool> scheduleQuickTestNotification() async {
    try {
      // Use BackgroundAlarmService for Android - works when app is closed!
      if (Platform.isAndroid) {
        final alarmService = BackgroundAlarmService();
        final result = await alarmService.scheduleQuickTest();
        debugPrint('✓ Background quick test scheduled: $result');
        return result;
      }
      
      // Fallback for iOS
      if (!_isInitialized) {
        await init();
      }
      
      // Schedule for 10 seconds from now
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(const Duration(seconds: 10));
      
      const testId = 99998; // Fixed ID for quick test
      
      // Cancel any existing test notification
      await _notifications.cancel(testId);
      
      await _notifications.zonedSchedule(
        testId,
        'Quick Test ✅',
        'Alarm triggered successfully! Your reminders are working.',
        scheduledDate,
        _notificationDetails(priority: ReminderPriority.high),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test:quick',
      );
      
      debugPrint('✓ Quick test scheduled for 10 seconds');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule quick test: $e');
      return false;
    }
  }
  
  /// Schedule a test notification that fires in 1 minute
  /// This helps verify that scheduled notifications are working
  Future<bool> scheduleTestNotificationIn1Minute() async {
    try {
      if (!_isInitialized) {
        await init();
      }
      
      // Schedule for 1 minute from now
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(const Duration(minutes: 1));
      
      const testId = 99999; // Fixed ID for test
      
      // Cancel any existing test notification
      await _notifications.cancel(testId);
      
      await _notifications.zonedSchedule(
        testId,
        'Scheduled Test ⏰',
        'This notification was scheduled 1 minute ago! Reminders are working.',
        scheduledDate,
        _notificationDetails(priority: ReminderPriority.high),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      debugPrint('✓ Test notification scheduled for: ${scheduledDate.hour}:${scheduledDate.minute}:${scheduledDate.second}');
      debugPrint('⏰ Wait 1 minute to see if it fires!');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule test notification: $e');
      return false;
    }
  }
  
  /// Check if exact alarms can be scheduled (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final canSchedule = await androidImpl?.canScheduleExactNotifications();
        return canSchedule ?? false;
      }
      return true; // iOS doesn't have this restriction
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
      return false;
    }
  }
  
  /// Request exact alarm permission (Android 12+)
  Future<bool> requestExactAlarmPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImpl?.requestExactAlarmsPermission();
        debugPrint('⏰ Exact alarm permission requested: $granted');
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
      return false;
    }
  }
  
  /// Check if battery optimization is disabled
  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }
  
  /// Get comprehensive permission status for debugging
  Future<Map<String, dynamic>> getPermissionStatus() async {
    final status = <String, dynamic>{};
    
    status['initialized'] = _isInitialized;
    status['permissionsGranted'] = _permissionsGranted;
    
    if (Platform.isAndroid) {
      try {
        final androidImpl = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        status['notificationsEnabled'] = await androidImpl?.areNotificationsEnabled();
        status['canScheduleExact'] = await androidImpl?.canScheduleExactNotifications();
        status['batteryOptimizationDisabled'] = await isBatteryOptimizationDisabled();
      } catch (e) {
        status['error'] = e.toString();
      }
    }
    
    // Get pending notifications count
    try {
      final pending = await getPendingNotifications();
      status['pendingNotifications'] = pending.length;
      if (pending.isNotEmpty) {
        status['nextNotificationId'] = pending.first.id;
        status['nextNotificationTitle'] = pending.first.title;
      }
    } catch (e) {
      status['pendingError'] = e.toString();
    }
    
    debugPrint('📋 Notification Permission Status: $status');
    return status;
  }
  
  /// Ensure all permissions are properly set for reliable notifications
  Future<bool> ensureAllPermissions() async {
    if (!Platform.isAndroid) return true;
    
    bool allGood = true;
    
    // Check notification permission
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      final result = await Permission.notification.request();
      if (!result.isGranted) allGood = false;
    }
    
    // Check exact alarm permission
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    if (!alarmStatus.isGranted) {
      final result = await Permission.scheduleExactAlarm.request();
      if (!result.isGranted) {
        debugPrint('⚠️ Exact alarm permission denied - reminders may not fire on time');
      }
    }
    
    // Check battery optimization
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      debugPrint('⚠️ Battery optimization is enabled - reminders may not fire when app is closed');
      // Don't auto-request this one, it should be done with user dialog
    }
    
    return allGood;
  }

  // Helper methods for Priority mapping
  Importance _getImportance(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.high:
        return Importance.max;
      case ReminderPriority.medium:
        return Importance.defaultImportance;
      case ReminderPriority.low:
        return Importance.low;
    }
  }

  Priority _getPriority(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.high:
        return Priority.max;
      case ReminderPriority.medium:
        return Priority.high;
      case ReminderPriority.low:
        return Priority.low;
    }
  }

  InterruptionLevel _getIOSInterruptionLevel(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.high:
        return InterruptionLevel.critical;
      case ReminderPriority.medium:
        return InterruptionLevel.active;
      case ReminderPriority.low:
        return InterruptionLevel.passive;
    }
  }

  /// Schedule a daily notification at a specific time
  Future<bool> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }
      
      await checkPermissions();

      if (Platform.isAndroid) {
        final alarmService = BackgroundAlarmService();
        return await alarmService.scheduleDailyAlarm(
          id: id,
          hour: hour,
          minute: minute,
          title: title,
          body: body,
          channelId: 'reminders_channel',
          channelName: 'General Reminders',
        );
      }

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
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
        scheduledDate,
        _notificationDetails(priority: ReminderPriority.high),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('✓ Scheduled daily notification: $title at $hour:$minute');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule daily notification: $e');
      return false;
    }
  }

  /// Schedule a one-time notification at a specific date/time
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }
      
      await checkPermissions();

      if (Platform.isAndroid) {
        final alarmService = BackgroundAlarmService();
        return await alarmService.scheduleOneTimeAlarm(
          id: id,
          dateTime: scheduledDate,
          title: title,
          body: body,
          channelId: 'reminders_channel',
          channelName: 'General Reminders',
        );
      }

      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        _notificationDetails(priority: ReminderPriority.high),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('✓ Scheduled notification: $title at $scheduledDate');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule notification: $e');
      return false;
    }
  }
}
