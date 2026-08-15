import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/widgets/aqua_quick_add_grid.dart';
import 'package:tablet_remainder/features/water/widgets/aqua_timeline_list.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// Water: quick-add and Undo, asserted on STATE rather than on a toast.
///
/// The distinction is the whole point. A toast saying "+500ml Water" proves a
/// snackbar was shown; it proves nothing about whether the drink was recorded,
/// and an Undo that only dismisses the snackbar is worse than no Undo at all —
/// the user believes their data came back. So every assertion here reads
/// `AquaTimelineList.logs`, which is the list the screen actually renders.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The number of drinks the screen is currently showing for today.
  int loggedDrinks(WidgetTester t) =>
      t.widget<AquaTimelineList>(find.byType(AquaTimelineList)).logs.length;

  testWidgets('quick-add records a drink, and Undo really removes it',
      (t) async {
    await E2E.launch(t);
    await E2E.goTab(t, NavTab.health);
    await E2E.tapWhenHittable(t, find.text(kLogWater), 'Water tile');
    E2E.at(find.byType(AquaWaterDashboard), where: 'Water');

    // The seeder plants a month of drinks, so this is a populated list, not an
    // empty one — the state the headless sweeps never render.
    await t.scrollUntilVisible(find.byType(AquaTimelineList).first, 300,
        scrollable: find.byType(Scrollable).first);
    await settle(t);
    final before = loggedDrinks(t);
    expect(before, greaterThan(0),
        reason: "Today's Log is empty on a seeded database — either the seed "
            'did not land or the screen is reading somewhere else');

    // ---- add ---------------------------------------------------------------
    // The tile renders '+500' and 'ml' as separate Texts — its `label`
    // ('Large') exists in the source but is never displayed.
    await E2E.tapWhenHittable(
        t,
        find.descendant(
          of: find.byType(AquaQuickAddGrid),
          matching: find.textContaining('+500'),
        ),
        'the 500 ml quick-add tile');

    expect(
      find.textContaining('500ml'),
      findsWidgets,
      reason: 'quick-add must confirm what it recorded',
    );
    expect(
      loggedDrinks(t),
      before + 1,
      reason: 'The toast appeared but the drink was not added to the log. A '
          'confirmation that confirms nothing is the defect this test exists '
          'for.',
    );

    // ---- undo --------------------------------------------------------------
    await E2E.tapWhenHittable(t, find.text(kUndo), 'Undo');

    expect(
      loggedDrinks(t),
      before,
      reason: 'Undo did not remove the drink. It dismissed the snackbar and '
          'left the data — which is worse than having no Undo, because the '
          'user believes it worked.',
    );

    // The SnackBar carries an action, and in this SDK that pins it open
    // forever unless `persist: false` is passed. aqua_water_dashboard.dart
    // passes it; this asserts that it stays passed.
    await E2E.assertToastGone(t);
    E2E.assertClean('water quick-add and undo');
  });
}
