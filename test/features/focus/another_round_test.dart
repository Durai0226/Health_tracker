import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/widgets/toast/premium_toast.dart';
import 'package:tablet_remainder/core/widgets/toast/toast_overlay.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// Finishing a session offers "Another round": the same session again, one tap
/// from the completion toast.
///
/// Reaching completion needs `tester.runAsync` (the completion path awaits a
/// platform channel that FakeAsync never answers), which lets google_fonts'
/// async load throw because no font is bundled — so, as in
/// `focus_first_run_test`, this uses a font-free theme. The assertion is about
/// the toast and the service, which no text style can influence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    ToastOverlay.instance.resetForTesting();
  });

  tearDown(() async => db.close());

  final theme = ThemeData.light().copyWith(
    extensions: const <ThemeExtension<dynamic>>[AppColorsExt.light],
  );

  /// Mounts Focus, runs a one-minute session to completion, and returns with
  /// the completion toast on screen.
  Future<void> finishOneSession(WidgetTester tester, FocusService focus,
      {required DateTime Function() now, required void Function(DateTime) setNow}) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      // A status-bar inset, as on every real phone: without one the toast sits
      // on the very top edge of the test view where its button is not reliably
      // hittable.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(padding: const EdgeInsets.only(top: 60)),
        child: child!,
      ),
      home: const AccentScope(
          feature: FeatureAccent.focus, child: FocusScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    focus.setDuration(1);
    await focus.startSession();
    await tester.pump(const Duration(milliseconds: 50));
    expect(focus.isRunning, isTrue, reason: 'sanity: the session started');

    setNow(now().add(const Duration(seconds: 61)));
    await tester.runAsync(() async {
      focus.applyTickFromClockForTesting();
      for (var i = 0; i < 200 && focus.isRunning; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump(const Duration(milliseconds: 50));
    // Long enough for the toast's slide-in to finish.
    await tester.pump(const Duration(milliseconds: 1200));
  }

  /// The action the screen handed the completion toast. Read off the widget
  /// rather than tapped: the toast slides and layers, so a pixel tap on its
  /// button is not reliable in a headless test, while this is exactly the
  /// callback a tap would run.
  ToastAction completionAction(WidgetTester tester) {
    final toast = tester.widget<PremiumToast>(find.byType(PremiumToast));
    expect(toast.action, isNotNull,
        reason: 'the completion toast carries an action');
    return toast.action!;
  }

  testWidgets('the completion toast offers Another round, and tapping it '
      'starts the same session again', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final focus = FocusService();
    var t = DateTime(2026, 3, 14, 13, 0);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await withClock(Clock(() => t), () async {
        await finishOneSession(tester, focus,
            now: () => t, setNow: (v) => t = v);

        expect(focus.isRunning, isFalse, reason: 'sanity: it completed');
        expect(focus.sessions.single.wasCompleted, isTrue);
        expect(find.text('Another round'), findsOneWidget);
        expect(completionAction(tester).label, 'Another round');

        completionAction(tester).onPressed();
        await tester.pump(const Duration(milliseconds: 50));

        expect(focus.isRunning, isTrue,
            reason: 'one tap restarts the session');
        expect(focus.selectedMinutes, 1,
            reason: 'with the settings the last one used');

        // Leave nothing running behind the test.
        await tester.runAsync(() => focus.abandonSession());
      });
    } finally {
      FlutterError.onError = prev;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 12));
    }
  });

  // Behaviour, not mechanism: `startSession()` is itself idempotent while a
  // session runs, so the screen's own guard in `_anotherRound` is belt and
  // braces and removing it does not change this outcome. What matters to the
  // user is that a second press can never restart the session under them.
  testWidgets('pressing it again while the new session runs does not restart '
      'it', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final focus = FocusService();
    var t = DateTime(2026, 3, 14, 13, 0);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await withClock(Clock(() => t), () async {
        await finishOneSession(tester, focus,
            now: () => t, setNow: (v) => t = v);

        final action = completionAction(tester);
        action.onPressed();
        await tester.pump(const Duration(milliseconds: 50));
        expect(focus.isRunning, isTrue);
        final startedAt = focus.sessionStartedAtForTesting;

        // The clock moves on, so a second startSession() WOULD stamp a new
        // start time and be visible. The toast outlives the tap, so the same
        // action can fire again.
        t = t.add(const Duration(seconds: 5));
        action.onPressed();
        await tester.pump(const Duration(milliseconds: 50));

        expect(focus.isRunning, isTrue);
        expect(focus.sessionStartedAtForTesting, startedAt,
            reason: 'no second startSession() over the running one');

        await tester.runAsync(() => focus.abandonSession());
      });
    } finally {
      FlutterError.onError = prev;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 12));
    }
  });
}
