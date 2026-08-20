import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// Focus, on a device, against seeded data.
///
/// ## Why this suite is worth its runtime
///
/// Everything else guarding Focus is headless, and three classes of defect are
/// structurally invisible there:
///
///  * **Occlusion.** The headless sweeps measure `RenderBox` size and never ask
///    what is painted on top. This app docks an `AppNavBar` and translates a
///    centre FAB outside its parent with `Clip.none`. A 48pt target under either
///    measures perfectly and cannot be tapped.
///  * **Populated state.** `focus_first_run_test.dart` asserts the EMPTY case by
///    design. The seeder plants ~48 sessions, a matching garden, real coins and
///    unlocked plants, so this is the state an actual user is in — and the one
///    where a chart divides by a count or a list overflows.
///  * **Real navigation.** `FocusScreen` is a PUSHED route
///    (`app_shell.dart:190-194`), not one of the four live tabs. Push/pop
///    lifecycle is where a listener leaks, a dialog is skipped, or a completion is
///    announced to a screen that no longer exists — and that last one was a real
///    regression that every headless gate passed.
///
/// Every assertion goes through [E2E], whose helpers are built so that a check
/// cannot silently skip: `at` replaces `if (found) expect(found)`,
/// `tapWhenHittable` fails naming what is on top, and `assertClean` catches
/// framework errors that `main.dart` used to print and discard.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Today → the Focus compact card → the pushed Focus screen.
  ///
  /// The card title is scoped to [HomeDashboard] because 'Focus' also appears in
  /// the Health hub and as a pulse-row KPI. The KPI renders `label.toUpperCase()`
  /// so it reads FOCUS and does not collide, but the hub tile would — and the
  /// shell keeps every visited tab alive.
  Future<void> openFocus(WidgetTester t) async {
    await E2E.goTab(t, NavTab.today);
    final card = find.descendant(
      of: find.byType(HomeDashboard),
      matching: find.text(kFocusCardTitle),
    );
    await E2E.tapWhenHittable(t, card, 'the Focus card on Today');
    E2E.at(find.byType(FocusScreen), where: 'Focus');
  }

  /// The logical viewport, for above-the-fold assertions.
  Size viewport(WidgetTester t) => t.view.physicalSize / t.view.devicePixelRatio;

  testWidgets('the resting surface offers a usable primary action', (t) async {
    await E2E.launch(t);
    await openFocus(t);

    // ---- the primary action is present, hittable and above the fold ---------
    //
    // "Above the fold" is asserted on the DEVICE viewport, not a synthetic one.
    // The headless first-run gate uses a hardcoded 375x812; this uses whatever
    // the simulator actually is, which is the only number a user experiences.
    final start = find.text(kFocusStart);
    expect(start, findsOneWidget,
        reason: 'a brand-new or returning user must be offered one obvious way '
            'to begin. On screen: ${E2E.screenSummary()}');
    E2E.assertHittable(t, start, kFocusStart);

    final startRect = t.getRect(start);
    final screen = viewport(t);
    expect(startRect.bottom, lessThanOrEqualTo(screen.height),
        reason: 'Start sits ${startRect.top.toStringAsFixed(0)}pt down on a '
            '${screen.height.toStringAsFixed(0)}pt screen — below the fold, so '
            'the one thing this screen is for needs scrolling to find');

    // ---- the setup row states what will happen -----------------------------
    //
    // Collapsing six configuration sections into a sheet is only defensible if
    // the user can still SEE what they are about to start.
    expect(find.text(kFocusSetupRow), findsOneWidget,
        reason: 'the setup summary is what makes the sheet honest rather than '
            'hidden');
    E2E.assertHittable(t, find.text(kFocusSetupRow), kFocusSetupRow);

    E2E.assertClean('focus resting surface');
  });

  testWidgets('every card in the More grid is reachable and hittable',
      (t) async {
    await E2E.launch(t);
    await openFocus(t);

    // All six, by name. Naming them is what makes "the grid" mean the whole grid
    // — the headless version of this check once measured whichever Row happened
    // to enclose 'Statistics' and reported a clean result for the other four.
    const cards = [
      kFocusGridBreathing,
      kFocusGridRelaxation,
      kFocusGridStatistics,
      kFocusGridPlantTrees,
      kFocusGridTags,
      kFocusGridDistractions,
    ];

    await E2E.scrollUntilPresent(
        t, find.text(kFocusMoreHeader), 'the More header');

    for (final card in cards) {
      final f = find.text(card);
      await E2E.scrollUntilPresent(t, f, 'the "$card" card');
      expect(f, findsWidgets, reason: '"$card" is missing from the More grid');
      // Hittability, not just presence: the docked nav bar and the centre FAB
      // both sit over the bottom of this list.
      await t.ensureVisible(f.first);
      await settle(t, const Duration(milliseconds: 100), 6);
      E2E.assertHittable(t, f, '"$card" grid card');
    }

    E2E.assertClean('focus More grid');
  });

  testWidgets('the garden shows the seeded plants, not an empty state',
      (t) async {
    await E2E.launch(t);
    await openFocus(t);

    await E2E.scrollUntilPresent(
        t, find.text(kFocusGridPlantTrees), 'the More grid');
    // Garden is reached from the grid's Statistics screen header action, and
    // directly from the app bar; go through Statistics so both are exercised.
    await E2E.tapWhenHittable(
        t, find.text(kFocusGridStatistics), 'the Statistics card');
    E2E.at(find.text(kStatsTitle), where: 'Statistics');

    await E2E.tapWhenHittable(t, find.byIcon(Symbols.park_rounded),
        'the Garden action in the Statistics header');
    E2E.at(find.byType(FocusGardenScreen), where: 'My Garden');

    // The seeder writes `focusGarden` alongside `focusSessions`. Before it did,
    // a QA pass saw an empty garden next to a statistics screen reporting 48
    // sessions — an inconsistent state no real user can reach.
    // e2e-absent-ok: proves the EMPTY state is NOT showing on a seeded
    // database, so the string must be absent.
    expect(find.text(kGardenEmptyTitle), findsNothing,
        reason: 'the seeded database has ~40 plants, so the empty state must '
            'not be showing. Either the garden seed did not land or the screen '
            'reads somewhere else. On screen: ${E2E.screenSummary()}');

    E2E.assertClean('focus garden with seeded plants');
  });

  testWidgets('NEGATIVE: leaving mid-session is guarded, not silent', (t) async {
    await E2E.launch(t);
    await openFocus(t);

    await E2E.tapWhenHittable(t, find.text(kFocusStart), kFocusStart);

    // State, not the toast. A toast proves a snackbar was shown; the controls
    // changing proves the session actually started.
    expect(find.text(kFocusGiveUp), findsOneWidget,
        reason: 'after Start the controls must become Pause + Give Up. '
            'On screen: ${E2E.screenSummary()}');
    expect(FocusService().isRunning, isTrue,
        reason: 'the button changed but no session is running');

    // ---- the negative: try to walk away ------------------------------------
    //
    // `PopScope(canPop: !isRunning)` should intercept and warn rather than
    // discarding a running session silently. This is the only place that
    // behaviour is exercised at all — headlessly there is no back gesture.
    final popped = await t.binding.handlePopRoute();
    await settle(t);

    expect(popped, isTrue,
        reason: 'the route must CONSUME the back gesture while a session runs');
    expect(find.text(kFocusSessionLocked), findsOneWidget,
        reason: 'backing out of a running session must warn, not silently '
            'abandon it. On screen: ${E2E.screenSummary()}');
    expect(FocusService().isRunning, isTrue,
        reason: 'showing the warning must not itself end the session');

    // Dismiss and confirm we are still focused.
    await E2E.tapWhenHittable(
        t, find.text(kFocusStayFocused), kFocusStayFocused);
    E2E.at(find.byType(FocusScreen), where: 'Focus');
    expect(FocusService().isRunning, isTrue);

    // ---- clean up through the real path -------------------------------------
    await E2E.tapWhenHittable(t, find.text(kFocusGiveUp), kFocusGiveUp);
    expect(find.text(kFocusGiveUpTitle), findsOneWidget,
        reason: 'abandoning must confirm — it discards the session');
    await E2E.tapWhenHittable(
        t, find.text(kFocusGiveUp).last, 'confirm Give Up');
    await settle(t);

    expect(FocusService().isRunning, isFalse,
        reason: 'confirming Give Up must actually end the session');
    expect(find.text(kFocusStart), findsOneWidget,
        reason: 'and the surface must return to its resting state');

    E2E.assertClean('focus leave-mid-session guard');
  });

  testWidgets('NEGATIVE: the setup sheet opens, applies, and closes cleanly',
      (t) async {
    await E2E.launch(t);
    await openFocus(t);

    await E2E.tapWhenHittable(t, find.text(kFocusSetupRow), kFocusSetupRow);
    await settle(t);

    // The sheet hosts the six sections the restructure moved off the resting
    // surface. If it opened empty, the restructure removed them rather than
    // relocating them — which is the claim the plan made and this checks.
    expect(find.byType(AppBottomSheet), findsOneWidget,
        reason: 'the setup row must open a sheet. '
            'On screen: ${E2E.screenSummary()}');

    // Named explicitly and asserted UNCONDITIONALLY. A loop counting
    // `if (finder.isNotEmpty)` hits can only ever raise the count and never
    // fail — the idiom `e2e_suite_conventions_test.dart` exists to ban.
    for (final section in [
      kFocusSheetActivity,
      kFocusSheetPlant,
      kFocusSheetSound,
    ]) {
      expect(find.text(section), findsWidgets,
          reason: '"$section" was moved into the setup sheet by the '
              'restructure. If it is missing the section was REMOVED rather '
              'than relocated, which is the opposite of what was claimed. '
              'On screen: ${E2E.screenSummary()}');
    }

    // Close by dragging the sheet down, the way a user does.
    await t.drag(find.byType(AppBottomSheet), const Offset(0, 600));
    await settle(t);
    await E2E.waitUntilGone(t, find.byType(AppBottomSheet), 'the setup sheet');

    // And the surface underneath still works — a sheet that leaves the route
    // stack wrong is invisible until the next tap.
    E2E.at(find.byType(FocusScreen), where: 'Focus');
    E2E.assertHittable(t, find.text(kFocusStart), kFocusStart);

    E2E.assertClean('focus setup sheet');
  });
}
