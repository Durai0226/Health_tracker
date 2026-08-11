import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Regression cover for a Phase 6 adversarial-review finding: expiry alerts
/// must see EVERY profile's medicines, not just the active one — a caregiver
/// with "Self" active must still be warned about a dependent's expiring
/// medicine. getExpiringMedicinesAsync used to default to
/// scopeToActiveProfile: true (inherited from getAllMedicines' own default),
/// silently hiding a dependent's expiring medicine unless that dependent
/// happened to be the active profile at reconciliation time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  EnhancedMedicine med(String id, {DateTime? expiryDate, String? dependentId}) =>
      EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        expiryDate: expiryDate,
        dependentId: dependentId,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
        ),
      );

  group('getExpiringMedicinesAsync profile scoping', () {
    test('unscoped sees a dependent-owned expiring medicine while self is active',
        () async {
      await MedicineCleanStorageService.addMedicine(
        med('dep-med', expiryDate: DateTime.now().add(const Duration(days: 5)), dependentId: 'dep-1'),
        stampActiveProfile: false,
      );
      await MedicineCleanStorageService.addMedicine(
        med('self-med', expiryDate: DateTime.now().add(const Duration(days: 5))),
        stampActiveProfile: false,
      );

      // Self is active (default) — a scoped query would hide dep-med.
      final unscoped = await MedicineCleanStorageService.getExpiringMedicinesAsync(
          scopeToActiveProfile: false);
      expect(unscoped.map((m) => m.id), containsAll(['dep-med', 'self-med']));
    });

    test('scoped (default) hides the dependent-owned medicine while self is active',
        () async {
      await MedicineCleanStorageService.addMedicine(
        med('dep-med2', expiryDate: DateTime.now().add(const Duration(days: 5)), dependentId: 'dep-2'),
        stampActiveProfile: false,
      );

      final scoped = await MedicineCleanStorageService.getExpiringMedicinesAsync();
      expect(scoped.map((m) => m.id), isNot(contains('dep-med2')));
    });

    test('reconcileMissedDoses (the real caller) does not throw with a dependent-owned expiring medicine',
        () async {
      await MedicineCleanStorageService.addMedicine(
        med('dep-med3', expiryDate: DateTime.now().add(const Duration(days: 5)), dependentId: 'dep-3'),
        stampActiveProfile: false,
      );
      await expectLater(
          MedicineCleanStorageService.reconcileMissedDoses(), completes);
    });
  });
}
