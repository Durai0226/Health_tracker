
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/services/clean_storage_service.dart';
import 'core/database/app_database.dart';
import 'core/services/auth_service.dart';
import 'core/services/haptic_service.dart';
import 'core/services/vitavibe_service.dart';
import 'features/medication/services/medicine_storage_service.dart';
import 'features/medication/services/intake_tracking_service.dart';
import 'features/water/services/water_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_reschedule_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/background_alarm_service.dart';
import 'core/services/focus_mode_service.dart';
import 'core/services/feature_flag_service.dart';
import 'core/services/feature_manager.dart';
import 'core/services/simple_ad_service.dart';
import 'features/focus/services/focus_service.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/screens/welcome_screen.dart';
import 'features/home/screens/app_shell.dart';
import 'features/reminders/screens/alarm_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Helper function to initialize a service with error handling
Future<void> _initService(String name, Future<void> Function() init) async {
  try {
    await init();
    debugPrint('✓ $name initialized');
  } catch (e) {
    debugPrint('$name initialization failed: $e');
  }
}

/// Sync snooze settings asynchronously without blocking startup
void _syncSnoozeSettings() {
  Future(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userSettings = CleanStorageService.getUserSettings();
      await prefs.setInt('snooze_interval_minutes', userSettings.snoozeIntervalMinutes);
      await prefs.setBool('snooze_enabled', userSettings.snoozeEnabled);
      debugPrint('✓ Synced snooze settings to SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Snooze settings sync failed: $e');
    }
  });
}

/// Initialize non-critical services after app launch to improve startup time
void _initDeferredServices() {
  Future(() async {
    try {
      final featureManager = FeatureManager();
      
      // Initialize non-critical services in background
      await Future.wait([
        _initService('SimpleAdService', () => SimpleAdService().init()),
        _initService('SyncService', () async => SyncService().init()),
        _initService('BackgroundAlarmService', () => BackgroundAlarmService().init()),
        _initService('FeatureFlagService', () => FeatureFlagService().init()),
        _initService('VitaVibeService', () => VitaVibeService().init()),
        // Other services can be initialized on-demand
      ]);
      
      // Reschedule reminders after services are ready (non-blocking)
      try {
        await ReminderRescheduleService.rescheduleAllReminders();
        debugPrint('✓ Reminders rescheduled in background');
      } catch (e) {
        debugPrint('⚠️ Reminder reschedule failed: $e');
      }
      
      debugPrint('✓ All deferred services initialized');
    } catch (e) {
      debugPrint('⚠️ Deferred services initialization failed: $e');
    }
  });
}

void main() async {
  // Catch all Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
    // Don't crash the app, just log the error
  };

  // Catch all async errors that escape the Flutter framework
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Enable Firestore persistence with reasonable cache size for faster startup
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 50 * 1024 * 1024, // 50MB cache instead of unlimited
      );
      debugPrint('✓ Firebase initialized with persistence enabled');
    } catch (e) {
      debugPrint("⚠️ Firebase initialization failed: $e");
      debugPrint("⚠️ App will continue with local storage only");
      // App can still function with local Drift storage
    }
    
    // Initialize critical storage services in parallel
    // Initialize Drift database first
    await _initService('AppDatabase', () async {
      final db = AppDatabase.instance;
      await db.customStatement('PRAGMA journal_mode=WAL;'); // Enable WAL mode for better performance
      debugPrint('✓ Drift database connection established');
    });
    
    // Initialize core storage service (now uses Drift)
    await _initService('CleanStorageService', () => CleanStorageService.init());

    // Initialize dependent storage services in parallel
    await Future.wait([
      _initService('MedicineCleanStorageService', () => MedicineCleanStorageService.init()),
      _initService('IntakeTrackingService', () => IntakeTrackingService.init()),
      _initService('WaterService', () => WaterService.init()),
    ]);
    
    // Sync snooze settings asynchronously (non-blocking)
    _syncSnoozeSettings();
    
    // Initialize only critical services for startup
    await Future.wait([
      _initService('NotificationService', () => NotificationService().init()),
      _initService('AuthService', () => AuthService().init()),
      _initService('HapticService', () => HapticService().init()),
      _initService('FeatureManager', () => FeatureManager().init()),
    ]);
    
    // Defer non-critical services to after app launch
    _initDeferredServices();
    
    // Check if app was launched by notification
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
    
    String? initialRoute;
    Map<String, dynamic>? alarmPayload;
    
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload = notificationAppLaunchDetails?.notificationResponse?.payload;
      if (payload != null && payload.startsWith('alarm:')) {
        initialRoute = '/alarm';
        // Extract ID and other data if needed, or pass full payload
        // For now, we'll reconstruct a basic payload map
        alarmPayload = {
          'id': payload.split(':').last,
          'payload': payload,
        };
      }
    }

    runApp(MyApp(initialRoute: initialRoute, alarmPayload: alarmPayload));
  }, (error, stackTrace) {
    debugPrint('Uncaught Error: $error');
    debugPrint('Stack trace: $stackTrace');
    // Log but don't crash the app
  });
}

class MyApp extends StatefulWidget {
  final String? initialRoute;
  final Map<String, dynamic>? alarmPayload;

  const MyApp({super.key, this.initialRoute, this.alarmPayload});

  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  void _loadThemePreference() {
    final settings = CleanStorageService.getUserSettings();
    setState(() {
      _themeMode = settings.darkModeEnabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFirstLaunch = CleanStorageService.isFirstLaunch;
    
    // Determine initial route based on launch state
    String determineInitialRoute() {
      if (widget.initialRoute != null) return widget.initialRoute!;
      if (isFirstLaunch) return '/welcome';
      return '/home';
    }
    
    return MaterialApp(
      title: 'DailyMinder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      navigatorKey: navigatorKey,
      initialRoute: determineInitialRoute(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => const AppShell(),
        '/alarm': (context) => AlarmScreen(
          payload: widget.alarmPayload ??
            (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {}),
        ),
      },
    );
  }
}

