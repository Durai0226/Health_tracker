import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// Taking a dose, and the inventory invariant behind Undo.
///
/// The invariant is stated in the app's own code, at the Undo handler:
///
///   > Reverse the stock decrement first, or Undo silently loses inventory.
///
/// That is the assertion worth making, and it is not a string. Taking a dose
/// must decrement stock; Undo must put the units back AND delete the log. Get
/// half of it right and the user's pill count drifts down every time they
/// mis-tap — a slow, invisible corruption of the number the refill predictor
/// and the low-stock reminder both depend on.
///
/// Stock is read through `MedicineCleanStorageService` rather than off the
/// screen. The test shares the isolate and the database singleton with the app,
/// so this is the same row the UI renders — just read without depending on how
/// it happens to be formatted.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// id -> stock, for every medicine.
  Future<Map<String, int?>> stockById() async {
    final meds = await MedicineCleanStorageService.getAllMedicines();
    return {for (final m in meds) m.id: m.currentStock};
  }

  Future<Set<String>> logIds() async =>
      (await MedicineCleanStorageService.getAllLogs()).map((l) => l.id).toSet();

  testWidgets('taking a dose decrements stock, and Undo restores it',
      (t) async {
    await E2E.launch(t);
    await E2E.goTab(t, NavTab.meds);

    // Snapshot EVERY medicine, not one guessed in advance. Which dose scrolls
    // into view depends on the time of day and on which slots have already
    // reconciled to Missed, so pinning the medicine up front would assert
    // against the wrong row and report a defect that is not there.
    final stockBefore = await stockById();
    final logsBefore = await logIds();
    expect(stockBefore, isNotEmpty,
        reason: 'no seeded medicines — run with --dart-define=E2E_SEED=true');

    // 'Take Now' on the next dose, 'Take' on the others — one code path
    // (_onTakeMedication), two labels.
    //
    // EXACT match on either, not `textContaining('Take')`: that also matches
    // the "Taken" stat tile at the top of the screen, so the scroll below
    // stopped immediately and the tap landed on a statistic.
    final takeButton = find.byWidgetPredicate(
      (w) => w is Text && (w.data == kMedsTake || w.data == kMedsTakeNow),
      description: 'a Take / Take Now dose action',
    );

    // The dose list is below the fold: at 411x731 the Meds screen opens on its
    // header, streak and adherence stats, so the rows are not built yet.
    // Today's 08:00 doses have already reconciled to "Missed" by the time this
    // runs, so the actionable ones are the evening slots further down.
    await E2E.scrollUntilPresent(t, takeButton, 'an actionable dose');
    await E2E.tapWhenHittable(t, takeButton, 'Take action on a scheduled dose');

    E2E.at(find.text(kMedsTakeMedication),
        where: 'the take-medication confirmation sheet');
    await E2E.tapWhenHittable(
        t, find.text(kMedsTakeMedication), 'Take Medication');

    // ---- what actually got written -----------------------------------------
    final newLogs =
        (await MedicineCleanStorageService.getAllLogs())
            .where((l) => !logsBefore.contains(l.id))
            .toList();
    expect(newLogs, hasLength(1),
        reason: 'taking a dose must write exactly one log');
    final log = newLogs.single;

    // ---- the decrement, against the medicine the dose ACTUALLY belonged to --
    final stockAfter = await stockById();
    final was = stockBefore[log.medicineId];
    final now = stockAfter[log.medicineId];
    expect(
      now,
      lessThan(was!),
      reason: 'Taking a dose must consume stock for medicine '
          '${log.medicineId}: it was $was before and $now after. The refill '
          'predictor and the low-stock reminder both read this number, so a '
          'dose that does not decrement it makes both of them wrong.',
    );

    // Nothing else moved.
    for (final id in stockBefore.keys.where((k) => k != log.medicineId)) {
      expect(stockAfter[id], stockBefore[id],
          reason: 'taking one dose changed the stock of a different medicine '
              '($id)');
    }

    // ---- Undo, the half that is easy to get wrong --------------------------
    await E2E.tapWhenHittable(t, find.text(kUndo), 'Undo');

    final stockUndone = await stockById();
    expect(
      stockUndone[log.medicineId],
      was,
      reason: 'Undo did not put the units back. Stock went $was -> $now -> '
          '${stockUndone[log.medicineId]}. Every mis-tapped dose would '
          'silently cost the user inventory, and nothing on screen would say '
          'so. The app\'s own comment at this handler says: "Reverse the '
          'stock decrement first, or Undo silently loses inventory."',
    );
    expect(
      await logIds(),
      logsBefore,
      reason: 'Undo restored the stock but left the log, so adherence still '
          'counts a dose the user did not take',
    );

    await E2E.assertToastGone(t);
    E2E.assertClean('take a dose and undo it');
  });
}
