import 'package:flutter/foundation.dart';

import '../../../core/health/measurement_plan.dart';
import '../../../core/services/clean_storage_service.dart';
import '../models/enhanced_medicine.dart';
import 'drug_name_catalog.dart';
import 'vitals_reminder_service.dart';

/// Connects [MeasurementPlan]'s drug rules to the reminders the app already has.
///
/// Offers only. Nothing here is called until the user taps "Remind me", and a
/// "not now" is remembered per reading so adding a second blood-pressure pill
/// does not ask again.
class MeasurementPlanService {
  MeasurementPlanService._();

  static const _declinedKey = 'measurement_plan_declined';

  /// The reminder specs behind each reading, in slot order — BP is the only one
  /// with two.
  static List<VitalsReminderSpec> specsFor(MeasurementKind kind) {
    switch (kind) {
      case MeasurementKind.bloodPressure:
        return const [VitalsReminderService.bp, VitalsReminderService.bpEvening];
      case MeasurementKind.bloodGlucose:
        return const [VitalsReminderService.glucose];
      case MeasurementKind.weight:
        return const [VitalsReminderService.weight];
    }
  }

  /// A reading counts as set up when ANY of its reminders is on: someone who
  /// already runs their own single BP reminder has made their choice.
  static bool isOn(MeasurementKind kind) =>
      specsFor(kind).any(VitalsReminderService.isEnabled);

  static Set<MeasurementKind> declined() {
    final v = CleanStorageService.getAppPreference(_declinedKey, const <String>[]);
    if (v is! List) return {};
    final names = v.map((e) => e.toString()).toSet();
    return {
      for (final k in MeasurementKind.values)
        if (names.contains(k.name)) k,
    };
  }

  /// What to offer for [medicine] — empty when nothing applies, everything is
  /// already on or was declined, or anything at all goes wrong. An offer is
  /// never worth failing a medicine save over.
  static Future<List<MeasurementSuggestion>> offerFor(
      EnhancedMedicine medicine) async {
    try {
      await DrugNameCatalog.ensureLoaded();
      return MeasurementPlan.offer(
        medicine.name,
        generic: DrugNameCatalog.genericFor(medicine.name),
        alreadyOn: {
          for (final k in MeasurementKind.values)
            if (isOn(k)) k,
        },
        declined: declined(),
      );
    } catch (e) {
      debugPrint('MeasurementPlanService.offerFor failed: $e');
      return const [];
    }
  }

  /// Turn on the reminders for [suggestion], at its times.
  static Future<void> accept(MeasurementSuggestion suggestion) async {
    final specs = specsFor(suggestion.kind);
    for (var i = 0; i < specs.length && i < suggestion.slots.length; i++) {
      final slot = suggestion.slots[i];
      await VitalsReminderService.apply(specs[i],
          enabled: true, hour: slot.hour, minute: slot.minute);
    }
  }

  /// Remember "not now" for [kinds] so they are not offered again.
  static Future<void> decline(Iterable<MeasurementKind> kinds) async {
    final all = {...declined(), ...kinds};
    await CleanStorageService.setAppPreference(
        _declinedKey, all.map((k) => k.name).toList());
  }
}
