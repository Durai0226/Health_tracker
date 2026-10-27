
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/dev/qa_seed.dart';
import 'core/services/active_profile_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/app_lock_service.dart';
import 'core/services/clean_storage_service.dart';
import 'core/database/app_database.dart';
import 'core/services/auth_service.dart';
import 'core/services/cloud_sync_runner.dart';
import 'core/services/haptic_service.dart';
import 'core/services/vitavibe_service.dart';
import 'features/medication/services/medicine_storage_service.dart';
import 'features/focus/services/focus_service.dart';
import 'features/water/services/water_service.dart';
import 'features/period/services/period_service.dart';
import 'features/steps/services/step_service.dart';
import 'features/sleep/services/sleep_service.dart';
import 'features/biometrics/services/biometrics_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_reschedule_service.dart';
import 'core/services/background_alarm_service.dart';
import 'core/services/background_health_sync_service.dart';
import 'core/services/feature_flag_service.dart';
import 'core/services/feature_manager.dart';
import 'core/services/simple_ad_service.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/screens/welcome_screen.dart';
import 'features/home/screens/app_shell.dart';
import 'features/reminders/screens/alarm_screen.dart';
import 'features/reminders/services/reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/services/app_check_service.dart';
import 'core/services/health_rationale_channel.dart';
import 'features/settings/screens/app_lock_gate.dart';
import 'core/constants/app_strings.dart';
import 'features/medication/services/refill_loop.dart';
import 'features/medication/services/visit_brief_link.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Test-only flag (set via `--dart-define=E2E_TEST=true`) to make the app
/// drivable by integration tests: skips the first-run welcome and the ads/ATT
/// init, whose native permission dialog a widget-test can't dismiss. Defaults to
/// false, so production builds are completely unaffected.
const bool kE2ETest = bool.fromEnvironment('E2E_TEST');

/// Test-only: plant sample data before the first frame.
///
///   --dart-define=E2E_SEED=true        ~30 days, 4 medicines
///   --dart-define=E2E_SEED=heavy       ~365 days, 8 medicines (load test)
///
/// `String.fromEnvironment` with no define is a compile-time constant empty
/// string, so the AOT compiler eliminates the branch below and tree-shakes
/// `seedQaData` — and every screen it reaches — out of the release binary.
/// Same argument that already justifies [kE2ETest].
const String kE2ESeed = String.fromEnvironment('E2E_SEED');

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

/// Sync the alarm-isolate settings mirror asynchronously without blocking startup.
///
/// A safety net, not the mechanism: [CleanStorageService.saveUserSettings] now
/// mirrors on every save, so a change in Settings takes effect immediately
/// instead of at the next cold start. This still runs to cover installs upgrading
/// from a build that never wrote some of these keys.
void _syncSnoozeSettings() {
  Future(() async {
    try {
      await CleanStorageService.mirrorSettingsForAlarmIsolate(
          CleanStorageService.getUserSettings());
      debugPrint('✓ Synced alarm-isolate settings to SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Snooze settings sync failed: $e');
    }
  });
}

/// Initialize non-critical services after app launch to improve startup time
void _initDeferredServices() {
  Future(() async {
    try {
      // Initialize non-critical services in background
      await Future.wait([
        // Skip ads/ATT under E2E or screenshot mode — its native permission
        // dialog blocks tests/screenshots.
        if (!kE2ETest && !kSkipNotifInit)
          _initService('SimpleAdService', () => SimpleAdService().init()),
        _initService('BackgroundAlarmService', () => BackgroundAlarmService().init()),
        // Separate from BackgroundAlarmService on purpose: a data sync must
        // not ride the exact-alarm path. See its class doc.
        _initService('BackgroundHealthSync',
            () => BackgroundHealthSyncService.instance.init()),
        _initService('FeatureFlagService', () => FeatureFlagService().init()),
        _initService('VitaVibeService', () => VitaVibeService().init()),
        // Registers the home-screen widget's tap handler. Without this the
        // widget's "+250" button fires its broadcast, the isolate starts, and
        // finds no callback to run — a dead button with no error anywhere.
        _initService('HomeWidget', () => HomeWidgetService.init()),
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
      // Two guards now:
      //   1. isAuthenticated — excludes anonymous users and offline guests
      //   2. cloudSyncEnabled — the user's own opt-in, default false
      // The same gates (a real account, and their own opt-in) now live in
      // CloudSyncRunner, which also runs it when sync is switched on and when the
      // app returns to the front — not only here.
      await CloudSyncRunner.maybeSync(force: true);

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
  // Whatever the host installed before us. Under `flutter test` /
  // `integration_test` that is the binding's reporter, which turns a framework
  // error into a FAILING TEST.
  final FlutterExceptionHandler? hostOnError = FlutterError.onError;

  // Catch all Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // Overwriting the host handler unconditionally is why every integration
    // suite could walk a visibly broken app and still report green: from this
    // line on, every RenderFlex overflow, every `setState() after dispose()`,
    // and every exception thrown inside a builder was printed and discarded.
    // Under E2E we hand the error back to the harness instead. Production is
    // unaffected — `kE2ETest` is a compile-time false there.
    if (kE2ETest) {
      hostOnError?.call(details);
      return;
    }
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
    
    // Initialize core storage service (now uses Drift).
    //
    // Deliberately AWAITED ALONE, not folded into the group below: the
    // services there read `CleanStorageService.getAppPreference`, which is the
    // SYNCHRONOUS cache — it answers from memory and cannot wait for a load in
    // flight. StepService.init reaches it for the best-day record and the
    // step-reminder settings (step_service.dart), and PeriodService.init fires
    // PeriodReminderService.reschedule, whose getConfig() reads
    // 'periodReminderConfig' the same way. Started concurrently, both would
    // silently read defaults on every cold start. The four reads INSIDE
    // CleanStorageService.init are the ones that now run together.
    await _initService('CleanStorageService', () => CleanStorageService.init());

    // Initialize dependent storage services in parallel
    await Future.wait([
      _initService('MedicineCleanStorageService', () => MedicineCleanStorageService.init()),
      _initService('WaterService', () => WaterService.init()),
      _initService('PeriodService', () => PeriodService.init()),
      _initService('StepService', () => StepService.init()),
      _initService('SleepService', () => SleepService.init()),
      _initService('BiometricsService', () => BiometricsService.init()),
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
      // Reminders start watching Drift at launch, not on screen mount — same
      // reasoning as Focus below. The Today dashboard shows reminders, so a
      // cold launch straight to Today must not read a stale list, and a write
      // from the reschedule pass (which runs at startup) must be visible
      // without the user navigating into the reminders screen first.
      _initService('ReminderService', () => ReminderService.instance.start()),
      // Focus hydrates at startup, not on screen mount.
      //
      // init() used to be called ONLY from FocusScreen.initState, so on a cold
      // launch the Today dashboard's Focus KPI and streak chip read an
      // un-hydrated singleton and rendered 0 minutes / no streak — with the real
      // data sitting on disk the whole time — until the user happened to open the
      // Focus screen once. Cheap here: it reads the already-loaded preference
      // cache, and audio self-initialises later on first playback.
      _initService('FocusService', () => FocusService().init()),
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
      RefillLoop.pendingOpen.value = RefillLoop.medicineIdFromPayload(payload);
      VisitBriefLink.pendingOpen.value = VisitBriefLink.appointmentIdFromPayload(payload);
      if (payload != null && payload.startsWith('alarm:')) {
        initialRoute = '/alarm';
        // The payload is `alarm:{json}` carrying the real title/body/id so the
        // AlarmScreen shows the actual reminder (with a fallback for the old
        // `alarm:$id` format).
        alarmPayload = parseAlarmPayload(
            payload, notificationAppLaunchDetails?.notificationResponse?.id);
      }
    }

    if (kE2ESeed.isNotEmpty) {
      await seedQaData(
        profile:
            kE2ESeed == 'heavy' ? SeedProfile.heavy : SeedProfile.typical,
      );
    }

    // Attach BEFORE runApp so a Health Connect rationale intent that arrives
    // during startup is deferred rather than dropped. The matching pull for
    // the cold-start case happens on the first frame, in _MyAppState.
    HealthRationaleChannel.instance.attach();

    runApp(MyApp(initialRoute: initialRoute, alarmPayload: alarmPayload));
  }, (error, stackTrace) {
    // The async half of the same problem. A `runZonedGuarded` handler that
    // only logs makes every escaping async error invisible to the harness, and
    // unlike `FlutterError.onError` a test cannot reclaim it from outside the
    // zone. Route it back through FlutterError under E2E so the collector in
    // `integration_test/support/e2e.dart` sees it.
    if (kE2ETest) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'app root zone',
      ));
      return;
    }
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
    // Health Connect may have launched us straight into its rationale deep
    // link. Kotlin buffers that until a navigator exists, which is only true
    // after the first frame.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => HealthRationaleChannel.instance.drainPending());
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
          title: AppStrings.productName,
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

