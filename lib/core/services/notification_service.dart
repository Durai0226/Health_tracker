import 'dart:convert';

import 'package:clock/clock.dart';
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
import 'notification_scheduler.dart';
import 'water_action_queue.dart';
import 'dose_action_queue.dart';
import '../../features/medication/models/enhanced_medicine.dart';
import '../../features/medication/models/medicine_schedule.dart' show ScheduledTime;
import '../../features/medication/services/reminder_slot_grouping.dart';
import '../../features/reminders/models/reminder_model.dart';
import '../models/user_settings.dart';
import 'background_alarm_service.dart';
import 'reminder_budget.dart';

// The single background action handler and the snooze plumbing live in
// background_alarm_service.dart — the alarm isolate needs them and cannot
// import this file. Re-exported so existing importers of
// `notification_service.dart` are unaffected by the move.
export 'background_alarm_service.dart'
    show notificationTapBackground, handleSnoozeAction, waterLogActionId;
import '../../main.dart';
import 'snooze_log.dart';
import '../../features/medication/services/refill_loop.dart';
import '../health/step_reminder_plan.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// The concrete plugin, for the two things that are NOT scheduling decisions:
  /// `initialize` and `resolvePlatformSpecificImplementation` (channels,
  /// permission queries, exact-alarm settings intents). Everything that arms,
  /// shows or cancels goes through [_scheduler] instead.
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// The scheduling seam. Lazily created, for the same reason `AudioService`'s
  /// engine is: a field initialiser would construct the real adapter before a
  /// test could substitute one.
  NotificationScheduler? _schedulerOverride;
  NotificationScheduler get _scheduler =>
      _schedulerOverride ??= PluginNotificationScheduler(_notifications);

  /// Substitute the OS scheduler in tests. See [NotificationScheduler] for why
  /// this exists at all.
  ///
  /// Also marks the service initialised. `init()` is otherwise reached from
  /// `checkPermissions()` on the first schedule, and it drives four platform
  /// channels (plugin init, `flutter_timezone`, AlarmManager, channel creation)
  /// that are unregistered headlessly. Every one of those failures is caught and
  /// only `debugPrint`ed, so the test would still pass — it would just spend the
  /// round trips and log four warnings that look like defects. A caller that
  /// wants the init path itself can still invoke `init()` directly.
  @visibleForTesting
  set schedulerForTesting(NotificationScheduler scheduler) {
    _schedulerOverride = scheduler;
    _isInitialized = true;
  }

  /// Instance-side shorthand for [zonedScheduleGuarded]. **Every** scheduling
  /// path in this class goes through here rather than touching
  /// `_scheduler.zonedSchedule` directly, so the exact-to-inexact fallback
  /// cannot be forgotten at a new call site.
  ///
  /// `uiLocalNotificationDateInterpretation` is accepted and ignored: every call
  /// site passed `absoluteTime` and the adapter hardcodes it. The parameter stays
  /// so the call sites read the same as the plugin API they replaced.
  Future<bool> _zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime when,
    NotificationDetails details, {
    AndroidScheduleMode androidScheduleMode =
        AndroidScheduleMode.exactAllowWhileIdle,
    UILocalNotificationDateInterpretation? uiLocalNotificationDateInterpretation,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
    bool? recordDowngrade,
    String debugLabel = 'notification',
  }) =>
      zonedScheduleGuarded(
        _scheduler,
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: androidScheduleMode,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
        recordDowngrade: recordDowngrade,
        debugLabel: debugLabel,
      );
  
  bool _isInitialized = false;
  bool _permissionsGranted = false;
  // The in-app-toast cluster was deleted here: `_isAppInForeground`,
  // `setAppForegroundState`, `showInAppToast` and `shouldShowInAppToast`.
  //
  // A complete, working implementation with ZERO callers — nothing ever set the
  // foreground state, so `shouldShowInAppToast` was permanently true, and nothing
  // read it or called the toast either. Wiring it up would have meant choosing
  // behaviour for a path no feature had asked for.
  //
  // The idea itself is right and is already implemented properly one layer up,
  // where it belongs: `FocusService.justCompleted` + `justCompleted.hasConsumer`
  // decide between an in-app celebration and a notification based on whether a
  // screen is actually LISTENING — which is the real question, and strictly
  // better than a foreground flag (the Focus screen is a pushed route, so
  // foregrounded-but-not-mounted is the ordinary case). `FocusToast` and
  // `ToastService` are called directly from the widgets that own the moment.

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
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        requestCriticalPermission: false,
        // iOS requires actions to be declared UP FRONT on a category, unlike
        // Android where they ride on the notification itself. Setting
        // `categoryIdentifier` without registering the category here means the
        // buttons simply never appear — silently, with no error.
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            darwinWaterCategoryId,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                waterLogActionId,
                'Log 250 ml',
              ),
              DarwinNotificationAction.plain(
                'dismiss',
                'Dismiss',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
            options: <DarwinNotificationCategoryOption>{
              DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            },
          ),
          // Dose actions on iOS. Until this existed, only the water category was
          // registered — so an iOS dose notification had **no buttons at all**,
          // silently, while the Android one offered Take / Snooze / Dismiss.
          // `docs/ux-review.md` calls one-tap Take "the app's single best
          // accelerator" and this gap "a real capability difference".
          //
          // The ids match the Android action ids exactly, so the one shared
          // background handler routes both platforms without branching.
          DarwinNotificationCategory(
            darwinDoseCategoryId,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain('take', 'Take'),
              DarwinNotificationAction.plain('snooze', 'Snooze'),
              DarwinNotificationAction.plain(
                'skip',
                'Skip',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
            options: <DarwinNotificationCategoryOption>{
              // The body is "Time to take <medicine name>" — a prescription on
              // a lock screen. Same reasoning as the Android `visibility`
              // default being private.
              DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            },
          ),
        ],
      );

      final initSettings = InitializationSettings(
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
          // Check-ins and heads-ups: vitals prompts, the onboarding daily
          // nudge, appointment and cycle reminders.
          //
          // A separate channel rather than reusing `reminders_channel` because
          // that one is created with `audioAttributesUsage: alarm` and channel
          // audio attributes are IMMUTABLE once created — a nudge posted there
          // rings at alarm volume however politely the notification asks. No
          // `audioAttributesUsage` here is deliberate: the default is the
          // notification stream, which respects the user's notification volume
          // and Do Not Disturb.
          // The daily summary, on its own channel so a user can mute it
          // without touching anything that matters. That separability is the
          // entire argument for this app having per-family channels rather
          // than one — muting hydration must not mute doses.
          const AndroidNotificationChannel(
            'reminders_digest',
            'Daily Summary',
            description: 'One batched summary of quiet reminders',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
          const AndroidNotificationChannel(
            'checkin_channel',
            'Check-ins & Nudges',
            description: 'Gentle check-in and heads-up nudges',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            showBadge: true,
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
          // Focus belongs HERE, with mood/steps/sleep, and not one entry higher.
          //
          // Everything above `mood_channel` carries
          // `audioAttributesUsage: AudioAttributesUsage.alarm` — the alarm audio
          // stream, which rings through Do Not Disturb at alarm volume. That is
          // right for a missed dose. Every Focus notification was landing there,
          // so "New Plant Unlocked! 🌱" arrived as a medicine alarm.
          //
          // No `audioAttributesUsage` at all is deliberate: the default is
          // USAGE_NOTIFICATION, which respects DND. A session-end ping is the
          // definition of something that should be silent when the user has asked
          // for silence. `bypassDnd` is not offered by this plugin's channel API
          // anyway, and setting it natively would need ACCESS_NOTIFICATION_POLICY,
          // which this app deliberately does not hold.
          //
          // `showBadge: false` because a finished session is not an unread item —
          // there is nothing to come back to and clear.
          const AndroidNotificationChannel(
            'focus_channel',
            'Focus Sessions',
            description: 'When a focus session or break ends',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            enableLights: false,
            showBadge: false,
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
       _scheduler.cancel(response.id ?? 0);
       debugPrint('✓ Notification dismissed via tap: ${response.id}');
    } else if (response.actionId == 'take' || response.actionId == 'skip') {
      // Android routes every `showsUserInterface: false` action through
      // ActionBroadcastReceiver's background isolate, so this arm is the
      // iOS/foreground path — but it must exist, or a dose acted on from a
      // notification that DOES reach the foreground handler is lost. Queued
      // (not written straight to Drift) so there is exactly one code path
      // applying these, with its single "Logged N doses · Undo" confirmation.
      handleDoseNotificationAction(
          response.payload,
          response.actionId == 'take'
              ? DoseActionQueue.actionTake
              : DoseActionQueue.actionSkip);
    } else if (response.actionId == waterLogActionId) {
      // Same reasoning as the dose arm above: Android normally routes this to
      // the background isolate, so this is the iOS/foreground path. Queued
      // rather than written directly so there is exactly ONE code path applying
      // quick-added drinks, with its single confirmation and Undo.
      WaterActionQueue.enqueue(
        amountMl: WaterActionQueue.defaultQuickAddMl,
        at: clock.now(),
      );
    } else {
      // Normal body-tap → open the full-screen alarm when this is an alarm
      // payload. This makes the redesigned AlarmScreen reachable while the app
      // is already alive (cold-launch is handled separately in main()).
      final p = response.payload;
      if (p != null && p.startsWith('alarm:')) {
        final args = parseAlarmPayload(p, response.id);
        navigatorKey.currentState?.pushNamed('/alarm', arguments: args);
      } else if (RefillLoop.medicineIdFromPayload(p) != null) {
        // The run-out reminder (or its follow-up): the app shell shows the
        // refill sheet, after the app lock if one is engaged.
        RefillLoop.pendingOpen.value = RefillLoop.medicineIdFromPayload(p);
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

      await _zonedSchedule(
        id,
        'Medicine Reminder 💊',
        'Time to take $medicineName',
        scheduledDate,
        _notificationDetails(
            priority: ReminderPriority.high, doseActions: true),
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
  /// Returns whether the reminder is actually armed.
  ///
  /// This used to return `void` and bail on a permission refusal with only a
  /// `debugPrint`, so the Sleep and Steps settings screens persisted the
  /// toggle, left the switch ON and printed "Rings at 7:00 AM" while NOTHING
  /// was scheduled. A user who declined the notification permission at
  /// onboarding (or revoked it later) slept through their alarm with the app
  /// insisting it was set. `scheduleHealthCheckReminder` already returned a
  /// bool; these three are now consistent with it.
  ///
  /// `false` means "not armed" — including the deliberate `enabled: false`
  /// case, where the caller asked for exactly that; callers should only treat
  /// `false` as an error when they asked for `enabled: true`.
  Future<bool> scheduleBedtimeReminder({
    required bool enabled,
    required int minuteOfDay,
  }) async {
    try {
      await _scheduler.cancel(bedtimeReminderId);
      if (!enabled) {
        debugPrint('✓ Bedtime reminder cancelled');
        return false;
      }
      if (!_isInitialized) {
        try {
          await init();
        } catch (_) {}
      }
      if (!await checkPermissions()) {
        debugPrint('❌ Bedtime reminder: notifications not permitted');
        return false;
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

      await _zonedSchedule(
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
      return true;
    } catch (e) {
      debugPrint('❌ Bedtime reminder schedule failed: $e');
      return false;
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
  /// Returns whether the reminder is actually armed.
  ///
  /// This used to return `void` and bail on a permission refusal with only a
  /// `debugPrint`, so the Sleep and Steps settings screens persisted the
  /// toggle, left the switch ON and printed "Rings at 7:00 AM" while NOTHING
  /// was scheduled. A user who declined the notification permission at
  /// onboarding (or revoked it later) slept through their alarm with the app
  /// insisting it was set. `scheduleHealthCheckReminder` already returned a
  /// bool; these three are now consistent with it.
  ///
  /// `false` means "not armed" — including the deliberate `enabled: false`
  /// case, where the caller asked for exactly that; callers should only treat
  /// `false` as an error when they asked for `enabled: true`.
  Future<bool> scheduleWakeAlarm({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    try {
      if (Platform.isAndroid) {
        await BackgroundAlarmService().cancelAlarm(wakeAlarmId);
      }
      await _scheduler.cancel(wakeAlarmId);
      if (!enabled) {
        debugPrint('✓ Wake alarm cancelled');
        return false;
      }
      if (!_isInitialized) {
        try {
          await init();
        } catch (_) {}
      }
      if (!await checkPermissions()) {
        debugPrint('❌ Wake alarm: notifications not permitted');
        return false;
      }

      const title = 'Wake up ☀️';
      const body = 'Good morning — time to start your day.';
      final payload = _buildAlarmPayload(wakeAlarmId, title, body, null);

      if (Platform.isAndroid) {
        // Report what the OS actually accepted, not that we asked. This is the
        // path where SCHEDULE_EXACT_ALARM can be denied — an alarm the user
        // sleeps through is precisely the failure worth surfacing.
        final armed = await BackgroundAlarmService().scheduleDailyAlarm(
          id: wakeAlarmId,
          hour: hour,
          minute: minute,
          title: title,
          body: body,
          channelId: 'alarm_channel',
          channelName: 'Alarm Reminders',
          kind: ReminderKind.alarm,
          payload: payload,
        );
        debugPrint(armed
            ? '✓ Wake alarm scheduled at $hour:$minute'
            : '❌ Wake alarm refused by the OS at $hour:$minute');
        return armed;
      }

      // iOS fallback (dev only — release is Android): exact daily zonedSchedule.
      final now = tz.TZDateTime.now(tz.local);
      var when =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      await _zonedSchedule(
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
      return true;
    } catch (e) {
      debugPrint('❌ Wake alarm schedule failed: $e');
      return false;
    }
  }

  /// Reserved id for the evening step reminder (own block, clear of medicine).
  static const int stepReminderId = 910001;

  /// Today's data-aware step reminder: a one-off beside the repeating
  /// [stepReminderId], which then starts tomorrow. See [StepReminderPlanner].
  static const int stepReminderTodayId = 910003;

  /// Schedule (or cancel) a gentle daily evening step reminder on [steps_channel].
  ///
  /// Deliberately NOT the data-aware "X steps to go" variant (that would need a
  /// cold background isolate to re-open Drift at fire time, and could show a
  /// stale number). This is a calm, generic, opt-in nudge at a user-set time —
  /// Importance.high (not max), inexact, no full-screen, its own id — so it can
  /// never crowd out or clobber a medicine reminder.
  /// Returns whether the reminder is actually armed.
  ///
  /// This used to return `void` and bail on a permission refusal with only a
  /// `debugPrint`, so the Sleep and Steps settings screens persisted the
  /// toggle, left the switch ON and printed "Rings at 7:00 AM" while NOTHING
  /// was scheduled. A user who declined the notification permission at
  /// onboarding (or revoked it later) slept through their alarm with the app
  /// insisting it was set. `scheduleHealthCheckReminder` already returned a
  /// bool; these three are now consistent with it.
  ///
  /// `false` means "not armed" — including the deliberate `enabled: false`
  /// case, where the caller asked for exactly that; callers should only treat
  /// `false` as an error when they asked for `enabled: true`.
  ///
  /// With [stepsToday], [goal] and [stepsAsOf] the evening reminder knows how far
  /// there is to go: nothing fires today once the goal is met, and a fresh count
  /// is quoted ("1,800 steps to go"). Without them it is exactly the old generic
  /// reminder. See [StepReminderPlanner] for why a figure is only quoted when it
  /// will still be fresh.
  Future<bool> scheduleStepReminder({
    required bool enabled,
    required int minuteOfDay,
    int? stepsToday,
    int? goal,
    DateTime? stepsAsOf,
    bool restToday = false,
  }) async {
    try {
      await _scheduler.cancel(stepReminderId);
      await _scheduler.cancel(stepReminderTodayId);
      if (!enabled) {
        debugPrint('✓ Step reminder cancelled');
        return false;
      }
      if (!_isInitialized) {
        try {
          await init();
        } catch (_) {}
      }
      if (!await checkPermissions()) {
        debugPrint('❌ Step reminder: notifications not permitted');
        return false;
      }

      final hour = (minuteOfDay ~/ 60) % 24;
      final minute = minuteOfDay % 60;
      final plan = StepReminderPlanner.plan(
        now: clock.now(),
        minuteOfDay: minuteOfDay,
        stepsToday: stepsToday,
        goal: goal,
        stepsAsOf: stepsAsOf,
        restDay: restToday,
      );
      final when = tz.TZDateTime.from(plan.repeatingFrom, tz.local);

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

      // Today's one-off, when the numbers say there is something to say.
      if (plan.todayAt != null && plan.todayBody != null) {
        await _zonedSchedule(
          stepReminderTodayId,
          'A little movement? 🚶',
          plan.todayBody,
          tz.TZDateTime.from(plan.todayAt!, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          debugLabel: 'step reminder today',
        );
      }

      await _zonedSchedule(
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
      return true;
    } catch (e) {
      debugPrint('❌ Step reminder schedule failed: $e');
      return false;
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
          kind: ReminderKind.gentle,
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

      await _zonedSchedule(
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
          kind: ReminderKind.gentle,
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
    /// How insistent this reminder is allowed to be.
    ///
    /// Every generic reminder used to be armed alarm-grade: `ReminderKind.alarm`
    /// on the Android branch, and a hardcoded `alarm_channel` /
    /// `Importance.max` / `fullScreenIntent: true` /
    /// `AudioAttributesUsage.alarm` block on the cross-platform one. Meanwhile
    /// the picker promised "Quiet — a silent notification", and
    /// `ReminderEscalation.kind` / `wantsFullScreen` / `wantsExactAlarm` had no
    /// callers outside their own file. So a Quiet "water the plants" at 22:30
    /// rang at alarm volume through Do Not Disturb and took over the screen.
    ///
    /// Defaults to [ReminderEscalation.standard] rather than the old behaviour
    /// on purpose: an un-migrated caller should get the gentler treatment, not
    /// the loudest one.
    ReminderEscalation escalation = ReminderEscalation.standard,
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
          // Both branches RETURN THE OS RESULT.
          //
          // They used to `await` the call, discard its bool and `return true`.
          // `scheduleOneTimeAlarm`/`scheduleDailyAlarm` return false when
          // AlarmManager refuses — which is exactly what happens with
          // SCHEDULE_EXACT_ALARM revoked, the failure mode
          // `docs/bug-hunt.md` records as "medicine alarms were silently never
          // scheduled". Reporting success there meant the Add Reminder screen
          // popped with a saved reminder that would never fire.
          case RepeatType.none:
             final armed = await alarmService.scheduleOneTimeAlarm(
              id: id,
              dateTime: scheduledTime,
              title: title,
              body: body,
              channelId: 'reminders_channel',
              channelName: 'General Reminders',
              kind: escalation.kind,
              snoozeDuration: snoozeDuration,
              sound: sound,
              payload: basePayload,
            );
            debugPrint(armed
                ? '✓ One-time reminder alarm armed'
                : '❌ One-time reminder alarm refused by the OS');
            return armed;

          case RepeatType.daily:
            final armed = await alarmService.scheduleDailyAlarm(
              id: id,
              hour: scheduledTime.hour,
              minute: scheduledTime.minute,
              title: title,
              body: body,
              channelId: 'reminders_channel',
              channelName: 'General Reminders',
              kind: escalation.kind,
              snoozeDuration: snoozeDuration,
              sound: sound,
              payload: basePayload,
            );
            debugPrint(armed
                ? '✓ Daily reminder alarm armed'
                : '❌ Daily reminder alarm refused by the OS');
            return armed;

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

      // Presentation from the SHARED helper, keyed on the escalation tier —
      // not a hardcoded alarm-grade block.
      //
      // This used to pin alarm_channel / Importance.max / fullScreenIntent /
      // AudioAttributesUsage.alarm for every weekly, weekdays, weekends and
      // custom reminder regardless of tier, which is how a "Quiet" reminder
      // ended up ringing on the alarm stream (which ignores Do Not Disturb)
      // and taking over the lock screen.
      final look = alarmPresentationFor(
        escalation.kind,
        snoozeMinutes: snoozeDuration ?? 5,
      );
      // Default PRIVATE, matching alarmCallback: for a health app the safe
      // default is not putting "Take sertraline" on a locked screen. The
      // 'Show on lock screen' toggle was already mirrored to SharedPreferences
      // for the alarm isolate; this path simply never read it.
      final prefs = await SharedPreferences.getInstance();
      final lockScreenVisibility = (prefs.getBool(kShowOnLockScreenPref) ?? false)
          ? NotificationVisibility.public
          : NotificationVisibility.private;
      final androidDetails = AndroidNotificationDetails(
        look.channelId,
        look.channelName,
        channelDescription: look.channelDescription,
        importance: look.importance,
        priority: look.priority,
        playSound: true,
        sound: null, // the channel supplies the sound
        enableVibration: true,
        vibrationPattern: Int64List.fromList(look.vibrationPattern),
        fullScreenIntent: look.fullScreenIntent,
        category: look.category,
        visibility: lockScreenVisibility,
        audioAttributesUsage: look.audioUsage,
        actions: look.actions,
        ongoing: look.ongoing,
        autoCancel: look.autoCancel,
        timeoutAfter: look.timeoutAfterMs,
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
          await _zonedSchedule(
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
          await _zonedSchedule(
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
          await _zonedSchedule(
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
            // Stable identity for the shared snoozeCountKeyFor(baseId)
            // counter — defaults to notifId, correct at ORIGINAL scheduling time
            // since nothing has been snoozed yet. snoozeReminder passes its own
            // resolved baseId explicitly when rebuilding a snoozed re-fire's
            // payload, so _snoozeFromPayload (which can't do
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
      await _zonedSchedule(
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
      scheduledDate = _tzNextDay(scheduledDate, time);
    }
    return scheduledDate;
  }
  
  tz.TZDateTime _nextInstanceOfTime(DateTime time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = _tzNextDay(scheduledDate, time);
    }
    return scheduledDate;
  }

  /// The next calendar day at the SAME wall-clock time, in the local zone.
  ///
  /// `TZDateTime.add(Duration(days: 1))` adds 24 absolute hours, so seeding a
  /// weekly/weekdays/custom reminder across a DST transition shifted its wall
  /// clock by an hour — and because the platform then repeats on
  /// `dayOfWeekAndTime`, every later occurrence inherited the wrong minute.
  /// Constructing the date re-resolves the offset and keeps 08:00 at 08:00.
  static tz.TZDateTime _tzNextDay(tz.TZDateTime d, DateTime time) =>
      tz.TZDateTime(
          tz.local, d.year, d.month, d.day + 1, time.hour, time.minute);

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

    await _zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      _notificationDetails(),
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
      //
      // Matched on the STORED notification id, not `r.id.hashCode`. The lookup
      // compared the raw hashCode while scheduling armed under
      // `_safeId(hashCode)` (masked to 31 bits) and weekday/weekend/custom
      // reminders fired under `baseId + weekday` — so for every one of those,
      // and for any reminder whose hashCode was negative, this loop found
      // nothing and the snooze silently degraded to ReminderPriority.high with
      // the caller's title. `notificationSlot` is the id actually armed.
      Reminder? reminder;
      var baseId = notificationId;
      for (final r in reminders) {
        final slot = _safeId(r.notificationSlot);
        // Weekday/weekend/custom repeats arm sub-ids at `slot + 1..7`; a fired
        // sub-id must resolve back to its reminder.
        final asSubId = notificationId - slot;
        if (slot == notificationId || (asSubId >= 1 && asSubId <= 7)) {
          reminder = r;
          baseId = notificationId;
          break;
        }
        if (slot == notificationId - snoozeIdOffset) {
          reminder = r;
          baseId = notificationId - snoozeIdOffset; // already a snoozed id
          break;
        }
      }

      // Cap repeat snoozing. baseId == notificationId means this is the
      // original (never-snoozed) firing — always start counting from 0 there,
      // so a stale count from a past occurrence of this same reminder can't
      // leak forward; there's no separate reset step needed because of that.
      final isFreshFire = notificationId == baseId;
      final snoozeCountKey = snoozeCountKeyFor(baseId);
      final prefs = await SharedPreferences.getInstance();
      final priorSnoozeCount =
          isFreshFire ? 0 : (prefs.getInt(snoozeCountKey) ?? 0);
      // NOT CleanStorageService.getUserSettings().maxSnoozeCount — that
      // getter never actually reads a persisted value for this field (see
      // clean_storage_service.dart's getUserSettings/saveUserSettings, which
      // wire up only 11 of UserSettings' 21 fields), so it always silently
      // returns the model's hardcoded default regardless of anything a
      // future settings screen might try to save. The other two snooze paths
      // (background_alarm_service.dart, _snoozeFromPayload)
      // already read this same raw key directly for that exact reason; doing
      // it here too keeps all three paths consistent so a future fix to
      // actually persist this setting only has to change one thing.
      final maxSnoozeCount =
          prefs.getInt(maxSnoozeCountKey) ?? defaultMaxSnoozeCount;
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
      await SnoozeLog.record(prefs, baseId, DateTime.now());

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
      await _scheduler.cancel(notificationId);
      await _zonedSchedule(
        snoozeId,
        '⏰ Snoozed: $cleanTitle',
        cleanBody,
        snoozeTime,
        // Dose actions only when this snooze belongs to a medicine — without
        // them the re-fire has no Take button at all, so the only route back
        // is opening the app.
        _notificationDetails(
            priority: priority, doseActions: medicineId != null),
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
  /// top-level `_showFinalCappedPayloadNotification` for why (the OS has
  /// already removed the tapped notification by the time this runs).
  Future<void> _showFinalCappedNotification(
      int id, String title, String body) async {
    try {
      await _scheduler.show(
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

    await _zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
    debugPrint('✓ Scheduled weekly fitness reminder');
  }

  /// Notification details for the `zonedSchedule`/`show` paths.
  ///
  /// **The `channelId`/`channelName` parameters this used to take were accepted
  /// and ignored** — every caller landed on `alarm_channel` with
  /// `category: alarm` and a full-screen intent regardless. Three call sites
  /// hand-rolled their own details to work around it, and the ones that did not
  /// shipped the bug: a low-stock refill alert passed `channelId: 'refill'` (not
  /// even a channel that exists) and rang as a full-screen alarm.
  ///
  /// [kind] replaces them, because a channel id was never the real question —
  /// "is this alarm-grade?" was. A `gentle` kind cannot be expressed as
  /// `alarm_channel` at all: that channel is created with
  /// `audioAttributesUsage: alarm` and channel audio attributes are immutable
  /// once created, so a polite notification posted there still rings at alarm
  /// volume.
  NotificationDetails _notificationDetails({
    ReminderPriority priority = ReminderPriority.high,
    ReminderKind kind = ReminderKind.alarm,
    /// Attach the iOS dose category, so Take / Snooze / Skip appear there too.
    /// Android carries its actions on the notification; iOS needs the category
    /// declared up front in [init] and referenced here.
    bool doseActions = false,
  }) {
    // Get user settings for notification preferences
    final settings = CleanStorageService.getUserSettings();
    final alarmGrade = kind.isAlarmGrade;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        alarmGrade ? 'alarm_channel' : 'checkin_channel',
        alarmGrade ? 'Alarm Reminders' : 'Check-ins & Nudges',
        channelDescription: alarmGrade
            ? 'High priority alarm reminders'
            : 'Gentle check-in and heads-up nudges',
        importance: alarmGrade ? Importance.max : Importance.high,
        priority: alarmGrade ? Priority.max : Priority.defaultPriority,
        playSound: true,
        sound: null, // Use system default sound from the channel
        enableVibration: settings.vibrationEnabled,
        vibrationPattern: !settings.vibrationEnabled
            ? null
            : alarmGrade
                ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000])
                : Int64List.fromList([0, 250, 250, 250]),
        enableLights: true,
        ledColor: const Color(0xFF4CAF50),
        ledOnMs: 1000,
        ledOffMs: 500,
        fullScreenIntent: alarmGrade && settings.fullScreenNotification,
        category: alarmGrade
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        audioAttributesUsage: alarmGrade
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        visibility: settings.showOnLockScreen 
            ? NotificationVisibility.public 
            : NotificationVisibility.private,
        showWhen: true,
        autoCancel: alarmGrade ? !settings.persistentNotification : true,
        ongoing: alarmGrade && settings.persistentNotification,
        channelShowBadge: true,
        timeoutAfter:
            alarmGrade ? settings.alarmRingDurationSeconds * 1000 : null,
        actions: (alarmGrade && settings.snoozeEnabled) ? [
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
        categoryIdentifier: doseActions ? darwinDoseCategoryId : null,
      ),
    );
  }
  
  /// Get current notification settings for display
  UserSettings getNotificationSettings() {
    return CleanStorageService.getUserSettings();
  }

  Future<void> cancelNotification(int id) async {
    await _scheduler.cancel(id);
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
      await _scheduler.cancel(baseId);
    } else if (frequency == 'weekdays') {
      for (int i = 1; i <= 5; i++) {
        await _scheduler.cancel(baseId * 10 + i);
      }
    } else if (frequency == 'weekends') {
      for (int i = 6; i <= 7; i++) {
        await _scheduler.cancel(baseId * 10 + i);
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    await _scheduler.cancelAll();
  }

  /// Cancel everything this app has scheduled, on every route it can be armed.
  ///
  /// `cancelAll` on the plugin only reaches `zonedSchedule` registrations. On
  /// Android most reminders — medicines, generic reminders, health checks — are
  /// AlarmManager alarms with their data in `alarm_*` preferences, which it
  /// does not touch, so they went on firing after "Delete all data". Returns how
  /// many AlarmManager alarms were torn down.
  Future<int> cancelEverythingScheduled() async {
    var alarms = 0;
    try {
      await _scheduler.cancelAll();
    } catch (e) {
      debugPrint('⚠️ cancelAll failed: $e');
    }
    if (Platform.isAndroid) {
      try {
        final service = BackgroundAlarmService();
        for (final a in await service.getScheduledAlarms()) {
          final id = a['id'];
          if (id is int) {
            await service.cancelAlarm(id);
            alarms++;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Cancelling alarms failed: $e');
      }
    }
    return alarms;
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
      
      await _scheduler.show(
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
  /// [kind] was a `String? channelId` that [_notificationDetails] silently
  /// discarded — which is how a refill alert passing `'refill'`, a channel that
  /// does not exist, ended up ringing as a full-screen alarm.
  Future<bool> showImmediateNotification({
    required String title,
    required String body,
    ReminderKind kind = ReminderKind.alarm,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }
      
      final id = DateTime.now().millisecondsSinceEpoch % 100000;
      
      await _scheduler.show(
        id,
        title,
        body,
        _notificationDetails(priority: _iosPriorityFor(kind), kind: kind),
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
      await _scheduler.show(id, title, body, details);
      debugPrint('✓ Caregiver alert shown: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to show caregiver alert: $e');
      return false;
    }
  }

  // ---- Focus: reserved id block 918_4xx -----------------------------------
  //
  // Kept together and here rather than on the settings screen so
  // `test/notifications/notification_id_ranges_test.dart` can see the whole
  // block. A notification id is last-write-wins: two features that compute the
  // same id are one notification, and cancelling it kills both.
  static const int focusDailyReminderId = 918_401;
  static const int focusStreakReminderId = 918_402;
  // ONE id for the armed completion, not one per phase: a session is only ever
  // in one phase at a time, so a second id could only ever be a way to leave one
  // of them armed. Arming replaces by id, which is what makes every arm site
  // idempotent.
  static const int focusSessionEndId = 918_410;

  /// A calm, immediate Focus notification — session complete, break over, an
  /// unlock.
  ///
  /// Built directly rather than through [_notificationDetails], which accepts a
  /// `channelId` and **ignores it**, hardcoding `alarm_channel` with
  /// `AudioAttributesUsage.alarm`, `AndroidNotificationCategory.alarm`,
  /// `Importance.max`, a full-screen intent and Snooze/Dismiss actions. Every
  /// Focus notification went through `showImmediateNotification`, so a plant
  /// unlock rang on the alarm stream and could take over the lock screen.
  /// [showCaregiverAlert] exists for the same reason and says so.
  Future<bool> showFocusNotification({
    required String title,
    required String body,
  }) async {
    try {
      if (!_isInitialized) await init();
      await _scheduler.show(
          focusSessionEndId, title, body, _focusDetails());
      debugPrint('✓ Focus notification shown: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to show focus notification: $e');
      return false;
    }
  }

  /// The one place Focus notification presentation is defined.
  ///
  /// `category: reminder` (never `alarm`), no `audioAttributesUsage`, no
  /// `fullScreenIntent`, no action buttons, and `autoCancel: true`. No action
  /// buttons matters beyond tidiness: the app-wide background tap handler is a
  /// single slot shared with the alarm isolate, so a Focus notification that
  /// carried actions would need routing there too.
  NotificationDetails _focusDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'focus_channel',
          'Focus Sessions',
          channelDescription: 'When a focus session or break ends',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

  /// Schedule (or cancel) a Focus reminder on `focus_channel`.
  ///
  /// Deliberately NOT [scheduleGenericReminder]. On Android that routes to
  /// `BackgroundAlarmService.scheduleOneTimeAlarm`/`scheduleDailyAlarm` →
  /// `AlarmManager.setAlarmClock()`, and `alarmCallback` then presents the
  /// notification with a hardcoded `alarm_channel`, `fullScreenIntent: true`,
  /// `ongoing: true` and **`✓ Take` / `⏰ Snooze` / `✕ Dismiss`** buttons. So
  /// *"Time to focus — a short session is enough"* arrived at 09:00 as a
  /// full-screen ringing alarm with a Take button, over the lock screen.
  ///
  /// Modelled on [scheduleStepReminder]: Importance.high not max, inexact, no
  /// full-screen, its own id — so it can never crowd out a medicine reminder.
  /// Inexact is the right trade here: a focus nudge a few minutes late is a
  /// nudge; a dose a few minutes late is a dose.
  Future<void> scheduleFocusReminder({
    required int id,
    required bool enabled,
    required String title,
    required String body,
    required DateTime when,
    bool repeatDaily = false,
  }) async {
    try {
      // cancelNotification, not _scheduler.cancel: an older build scheduled
      // these ids through AlarmManager, and only this tears that registration
      // down. It is a no-op for ids AlarmManager never held.
      await cancelNotification(id);
      if (!enabled) {
        debugPrint('✓ Focus reminder $id cancelled');
        return;
      }
      if (!_isInitialized) {
        try {
          await init();
        } catch (_) {}
      }
      if (!await checkPermissions()) {
        debugPrint('❌ Focus reminder: notifications not permitted');
        return;
      }

      final local = tz.TZDateTime.from(when, tz.local);
      await _zonedSchedule(
        id,
        title,
        body,
        local,
        _focusDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
      );
      debugPrint('✓ Focus reminder $id at $local (focus_channel, inexact)');
    } catch (e) {
      debugPrint('❌ Focus reminder schedule failed: $e');
    }
  }

  /// Schedule the one-shot "your session ended" notification for [at].
  ///
  /// The Focus timer cancels its 1 Hz ticker when the app is backgrounded (the
  /// countdown is derived from an absolute end time, so a background ticker only
  /// costs battery). The consequence was that `_completeSession()` could only ever
  /// run on resume, so the app never told you the moment your session ended
  /// unless you were already looking at it.
  ///
  /// `zonedSchedule` is the right vehicle and needs no new native code or
  /// permission: the manifest already declares `ScheduledNotificationReceiver`
  /// AND `ScheduledNotificationBootReceiver` with `BOOT_COMPLETED`, so a pending
  /// focus-end notification survives process death and a reboot.
  ///
  /// **Exact, then inexact — never a downgrade flag.** `USE_EXACT_ALARM` was
  /// deliberately dropped (Play's acceptable-use policy for that auto-granted,
  /// non-revocable permission covers alarm/timer and calendar apps, which this is
  /// not), so on Android 14+ `canScheduleExactNotifications()` is false by
  /// default and this plugin throws `exact_alarms_not_permitted` for BOTH exact
  /// modes. We retry inexact rather than propagate: a focus ping a few minutes
  /// late is still a ping. What we must NOT do is touch
  /// `BackgroundAlarmService.exactAlarmsDowngraded()` — that flag drives the
  /// "your medicine reminders are inexact" warning, and a focus timer has no
  /// business raising it. That is now expressed as `recordDowngrade: false` on the
  /// shared [zonedScheduleGuarded] path, which also performs the retry; the
  /// bespoke retry that used to live here was the template for it.
  Future<void> scheduleFocusCompletion({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      try {
        await init();
      } catch (_) {}
    }
    final when = tz.TZDateTime.from(at, tz.local);

    final exact = await _zonedSchedule(
      id,
      title,
      body,
      when,
      _focusDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      recordDowngrade: false,
      debugLabel: 'focus completion',
    );
    debugPrint(
        '✓ Focus completion armed for $when (${exact ? 'exact' : 'inexact — exact denied'})');
  }

  /// Cancel a pending focus-end notification.
  ///
  /// `_scheduler.cancel`, deliberately not [cancelNotification]: these ids are
  /// never registered with AlarmManager, so reaching into `BackgroundAlarmService`
  /// for them would be a no-op that implies otherwise.
  Future<void> cancelFocusCompletion(int id) async {
    try {
      await _scheduler.cancel(id);
    } catch (e) {
      debugPrint('Focus completion cancel failed for $id: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _scheduler.pendingNotificationRequests();
  }
  
  Future<int> getPendingNotificationCount() async {
    final pending = await getPendingNotifications();
    return pending.length;
  }

  /// Notification style for water reminders — deliberately NOT
  /// [_notificationDetails].
  ///
  /// That helper takes `channelId`/`channelName` and then ignores both: every
  /// reminder in the app was posted on `alarm_channel` with `Importance.max`,
  /// `AudioAttributesUsage.alarm`, `category: alarm` and the user's
  /// full-screen-intent setting. For a dose that is defensible. For "time to
  /// drink water" it is not — it takes over the screen, rings with the alarm
  /// stream, and holds the display on. That exact behaviour is one of the
  /// most-cited one-star complaints across this whole app category ("makes the
  /// phone screen stay on… literally hot from being on for a long time").
  ///
  /// So water gets the `water_channel` that was created at init and never once
  /// used: a normal high-importance notification, notification audio, no
  /// full-screen intent, and two action buttons so the drink can be logged
  /// without opening the app.
  NotificationDetails _waterNotificationDetails() {
    final settings = CleanStorageService.getUserSettings();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'water_channel',
        'Water Reminders',
        channelDescription: 'Reminders to drink water',
        importance: Importance.high,
        priority: Priority.high,
        playSound: settings.soundEnabled,
        enableVibration: settings.vibrationEnabled,
        category: AndroidNotificationCategory.reminder,
        audioAttributesUsage: AudioAttributesUsage.notification,
        visibility: settings.showOnLockScreen
            ? NotificationVisibility.public
            : NotificationVisibility.private,
        showWhen: true,
        autoCancel: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            waterLogActionId,
            '💧 Log ${WaterActionQueue.defaultQuickAddMl} ml',
            // No UI: the point is to log without opening the app. The drink is
            // queued in the background isolate and applied on next resume.
            showsUserInterface: false,
            cancelNotification: true,
          ),
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
        // A hydration nudge is not time-sensitive in the iOS sense; leaving it
        // at the default lets Focus modes and Scheduled Summary do their job.
        interruptionLevel: InterruptionLevel.active,
        categoryIdentifier: darwinWaterCategoryId,
      ),
    );
  }

  /// Action id for the notification's quick-add button. Handled in BOTH the
  /// foreground and `@pragma('vm:entry-point')` background response handlers —
  /// which one runs depends on whether the app has been opened since the
  /// notification was posted (see [notificationTapBackground]'s doc).

  /// iOS needs actions declared up-front on a category, unlike Android where
  /// they ride on the notification.
  static const String darwinWaterCategoryId = 'water_reminder';

  /// The iOS category carrying dose actions. See the registration in [init] for
  /// why declaring it there is mandatory — a `categoryIdentifier` with no
  /// registered category produces no buttons and no error.
  static const String darwinDoseCategoryId = 'dose_reminder';

  Future<bool> scheduleWaterReminder({
    required int id,
    required int hour,
    required int minute,
    /// Set by [scheduleWaterReminderTimes], which checks once for the batch.
    /// Defaults to false so a lone caller still checks for itself.
    bool permissionsAlreadyChecked = false,
  }) async {
    try {
      if (!permissionsAlreadyChecked && !await checkPermissions()) {
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

      await _zonedSchedule(
        id,
        'Water Reminder 💧',
        'Time to drink water! Stay hydrated',
        scheduledDate,
        _waterNotificationDetails(),
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

      await _zonedSchedule(
        id,
        'Period Reminder 🌸',
        'Your period is expected in $daysBefore days',
        scheduledDate,
        _notificationDetails(
            priority: ReminderPriority.low, kind: ReminderKind.gentle),
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
      await _scheduler.cancel(id);
    }
    debugPrint('✓ Cancelled ${ids.length} water reminders');
  }

  /// Base notification id for interval water reminders. Each computed time uses
  /// [waterReminderBaseId] + index, capped at [maxWaterReminders] slots.
  ///
  /// MOVED off 900000 (see [legacyWaterReminderBaseId]): that block was not
  /// actually exclusive. Five vitals reminders (BP 900020, blood sugar 900021,
  /// weight 900022, mood 900023, evening BP 900024 — `VitalsReminderService`) and onboarding's
  /// daily check-in (900001 — `welcome_screen.dart`) sit inside it, and a
  /// notification id is last-write-wins: a user with 21+ interval water
  /// reminders (every 40 min across a normal waking day) silently REPLACED
  /// their blood-pressure and blood-sugar reminders, and every
  /// `cancelAllWaterReminders()` sweep deleted them outright. 960000 is clear
  /// of every reserved block in the app: medicine slots (100000-101439) and
  /// their +100000 snooze twins, water/bedtime/step/wake (900000-910002),
  /// caregiver alerts (920000-920999), window nudges (930000 + 72 per
  /// medicine) and period reminders (990001-990004).
  static const int waterReminderBaseId = 960000;
  static const int maxWaterReminders = 100;

  /// The pre-move base id. Water reminders scheduled by an older build still
  /// live here, so the sweep below clears them too — otherwise they would fire
  /// forever with nothing left able to cancel them.
  static const int legacyWaterReminderBaseId = 900000;

  /// Ids inside the legacy water block that belong to OTHER features and must
  /// never be cancelled by a water sweep. Kept explicit (rather than relying on
  /// the other services' constants) so this file has no dependency on them —
  /// but they must stay in sync with `VitalsReminderService` /
  /// `welcome_screen.dart` for as long as those ids exist.
  static const Set<int> _foreignIdsInLegacyWaterBlock = {
    900001, // onboarding "Daily check-in"
    900020, // vitals: blood pressure
    900021, // vitals: blood sugar
    900022, // vitals: weight
    900023, // vitals: mood
    900024, // vitals: blood pressure, evening
  };

  /// Every id a water sweep is allowed to cancel: the reserved block, plus the
  /// legacy block minus the ids other features own there.
  static Set<int> get _sweepableWaterIds => {
        for (int i = 0; i < maxWaterReminders; i++) waterReminderBaseId + i,
        for (int i = 0; i < maxWaterReminders; i++)
          if (!_foreignIdsInLegacyWaterBlock
              .contains(legacyWaterReminderBaseId + i))
            legacyWaterReminderBaseId + i,
      };

  /// Cancel every interval water reminder in the reserved id range — plus any
  /// left over in the legacy range, minus the ids other features own there.
  ///
  /// Cancels only ids the OS actually holds. This used to issue 195 `cancel()`
  /// calls every time — one per id in both blocks — on every launch and every
  /// Save, whether or not a single water reminder existed. Cancelling an id
  /// that was never scheduled is a no-op with a platform round trip attached,
  /// so the work was real and the effect was nil. A user with ten slots now
  /// pays ten.
  ///
  /// Returns how many were cancelled, so a caller that already read the pending
  /// list can adjust its own count without a second round trip.
  Future<int> cancelAllWaterReminders() async {
    return _cancelPendingWaterReminders(await getPendingNotifications());
  }

  /// Which of [pendingIds] a water sweep may cancel.
  ///
  /// Pure and public because the decision of WHAT to cancel is the part that had
  /// the bug in it, and it is just a set intersection — testable with no service
  /// and no scheduler.
  ///
  /// Two properties matter and both are asserted in
  /// `test/notifications/water_reminder_sweep_test.dart`:
  /// an id that is not pending is never cancelled (that is the whole saving),
  /// and an id another feature owns inside the legacy block is never cancelled
  /// even though it sits in the range.
  ///
  /// That the sweep actually cancels what this returns — and cancels it before
  /// arming the replacements — is a separate claim, asserted against the
  /// [NotificationScheduler] seam in
  /// `test/notifications/water_reminder_schedule_test.dart`.
  @visibleForTesting
  static List<int> staleWaterIdsIn(Iterable<int> pendingIds) {
    final sweepable = _sweepableWaterIds;
    return pendingIds.where(sweepable.contains).toList(growable: false);
  }

  /// The sweep itself, over a pending list the caller has already read.
  Future<int> _cancelPendingWaterReminders(
      List<PendingNotificationRequest> pending) async {
    final stale = staleWaterIdsIn(pending.map((p) => p.id));
    await cancelWaterReminders(stale);
    return stale.length;
  }

  /// Schedule a set of daily-repeating water reminders at the given
  /// [minutesSinceMidnight] times. Stale reminders in the reserved id range are
  /// cancelled first so re-saving/rescheduling never leaves orphans. Returns the
  /// number of reminders successfully scheduled.
  Future<int> scheduleWaterReminderTimes(List<int> minutesSinceMidnight) async {
    // Check once for the whole batch. `scheduleWaterReminder` checks per call,
    // which meant up to 100 permission round trips for one reschedule — and the
    // answer cannot change midway through a loop that takes milliseconds.
    if (!await checkPermissions()) {
      debugPrint('❌ Cannot schedule water reminders: permissions not granted');
      return 0;
    }

    // ONE read of the pending list, used for both the stale sweep and the
    // headroom budget below. It was already being fetched here and thrown away
    // except for its length.
    final pendingBefore = await getPendingNotifications();
    final cancelled = await _cancelPendingWaterReminders(pendingBefore);

    // Truncate against what the OS will actually keep, not just this family's
    // own cap. On iOS the system keeps the soonest-firing 64 pending requests
    // and silently discards the rest — so 100 water reminders do not merely fail
    // to arm, they evict a user's dose reminders, which are further out. Water
    // is a `gentle` nudge: it yields first, by design.
    //
    // Counted AFTER the sweep, matching the original order: the slots just
    // cancelled must not count against the headroom they are about to reuse.
    final pending = pendingBefore.length - cancelled;
    final headroom = ReminderBudget.headroomFor(
      ReminderKind.gentle,
      pending: pending,
    );
    final limit = [minutesSinceMidnight.length, maxWaterReminders, headroom]
        .reduce((a, b) => a < b ? a : b);
    ReminderBudget.reportTruncation(
      family: 'interval water reminders',
      wanted: minutesSinceMidnight.length,
      granted: limit,
    );

    int count = 0;
    for (int i = 0; i < limit; i++) {
      final m = minutesSinceMidnight[i];
      final ok = await scheduleWaterReminder(
        id: waterReminderBaseId + i,
        hour: m ~/ 60,
        minute: m % 60,
        permissionsAlreadyChecked: true,
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
      await _scheduler.cancel(testId);
      
      await _zonedSchedule(
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
      await _scheduler.cancel(testId);
      
      await _zonedSchedule(
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
  
  /// `true` when reminders are currently being registered INEXACTLY because
  /// Android refuses exact alarms for this app.
  ///
  /// Worth surfacing (e.g. next to `NotificationPermissionBanner`): the alarms
  /// still fire, but within the OS's batching window rather than to the
  /// minute. Before this existed, a revoked SCHEDULE_EXACT_ALARM made
  /// android_alarm_manager_plus drop every medicine alarm while still
  /// reporting success — the patient believed reminders were set and got none.
  /// [requestExactAlarmPermission] is the fix to offer alongside it.
  Future<bool> remindersDowngradedToInexact() =>
      BackgroundAlarmService().exactAlarmsDowngraded();

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


  /// iOS has no [ReminderKind]; it has interruption levels. Map through the
  /// existing priority ladder so a `gentle` nudge lands on `passive` rather than
  /// on `critical`, which [_getIOSInterruptionLevel] gives `high` and which needs
  /// an Apple entitlement this app has not been granted.
  ReminderPriority _iosPriorityFor(ReminderKind kind) =>
      kind.isAlarmGrade ? ReminderPriority.high : ReminderPriority.low;

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

  /// Schedule a daily notification at a specific time.
  ///
  /// Every caller today is a check-in nudge — the four vitals reminders and the
  /// onboarding daily prompt — hence the [kind] default. Before [ReminderKind]
  /// existed these arrived as full-screen ringing medicine alarms with a `✓ Take`
  /// button, because `alarmCallback` hardcoded that shape and ignored the
  /// `channelId` passed from here.
  Future<bool> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    ReminderKind kind = ReminderKind.gentle,
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
          channelId: 'checkin_channel',
          channelName: 'Check-ins & Nudges',
          kind: kind,
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

      await _zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _notificationDetails(priority: _iosPriorityFor(kind)),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        debugLabel: 'daily ${kind.name}',
      );

      debugPrint('✓ Scheduled daily notification: $title at $hour:$minute');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule daily notification: $e');
      return false;
    }
  }

  /// Schedule a one-time notification at a specific date/time.
  ///
  /// Callers today are appointment and cycle heads-ups, hence the [kind] default.
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    ReminderKind kind = ReminderKind.gentle,

    /// What a tap on the notification should open. Null keeps the old
    /// behaviour: it just brings the app forward.
    String? payload,
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
          channelId: 'checkin_channel',
          channelName: 'Check-ins & Nudges',
          kind: kind,
          payload: payload,
        );
      }

      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        _notificationDetails(priority: _iosPriorityFor(kind)),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        debugLabel: 'one-shot ${kind.name}',
      );

      debugPrint('✓ Scheduled notification: $title at $scheduledDate');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule notification: $e');
      return false;
    }
  }
}
