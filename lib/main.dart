
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/storage_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/haptic_service.dart';
import 'core/services/vitavibe_service.dart';
import 'features/medication/services/medicine_storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_reschedule_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/background_alarm_service.dart';
import 'core/services/focus_mode_service.dart';
import 'core/services/feature_flag_service.dart';
import 'features/focus/services/focus_service.dart';
import 'features/exam_prep/services/exam_prep_service.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/screens/welcome_screen.dart';
import 'features/navigation/screens/main_navigation_screen.dart';
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
      await Firebase.initializeApp();
      
      // Enable Firestore persistence for offline support and faster queries
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('✓ Firebase initialized with persistence enabled');
    } catch (e) {
      debugPrint("Firebase initialization failed: $e");
    }
    
    try {
      await StorageService.init();
      
      // Sync snooze settings to SharedPreferences for background alarm service
      final prefs = await SharedPreferences.getInstance();
      final userSettings = StorageService.getUserSettings();
      await prefs.setInt('snooze_interval_minutes', userSettings.snoozeIntervalMinutes);
      await prefs.setBool('snooze_enabled', userSettings.snoozeEnabled);
      debugPrint('✓ Synced snooze settings to SharedPreferences');
    } catch (e) {
      debugPrint("Storage initialization failed: $e");
    }
    
    try {
      debugPrint("Initializing MedicineStorageService...");
      await MedicineStorageService.init();
    } catch (e, stackTrace) {
      debugPrint("MedicineStorageService initialization failed: $e");
      debugPrint("Stack trace: $stackTrace");
    }
    
    // Run independent services in parallel for faster startup
    await Future.wait([
      _initService('AuthService', () => AuthService().init()),
      _initService('NotificationService', () => NotificationService().init()),
      _initService('SyncService', () async => SyncService().init()), // Initialize Sync Service
      _initService('BackgroundAlarmService', () => BackgroundAlarmService().init()),
      _initService('FocusModeService', () => FocusModeService().init()),
      _initService('FocusService', () => FocusService().init()),
      _initService('ExamPrepService', () => ExamPrepService().init()),
      _initService('HapticService', () => HapticService().init()),
      _initService('FeatureFlagService', () => FeatureFlagService().init()),
      _initService('VitaVibeService', () => VitaVibeService().init()),
    ]);
    
    // Reschedule reminders after notification service is ready
    try {
      await ReminderRescheduleService.rescheduleAllReminders();
    } catch (e) {
      debugPrint("Reminder reschedule failed: $e");
    }
    
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

class MyApp extends StatelessWidget {
  final String? initialRoute;
  final Map<String, dynamic>? alarmPayload;

  const MyApp({super.key, this.initialRoute, this.alarmPayload});

  @override
  Widget build(BuildContext context) {
    final isFirstLaunch = StorageService.isFirstLaunch;
    
    return MaterialApp(
      title: 'DailyMinder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      initialRoute: initialRoute ?? (isFirstLaunch ? '/welcome' : '/home'),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => const MainNavigationScreen(),
        '/alarm': (context) => AlarmScreen(
          payload: alarmPayload ?? 
            (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {}),
        ),
      },
    );
  }
}
