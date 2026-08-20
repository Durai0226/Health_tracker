@Tags(['responsive'])
library;

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
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/primitives.dart';
import 'package:tablet_remainder/core/widgets/toast/toast_overlay.dart';
import 'package:tablet_remainder/features/focus/screens/app_allow_list_screen.dart';
import 'package:tablet_remainder/features/focus/screens/custom_tags_screen.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/screens/plant_real_trees_screen.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/perf_rating.dart';

/// What a brand-new user meets, and what finishing a session feels like.
///
/// ## `dead-end-empty-state` — the screen that decides whether they come back
///
/// A fresh install has no sessions, no plants and no stats, so most of Focus
/// opens on an empty state. Today those states report ABSENCE and stop there:
/// *"Your garden is empty / Complete focus sessions to grow plants!"*,
/// *"No focus sessions yet"*. Nothing on either screen offers a way forward, and
/// nothing in the twelve structural dimensions can see that — a dead end builds,
/// lays out, contrasts and fits perfectly.
///
/// Measured as a structural contract rather than a reading of the copy: on a
/// fresh install each surface below must render an [EmptyState] **with a
/// non-null `action`**. Requiring the shared widget is the load-bearing half —
/// `focus_garden_screen.dart:319` hand-rolls its own empty Column, so a gate that
/// only checked `EmptyState.action` would have found nothing there and reported
/// the screen clean.
///
/// ## `silent-completion` — the one moment that should feel like something
///
/// `_completeSession` (`focus_service.dart:898`) calls
/// `NotificationService.showImmediateNotification` unconditionally, so a user
/// watching the timer hit zero gets a system banner over the screen they are
/// already looking at. Meanwhile `focus_toast.dart` holds 144 lines of finished
/// celebration — `sessionComplete` with `showParticles: true` — and has **zero
/// callers**. It is the usage example in the barrel file.
///
/// Measured by driving a real session to completion with the screen mounted and
/// asking `ToastService.hasActiveToasts`. Not "is a notification scheduled" —
/// the notification is not the defect. Delivering it to someone who is already
/// looking at the app, instead of anything in-app, is.
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
    // Without this the first overlay of the file is cached for every later test
    // and the completion assertion would turn on test order.
    ToastOverlay.instance.resetForTesting();
  });

  tearDown(() async {
    ToastOverlay.instance.resetForTesting();
    FocusService().resetForTesting();
    await db.close();
  });

  /// Surfaces a fresh install can land on with nothing to show.
  ///
  /// Deliberately NOT every Focus screen — a gate demanding an empty state from a
  /// screen that is never empty measures nothing, and the membership below was
  /// corrected by the harness rather than assumed:
  ///
  ///  * `focus_tags` started in this list and does not belong. It renders a
  ///    "Default Tags" section from the eight tags `TagService` ships
  ///    (`custom_tags_screen.dart:54`), so a brand-new user already sees content.
  ///  * `relaxation` and `plant_trees` are catalogues; their content is compiled
  ///    in.
  ///
  /// All three are still probed and printed below, so an exclusion is visible in
  /// the output rather than being a silent omission.
  final emptyable = <String, Widget Function()>{
    'focus_garden': () => const FocusGardenScreen(),
    'focus_stats': () => const DetailedStatsScreen(),
    // Genuinely empty on a fresh install: `app_allow_list_screen.dart:285`
    // branches on `_allowList.apps.isEmpty` to a hand-rolled 'No apps added yet'.
    'focus_apps': () => const AppAllowListScreen(),
  };

  final probeOnly = <String, Widget Function()>{
    'focus_tags': () => const CustomTagsScreen(),
    'relaxation': () => const RelaxationScreen(),
    'plant_trees': () => const PlantRealTreesScreen(),
  };

  final deadEnds = <String, String>{};
  final report = <String, String>{};

  /// Starts as "did not conclude" and is cleared only on an observed pass.
  ///
  /// The first version of this harness left it null until a defect was found, so
  /// when the probe threw on its own sanity check the report printed "in-app
  /// feedback shown on completion" — a clean result for a measurement that never
  /// happened. `tool/rate.dart` cannot catch that either: a failing harness exits
  /// 1, which it treats as ordinary findings, so a dimension that emits nothing
  /// prints as clean.
  ///
  /// So the default is a finding. Nothing measured must never read as nothing
  /// wrong; that is the entire premise of `rating/manifest.json`.
  String? completionFinding =
      'the completion probe did not reach a conclusion, so in-app feedback on '
      'session completion is UNMEASURED rather than absent — treat as a defect '
      'until the probe runs';

  /// Same doctrine as [completionFinding]: defaults to a finding, so a probe that
  /// never reaches a conclusion cannot print as a clean first run.
  String? firstRunFinding =
      'the Focus screen first-run probe did not reach a conclusion, so whether a '
      'new user is offered anything is UNMEASURED rather than fine';

  Future<bool> pumpFresh(WidgetTester tester, Widget Function() build) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await withClock(Clock.fixed(DateTime(2026, 3, 14, 13, 0)), () async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: AccentScope(feature: FeatureAccent.focus, child: build()),
        ));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 350));
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      FlutterError.onError = prev;
    }
  }

  /// Describes what [name] shows a brand-new user, and returns the failure
  /// reason if it is a dead end.
  String? inspect(WidgetTester tester, String name) {
    final states = tester.widgetList<EmptyState>(find.byType(EmptyState)).toList();
    if (states.isEmpty) {
      report[name] = 'no EmptyState widget rendered';
      return 'a fresh install renders no EmptyState at all — either the screen '
          'is not actually empty, or its empty state is hand-rolled and so '
          'carries no action contract';
    }
    final withAction = states.where((s) => s.action != null).toList();
    report[name] = '${states.length} EmptyState(s): '
        '${states.map((s) => '"${s.title}"${s.action == null ? ' [no action]' : ''}').join(', ')}';
    if (withAction.isEmpty) {
      return '${states.length} empty state(s), none offering an action: '
          '${states.map((s) => '"${s.title}"').join(', ')}';
    }
    return null;
  }

  for (final entry in emptyable.entries) {
    final name = entry.key;
    testWidgets('$name: a fresh install offers a way forward', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      if (!await pumpFresh(tester, entry.value)) return;
      final problem = inspect(tester, name);
      if (problem != null) deadEnds[name] = problem;

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 7));
    });
  }

  for (final entry in probeOnly.entries) {
    final name = entry.key;
    testWidgets('$name: reported, not gated (a catalogue is never empty)',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      if (!await pumpFresh(tester, entry.value)) return;
      inspect(tester, name);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 7));
    });
  }

  testWidgets('the Focus screen itself offers a first session above the fold',
      (tester) async {
    // The plan promised the empty Focus screen would offer "one obvious next
    // step, not thirteen empty configuration sections". The restructure is what
    // delivers that, and the coach line supplies the prompt — but neither was
    // MEASURED, and "the restructure probably handles it" is the kind of claim
    // this whole exercise exists to stop making.
    //
    // Deliberately a realistic 375x812 rather than the 1200-tall canvas the other
    // tests use: "above the fold" is meaningless on a viewport no phone has.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    if (!await pumpFresh(tester, () => const FocusScreen())) {
      firstRunFinding = 'the Focus screen threw while building on a fresh '
          'install, so its first run is UNMEASURED';
      return;
    }

    final start = find.text('Start Focus');
    if (start.evaluate().isEmpty) {
      firstRunFinding = 'a brand-new user sees no "Start Focus" affordance at all';
      return;
    }

    final rect = tester.getRect(start.first);
    if (rect.bottom > 812) {
      firstRunFinding = 'the only way to begin sits ${rect.top.toStringAsFixed(0)}pt '
          'down, below the fold of a 375x812 phone — a new user has to scroll to '
          'find the one thing the screen is for';
      return;
    }

    // And it must say what to do, not just offer a button. `focusCoach` returns a
    // start prompt at totalSessions == 0; this pins that it actually reaches the
    // screen rather than sitting in a builder nobody calls.
    final prompts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.toLowerCase().contains('start'))
        .toList();
    if (prompts.length < 2) {
      firstRunFinding = 'the screen offers a Start button but no first-session '
          'prompt anywhere near it. Strings containing "start": $prompts';
      return;
    }

    firstRunFinding = null;
  });

  testWidgets('finishing a session produces in-app feedback, not just an OS banner',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final focus = FocusService();
    // An ADVANCING clock, not a fixed one: the timer derives its remaining
    // seconds from `_endTime.difference(clock.now())`, so completion has to be
    // reached by moving the clock rather than by injecting a tick count.
    var now = DateTime(2026, 3, 14, 13, 0);

    // A GoogleFonts-free theme, for this test only.
    //
    // Reaching completion needs `tester.runAsync` (see below), and that lets the
    // REAL event loop run — which surfaces a latent async throw that every other
    // harness merely postpones forever: no font is bundled (pubspec's `fonts:`
    // block is entirely commented out), so with `allowRuntimeFetching = false`
    // google_fonts throws asynchronously for each missing face. Under pure
    // FakeAsync that future is never scheduled, so nobody has ever seen it.
    //
    // `AppTheme` registers exactly one extension, so substituting the const
    // `AppColorsExt.light` gives the screen everything it reads. The assertion
    // here is about ToastOverlay, which no text style can influence, and the
    // real theme stays under test on all eight surfaces above.
    final theme = ThemeData.light().copyWith(
      extensions: const <ThemeExtension<dynamic>>[AppColorsExt.light],
    );

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: const AccentScope(
              feature: FeatureAccent.focus, child: FocusScreen()),
        ));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 350));

        focus.setDuration(1); // kMinSessionMinutes
        await focus.startSession();
        await tester.pump(const Duration(milliseconds: 50));
        expect(focus.isRunning, isTrue, reason: 'sanity: the session started');

        now = now.add(const Duration(seconds: 61));

        // `runAsync`, not a pump loop. `_completeSession` reaches
        // `NotificationService.showImmediateNotification`, which awaits `init()`
        // and therefore a platform channel round trip. Channel replies arrive on
        // the REAL event loop, which `tester.pump` does not advance — so inside
        // FakeAsync the await never returns, `_resetSession()` is never reached
        // and the session stays running forever. `focus_negative_test.dart` drives
        // completions happily only because it uses plain `test()`, where the
        // event loop is real. Under `runAsync` the missing plugin rejects
        // promptly and the service's own try/catch absorbs it.
        await tester.runAsync(() async {
          focus.applyTickFromClockForTesting();
          for (var i = 0; i < 200 && focus.isRunning; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });

        // Back under FakeAsync, let the overlay insertion actually build.
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 350));
      });

      expect(focus.isRunning, isFalse,
          reason: 'sanity: the session must have completed for this assertion '
              'to mean anything');
      expect(focus.sessions.single.wasCompleted, isTrue,
          reason: 'sanity: it completed rather than being abandoned');

      completionFinding = ToastOverlay.instance.hasActiveToasts
          ? null
          : 'a session completed with the screen mounted and no in-app feedback '
              'appeared; the only signal was NotificationService, i.e. a system '
              'banner over the screen the user is already looking at';
    } finally {
      FlutterError.onError = prev;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 7));
    }
  });

  tearDownAll(() {
    // ignore: avoid_print
    void p(String s) => print(s);

    p('\n===== FOCUS FIRST RUN =====');
    p('-- what a brand-new user sees --');
    if (report.isEmpty) {
      p('  nothing recorded');
    } else {
      report.forEach((k, v) => p('  $k: $v'));
    }
    p('\n-- dead ends (no action offered) --');
    if (deadEnds.isEmpty) {
      p('  none');
    } else {
      deadEnds.forEach((k, v) => p('  $k: $v'));
    }
    p('\n-- the Focus screen on a fresh install --');
    p('  ${firstRunFinding ?? 'Start is above the fold, with a first-session prompt'}');
    p('\n-- completion feedback --');
    p('  ${completionFinding ?? 'in-app feedback shown on completion'}');
    p('===========================\n');

    // Emit before asserting: `expect` throws, and a harness that dies before it
    // reports leaves the rating looking clean.
    // Beacon first: these dimensions were measured, findings or not.
    // Without this a clean run and a run that never happened are the same
    // silence, and tool/rate.dart scores both as perfect.
    reportMeasured(const ['dead-end-empty-state', 'silent-completion'],
        samples: report.length);

    for (final e in deadEnds.entries) {
      emitFinding(Finding(
        feature: 'Focus',
        screen: e.key,
        dimension: 'dead-end-empty-state',
        sev: Sev.p1,
        detail: e.value,
        source: 'structural: a fresh install must render an EmptyState with a '
            'non-null action (EmptyState is in primitives.dart and already '
            'takes one)',
      ));
    }
    if (firstRunFinding != null) {
      emitFinding(Finding(
        feature: 'Focus',
        screen: 'focus',
        dimension: 'dead-end-empty-state',
        sev: Sev.p1,
        detail: firstRunFinding!,
        source: 'structural: on a fresh install the Focus screen must show a '
            'Start affordance above the fold of a 375x812 phone, plus a '
            'first-session prompt',
      ));
    }
    if (completionFinding != null) {
      emitFinding(Finding(
        feature: 'Focus',
        screen: 'focus',
        dimension: 'silent-completion',
        sev: Sev.p1,
        detail: completionFinding!,
        source: 'structural: ToastOverlay.hasActiveToasts after a real session '
            'completes with the screen mounted',
      ));
    }

    expect(deadEnds, isEmpty,
        reason: 'screens where a new user has nothing to do:\n'
            '${deadEnds.entries.map((e) => '${e.key}: ${e.value}').join('\n')}');
    expect(firstRunFinding, isNull, reason: firstRunFinding ?? '');
    expect(completionFinding, isNull, reason: completionFinding ?? '');
  });
}
