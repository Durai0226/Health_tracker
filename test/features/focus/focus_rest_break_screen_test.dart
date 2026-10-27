/// The break Flow offers when a session ends, on the Focus screen.
///
/// "Start 6 min" used to switch to single mode and start a six-minute FOCUS
/// session: the plant grew, the coins were paid, the streak counted, and the
/// median that "your usual length" comes from now included a rest. It starts a
/// break instead, and a break you stop early is not "giving up".
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart'
    show FocusMode;
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final focus = FocusService();
  final coins = CoinsService();
  final t0 = DateTime(2026, 3, 14, 13, 0);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    coins.resetForTesting();
    TagService().resetForTesting();
    StatsService().resetForTesting();
    await focus.init();
  });

  tearDown(() async {
    focus.resetForTesting();
    StatsService().resetForTesting();
    await db.close();
  });

  /// A test font makes every glyph a wide square, so a title that fits on a
  /// phone overflows here; that belongs to the responsive harness, not to this.
  void quietOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Several short pumps, then past the toast's own timeout, so neither a
  /// half-finished payout nor a toast timer outlives the test.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 5));
  }

  /// A Flow session that has run for [minutes], with the screen on top of it.
  Future<void> pumpFlowSession(WidgetTester tester, {int minutes = 30}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await withClock(Clock.fixed(t0), () async {
      focus.setMode(FocusMode.flow);
      await focus.startSession();
    });
    await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
    await pump(tester);
  }

  testWidgets('Done offers a break the length Flow suggests, and starting it is a break',
      (tester) async {
    quietOverflow();
    await withClock(Clock.fixed(t0.add(const Duration(minutes: 30))), () async {
      await pumpFlowSession(tester);
      try {
        await tester.ensureVisible(find.text('Done'));
        await tester.pump();
        await tester.tap(find.text('Done'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(focus.isRunning, isFalse, reason: 'the flow session itself ended');
        expect(focus.sessions, hasLength(1), reason: 'and was banked as a session');
        final coinsAfterSession = coins.coins.totalCoins;
        final sessionsAfter = focus.sessions.length;
        expect(find.text('Start 6 min'), findsOneWidget,
            reason: 'thirty minutes focused, divided by five');

        await tester.tap(find.text('Start 6 min'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(focus.isRunning, isTrue);
        expect(focus.isRestBreak, isTrue);
        expect(focus.isOnBreak, isTrue);
        expect(focus.remainingSeconds, 6 * 60);
        expect(focus.mode, FocusMode.flow,
            reason: 'it used to flip to single mode and start a focus session');
        expect(focus.sessions.length, sessionsAfter,
            reason: 'a break is not a session');
        expect(coins.coins.totalCoins, coinsAfterSession);

        await pump(tester);
        expect(find.text('On a Break'), findsOneWidget);
        expect(find.text('Step away from the screen for a bit.'), findsOneWidget);
        expect(find.text('End break'), findsOneWidget);
        expect(find.text('Give up'), findsNothing,
            reason: 'there is nothing to give up on');
        expect(find.text('Done'), findsNothing);
      } finally {
        if (focus.isRunning) await focus.abandonSession();
        await settle(tester);
      }
    });
  });

  testWidgets('End break stops it with no question, no withered plant and no record',
      (tester) async {
    quietOverflow();
    await withClock(Clock.fixed(t0), () async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await focus.startRestBreak(8);
      await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
      await pump(tester);
      final sessionsBefore = focus.sessions.length;
      final abandonedBefore = focus.stats.abandonedSessions;
      final gardenBefore = focus.garden.length;

      try {
        await tester.ensureVisible(find.text('End break'));
        await tester.pump();
        await tester.tap(find.text('End break'));
        await settle(tester);

        expect(find.text('Give up?'), findsNothing, reason: 'no confirmation');
        expect(focus.isRunning, isFalse);
        expect(focus.isRestBreak, isFalse);
        expect(focus.sessions.length, sessionsBefore);
        expect(focus.stats.abandonedSessions, abandonedBefore);
        expect(focus.garden.length, gardenBefore, reason: 'no plant withered');
      } finally {
        if (focus.isRunning) await focus.abandonSession();
        await settle(tester);
      }
    });
  });

  testWidgets('leaving the screen during a rest break is just leaving', (tester) async {
    quietOverflow();
    await withClock(Clock.fixed(t0), () async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await focus.startRestBreak(8);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const FocusScreen())),
                child: const Text('open focus'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open focus'));
      await pump(tester);
      expect(find.text('End break'), findsOneWidget, reason: 'the premise: on the screen');

      try {
        await tester.binding.handlePopRoute();
        await pump(tester);

        expect(find.text('Session Locked'), findsNothing,
            reason: '"leaving now will kill your plant" — there is no plant');
        expect(find.text('open focus'), findsOneWidget, reason: 'it simply went back');
        expect(focus.isRestBreak, isTrue, reason: 'and the break carries on');
      } finally {
        if (focus.isRunning) await focus.abandonSession();
        await settle(tester);
      }
    });
  });

  testWidgets('a focus session still asks before it lets you leave', (tester) async {
    quietOverflow();
    await withClock(Clock.fixed(t0), () async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      focus.setDuration(25);
      await focus.startSession();
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const FocusScreen())),
                child: const Text('open focus'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open focus'));
      await pump(tester);

      try {
        await tester.binding.handlePopRoute();
        await pump(tester);
        expect(find.text('Session Locked'), findsOneWidget,
            reason: 'the negative control: only a rest break is let go of freely');
      } finally {
        if (focus.isRunning) await focus.abandonSession();
        await settle(tester);
      }
    });
  });
}
