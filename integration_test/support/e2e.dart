import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/home/screens/health_browse_screen.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/insights/screens/trends_dashboard_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/main.dart' as app;

import 'app_strings.dart';

/// The driving kernel for every device suite.
///
/// ## Why this replaces `e2e_helpers.dart`
///
/// The old helpers could not fail. Three independent silencers, all fixed here:
///
/// 1. **`app.main()` disabled error reporting.** `main.dart` used to overwrite
///    `FlutterError.onError` with a logger, and the test binding's reporter —
///    the thing that turns a framework error into a FAILING TEST — went with
///    it. Every overflow, every `setState() after dispose()`, every exception
///    inside a builder was printed and discarded for the rest of the test.
///    `main.dart` now hands the error back when `kE2ETest` is set, and
///    [launch] installs [errors] to collect them.
/// 2. **`if (finder.evaluate().isNotEmpty) expect(...)`.** An assertion that
///    only runs when the thing is already there cannot fail. [at] replaces it.
/// 3. **`reachHome()` gave up silently** after 24 rounds and returned normally,
///    so the real failure ("app never started") surfaced 40 lines later as
///    "'Today' not found", pointing at the nav bar. [launch] throws instead.
///
/// `test/e2e_hygiene/e2e_suite_conventions_test.dart` enforces 1-3 mechanically.

/// Pumps a fixed number of frames rather than waiting for quiescence.
///
/// NOT `pumpAndSettle`: this app runs continuous animations (the nav orb, the
/// loading skeletons, ad views) that never reach a settled state, so
/// `pumpAndSettle` times out rather than returning. `integration_test` sets
/// `defaultTestTimeout = Timeout.none`, so such a timeout costs TEN REAL
/// MINUTES per call and `--timeout` cannot shorten it.
Future<void> settle(
  WidgetTester t, [
  Duration d = const Duration(milliseconds: 250),
  int frames = 12,
]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(d);
  }
}

/// The four nav destinations. Slot 2 (`Log`) is an action, not a destination —
/// see `app_shell.dart:132-136` — so it is deliberately absent.
enum NavTab { today, meds, health, trends }

extension NavTabInfo on NavTab {
  String get label => switch (this) {
        NavTab.today => kNavToday,
        NavTab.meds => kNavMeds,
        NavTab.health => kNavHealth,
        NavTab.trends => kNavTrends,
      };

  /// A marker unique to the tab's CONTENT, so arriving is proven by the body
  /// rather than by the nav label we just tapped.
  Finder get marker => switch (this) {
        NavTab.today => find.byType(HomeDashboard),
        NavTab.meds => find.byType(NunitoMedicationDashboard),
        NavTab.health => find.byType(HealthBrowseScreen),
        NavTab.trends => find.byType(TrendsDashboardScreen),
      };
}

class E2E {
  const E2E._();

  /// Framework errors captured since the last [launch].
  ///
  /// Populated by the handler installed in [launch]. `main.dart`'s root-zone
  /// handler also routes escaping async errors here via `FlutterError.reportError`
  /// when `kE2ETest` is set, so this covers both halves.
  static final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];

  /// Errors that are noise rather than defects. Deliberately EMPTY — add an
  /// entry only with a comment explaining why it is not a bug.
  static const List<String> _ignoredErrorSubstrings = <String>[];

  /// Starts the app and waits for the shell. The ONLY permitted `app.main()`
  /// call site — `e2e_suite_conventions_test.dart` enforces that.
  ///
  /// Throws with a diagnostic if the shell never appears, instead of letting
  /// every later finder fail against whatever screen the app got stuck on.
  static Future<void> launch(WidgetTester t) async {
    errors.clear();

    app.main();

    // `main()` runs synchronously to its first `await` (Firebase.initializeApp),
    // so control is back here before any async init runs. Installing the
    // collector now covers the whole of startup.
    //
    // The binding ASSERTS at teardown that a test which replaced
    // `FlutterError.onError` put it back ("A test overrode FlutterError.onError
    // but either failed to return it to its original state..."). Without the
    // restore below that assertion fires on every test and buries the real
    // failure underneath it — which is exactly what it did on the first run.
    final previous = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previous);
    FlutterError.onError = (FlutterErrorDetails details) {
      errors.add(details);
      // FORWARD, don't just record. The binding tracks its own
      // `_pendingExceptionDetails` when it handles an error, and asserts on it
      // from `handleUncaughtError`. A collector that merely called
      // `presentError` left that null, so the first escaping async error blew
      // up as "A test overrode FlutterError.onError but ... had unexpected
      // additional errors it could not handle" — burying the real failure.
      //
      // Forwarding also means the binding fails the test on the error itself.
      // `errors` and [assertClean] then exist to give the failure a journey
      // name and to catch anything that arrives after the last assertion.
      previous?.call(details);
    };

    await _pumpUntilShell(t);
  }

  /// True when a tap at the widget's centre would actually reach it.
  static bool _receivesTap(WidgetTester t, Finder one) {
    final target = t.renderObject(one);
    final result = HitTestResult();
    t.binding.hitTestInView(result, t.getCenter(one), t.view.viewId);
    return result.path.map((e) => e.target).contains(target);
  }

  /// Taps a widget once it genuinely receives hit tests.
  ///
  /// "derived an Offset that would not hit test on the specified widget" has
  /// two very different causes, and the raw warning does not distinguish them:
  ///
  ///  * a route transition still in flight — the incoming route is wrapped in
  ///    `IgnorePointer`/`AbsorbPointer`, so the tap is swallowed. Transient;
  ///    polling fixes it honestly, where a bigger fixed pump only moves the
  ///    flake around.
  ///  * something is genuinely painted on top — a real, user-visible defect.
  ///
  /// This polls for the first and FAILS on the second, naming what is on top.
  static Future<void> tapWhenHittable(
    WidgetTester t,
    Finder f,
    String what, {
    int maxPumps = 30,
  }) async {
    expect(f, findsWidgets, reason: '"$what" is not on screen at all');
    final one = f.first;

    // Scroll it into the viewport first, the way a user would.
    //
    // A `Viewport` keeps children alive slightly beyond what it paints (its
    // cache extent), so `find.text(...)` happily returns a widget that is
    // BELOW THE FOLD and therefore unhittable. On a 411x731 phone the Health
    // hub shows about two tracker tiles, so this is the common case, not an
    // edge case — and without this the failure reads as "occluded", which
    // sends you looking for an overlay that does not exist.
    try {
      await t.ensureVisible(one);
      await settle(t, const Duration(milliseconds: 100), 6);
    } catch (_) {
      // No Scrollable ancestor — nothing to scroll, carry on to the poll.
    }

    for (var i = 0; i < maxPumps; i++) {
      if (_receivesTap(t, one)) {
        await t.tap(one);
        await settle(t);
        return;
      }
      await t.pump(const Duration(milliseconds: 100));
    }

    // 3s is far longer than any transition in this app, so this is occlusion.
    final centre = t.getCenter(one);
    final result = HitTestResult();
    t.binding.hitTestInView(result, centre, t.view.viewId);
    final onTop = result.path
        .map((e) => e.target)
        .whereType<RenderObject>()
        .take(6)
        .map((r) => r.runtimeType.toString())
        .join(' < ');

    // Geometry, so the report distinguishes the three real causes without a
    // second run: off the bottom of the viewport, under the docked nav bar, or
    // covered by an overlay.
    final logical = t.view.physicalSize / t.view.devicePixelRatio;
    final rect = t.getRect(one);
    final navBar = find.byType(AppNavBar);
    final navTop = navBar.evaluate().isEmpty // e2e-conditional-ok: geometry for a diagnostic string, not an assertion
        ? null
        : t.getRect(navBar.first).top;

    fail('"$what" is visible at $centre but never becomes tappable.\n'
        'This is not a transition — it stayed unhittable for '
        '${maxPumps * 100}ms.\n'
        '  target rect : $rect\n'
        '  screen      : ${logical.width.toStringAsFixed(1)} x '
        '${logical.height.toStringAsFixed(1)} logical '
        '(dpr ${t.view.devicePixelRatio})\n'
        '  nav bar top : ${navTop?.toStringAsFixed(1) ?? 'no AppNavBar'}\n'
        '  receiving   : $onTop\n'
        'If the target sits below "nav bar top" it is behind the docked nav; '
        'if it sits below "screen" height it is off the bottom of the '
        'viewport and needs scrolling into view.');
  }

  static Future<void> _pumpUntilShell(WidgetTester t) async {
    const rounds = 40;
    const perRound = Duration(milliseconds: 250);
    for (var i = 0; i < rounds; i++) {
      if (find.byType(AppNavBar).evaluate().isNotEmpty) {
        await settle(t);
        return;
      }
      await t.pump(perRound);
    }
    throw StateError(
      'App never reached the shell in ${(rounds * perRound.inMilliseconds) / 1000}s.\n'
      'Visible text was: ${_visibleText().take(12).toList()}\n'
      'Did you pass --dart-define=E2E_TEST=true? Without it main.dart routes '
      'first-run users to /welcome instead of /home.\n'
      'Errors so far: ${errors.map((e) => e.exceptionAsString()).toList()}',
    );
  }

  static Iterable<String> _visibleText() => find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>();

  /// Asserts we are where we think we are.
  ///
  /// Replaces the `if (found) { expect(found) }` idiom, which is a tautology:
  /// it can only run when it would pass. Every navigation helper ends in one of
  /// these so a failed navigation is reported AT the navigation, not as a
  /// puzzling finder failure further down.
  static void at(Finder marker, {required String where}) {
    expect(
      marker,
      findsWidgets,
      reason: 'Expected to be on "$where", but its marker was not on screen. '
          'Navigation failed; every assertion after this point would have been '
          'evaluated against the wrong screen.',
    );
  }

  /// Switches nav tabs, scoped to the nav bar.
  ///
  /// `find.text('Meds')` is ambiguous — it matches the nav label
  /// (`app_shell.dart:214`) AND Today's pulse-row KPI
  /// (`home_dashboard.dart`). `.last` is a coin flip on tree order, so the
  /// finder is scoped to [AppNavBar] instead.
  static Future<void> goTab(WidgetTester t, NavTab tab) async {
    final slot = find.descendant(
      of: find.byType(AppNavBar),
      matching: find.text(tab.label),
    );
    expect(slot, findsOneWidget,
        reason: 'nav slot "${tab.label}" is missing from AppNavBar');
    await t.tap(slot);
    await settle(t);
    at(tab.marker, where: tab.label);
  }

  /// Every test ends here.
  ///
  /// Two checks, because they catch different things: [errors] catches whatever
  /// reached `FlutterError.onError`, and the `ErrorWidget` check catches a
  /// subtree that failed to build and rendered the red box — which is visible
  /// even when something upstream swallowed the exception.
  static void assertClean(String journey) {
    final real = errors
        .where((e) => !_ignoredErrorSubstrings
            .any((s) => e.exceptionAsString().contains(s)))
        .toList();

    expect(
      real.map((e) => e.exceptionAsString()),
      isEmpty,
      reason: '$journey — the app threw ${real.length} framework error(s) '
          'during this journey. Before this harness existed these were '
          'printed and discarded, so the suite reported green.',
    );
    expect(
      find.byType(ErrorWidget),
      findsNothing,
      reason: '$journey — a subtree failed to build and rendered ErrorWidget.',
    );
  }

  /// Asserts a widget is not merely present but actually TAPPABLE.
  ///
  /// The headless responsive sweep measures `RenderBox` size and never asks
  /// what is painted on top. This app has four overlays that only exist once
  /// screens are composed: the docked `AppNavBar`, the centre FAB translated
  /// outside its parent with `Clip.none`, floating snackbars, and per-screen
  /// FABs. A 48pt target under any of them measures fine and cannot be hit.
  static void assertHittable(WidgetTester t, Finder f, String what) {
    expect(f, findsWidgets, reason: '"$what" is not on screen at all');
    final centre = t.getCenter(f.first);
    final result = HitTestResult();
    t.binding.hitTestInView(result, centre, t.view.viewId);
    final target = t.renderObject(f.first);
    expect(
      result.path.map((e) => e.target),
      contains(target),
      reason: '"$what" is on screen at $centre but something else receives the '
          'tap — the nav bar, the centre FAB, or a floating snackbar is over '
          'it. Present is not the same as tappable.',
    );
  }
}
