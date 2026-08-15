import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// The add-medication wizard, driven end to end — and the safety dialog at the
/// end of it.
///
/// 3,248 lines, the largest screen in the app, and the one `docs/ui-audit.md`
/// calls *"Worst. 5 overflow stripes"*. It had never been rendered by ANY
/// harness until it was added to the responsive sweep, and it overflowed on its
/// first run in two places. This drives the real flow instead.
///
/// The second test is the one that matters most in a medication app. The
/// interaction check is not decoration: it is the last thing between a user and
/// a combination their pharmacist would have stopped. A dialog that silently
/// fails to appear is a patient-safety defect, and it is invisible from the
/// outside — the save simply succeeds, exactly as it does when there is no
/// interaction at all. Only a test that creates a KNOWN interacting pair and
/// then demands the dialog can tell those two apart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  Future<void> openWizard(WidgetTester t) async {
    await E2E.launch(t);
    await E2E.goTab(t, NavTab.meds);
    // The FAB is icon-only, so find it by type rather than by a label.
    await E2E.tapWhenHittable(t, find.byType(AppFab), 'Add medication FAB');
    E2E.at(find.byType(NunitoAddMedicationFlow), where: 'the add-medication wizard');
    expect(find.text(kWizStep1), findsOneWidget,
        reason: 'the wizard must open on its first step');
  }

  /// Fills the name and advances to the schedule step, where the primary
  /// button becomes "Add Medication" (`canFinish = _currentStep >= 2`).
  final saveButton = find.widgetWithText(AppButton, kWizAddMedication);

  Future<void> fillNameAndReachSave(WidgetTester t, String name) async {
    await t.enterText(
        find.widgetWithText(AppTextField, kWizNameField).first, name);
    await settle(t);

    // Step 0 -> 1 -> 2. Two Continues, then the button relabels itself.
    for (var i = 0; i < 2; i++) {
      await E2E.tapWhenHittable(t, find.text(kWizContinue), 'Continue');
    }
    // Scoped to the BUTTON. 'Add Medication' is also the wizard's screen
    // title, so an unscoped find.text().first taps the title bar and nothing
    // happens — the wizard just sits there looking like a rejected save.
    E2E.at(saveButton, where: 'the schedule step, where the wizard can save');
  }

  testWidgets('a medicine can be added through the wizard and appears',
      (t) async {
    final name = 'E2E Testmed $stamp';
    await openWizard(t);

    final before = (await MedicineCleanStorageService.getAllMedicines()).length;
    await fillNameAndReachSave(t, name);
    await E2E.tapWhenHittable(t, saveButton, 'Add Medication button');

    // A successful save pops the wizard — but not instantly: saving also
    // schedules this medicine's notifications and background alarms, which
    // takes seconds on the emulator. Wait for it rather than assuming a fixed
    // settle was long enough; asserting too early reports a working save as a
    // validation failure.
    await E2E.waitUntilGone(
        t, find.byType(NunitoAddMedicationFlow), 'the add-medication wizard');

    final after = await MedicineCleanStorageService.getAllMedicines();
    expect(after.length, before + 1,
        reason: 'the wizard completed but no medicine was stored');
    expect(after.map((m) => m.name), contains(name),
        reason: 'a medicine was stored under a different name than typed');

    // Clean up: this suite shares a container with the others in the run.
    final created = after.firstWhere((m) => m.name == name);
    await MedicineCleanStorageService.deleteMedicine(created.id);

    E2E.assertClean('add a medicine through the wizard');
  });

  testWidgets('a known interacting pair raises the safety dialog, and Cancel '
      'does not save', (t) async {
    // Atorvastatin is seeded; Atorvastatin + Clarithromycin is a SEVERE pair in
    // the curated table (drug_interaction_service.dart, int_005 — statin
    // metabolism inhibition, rhabdomyolysis risk). Verified present before
    // writing this, rather than assumed.
    await openWizard(t);

    final before = (await MedicineCleanStorageService.getAllMedicines()).length;
    await fillNameAndReachSave(t, 'Clarithromycin');
    await E2E.tapWhenHittable(t, saveButton, 'Add Medication button');

    E2E.at(find.text(kWizInteraction),
        where: 'the drug-interaction warning dialog');
    expect(find.text(kWizSaveAnyway), findsOneWidget,
        reason: 'the warning must offer a way through — it informs, it does '
            'not block');
    expect(find.text(kWizCancel), findsWidgets,
        reason: 'and a way back out');

    // Cancel must actually abort the save. A dialog that warns and saves
    // anyway is worse than no dialog: the user believes they declined.
    await E2E.tapWhenHittable(t, find.text(kWizCancel).last, 'Cancel');
    await settle(t);

    expect(
      (await MedicineCleanStorageService.getAllMedicines()).length,
      before,
      reason: 'Cancel on the interaction warning still saved the medicine. The '
          'user was shown a severe-interaction warning, chose not to proceed, '
          'and it was added regardless.',
    );

    E2E.assertClean('drug-interaction warning');
  });

  testWidgets('a medicine with no known interaction saves without a warning',
      (t) async {
    // The negative half. Without it, a dialog that appeared on EVERY save would
    // pass the test above — and a warning that always fires is one users learn
    // to dismiss without reading, which is worse than none at all.
    final name = 'E2E Placebo $stamp';
    await openWizard(t);

    await fillNameAndReachSave(t, name);
    await E2E.tapWhenHittable(t, saveButton, 'Add Medication button');

    expect(
      find.text(kWizInteraction),
      findsNothing,
      reason: 'An invented name interacts with nothing, so no warning is due. '
          'A dialog that fires unconditionally trains users to dismiss it '
          'unread, which is how the real warning gets missed.',
    );

    final all = await MedicineCleanStorageService.getAllMedicines();
    expect(all.map((m) => m.name), contains(name));
    await MedicineCleanStorageService
        .deleteMedicine(all.firstWhere((m) => m.name == name).id);

    E2E.assertClean('no spurious interaction warning');
  });
}
