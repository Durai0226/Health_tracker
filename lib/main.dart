
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/services/active_profile_service.dart';
import 'core/services/app_lock_service.dart';
import 'core/services/clean_storage_service.dart';
import 'core/database/app_database.dart';
import 'core/services/auth_service.dart';
import 'core/services/cloud_sync_service.dart';
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
import 'core/services/app_check_service.dart';
import 'features/settings/screens/app_lock_gate.dart';

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
        // Other services can be initialized on-demand
      ]);
      
      // Reschedule reminders after services are ready (non-blocking)
      try {
        await ReminderRescheduleService.rescheduleAllReminders();
        debugPrint('✓ Reminders rescheduled in background');
      } catch (e) {
        debugPrint('⚠️ Reminder reschedule failed: $e');
      }

      // Cloud sync (medicines, water, and — via HealthCloudSyncService —
      // period/steps/sleep) was fully implemented but never actually invoked
      // anywhere; wire it in here so it runs once per app start for a signed-
      // in user, the same best-effort, non-blocking way as the reschedule above.
      // Health data may only leave the device with explicit consent.
      //
      // This used to gate on `currentUser?.id != null`, which is satisfied by
      // the ANONYMOUS Firebase account that AuthService.init() creates silently
      // on first launch — so medicines, water and 60 days of steps/sleep were
      // uploaded for every user, including people who tapped "Continue as
      // guest", while onboarding told them "Private · on-device · no account".
      //
      // Two guards now, matching what SyncService already does
      // (sync_service.dart: `if (user.isAnonymous) return;`):
      //   1. isAuthenticated — excludes anonymous users and offline guests
      //   2. cloudSyncEnabled — the user's own opt-in, default false
      final auth = AuthService();
      final userId = auth.currentUser?.id;
      if (auth.isAuthenticated &&
          CleanStorageService.cloudSyncEnabled &&
          userId != null &&
          userId.isNotEmpty) {
        try {
          await CloudSyncService().syncUserData(userId);
          debugPrint('✓ Cloud sync completed in background');
        } catch (e) {
          debugPrint('⚠️ Cloud sync failed: $e');
        }
      } else {
        debugPrint('• Cloud sync skipped — data stays on device');
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

    // SILENCE LOGGING IN RELEASE BUILDS.
    //
    // `debugPrint` is not compiled out of release builds — it writes to
    // logcat. This app has ~692 print sites, and they emit real PII: the
    // signed-in user's email address, Firebase UIDs across the sync services,
    // medicine names from the alarm isolate, and (until this pass) an entire
    // drink-by-drink health CSV.
    //
    // Android has restricted cross-app logcat reads since 4.1, so this is not
    // remotely exploitable — but it lands in bug reports, in `adb logcat` on
    // any connected machine, and in whatever crash-reporting SDK gets added
    // next. One line removes the whole class.
    if (kReleaseMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
    
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // App Check — attest that requests come from a genuine, untampered build
      // BEFORE any Firestore/Auth use, so the backend can reject abuse (e.g.
      // scripted anonymous writes). It is also the ONLY credential behind the
      // Smart answers tier, so AppCheckService can explain a failure rather than
      // leaving the AI silently unavailable. Non-fatal on failure.
      // Bounded: App Check is a Play Integrity / App Attest attestation, i.e.
      // a network round trip, and it sat on the critical path BEFORE the first
      // frame with no timeout. On a flaky connection or behind a captive
      // portal the user stared at the system splash until Firebase's own
      // internal timeout expired. Attestation failing is already non-fatal —
      // it should also be non-blocking.
      await AppCheckService.activate()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('⚠️ App Check attestation timed out — continuing');
      });

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
    ]);
    
    // Sync snooze settings asynchronously (non-blocking)
    _syncSnoozeSettings();
    
    // Initialize only critical services for startup
    await Future.wait([
      if (!kSkipNotifInit)
        _initService('NotificationService', () => NotificationService().init()),
      // Bounded for the same reason as App Check above: AuthService.init()
      // awaits `authStateChanges().first` and then `signInAnonymously()` —
      // both network round trips, both previously untimed, both ahead of the
      // first frame. Nothing painted at startup needs a uid.
      _initService(
          'AuthService',
          () => AuthService().init().timeout(
                const Duration(seconds: 3),
                onTimeout: () =>
                    debugPrint('⚠️ Auth init timed out — continuing offline'),
              )),
      _initService('HapticService', () => HapticService().init()),
      _initService('FeatureManager', () => FeatureManager().init()),
      _initService('ActiveProfileService', () => ActiveProfileService().init()),
      _initService('AppLockService', () => AppLockService().init()),
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
          navigatorObservers: [appLockRouteObserver],
          // Wraps the Navigator (passed in as `child`) so the app-lock PIN
          // overlay can sit above EVERY screen without threading itself into
          // each route individually. See AppLockGate's doc comment.
          builder: (context, child) {
            // Honour Dynamic Type up to 200%, which is what WCAG 2.2 SC 1.4.4
            // requires ("text can be resized up to 200 percent without loss of
            // content or functionality").
            //
            // This was temporarily capped at 1.3x while the layout was fixed —
            // at the time 12 screens overflowed at 2.0x. They now pass, so the
            // cap is at the standard. test/responsive/responsive_overflow_test.dart
            // renders every screen at 1.0x / 1.3x / 2.0x across four phone
            // widths and is the regression gate; do not lower this without
            // making that harness green at the lower value first.
            //
            // The ceiling remains because beyond 200% the fixed-geometry
            // elements (progress rings, the focus timer) have no reflow story.
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(maxScaleFactor: 2.0),
              ),
              child: AppLockGate(child: child ?? const SizedBox.shrink()),
            );
          },
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

