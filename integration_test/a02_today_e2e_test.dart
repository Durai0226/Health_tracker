import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// Today, the screen every session starts on, against SEEDED data.
///
/// The distinction matters more here than anywhere else in the app. Every
/// element on this screen has an empty state and a populated state, and the
/// headless sweeps run on an empty in-memory database — so the populated half,
/// which is what users actually see, has never been rendered by any harness.
/// These tests assert the populated half specifically: a KPI showing `—` with
/// a month of history behind it is a bug the empty-state screenshot cannot show.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Scoped to Today: 'Meds', 'Water' and 'Focus' all appear elsewhere in the
  /// live tree (the nav bar, the Health hub) because the shell keeps every tab
  /// alive in an IndexedStack.
  Finder inToday(Finder f) =>
      find.descendant(of: find.byType(HomeDashboard), matching: f);

  testWidgets('the pulse row reflects seeded data, not an empty state',
      (t) async {
    await E2E.launch(t);
    E2E.at(find.byType(HomeDashboard), where: kTodayHeader);

    for (final label in const [
      kKpiMeds,
      kKpiWater,
      kKpiFocus,
      kKpiReminders,
    ]) {
      expect(inToday(find.text(label)), findsWidgets,
          reason: 'pulse-row pillar "$label"');
    }

    // `—` is the no-data placeholder for Meds and Reminders
    // (home_dashboard.dart:775, :806). With a seeded month of dose history and
    // four reminders it must never appear: that would mean the screen is
    // reading a different database than the seeder wrote, which is precisely
    // the failure a presence-only check sails past.
    expect(
      inToday(find.text('—')),
      findsNothing,
      reason: 'A pulse-row pillar rendered its no-data placeholder while the '
          'database holds a month of history. Either the seed did not land or '
          'the screen is not reading it.',
    );

    E2E.assertClean('Today pulse row');
  });

  testWidgets('the next-dose hero always says something', (t) async {
    await E2E.launch(t);

    // Three legitimate states, no fourth. A blank hero was the reported
    // symptom when the schedule query returned nothing at all.
    final upNext = find.textContaining('UP NEXT');
    final overdue = find.textContaining('OVERDUE');
    final done = find.text(kHeroNothingLeft);

    final states = [upNext, overdue, done]
        .where((f) => f.evaluate().isNotEmpty) // e2e-conditional-ok: counting which of three exclusive states rendered, not asserting
        .length;

    expect(
      states,
      greaterThan(0),
      reason: 'The next-dose hero rendered none of its three states with four '
          'seeded medicines on schedule. It must never be blank.',
    );

    E2E.assertClean('next-dose hero');
  });

  testWidgets('Customize Today round-trips and persists across a tab switch',
      (t) async {
    await E2E.launch(t);

    final customize = inToday(find.text(kTodayCustomize));
    await t.scrollUntilVisible(customize.first, 300,
        scrollable: find.byType(Scrollable).first);
    await settle(t);
    await E2E.tapWhenHittable(t, customize, 'Customize action');

    expect(find.text(kTodayCustomizeSheet), findsOneWidget,
        reason: 'Customize must open the card-visibility sheet');
    expect(find.byType(SwitchListTile), findsWidgets,
        reason: 'the sheet must list card toggles');

    // Toggle the first card off, then prove it SURVIVES leaving and returning.
    // A round-trip through another tab is the cheap proof that the choice was
    // persisted rather than held in the widget's own State.
    final firstSwitch = find.byType(SwitchListTile).first;
    final before = t.widget<SwitchListTile>(firstSwitch);
    final label = (before.title as Text?)?.data ?? '<unnamed>';
    await t.tap(firstSwitch);
    await settle(t);

    Navigator.of(t.element(find.byType(AppBottomSheet))).pop();
    await settle(t);

    await E2E.goTab(t, NavTab.health);
    await E2E.goTab(t, NavTab.today);

    await t.scrollUntilVisible(inToday(find.text(kTodayCustomize)).first, 300,
        scrollable: find.byType(Scrollable).first);
    await settle(t);
    await E2E.tapWhenHittable(
        t, inToday(find.text(kTodayCustomize)), 'Customize action');

    final after = t.widget<SwitchListTile>(find.byType(SwitchListTile).first);
    expect(
      after.value,
      isNot(before.value),
      reason: 'Toggling "$label" off did not survive a tab switch, so the '
          'choice lives in widget State rather than storage. The user makes '
          'this change once and expects it to stick.',
    );

    // Put it back so the next test in this isolate starts from the same place.
    await t.tap(find.byType(SwitchListTile).first);
    await settle(t);
    Navigator.of(t.element(find.byType(AppBottomSheet))).pop();
    await settle(t);

    E2E.assertClean('Customize Today round-trip');
  });
}
