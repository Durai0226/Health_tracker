import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_screen.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';

import '../../support/counting_executor.dart';
import '../../support/fake_audio_engine.dart';
import '../../support/recording_notification_scheduler.dart';

/// The locked relaxation session: what it rebuilds, what it writes, and how it
/// says the session is over.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CountingExecutor counter;
  late AppDatabase db;
  late RecordingNotificationScheduler notifications;
  final service = RelaxationService();

  final t0 = DateTime(2026, 3, 14, 13, 0);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory());
    db = AppDatabase.forTesting(counter);
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    AudioService().engineForTesting = FakeAudioEngine();
    AudioService().resetForTesting();
    // The completion announcement has two destinations and the choice between
    // them is the fix under test, so BOTH have to be observable. Without this
    // seam `showFocusNotification` fails headlessly and swallows it, and
    // deleting the notification branch outright passed every test in the file.
    notifications = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = notifications;
    service.resetForTesting();
  });

  tearDown(() async {
    service.resetForTesting();
    await db.close();
  });

  /// Put a running session on screen.
  ///
  /// `deepSleepDelta` is one of the three tracks that actually has audio behind
  /// it, so `startSession` is not refused.
  Future<void> pumpRunningSession(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    service.setMusic(RelaxationMusicType.deepSleepDelta);
    service.setDuration(15);
    await service.startSession();

    await tester.pumpWidget(const MaterialApp(home: RelaxationScreen()));
    // Never pumpAndSettle: the selection screen runs a looping breathing pulse.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('the timer display is not rebuilt every frame', (tester) async {
    // `_buildTimerDisplay` returned `AnimatedBuilder(animation: _waveController,
    // builder: …)` whose builder never read the controller's value — so a
    // 4-second controller on `repeat()` rebuilt the whole 260px display
    // (gradient circle, shadowed disc, FittedBox, progress column) on every
    // vsync to paint exactly the same pixels, for the length of the session.
    //
    // Measured as REBUILDS, not as the absence of an `AnimatedBuilder`: the
    // framework puts two of its own above this subtree (the stretch overscroll
    // indicator and a title notifier), so a structural assertion would fail on
    // widgets that have nothing to do with the defect. `_buildTimerDisplay`
    // constructs a fresh `ValueListenableBuilder` every time it runs, so widget
    // identity across quiet frames is exactly "was this subtree rebuilt".
    await withClock(Clock.fixed(t0), () async {
      await pumpRunningSession(tester);

      try {
        final clock = find.byType(ValueListenableBuilder<int>);
        expect(clock, findsOneWidget,
            reason: 'sanity: the locked session screen really is up');

        final before = tester.widget(clock);
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(identical(tester.widget(clock), before), isTrue,
            reason: 'five vsyncs with no state change must not rebuild the '
                'timer display — BEFORE THE FIX a repeating controller drove '
                'an AnimatedBuilder around all of it whose builder never read '
                'the value');

        // The control: a real state change DOES rebuild it, so the assertion
        // above cannot be passing because nothing is capable of rebuilding.
        service.pauseSession();
        await tester.pump();
        expect(identical(tester.widget(clock), before), isFalse,
            reason: 'pausing changes what the screen shows');
      } finally {
        service.resetForTesting();
        await tester.pump();
      }
    });
  });

  testWidgets('dragging the volume writes nothing until the thumb is released',
      (tester) async {
    // The screen half of the per-frame write. `RelaxationService.setVolume`
    // takes `persist: false` now, but only if the slider actually passes it —
    // `onChanged` firing the persisting call is exactly the defect.
    await withClock(Clock.fixed(t0), () async {
      await pumpRunningSession(tester);

      try {
        final slider = find.byType(Slider);
        expect(slider, findsOneWidget,
            reason: 'sanity: the running session shows its volume slider');

        counter.reset();
        // A drag that is still IN PROGRESS: down and move, deliberately no up.
        final gesture = await tester.startGesture(tester.getCenter(slider));
        for (var frame = 0; frame < 10; frame++) {
          await gesture.moveBy(const Offset(-8, 0));
          await tester.pump();
        }
        // NOT `pumpEventQueue()`: the session installs a `Timer.periodic`, and
        // inside testWidgets' FakeAsync the event queue never drains while a
        // periodic timer is pending. `tester.pump` advances it deterministically
        // and flushes the microtasks an unawaited write rides on.
        await tester.pump(const Duration(milliseconds: 20));

        expect(counter.writeTally['app_preferences'] ?? 0, 0,
            reason: 'BEFORE THE FIX every drag frame ran six Drift writes, two '
                'of them re-encoding the stats blob and the session history');
        expect(service.volume, lessThan(0.7),
            reason: 'sanity: the drag really did move the volume');

        counter.reset();
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(counter.writeTally['app_preferences'] ?? 0, 1,
            reason: 'releasing persists the one key it changed');
      } finally {
        service.resetForTesting();
        await tester.pump();
      }
    });
  });

  testWidgets('a completion the user is watching is said in the app',
      (tester) async {
    // `_completeSession` fired an OS notification unconditionally — and it can
    // only ever RUN in the foreground, because the ticker is cancelled when the
    // app is backgrounded and an elapsed session completes inside `_syncTimer()`
    // on the way back in. So every completion this feature has ever announced
    // arrived as a system banner dropped over the screen already showing it.
    await withClock(Clock.fixed(t0), () async {
      await pumpRunningSession(tester);
    });

    try {
      // Fifteen minutes later: the session has elapsed.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 15))),
          () async {
        service.applyTick();
      });
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));

      expect(service.justCompleted.value, isNotNull,
          reason: 'a listening screen must be handed the completion instead of '
              'being talked over by the OS');
      expect(find.text('Relaxation complete'), findsOneWidget,
          reason: 'and the screen has to actually present it — publishing to a '
              'notifier nobody renders would be worse than the banner');
      expect(find.text('15 minutes of Full Reset done'), findsOneWidget);
      expect(notifications.shown, isEmpty,
          reason: 'and the OS banner is the half that must NOT also fire — '
              'talking over the screen is the defect');
    } finally {
      service.resetForTesting();
      await tester.pump();
    }
  });

  test('a completion with no screen listening still uses the notification',
      () async {
    // The other half, and the reason the gate asks `hasConsumer` rather than
    // just reading a foreground flag: `RelaxationScreen` is a pushed route, so
    // "in the app, but not on this screen" is an ordinary state, and someone
    // there still has to be told.
    await withClock(Clock.fixed(t0), () async {
      service.setMusic(RelaxationMusicType.deepSleepDelta);
      service.setDuration(15);
      await service.startSession();
    });
    await withClock(Clock.fixed(t0.add(const Duration(minutes: 15))), () async {
      service.applyTick();
    });
    await pumpEventQueue();

    expect(service.isRunning, isFalse, reason: 'sanity: it did complete');
    expect(service.justCompleted.value, isNull,
        reason: 'nothing was listening, so the completion must NOT be dropped '
            'into a notifier nobody reads — the notification is the fallback');
    // Asserted, not assumed. `justCompleted` being null only says the notifier
    // was not used; on its own it is equally satisfied by announcing NOTHING,
    // which is the way this gate fails badly — the user is told by neither
    // route. Deleting the notification branch passed the whole file before this
    // line existed.
    expect(notifications.shown, hasLength(1),
        reason: 'someone still has to be told');
    expect(notifications.shown.single.id, NotificationService.focusSessionEndId);
    expect(notifications.shown.single.title, contains('Relaxation Complete'));
    expect(notifications.shown.single.body, contains('15 minutes'));
  });
}
