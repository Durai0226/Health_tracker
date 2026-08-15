import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
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

  Future<EnhancedMedicine?> firstSeeded() async {
    final meds = await MedicineCleanStorageService.getAllMedicines();
    return meds.isEmpty ? null : meds.first;
  }

  testWidgets('taking a dose decrements stock, and Undo restores it',
      (t) async {
    await E2E.launch(t);
    await E2E.goTab(t, NavTab.meds);

    final seeded = await firstSeeded();
    expect(seeded, isNotNull,
        reason: 'no seeded medicines — run with --dart-define=E2E_SEED=true');
    final id = seeded!.id;
    // currentStock is nullable on the model; the seeder always sets it, and a
    // null here would make every comparison below vacuous, so pin it.
    final stockBefore = seeded.currentStock;
    expect(stockBefore, isNotNull, reason: 'seeded medicine has no stock set');
    final stock = stockBefore!;
    final logsBefore = (await MedicineCleanStorageService.getAllLogs()).length;

    expect(stock, greaterThan(0),
        reason: 'the seeded medicine must have stock for this test to mean '
            'anything');

    // 'Take Now' on the next dose, 'Take' on the others — either is the same
    // code path (_onTakeMedication).
    // e2e-conditional-ok: one action, two labels — choosing which exists is
    // not an assertion, and tapWhenHittable below still asserts presence.
    final takeButton = find.text(kMedsTakeNow).evaluate().isNotEmpty
        ? find.text(kMedsTakeNow)
        : find.text(kMedsTake);
    await E2E.tapWhenHittable(t, takeButton, 'Take action on a scheduled dose');

    // The take sheet.
    expect(find.text(kMedsTakeMedication), findsOneWidget,
        reason: 'the Take action must open the confirmation sheet');
    await E2E.tapWhenHittable(
        t, find.text(kMedsTakeMedication), 'Take Medication');

    // ---- the decrement -----------------------------------------------------
    final afterTake = await MedicineCleanStorageService.getMedicine(id);
    expect(
      afterTake!.currentStock,
      lessThan(stock),
      reason: 'Taking a dose must consume stock. It was $stock before '
          'and ${afterTake.currentStock} after — the refill predictor and the '
          'low-stock reminder both read this number.',
    );
    expect(
      (await MedicineCleanStorageService.getAllLogs()).length,
      logsBefore + 1,
      reason: 'taking a dose must write a log',
    );

    // ---- Undo, the half that is easy to get wrong --------------------------
    await E2E.tapWhenHittable(t, find.text(kUndo), 'Undo');

    final afterUndo = await MedicineCleanStorageService.getMedicine(id);
    expect(
      afterUndo!.currentStock,
      stock,
      reason: 'Undo did not put the units back. Stock went $stock -> '
          '${afterTake.currentStock} -> ${afterUndo.currentStock}. Every '
          'mis-tapped dose would silently cost the user inventory, and nothing '
          'on screen would say so.',
    );
    expect(
      (await MedicineCleanStorageService.getAllLogs()).length,
      logsBefore,
      reason: 'Undo restored the stock but left the log, so adherence still '
          'counts a dose the user did not take',
    );

    await E2E.assertToastGone(t);
    E2E.assertClean('take a dose and undo it');
  });
}
