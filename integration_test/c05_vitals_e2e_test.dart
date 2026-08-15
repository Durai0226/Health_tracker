import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/widgets/app/vitals_widgets.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// The hypertensive-crisis card: the app's highest-stakes smart feature, wired
/// end to end.
///
/// `VitalsAnalyzer` is covered headlessly — it knows 185/120 is a crisis. What
/// no headless test can answer is whether that verdict reaches the screen, and
/// whether it *stops* reaching the screen when it should. Both halves matter,
/// and the second is the one that goes wrong:
///
///   > Without the recency bound a single crisis reading from weeks ago
///   > re-rendered a non-dismissible "Call emergency" banner on every visit,
///   > long after it stopped being actionable.
///   —  blood_pressure_screen.dart
///
/// A card that cannot be dismissed and is not currently true is worse than no
/// card: it teaches the user to ignore the one alarm the app has. So this test
/// asserts the card appears for a crisis reading AND disappears when that
/// reading is deleted. A presence-only check would pass on a banner that never
/// goes away.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openBloodPressure(WidgetTester t) async {
    await E2E.launch(t);
    await E2E.goTab(t, NavTab.health);
    await E2E.tapWhenHittable(
        t, find.text(kLogBloodPressure), 'Blood pressure tile');
    E2E.at(find.byType(BloodPressureScreen), where: 'Blood pressure');
  }

  testWidgets('a crisis reading raises the emergency card, and deleting it '
      'takes the card away', (t) async {
    await openBloodPressure(t);

    // The seeded readings are 118-132 / 76-84 — deliberately normal-ish, so
    // the card must NOT be showing before we create the crisis. This is the
    // control: without it, a card that is always on would pass the next
    // assertion.
    expect(
      find.byType(VitalsEmergencyCard),
      findsNothing,
      reason: 'The seeded readings are not a crisis, so the emergency card '
          'must not be on screen. If it is, the card is showing '
          'unconditionally and the assertion below proves nothing.',
    );

    final before = (await VitalsStorageService.getAllBp()).length;

    // ---- create a crisis reading -------------------------------------------
    await E2E.tapWhenHittable(t, find.text(kBpLogFab), 'Log reading');

    // 185/120 is unambiguously a hypertensive crisis (>=180 or >=120).
    await t.enterText(
        find.widgetWithText(AppTextField, kBpSystolic).first, '185');
    await t.enterText(
        find.widgetWithText(AppTextField, kBpDiastolic).first, '120');
    await settle(t);
    await E2E.tapWhenHittable(t, find.text(kBpSaveReading), 'Save reading');

    expect((await VitalsStorageService.getAllBp()).length, before + 1,
        reason: 'the reading must be stored');

    // ---- the card, and its actions -----------------------------------------
    await E2E.scrollUntilPresent(
        t, find.byType(VitalsEmergencyCard), 'the emergency card');

    expect(find.text(kBpCrisisTitle), findsOneWidget,
        reason: '185/120 is a hypertensive crisis and the screen must say so');
    expect(find.text(kBpCallEmergency), findsWidgets,
        reason: 'an emergency card without an emergency action is decoration');
    expect(find.text(kBpReMeasure), findsWidgets,
        reason: 'the user must be offered the non-panic option too');

    // ---- delete it, and the card must go -----------------------------------
    // This is the half that regressed before. The card is non-dismissible by
    // design, so "it is showing" and "it should be showing" have to be the
    // same statement.
    final crisis = (await VitalsStorageService.getAllBp())
        .firstWhere((r) => r.systolic == 185 && r.diastolic == 120);
    await VitalsStorageService.deleteBp(crisis.id);

    // Leave and come back rather than poking setState — that is the path a
    // user takes, and it also proves the screen re-reads on entry.
    await E2E.tapWhenHittable(
        t, find.byIcon(Symbols.arrow_back_rounded), 'back to Health');
    await E2E.tapWhenHittable(
        t, find.text(kLogBloodPressure), 'Blood pressure tile');
    E2E.at(find.byType(BloodPressureScreen), where: 'Blood pressure');

    expect(
      find.byType(VitalsEmergencyCard),
      findsNothing,
      reason: 'The crisis reading is gone but the emergency card is still on '
          'screen. A non-dismissible "Call emergency" banner that is no longer '
          'true teaches the user to ignore the one alarm this app has.',
    );
    expect((await VitalsStorageService.getAllBp()).length, before,
        reason: 'the database is back where it started');

    E2E.assertClean('blood pressure crisis card round-trip');
  });
}
