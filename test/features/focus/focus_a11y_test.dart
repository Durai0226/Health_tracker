@Tags(['responsive'])
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/focus/screens/app_allow_list_screen.dart';
import 'package:tablet_remainder/features/focus/screens/custom_tags_screen.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/screens/plant_real_trees_screen.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_screen.dart';
import 'package:tablet_remainder/features/focus/screens/settings/focus_reminders_settings_screen.dart';
import 'package:tablet_remainder/features/focus/models/breathing_exercise.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/widgets/breathing_widget.dart';
import 'package:tablet_remainder/features/focus/widgets/plant_animation_widget.dart';
import 'package:tablet_remainder/core/widgets/toast/toast.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/perf_rating.dart';

/// A RenderFlex/RenderBox overflow, which belongs to `responsive_overflow_test`
/// and not to this file.
///
/// Everything else that reaches `FlutterError.onError` here means the surface
/// did not render. That distinction is the whole point: this harness used to
/// install `FlutterError.onError = (_) {}` and swallow the lot, so a `build()`
/// that threw left an `ErrorWidget` on screen, scheduled no animation and
/// exposed no tap target — and both dimensions scored it clean.
bool _isOverflow(Object e) {
  final s = e.toString();
  return s.contains('overflowed by') || s.contains('A RenderFlex overflowed');
}

/// Can Focus be used without sight, and can it be used without motion?
///
/// ## Why this harness exists
///
/// The twelve dimensions in `rating/manifest.json` all measure **structure**:
/// does it build, does it overflow, is the text visible, are the targets big
/// enough. Every one of them can be green on a screen that a blind user cannot
/// operate and that makes a vestibular-sensitive user ill. The app scored
/// 4.75/5 with `Semantics(` appearing **zero times** in the whole Focus feature
/// and `disableAnimations` respected **nowhere** in it.
///
/// That is not the score being wrong. It is the score being blind. So this adds
/// the two experience dimensions that can be measured as a count or a boolean —
/// the same discipline every other dimension here follows. Taste stays out.
///
/// ## `no-semantics` — WCAG 2.2 SC 4.1.2 Name, Role, Value (Level A)
///
/// Every control a user can operate must have a programmatically determinable
/// name. An `IconButton` with no `tooltip` and no `Semantics` label is announced
/// by TalkBack and VoiceOver as, literally, "button" — the user is told
/// something is there and not what it does.
///
/// This walks the real semantics tree rather than the widget tree, because the
/// semantics tree is what the screen reader actually receives. Flutter's own
/// `labeledTapTargetGuideline` asserts the same property; this reimplements it
/// only so that each offender can be reported with its rect. `touch_target_audit`
/// learned that lesson the hard way: a finding nobody can locate gets read once
/// and ignored.
///
/// ## `motion-not-reduced` — WCAG 2.2 SC 2.3.3 Animation from Interactions
///
/// Measured as a **boolean, not a judgement**: pump the surface with
/// `disableAnimations: true` and ask whether the scheduler still holds a
/// transient callback once every finite animation has had time to finish. A
/// perpetual `AnimationController.repeat()` holds its ticker forever, so
/// `transientCallbackCount` stays above zero and the surface is, provably, still
/// moving after the user asked it to stop. This is the same signal
/// `pumpAndSettle` loops on.
///
/// Focus ships **five** perpetual `repeat()` controllers — two in
/// `relaxation_screen`, two in `breathing_widget`, two in
/// `plant_animation_widget` (one shared) — and consults the accessibility flag
/// in none of them.
///
/// Note this is NOT a duplicate of `never-settles` in `screen_build_cost`. That
/// dimension asks "does this cost battery unobserved" and covers exactly two
/// Focus screens (`timer`, `stats`). This one asks "does the OS-level
/// accessibility preference change anything", across all eight.
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
  });

  tearDown(() async {
    FocusService().resetForTesting();
    await db.close();
  });

  final surfaces = <String, Widget Function()>{
    'focus': () => const FocusScreen(),
    'focus_stats': () => const DetailedStatsScreen(),
    'focus_garden': () => const FocusGardenScreen(),
    'focus_tags': () => const CustomTagsScreen(),
    'focus_apps': () => const AppAllowListScreen(),
    'plant_trees': () => const PlantRealTreesScreen(),
    'relaxation': () => const RelaxationScreen(),
    'focus_reminders': () => const FocusRemindersSettingsScreen(),
  };

  /// The two widgets that hold Focus's remaining perpetual animations.
  ///
  /// Neither is reachable from the eight surfaces above in their resting state:
  /// `BreathingWidget` lives behind a pushed route (`focus_screen.dart:64`) and
  /// `PlantAnimationWidget` only mounts once a session is running
  /// (`focus_screen.dart:299`). The first run of this harness therefore reported
  /// exactly one motion failure — `relaxation` — and fixing only that would have
  /// turned the gate green with two of the three animating widgets untouched.
  ///
  /// Testing them directly closes that hole and is also the honest unit: the
  /// defect lives in the widget, not in whichever screen happens to host it.
  final motionWidgets = <String, Widget Function()>{
    'breathing_widget': () => const Scaffold(
        body: BreathingWidget(
            pattern: BreathingPattern.balancing, targetCycles: 4)),
    'plant_widget': () => const Scaffold(
        body: Center(
            child: PlantAnimationWidget(
                plantType: PlantType.sprout, progress: 0.5))),
    // The confetti Phase 5 switched on.
    //
    // This was the hole that mattered. Phase 5 wired
    // `FocusToast.sessionComplete(..., showParticles: true)` and the plan promised
    // "particles honour reduce-motion" — but the toast package held THREE ungated
    // `repeat()` controllers (shimmer and pulse in `toast_animations.dart`,
    // confetti here) and `disableAnimations` appeared nowhere in it. Switching the
    // celebration on introduced a reduce-motion violation, and this gate could not
    // see it because it only ever looked at Focus screens and Focus widgets.
    //
    // `ParticleSystem` directly, NOT a whole `PremiumToast`. A toast auto-dismisses
    // after `ToastTheme.defaultAutoDismiss` = 4 seconds, which is inside this
    // harness's 6-second window — so a toast surface passes the reduce-motion half
    // because the widget went AWAY, and fails the opposite half for the same
    // reason. Both directions would have been measuring its lifetime instead of its
    // motion. The shimmer and the pulse are covered by a source guard in
    // `focus_guards_test.dart`, which no widget lifecycle can fool.
    'particle_system': () => const Scaffold(
          body: Center(
            child: ParticleSystem(
              effectType: ParticleEffectType.rings,
              primaryColor: Color(0xFF7C4DFF),
              secondaryColor: Color(0xFFB388FF),
            ),
          ),
        ),
  };

  /// screen -> offending descriptions
  final unnamed = <String, List<String>>{};
  final stillMoving = <String, String>{};

  /// Informational graphics with no text alternative (WCAG 2.2 SC 1.1.1).
  /// Reported under the same `no-semantics` dimension: an unnamed button and an
  /// undescribed progress ring are one defect — something conveys meaning and a
  /// screen reader receives none of it.
  final undescribed = <String, String>{};

  /// Surfaces that threw while building, so nothing about them was inspected.
  /// Gated but not scored — see the note at the recording site.
  final couldNotBuild = <String, String>{};

  /// Surfaces whose motion disappeared entirely. Deliberately NOT a scored
  /// dimension: the manifest prices defects in the product, and this guards the
  /// instrument. It fails the build without moving the rating, the same way the
  /// self-verification tests in `focus_guards_test.dart` do.
  final motionRemoved = <String, String>{};
  var tapTargetsSeen = 0;

  /// Pump [build] inside the app shell, optionally with reduce-motion on.
  ///
  /// Returns null when the surface rendered, or a one-line description of why it
  /// did not. Every caller MUST record that description into [couldNotBuild],
  /// which `tearDownAll` gates on — a surface that never rendered has no unnamed
  /// controls and schedules no animation, so returning early without recording
  /// makes "nothing was wrong" and "nothing was inspected" the same green.
  ///
  /// Both failure routes are covered. A throw that escapes `pumpWidget` lands in
  /// the `catch`; a throw inside `build()` does NOT — the framework catches it,
  /// reports it to `FlutterError.onError` and paints an `ErrorWidget`, so the
  /// handler below keeps anything that is not an overflow instead of dropping it.
  ///
  /// The `MediaQuery` override goes in `MaterialApp.builder`, not above
  /// `MaterialApp`: `WidgetsApp` inserts its own `MediaQuery.fromView` and would
  /// discard an ancestor one, which would silently make the reduce-motion half of
  /// this harness test nothing at all.
  Future<String?> pumpSurface(
    WidgetTester tester,
    Widget Function() build, {
    bool reduceMotion = false,
    double textScale = 1.0,
  }) async {
    final failures = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      // Overflow is the responsive sweep's job; anything else is this surface
      // failing to render, and that must not be silent.
      if (_isOverflow(d.exception)) return;
      failures.add(d.exception.toString().split('\n').first);
    };
    try {
      await withClock(Clock.fixed(DateTime(2026, 3, 14, 13, 0)), () async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          // Both overrides go in `MaterialApp.builder`, not above `MaterialApp`:
          // `WidgetsApp` inserts its own `MediaQuery.fromView` and discards an
          // ancestor one, which would silently make these settings test nothing.
          builder: (reduceMotion || textScale != 1.0)
              ? (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: reduceMotion ? true : null,
                      textScaler: textScale == 1.0
                          ? null
                          : TextScaler.linear(textScale),
                    ),
                    child: child!,
                  )
              : null,
          home: AccentScope(feature: FeatureAccent.focus, child: build()),
        ));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 350));
      });
    } catch (e) {
      failures.add(e.toString().split('\n').first);
    } finally {
      FlutterError.onError = prev;
    }
    // Anything the binding recorded on its own, drained so it is reported here
    // rather than as a bare teardown failure with no surface name on it.
    Object? ex;
    while ((ex = tester.takeException()) != null) {
      if (!_isOverflow(ex!)) failures.add(ex.toString().split('\n').first);
    }
    return failures.isEmpty ? null : failures.first;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 7));
  }

  /// The root of the real semantics tree.
  ///
  /// Deliberately NOT `tester.getSemantics(...)`. That routes through
  /// `SemanticsController.find`, which walks the ELEMENT tree using the
  /// debug-only `debugVisitOnstageChildren`, and `_ViewportElement`'s
  /// implementation of it does an unguarded `center!`. Restructuring the Focus
  /// screen's `ListView` was enough to make that throw
  /// "Null check operator used on a null value" from inside the framework —
  /// a harness crash that had nothing to say about accessibility.
  ///
  /// `semanticsOwner` reads the semantics tree directly, with no element
  /// traversal, so it cannot be destabilised by whatever the widget tree happens
  /// to look like. The accessor is deprecated in favour of interacting with
  /// `SemanticsBinding`, but there is no non-deprecated way to reach the root
  /// node, and correctness beats a lint here.
  SemanticsNode semanticsRoot(WidgetTester tester) {
    // ignore: deprecated_member_use
    final owner = tester.binding.pipelineOwner.semanticsOwner;
    final root = owner?.rootSemanticsNode;
    expect(root, isNotNull,
        reason: 'no semantics tree was generated — ensureSemantics() must be '
            'held open, or this assertion is checking nothing');
    return root!;
  }

  /// Registers the reduce-motion gate for one surface, screen or widget.
  ///
  /// Set [animatesByDefault] for surfaces whose motion is the point of the
  /// feature — the breathing guide, the swaying plant, the relaxation pulse.
  /// Those get a SECOND, opposite assertion: with the preference off they must
  /// still move.
  ///
  /// Without that second half the gate is gameable in the worst possible
  /// direction. "Nothing is scheduled with disableAnimations: true" is satisfied
  /// perfectly by deleting the animation, which would turn this green while
  /// making the app worse. Pinning both directions means the only way through is
  /// the actual fix: keep the motion, and let the user turn it off.
  void motionTest(String name, Widget Function() build,
      {bool animatesByDefault = false}) {
    testWidgets('$name: motion stops when the user asks for stillness',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failure = await pumpSurface(tester, build, reduceMotion: true);
      if (failure != null) {
        // A surface that never rendered scheduled nothing, so the count below
        // would read 0 and this gate would call it respectful of reduce-motion.
        // Recorded and gated in tearDownAll instead of returning silently.
        couldNotBuild['$name (reduce-motion)'] = failure;
        return;
      }

      // Give every FINITE animation room to finish. Anything still scheduled
      // after this is repeating, i.e. it ignored the preference.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      final pending = tester.binding.transientCallbackCount;
      if (pending > 0) {
        stillMoving[name] = '$pending transient callback(s) still scheduled '
            'after 6s of idle pumping with disableAnimations: true';
      }

      await unmount(tester);
    });

    if (!animatesByDefault) return;

    testWidgets('$name: still animates when motion is allowed', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failure = await pumpSurface(tester, build);
      if (failure != null) {
        // Same hazard mirrored: an unbuilt surface animates nothing, which this
        // half reads as "the motion was deleted". Record the real reason.
        couldNotBuild['$name (motion allowed)'] = failure;
        return;
      }
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      if (tester.binding.transientCallbackCount == 0) {
        motionRemoved[name] = 'nothing is animating even with '
            'disableAnimations: false — the motion looks to have been deleted '
            'rather than made optional';
      }

      await unmount(tester);
    });
  }

  /// Registers the accessible-name sweep for one surface at one text scale.
  ///
  /// Run at 1.0 AND 2.0. 1.0 alone was a real gap: at accessibility text sizes a
  /// label can be clipped away, a control can be pushed off-screen (and so out of
  /// the semantics tree), or a row can reflow into a different widget. A screen
  /// reader user and a large-text user are frequently the SAME person, so checking
  /// names only at the default size checks the case least likely to need it.
  ///
  /// [expectTargets] must be false for surfaces that legitimately have no
  /// controls — `plant_widget` and `particle_system` are pure decoration. Their
  /// value here is the reduce-motion half; asserting they expose a tap target
  /// would be asserting something untrue about them, and the alternative
  /// (dropping the "measured nothing" guard for everyone) would let a screen that
  /// silently renders no controls pass as clean.
  void namingTest(String name, Widget Function() build, double scale,
      {bool expectTargets = true}) {
    testWidgets('$name: every tap target has an accessible name @${scale}x',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final handle = tester.ensureSemantics();
      final failure = await pumpSurface(tester, build, textScale: scale);
      if (failure != null) {
        handle.dispose();
        // A surface that cannot build leaves BOTH a11y dimensions unmeasured
        // for it, and unmeasured must never read as clean. Recorded and gated
        // rather than scored: `unrenderable` in `responsive_overflow` owns the
        // severity for a screen that will not build, and pricing it twice would
        // make one defect cost two findings.
        couldNotBuild['$name@${scale}x'] =
            'threw while building, so its tap targets and its motion were '
            'never inspected: $failure';
        return;
      }

      var seen = 0;

    /// [parentTransform] carries the accumulated transform down the tree.
    ///
    /// `SemanticsNode.rect` is in the node's OWN coordinate space, so reporting
    /// it raw prints every offender at (0,0) — which is how the first run of
    /// this harness described fourteen defects, uselessly. A child's rect in its
    /// parent's space is `transformRect(child.transform, child.rect)`, so the
    /// global rect is that composed all the way to the root.
    void walk(SemanticsNode node, Matrix4 parentTransform) {
      final t = parentTransform.clone();
      if (node.transform != null) t.multiply(node.transform!);

      final d = node.getSemanticsData();
      // Skip, for the same reasons Flutter's own labeledTapTargetGuideline
      // does: a route scope is a container rather than a control, and a node
      // scrolled out of view is not currently operable — flagging it would make
      // the count depend on scroll offset instead of on the code.
      final skip = d.flagsCollection.isHidden || d.flagsCollection.scopesRoute;
      final tappable = d.hasAction(SemanticsAction.tap) ||
          d.hasAction(SemanticsAction.longPress);
      if (tappable && !skip) {
        seen++;
        // A tooltip becomes the announced name in Flutter, and a text field is
        // named by its hint, so all four count as an accessible name.
        final named = d.label.trim().isNotEmpty ||
            d.value.trim().isNotEmpty ||
            d.tooltip.trim().isNotEmpty ||
            d.hint.trim().isNotEmpty;
        if (!named) {
          final r = MatrixUtils.transformRect(t, node.rect);
          unnamed.putIfAbsent(name, () => []).add(
              '@${scale}x ${r.width.toStringAsFixed(0)}x'
              '${r.height.toStringAsFixed(0)}'
              ' at (${r.left.toStringAsFixed(0)},${r.top.toStringAsFixed(0)})');
        }
      }

      // A node that merges its descendants already carries their labels in its
      // own data; recursing past it would count parts of one control as
      // several unnamed controls.
      if (node.mergeAllDescendantsIntoThisNode) return;
      node.visitChildren((child) {
        walk(child, t);
        return true;
      });
    }

    walk(semanticsRoot(tester), Matrix4.identity());
    tapTargetsSeen += seen;

      // A probe that observed nothing must not read as a pass — that is the
      // failure mode this whole rating system was built to remove.
      if (expectTargets) {
        expect(seen, greaterThan(0),
            reason: '$name: the semantics tree exposed no tap targets at all, so '
                'this assertion checked nothing. Either the walk is wrong or '
                'semantics are not being generated.');
      }

      handle.dispose();
      await unmount(tester);
    });
  }

  for (final entry in surfaces.entries) {
    for (final scale in const [1.0, 2.0]) {
      namingTest(entry.key, entry.value, scale);
    }
    // `relaxation` runs a pulse and a wave controller, both unconditional.
    motionTest(entry.key, entry.value,
        animatesByDefault: entry.key == 'relaxation');
  }

  // The widget surfaces get BOTH sweeps.
  //
  // Naming was screens-only, and that was a real coverage hole: `BreathingWidget`
  // lives behind a pushed route, so its icon-only close button — announced as
  // just "button" — was invisible to a gate that reported "0 unnamed targets
  // across all 8 Focus screens". The claim was true and the coverage was not.
  for (final entry in motionWidgets.entries) {
    // Only `breathing_widget` has controls; the plant and the confetti are pure
    // decoration and expose no tap target by design.
    namingTest(entry.key, entry.value, 1.0,
        expectTargets: entry.key == 'breathing_widget');
    motionTest(entry.key, entry.value, animatesByDefault: true);
  }

  testWidgets('focus: the timer readout is described in words', (tester) async {
    // WCAG 2.2 SC 1.1.1 Non-text Content. The 210px ring is a CustomPaint, so
    // its progress reaches a screen reader not at all; the clock under it is a
    // Text, which is announced digit by digit as "two five colon zero zero".
    // Together they are the whole screen, so a text alternative is not a nicety.
    //
    // Gated rather than merely written: an `excludeSemantics` wrapper is one
    // deletion away from silently disappearing, and nothing else here would
    // notice.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = tester.ensureSemantics();
    final failure = await pumpSurface(tester, () => const FocusScreen());
    if (failure != null) {
      handle.dispose();
      // Not a silent return: with no tree there are no labels, so `described`
      // below would be false and `rawClock` false too — the screen would be
      // recorded as neither undescribed nor offending, which is the shape of a
      // pass. Gated in tearDownAll with the reason attached.
      couldNotBuild['focus (timer readout)'] = failure;
      return;
    }

    final labels = <String>[];
    void collect(SemanticsNode node) {
      final l = node.getSemanticsData().label.trim();
      if (l.isNotEmpty) labels.add(l);
      if (node.mergeAllDescendantsIntoThisNode) return;
      node.visitChildren((c) {
        collect(c);
        return true;
      });
    }

    collect(semanticsRoot(tester));

    final described = labels.any((l) =>
        l.contains('minute') &&
        (l.contains('selected') || l.contains('remaining')));
    if (!described) {
      undescribed['focus'] = 'the timer exposes no spoken duration. Labels '
          'found: ${labels.take(6).join(' | ')}';
    }

    // The digits must ALSO be gone from the spoken output, or the sentence is
    // just extra noise on top of "two five colon zero zero".
    final rawClock = labels.any((l) => RegExp(r'^\d+:\d\d$').hasMatch(l));
    if (rawClock) {
      undescribed['focus_clock'] =
          'the bare "MM:SS" string is still in the semantics tree, so a screen '
          'reader reads the digits as well as the sentence';
    }

    handle.dispose();
    await unmount(tester);
  });

  tearDownAll(() {
    // ignore: avoid_print
    void p(String s) => print(s);

    p('\n===== FOCUS ACCESSIBILITY =====');
    p('tap targets inspected: $tapTargetsSeen');
    p('\n-- unnamed tap targets (WCAG 2.2 SC 4.1.2, Level A) --');
    if (unnamed.isEmpty) {
      p('  none');
    } else {
      unnamed.forEach((k, v) {
        final counts = <String, int>{};
        for (final x in v) {
          counts[x] = (counts[x] ?? 0) + 1;
        }
        p('  $k (${v.length}): '
            '${counts.entries.take(4).map((e) => "${e.key} x${e.value}").join(", ")}');
      });
    }
    p('\n-- surfaces that could not be built (nothing inspected) --');
    p(couldNotBuild.isEmpty ? '  none' : '  ${couldNotBuild.keys.join(', ')}');
    p('\n-- undescribed informational graphics (WCAG 2.2 SC 1.1.1) --');
    if (undescribed.isEmpty) {
      p('  none');
    } else {
      undescribed.forEach((k, v) => p('  $k: $v'));
    }
    p('\n-- still animating with reduce-motion on (WCAG 2.2 SC 2.3.3) --');
    if (stillMoving.isEmpty) {
      p('  none');
    } else {
      stillMoving.forEach((k, v) => p('  $k: $v'));
    }
    p('===============================\n');

    // Emit BEFORE asserting. `expect` throws, and a harness that dies before it
    // reports leaves the rating untouched — which reads as "clean".
    // Beacon first: these dimensions were measured, findings or not.
    // Without this a clean run and a run that never happened are the same
    // silence, and tool/rate.dart scores both as perfect.
    reportMeasured(const ['no-semantics', 'motion-not-reduced'],
        samples: tapTargetsSeen);

    for (final e in unnamed.entries) {
      emitFinding(Finding(
        feature: 'Focus',
        screen: e.key,
        dimension: 'no-semantics',
        sev: Sev.p1,
        detail: '${e.value.length} tap target(s) with no accessible name: '
            '${e.value.take(3).join('; ')}',
        source: 'WCAG 2.2 SC 4.1.2 Name, Role, Value (Level A); same property '
            "as Flutter's labeledTapTargetGuideline",
      ));
    }
    for (final e in undescribed.entries) {
      emitFinding(Finding(
        feature: 'Focus',
        screen: e.key,
        dimension: 'no-semantics',
        sev: Sev.p1,
        detail: e.value,
        source: 'WCAG 2.2 SC 1.1.1 Non-text Content (Level A) — a CustomPaint '
            'carrying information needs a text alternative',
      ));
    }
    for (final e in stillMoving.entries) {
      emitFinding(Finding(
        feature: 'Focus',
        screen: e.key,
        dimension: 'motion-not-reduced',
        sev: Sev.p1,
        detail: e.value,
        source: 'WCAG 2.2 SC 2.3.3 Animation from Interactions; measured via '
            'SchedulerBinding.transientCallbackCount, the signal pumpAndSettle '
            'itself loops on',
      ));
    }

    expect(couldNotBuild, isEmpty,
        reason: 'these surfaces were never inspected, so a clean a11y result '
            'above does not cover them:\n'
            '${couldNotBuild.entries.map((e) => '${e.key}: ${e.value}').join('\n')}');
    expect(motionRemoved, isEmpty,
        reason: 'the reduce-motion gate must be cleared by making motion '
            'OPTIONAL, not by removing it:\n'
            '${motionRemoved.entries.map((e) => '${e.key}: ${e.value}').join('\n')}');
    expect(undescribed, isEmpty,
        reason: 'information conveyed only by paint:\n'
            '${undescribed.entries.map((e) => '${e.key}: ${e.value}').join('\n')}');
    expect(unnamed, isEmpty,
        reason: 'tap targets a screen reader announces as just "button":\n'
            '${unnamed.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('\n')}');
    expect(stillMoving, isEmpty,
        reason: 'surfaces that keep animating after the user asked for '
            'stillness:\n${stillMoving.entries.map((e) => '${e.key}: ${e.value}').join('\n')}');
  });
}
