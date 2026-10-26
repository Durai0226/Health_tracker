import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/drug_info_catalog.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/condition_library_service.dart';
import 'package:tablet_remainder/features/medication/services/drug_name_catalog.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// The condition library personalises from the active profile's medicines. Its
/// cache was keyed on the medicine-write counter alone, and switching to a
/// family member writes nothing — so the library kept showing the previous
/// person's medicines against their conditions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() async {
    await DrugNameCatalog.ensureLoaded();
    await DrugInfoCatalog.ensureLoaded();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
    ConditionLibraryService.resetForTesting();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  EnhancedMedicine metformin(String id, {String? dependentId}) => EnhancedMedicine(
        id: id,
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        dependentId: dependentId,
        schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)]),
        createdAt: DateTime(2026, 1, 1),
      );

  Set<String> diabetesMedicineIds(ConditionLibraryPersonalisation p) =>
      {for (final l in p.linksFor('type-2-diabetes')) l.medicineId};

  test('switching profile shows that profile\'s medicines, not the last one\'s',
      () async {
    await MedicineCleanStorageService.addMedicine(metformin('mine'));
    await MedicineCleanStorageService.addMedicine(
        metformin('mums', dependentId: 'dep1'));

    expect(diabetesMedicineIds(await ConditionLibraryService.load()), {'mine'});

    await ActiveProfileService().setActiveDependent('dep1');
    expect(diabetesMedicineIds(await ConditionLibraryService.load()), {'mums'},
        reason: 'no medicine was written, so only the profile can tell the '
            'cache it is stale');

    await ActiveProfileService().setActiveDependent(null);
    expect(diabetesMedicineIds(await ConditionLibraryService.load()), {'mine'});
  });

  test('the same profile still hits the cache', () async {
    await MedicineCleanStorageService.addMedicine(metformin('mine'));
    final a = await ConditionLibraryService.load();
    final b = await ConditionLibraryService.load();
    expect(identical(a, b), isTrue);
  });
}
