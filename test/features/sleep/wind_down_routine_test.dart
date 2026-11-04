/// "One-tap wind-down": the reminder opens a screen that asks, and Start chains
/// 4-7-8 breathing into a low sound that stops by itself.
///
/// What must hold: nothing starts without a tap; closing the breathing part-way starts
/// no sound and records nothing; finishing it starts the one Full Reset track that has
/// audio, for twenty minutes; an offer made while a relaxation session is already
/// playing never replaces it; a tap on the reminder opens the screen, once, and after
/// the app lock.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/breathing_exercise.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';
import 'package:tablet_remainder/features/focus/widgets/breathing_widget.dart';
import 'package:tablet_remainder/features/home/screens/app_shell.dart';
import 'package:tablet_remainder/features/medication/services/visit_brief_link.dart';
import 'package:tablet_remainder/features/sleep/screens/wind_down_screen.dart';
import 'package:tablet_remainder/features/sleep/services/wind_down_link.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/fake_audio_engine.dart';
import '../../support/font_free_theme.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeAudioEngine engine;
  late RecordingNotificationScheduler scheduler;
  final relax = RelaxationService();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    engine = FakeAudioEngine();
    AudioService().engineForTesting = engine;
    AudioService().resetForTesting();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    relax.resetForTesting();
    WindDownLink.pendingOpen.value = false;
    VisitBriefLink.pendingOpen.value = null;
  });

  tearDown(() async {
    relax.resetForTesting();
    FocusService().resetForTesting();
    WindDownLink.pendingOpen.value = false;
    VisitBriefLink.pendingOpen.value = null;
    await db.close();
  });

  /// Frames enough for a route to finish arriving or leaving; never
  /// pumpAndSettle, which the breathing circle's own loop would hold open.
  Future<void> settleRoute(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('the routine', () {
    test('is 4-7-8 breathing, the Full Reset track that has audio, then nothing', () {
      expect(WindDownRoutine.pattern, BreathingPattern.sleepBreathing);
      expect(WindDownRoutine.pattern.inhaleSeconds, 4);
      expect(WindDownRoutine.pattern.holdAfterInhaleSeconds, 7);
      expect(WindDownRoutine.pattern.exhaleSeconds, 8);
      expect(WindDownRoutine.track.category, RelaxationCategory.nervousSystemReset);
      expect(AudioService.hasRelaxationAudio(WindDownRoutine.track.assetKey), isTrue,
          reason: 'the screen would offer a sound that plays nothing');
      expect(WindDownRoutine.soundMinutes, 20);
    });

    test('the breathing is worded as the minutes it takes, never fewer than one', () {
      expect(WindDownRoutine.breathingMinutes, 1);
    });
  });

  group('the reminder', () {
    test('carries the wind-down payload, and says what a tap does', () async {
      expect(
          await NotificationService()
              .scheduleBedtimeReminder(enabled: true, minuteOfDay: 21 * 60 + 30),
          isTrue);
      final armed = scheduler.scheduled.single;
      expect(armed.payload, WindDownLink.payload);
      expect(armed.body, contains('Tap for'));
    });

    NotificationResponse tap(String? payload) => NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload);

    test('a tap on it asks the shell to open the routine', () {
      NotificationService().onNotificationResponseForTesting(tap('winddown'));
      expect(WindDownLink.pendingOpen.value, isTrue);
    });

    test('other taps leave it alone, and it leaves theirs alone', () {
      for (final p in <String?>[null, '', 'visit:a1', 'refill:m1', 'winddown2']) {
        NotificationService().onNotificationResponseForTesting(tap(p));
        expect(WindDownLink.pendingOpen.value, isFalse, reason: '$p');
      }
      VisitBriefLink.pendingOpen.value = null;
      NotificationService().onNotificationResponseForTesting(tap('winddown'));
      expect(VisitBriefLink.pendingOpen.value, isNull);
    });

    test('only that payload is ours', () {
      expect(WindDownLink.isPayload('winddown'), isTrue);
      expect(WindDownLink.isPayload(null), isFalse);
      expect(WindDownLink.isPayload('Winddown'), isFalse);
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(411, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(),
        home: const Scaffold(body: SizedBox()),
      ));
      // Pushed over a first route, as it is from the Sleep screen, so closing
      // it has somewhere to go.
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<void>(builder: (_) => const WindDownScreen()));
      await tester.pump();
      await settleRoute(tester);
    }

    BreathingWidget breathing(WidgetTester tester) =>
        tester.widget<BreathingWidget>(find.byType(BreathingWidget));

    testWidgets('asks first: the three steps, and nothing playing', (tester) async {
      await open(tester);

      expect(find.text('Wind down'), findsOneWidget);
      expect(find.text('4-7-8 breathing'), findsOneWidget);
      expect(find.text(WindDownRoutine.track.name), findsOneWidget);
      expect(find.textContaining('20 minutes'), findsOneWidget);
      expect(find.text('Then quiet'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Skip the breathing'), findsOneWidget);
      expect(find.byType(BreathingWidget), findsNothing);
      expect(relax.isRunning, isFalse);
      expect(engine.playCalls, 0);
    });

    testWidgets('says it is not a treatment', (tester) async {
      await open(tester);
      expect(find.textContaining('not a treatment'), findsOneWidget);
    });

    testWidgets('Start begins the breathing, and still no sound', (tester) async {
      await open(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.byType(BreathingWidget), findsOneWidget);
      expect(breathing(tester).pattern, BreathingPattern.sleepBreathing);
      expect(breathing(tester).targetCycles, BreathingPattern.sleepBreathing.recommendedCycles);
      expect(relax.isRunning, isFalse);
      expect(engine.playCalls, 0);
    });

    testWidgets('closing the breathing part-way starts no sound and leaves', (tester) async {
      await open(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      breathing(tester).onClose!();
      await tester.pump();
      await settleRoute(tester);

      expect(relax.isRunning, isFalse);
      expect(engine.playCalls, 0);
      expect(find.byType(WindDownScreen), findsNothing,
          reason: 'someone who stopped breathing has not asked for a sound');
    });

    testWidgets('finishing the breathing starts the sound for twenty minutes', (tester) async {
      await open(tester);
      await tester.tap(find.text('Start'));
      await tester.pump();

      await tester.runAsync(() async {
        breathing(tester).onComplete!();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settleRoute(tester);

      expect(relax.isRunning, isTrue);
      expect(relax.selectedMusic, RelaxationMusicType.deepSleepDelta);
      expect(relax.selectedMinutes, 20);
      expect(find.byType(RelaxationScreen), findsOneWidget,
          reason: 'the running session, where it can be paused or ended');
      expect(find.byType(WindDownScreen), findsNothing);
    });

    testWidgets('finishing the breathing counts one exercise', (tester) async {
      await open(tester);
      int count() =>
          (CleanStorageService.getAppPreferences()['focusBreathingCount'] as int?) ?? 0;
      final before = count();
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.runAsync(() async {
        breathing(tester).onComplete!();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settleRoute(tester);

      expect(count(), before + 1);
    });

    testWidgets('skipping the breathing starts the sound at once', (tester) async {
      await open(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Skip the breathing'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settleRoute(tester);

      expect(relax.isRunning, isTrue);
      expect(relax.selectedMusic, RelaxationMusicType.deepSleepDelta);
      expect(find.byType(BreathingWidget), findsNothing);
    });

    testWidgets('a session already playing is never replaced', (tester) async {
      await tester.runAsync(() async {
        relax.setMusic(RelaxationMusicType.binauralBeatsAlpha);
        relax.setDuration(45);
        await relax.startSession();
      });
      await open(tester);

      expect(find.text('Your relaxation session'), findsOneWidget);
      expect(find.text(WindDownRoutine.track.name), findsNothing);
      expect(find.text('Skip the breathing'), findsNothing,
          reason: 'there is no sound to start straight away');

      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.runAsync(() async {
        breathing(tester).onComplete!();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settleRoute(tester);

      expect(relax.selectedMusic, RelaxationMusicType.binauralBeatsAlpha);
      expect(relax.selectedMinutes, 45);
    });
  });

  group('the app shell', () {
    Future<void> frames(WidgetTester tester, [int n = 12]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(theme: fontFreeTheme(), home: const AppShell()));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 300));
      } finally {
        FlutterError.onError = prev;
      }
    }

    testWidgets('a reminder that started the app opens the routine, once', (tester) async {
      WindDownLink.pendingOpen.value = true;
      await pumpShell(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await frames(tester);

      expect(find.byType(WindDownScreen), findsOneWidget);
      expect(WindDownLink.pendingOpen.value, isFalse);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('one tapped while the app is open does too', (tester) async {
      await pumpShell(tester);
      expect(find.byType(WindDownScreen), findsNothing);

      WindDownLink.pendingOpen.value = true;
      await frames(tester, 4);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await frames(tester);

      expect(find.byType(WindDownScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('while the app lock is engaged it waits for the unlock', (tester) async {
      final lock = AppLockService().isLockedNotifier;
      lock.value = true;
      addTearDown(() => lock.value = false);
      await pumpShell(tester);

      WindDownLink.pendingOpen.value = true;
      await frames(tester, 4);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await frames(tester);
      expect(find.byType(WindDownScreen), findsNothing,
          reason: 'it must not open behind the PIN screen');

      lock.value = false;
      await frames(tester, 4);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await frames(tester);
      expect(find.byType(WindDownScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
