
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/services/clean_storage_service.dart';
import 'core/services/llm_service.dart';
import 'core/ai/knowledge_base.dart';
import 'core/ai/ai_assistant.dart';
import 'core/database/app_database.dart';
import 'core/services/auth_service.dart';
import 'core/services/haptic_service.dart';
import 'core/services/vitavibe_service.dart';
import 'features/medication/services/medicine_storage_service.dart';
import 'features/medication/services/intake_tracking_service.dart';
import 'features/water/services/water_service.dart';
import 'features/period/services/period_service.dart';
import 'features/steps/services/step_service.dart';
import 'features/sleep/services/sleep_service.dart';
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

/// Test-only flag (set via `--dart-define=E2E_TEST=true`) to make the app
/// drivable by integration tests: skips the first-run welcome and the ads/ATT
/// init, whose native permission dialog a widget-test can't dismiss. Defaults to
/// false, so production builds are completely unaffected.
const bool kE2ETest = bool.fromEnvironment('E2E_TEST');

/// Debug-only: skip NotificationService.init() so the iOS-simulator plugin
/// permission prompt doesn't block screenshots of the welcome flow. Defaults
/// false — production is unaffected.
const bool kSkipNotifInit = bool.fromEnvironment('SKIP_NOTIF_INIT');

/// Global theme-mode notifier so a settings change rebuilds [MaterialApp]
/// instantly (ONB-5 follow-system support). Updated on save in Settings.
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

/// Maps the persisted `themeModePreference` string to a [ThemeMode].
ThemeMode themeModeFromPreference(String pref) {
  switch (pref) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

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
        // Skip ads/ATT under E2E or screenshot mode — its native permission
        // dialog blocks tests/screenshots.
        if (!kE2ETest && !kSkipNotifInit)
          _initService('SimpleAdService', () => SimpleAdService().init()),
        _initService('SyncService', () async => SyncService().init()),
        _initService('BackgroundAlarmService', () => BackgroundAlarmService().init()),
        _initService('FeatureFlagService', () => FeatureFlagService().init()),
        _initService('VitaVibeService', () => VitaVibeService().init()),
        // Seed the on-device RAG knowledge base (idempotent + versioned).
        _initService('KnowledgeBaseSeeder', () => KnowledgeBaseSeeder.ensureSeeded()),
        // Attach the on-device LLM only if the user opted in + a model is present.
        _initService('OnDeviceAI', () => AiAssistant().maybeActivateOnDeviceAtStartup()),
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

/// Parses an `alarm:{json}` launch payload into the map the [AlarmScreen] reads
/// (`id`, `title`, `body`, `snoozeDuration`). Falls back to the legacy
/// `alarm:$id` format so older scheduled notifications still open correctly.
Map<String, dynamic> parseAlarmPayload(String payload, int? notifId) {
  final raw = payload.substring('alarm:'.length);
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      m['payload'] = payload;
      return m;
    }
  } catch (_) {
    // legacy `alarm:$id` — not JSON
  }
  return {'id': notifId ?? int.tryParse(raw) ?? raw, 'payload': payload};
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

      // App Check — attest that requests come from a genuine, untampered build
      // BEFORE any Firestore/Auth use, so the backend can reject abuse (e.g.
      // scripted anonymous writes). Debug builds use the debug provider (print
      // the token once and register it in the Firebase console); release builds
      // use Play Integrity (Android) / App Attest (iOS). Non-fatal on failure.
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider:
              kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        );
        debugPrint('✓ Firebase App Check activated');
      } catch (e) {
        debugPrint('⚠️ App Check activation failed: $e');
      }

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
      _initService('PeriodService', () => PeriodService.init()),
      _initService('StepService', () => StepService.init()),
      _initService('SleepService', () => SleepService.init()),
      _initService('LlmService', () => LlmService().init()),
    ]);
    
    // Sync snooze settings asynchronously (non-blocking)
    _syncSnoozeSettings();
    
    // Initialize only critical services for startup
    await Future.wait([
      if (!kSkipNotifInit)
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
        // The payload is `alarm:{json}` carrying the real title/body/id so the
        // AlarmScreen shows the actual reminder (with a fallback for the old
        // `alarm:$id` format).
        alarmPayload = parseAlarmPayload(
            payload, notificationAppLaunchDetails?.notificationResponse?.id);
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
  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  void _loadThemePreference() {
    final settings = CleanStorageService.getUserSettings();
    themeModeNotifier.value =
        themeModeFromPreference(settings.themeModePreference);
  }

  /// Kept for backward compatibility — delegates to [themeModeNotifier] so any
  /// caller using `MyApp.of(context)?.setThemeMode(...)` still works.
  void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }

  @override
  Widget build(BuildContext context) {
    final isFirstLaunch = CleanStorageService.isFirstLaunch;

    // Determine initial route based on launch state
    String determineInitialRoute() {
      if (widget.initialRoute != null) return widget.initialRoute!;
      if (kE2ETest) return '/home'; // tests skip onboarding
      if (isFirstLaunch) return '/welcome';
      return '/home';
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'DailyMinder',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          navigatorKey: navigatorKey,
          initialRoute: determineInitialRoute(),
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/home': (context) => const AppShell(),
            '/alarm': (context) => AlarmScreen(
              // Per-navigation arguments (a tapped notification while the app is
              // alive) MUST win over the one-time cold-launch payload, else a
              // second alarm would show the first one's content.
              payload: (ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?) ??
                  widget.alarmPayload ??
                  {},
            ),
          },
        );
      },
    );
  }
}

