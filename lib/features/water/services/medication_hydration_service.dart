import 'package:flutter/foundation.dart';

import '../../../core/health/medication_hydration.dart';
import '../../medication/services/drug_name_catalog.dart';
import '../../medication/services/medicine_storage_service.dart';
import 'water_service.dart';

/// Bridges the medicine list to [medicationHydrationRules].
///
/// Kept out of `WaterService` deliberately: water's service is fully static and
/// used headlessly in a dozen tests, and pulling the medication stack into it
/// would couple two features that only need to meet at this one seam.
///
/// Everything here degrades to "no advice" on failure. Hydration guidance is
/// additive information; it must never be the reason a screen fails to render.
class MedicationHydrationService {
  MedicationHydrationService._();

  /// Advice derived from what the user is actually taking today.
  ///
  /// Resolves each medicine's display name to its generic through
  /// [DrugNameCatalog.genericFor] — which is why that lookup had to stop
  /// requiring an exact full-string match. A medicine called "Lithosun SR 400"
  /// resolved to null before, so the single most important rule in the table
  /// could never fire for the people it is for.
  static Future<MedicationHydrationAdvice> current() async {
    try {
      final medicines = await MedicineCleanStorageService.getAllMedicines();
      if (medicines.isEmpty) return MedicationHydrationAdvice.empty;

      // The catalogue has to be loaded before `genericFor` can resolve
      // anything: it returns null whenever `_entries` is null, and nothing on
      // the water path ever called `ensureLoaded` (its only callers are the
      // medicine detail screen, the add flow and the condition library). On a
      // cold start straight into Water every name resolved to null, so the card
      // silently never appeared — including the lithium rule, which is the most
      // safety-relevant entry in the table. Memoised, and the asset is ~32 KB.
      await DrugNameCatalog.ensureLoaded();

      final advice = hydrationAdviceFor(
        medicines.map((m) => DrugNameCatalog.genericFor(m.name)),
      );

      // Under a fluid restriction (dialysis, heart failure) a "drink more"
      // line is advice to breach a clinical limit, and the limit outranks any
      // drug's hydration floor. Keep the cautions — they are information the
      // user still needs — and drop the increases along with the floor they
      // impose. See HydrationProfile.fluidCeilingMl.
      if (WaterService.isFluidRestricted) {
        return MedicationHydrationAdvice(
          floorMl: 0,
          increases: const [],
          cautions: advice.cautions,
        );
      }
      return advice;
    } catch (e) {
      debugPrint('MedicationHydrationService.current failed: $e');
      return MedicationHydrationAdvice.empty;
    }
  }
}
