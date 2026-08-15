import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// The shell and its information architecture, on a real device.
///
/// Supersedes `redesign_e2e_test.dart`, whose three tests had rotted in three
/// different ways: one asserted the deleted `'AI Assistant'` screen, one used
/// `find.byIcon(Icons.arrow_back_rounded)` when the app draws
/// `Symbols.arrow_back_rounded` (a permanent zero-match — different
/// `fontFamily`, so `IconData ==` is false), and only the first still described
/// the shipped app.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all four destinations render their own content', (t) async {
    await E2E.launch(t);

    // The nav bar itself, by type — not by a label we are about to tap.
    expect(find.byType(AppNavBar), findsOneWidget);
    for (final label in const [
      kNavToday,
      kNavMeds,
      kNavLog,
      kNavHealth,
      kNavTrends,
    ]) {
      expect(
        find.descendant(of: find.byType(AppNavBar), matching: find.text(label)),
        findsOneWidget,
        reason: 'nav slot "$label"',
      );
    }

    // goTab asserts arrival by the tab's OWN content, so a nav bar that
    // highlights correctly while rendering an empty body still fails.
    for (final tab in NavTab.values) {
      await E2E.goTab(t, tab);
    }

    E2E.assertClean('visit all four destinations');
  });

  testWidgets('Meds is not built until it is first selected', (t) async {
    await E2E.launch(t);
    E2E.at(find.byType(HomeDashboard), where: kNavToday);

    // The lazy first-mount optimisation, asserted rather than assumed.
    // `IndexedStack` builds and keeps alive EVERY child, so landing on Today
    // used to run the Meds dashboard's full load — which also WRITES: it
    // drains queued dose actions and reconciles missed doses.
    expect(
      find.byType(NunitoMedicationDashboard),
      findsNothing,
      reason: 'Landing on Today must not build the Meds dashboard. It is not '
          'merely expensive, it writes to the database.',
    );

    await E2E.goTab(t, NavTab.meds);
    expect(find.byType(NunitoMedicationDashboard), findsOneWidget);

    E2E.assertClean('lazy first-mount');
  });

  testWidgets('the centre Log slot opens the sheet without changing tab',
      (t) async {
    await E2E.launch(t);
    E2E.at(find.byType(HomeDashboard), where: kNavToday);

    await t.tap(find.descendant(
      of: find.byType(AppNavBar),
      matching: find.text(kNavLog),
    ));
    await settle(t);

    // Scoped to the sheet: Today renders the same phrase as a section label,
    // so an unscoped find.text would pass with the sheet closed.
    expect(
      find.descendant(
        of: find.byType(AppBottomSheet),
        matching: find.text(kLogSheetTitle),
      ),
      findsOneWidget,
      reason: 'centre Log action must open the unified capture sheet',
    );

    for (final entry in const [
      kLogMedicineDose,
      kLogWater,
      kLogBloodPressure,
      kLogBloodSugar,
      kLogWeight,
      kLogMood,
      kLogSteps,
      kLogSleep,
      kLogPeriod,
    ]) {
      expect(find.text(entry), findsWidgets, reason: 'log option "$entry"');
    }

    // Slot 2 is an action, never a selection: Today must still be underneath.
    expect(
      find.byType(HomeDashboard),
      findsOneWidget,
      reason: 'opening the Log sheet must not change the selected tab',
    );

    Navigator.of(t.element(find.byType(AppBottomSheet))).pop();
    await settle(t);
    expect(find.byType(AppBottomSheet), findsNothing);

    E2E.assertClean('centre Log action');
  });

  testWidgets('Health lists its trackers and each one opens and returns',
      (t) async {
    await E2E.launch(t);
    await E2E.goTab(t, NavTab.health);

    expect(find.text(kHealthTrackers), findsOneWidget);
    expect(find.text(kHealthWeeklyRecap), findsOneWidget);
    expect(find.text(kHealthConditionLibrary), findsOneWidget);

    for (final tracker in const [kLogWater, kLogSteps, kLogSleep]) {
      // tapWhenHittable, not tap: a bare tap during the previous screen's pop
      // transition is swallowed by the route's IgnorePointer and reported only
      // as a warning, so the test fails later and somewhere else.
      await E2E.tapWhenHittable(t, find.text(tracker), '$tracker tile');

      // Symbols.*, not Icons.*. The old suite used Icons.arrow_back_rounded,
      // which cannot match anything this app draws.
      final back = find.byIcon(Symbols.arrow_back_rounded);
      expect(back, findsWidgets,
          reason: '"$tracker" should push a screen with a back affordance');
      await E2E.tapWhenHittable(t, back, 'back from $tracker');

      expect(find.text(kHealthTrackers), findsOneWidget,
          reason: 'returned to the Health hub after "$tracker"');
    }

    E2E.assertClean('open and return from each Health tracker');
  });
}
