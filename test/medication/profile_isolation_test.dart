import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/med_safety_checker.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Phase 3's gate: "a medicine under profile A is invisible under B", and
/// self-backfill must never orphan data that predates profiles existing.
/// Each `setUp` builds a fresh in-memory DB — the closest a unit test can get
/// to "a copied pre-change DB" without a real device file, since it starts
/// from the exact same state a pre-feature install would have: no dependent
/// rows, every medicine/log with a null dependentId.
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

  EnhancedMedicine med(String id, {DateTime? createdAt, int hour = 8}) =>
      EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: createdAt,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: hour, minute: 0)],
        ),
      );

  group('ActiveProfileService self-backfill', () {
    test('init() creates exactly one self DependentProfile row', () async {
      await ActiveProfileService().init();
      final deps = await MedicineCleanStorageService.getAllDependents();
      expect(deps.where((d) => d.isSelf), hasLength(1));
      expect(ActiveProfileService().isSelfActive, isTrue);
    });

    test(
        'backfilling on a DB with pre-existing (pre-feature) medicines '
        'orphans nothing — they stay visible under self', () async {
      // Simulates a copied pre-change DB: medicines already exist, all with
      // a null dependentId, no self profile row, ActiveProfileService never
      // having run.
      await MedicineCleanStorageService.addMedicine(med('pre1'));
      await MedicineCleanStorageService.addMedicine(med('pre2'));

      await ActiveProfileService().init();

      final visible = await MedicineCleanStorageService.getAllMedicines();
      expect(visible.map((m) => m.id), containsAll(['pre1', 'pre2']));
    });

    test('running init() again (e.g. a second cold start) does not duplicate the self profile',
        () async {
      await ActiveProfileService().init();
      ActiveProfileService().resetForTesting();
      await ActiveProfileService().init();

      final deps = await MedicineCleanStorageService.getAllDependents();
      expect(deps.where((d) => d.isSelf), hasLength(1));
    });
  });

  group('profile isolation (the core gate)', () {
    test('a medicine under profile A is invisible under profile B', () async {
      await ActiveProfileService().init();
      await MedicineCleanStorageService.addMedicine(med('self-med'));

      await ActiveProfileService().setActiveDependent('dep-a');
      // dependentId left unset — write-side stamping should attribute this
      // to whichever profile is active at creation time.
      await MedicineCleanStorageService.addMedicine(med('dep-a-med'));

      await ActiveProfileService().setActiveDependent(null); // back to self
      final selfView = await MedicineCleanStorageService.getAllMedicines();
      expect(selfView.map((m) => m.id), contains('self-med'));
      expect(selfView.map((m) => m.id), isNot(contains('dep-a-med')));

      await ActiveProfileService().setActiveDependent('dep-a');
      final depAView = await MedicineCleanStorageService.getAllMedicines();
      expect(depAView.map((m) => m.id), contains('dep-a-med'));
      expect(depAView.map((m) => m.id), isNot(contains('self-med')));
    });

    test(
        "a dose log inherits its MEDICINE's owner, not whichever profile "
        'happens to be active when it is logged', () async {
      await ActiveProfileService().init();
      await ActiveProfileService().setActiveDependent('dep-a');
      await MedicineCleanStorageService.addMedicine(med('dep-a-med'));

      // Switch to self, then take the dep-a medicine's dose — e.g. exactly
      // what happens when a queued background "Take all" drains while a
      // different profile happens to be open in the UI.
      await ActiveProfileService().setActiveDependent(null);
      final log = await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'dep-a-med',
        scheduledTime: DateTime(2026, 1, 1, 8),
      );
      expect(log.dependentId, 'dep-a');

      final selfLogs = await MedicineCleanStorageService.getAllLogs();
      expect(selfLogs.map((l) => l.id), isNot(contains(log.id)));

      await ActiveProfileService().setActiveDependent('dep-a');
      final depALogs = await MedicineCleanStorageService.getAllLogs();
      expect(depALogs.map((l) => l.id), contains(log.id));
    });

    test('markMedicineSkipped also inherits the medicine\'s owner', () async {
      await ActiveProfileService().init();
      await ActiveProfileService().setActiveDependent('dep-a');
      await MedicineCleanStorageService.addMedicine(med('dep-a-med'));
      await ActiveProfileService().setActiveDependent(null);

      final log = await MedicineCleanStorageService.markMedicineSkipped(
        medicineId: 'dep-a-med',
        scheduledTime: DateTime(2026, 1, 1, 8),
        reason: SkipReason.values.first,
      );
      expect(log.dependentId, 'dep-a');
    });

    test("editing an existing medicine never reassigns its owner just because a different profile is active",
        () async {
      await ActiveProfileService().init();
      await MedicineCleanStorageService.addMedicine(med('self-med'));

      await ActiveProfileService().setActiveDependent('dep-a');
      final existing = await MedicineCleanStorageService.getMedicine('self-med');
      await MedicineCleanStorageService.updateMedicine(
          existing!.copyWith(name: 'Renamed'));

      final reloaded = await MedicineCleanStorageService.getMedicine('self-med');
      expect(reloaded!.dependentId, isNull); // still self
      expect(reloaded.name, 'Renamed');
    });
  });

  group('global sweeps stay unscoped (must see every profile)', () {
    test('getAllMedicines(scopeToActiveProfile: false) ignores the active profile filter',
        () async {
      await ActiveProfileService().init();
      await MedicineCleanStorageService.addMedicine(med('self-med'));
      await ActiveProfileService().setActiveDependent('dep-a');
      await MedicineCleanStorageService.addMedicine(med('dep-a-med'));

      final all = await MedicineCleanStorageService.getAllMedicines(
          scopeToActiveProfile: false);
      expect(all.map((m) => m.id), containsAll(['self-med', 'dep-a-med']));
    });

    test('exportMedicinesJson captures every profile regardless of which is active at export time',
        () async {
      await ActiveProfileService().init();
      await MedicineCleanStorageService.addMedicine(med('self-med'));
      await ActiveProfileService().setActiveDependent('dep-a');
      await MedicineCleanStorageService.addMedicine(med('dep-a-med'));

      final backup = await MedicineCleanStorageService.exportMedicinesJson();
      final ids = backup.map((m) => m['id']).toSet();
      expect(ids, containsAll(['self-med', 'dep-a-med']));
    });

    test('importMedicinesJson does not stamp the active profile onto a self-owned record being restored',
        () async {
      await ActiveProfileService().init();
      // A DIFFERENT profile is active during the restore than the one that
      // owns the record being imported.
      await ActiveProfileService().setActiveDependent('dep-a');

      await MedicineCleanStorageService.importMedicinesJson([
        med('restored-self').toJson(), // dependentId null in the backup
      ]);

      final restored =
          await MedicineCleanStorageService.getMedicine('restored-self');
      expect(restored!.dependentId, isNull); // must stay self
    });

    test('reconcileMissedDoses reconciles every profile\'s missed doses regardless of which is active',
        () async {
      await ActiveProfileService().init();
      final createdAt = DateTime.now().subtract(const Duration(days: 3));
      final missedHour = DateTime.now().subtract(const Duration(hours: 5)).hour;

      await MedicineCleanStorageService.addMedicine(
          med('self-med', createdAt: createdAt, hour: missedHour));

      await ActiveProfileService().setActiveDependent('dep-a');
      await MedicineCleanStorageService.addMedicine(
          med('dep-a-med', createdAt: createdAt, hour: missedHour));

      // Self is active during the sweep — dep-a's medicine must still be
      // reconciled, not skipped because it's not the active profile.
      await ActiveProfileService().setActiveDependent(null);
      await MedicineCleanStorageService.reconcileMissedDoses();

      final allLogs =
          await MedicineCleanStorageService.getAllLogs(scopeToActiveProfile: false);
      expect(allLogs.where((l) => l.medicineId == 'self-med' && l.isMissed),
          isNotEmpty);
      final depAMissed = allLogs
          .where((l) => l.medicineId == 'dep-a-med' && l.isMissed)
          .toList();
      expect(depAMissed, isNotEmpty);
      // The missed log for dep-a's medicine must carry dep-a's ownership —
      // inherited from the medicine, matching the take/skip paths' contract.
      expect(depAMissed.first.dependentId, 'dep-a');
    });
  });

  group('MedSafetyChecker.checkAllergies revival', () {
    test('a dependent with allergies now yields a real conflict warning',
        () async {
      await MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'dep-a',
        name: 'Kid A',
        relationship: RelationshipType.child,
        allergies: const ['Penicillin'],
      ));

      final deps = await MedicineCleanStorageService.getAllDependents();
      final profile = deps.firstWhere((d) => d.id == 'dep-a');

      final warnings = MedSafetyChecker.checkAllergies(
        name: 'Penicillin V',
        allergies: profile.allergies ?? const [],
      );

      expect(warnings, isNotEmpty);
      expect(warnings.single.kind, 'allergy');
    });

    test('a dependent with no recorded allergies yields no warning (today\'s pre-fix behavior)',
        () async {
      await MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'dep-b',
        name: 'Kid B',
        relationship: RelationshipType.child,
      ));

      final deps = await MedicineCleanStorageService.getAllDependents();
      final profile = deps.firstWhere((d) => d.id == 'dep-b');

      final warnings = MedSafetyChecker.checkAllergies(
        name: 'Penicillin V',
        allergies: profile.allergies ?? const [],
      );

      expect(warnings, isEmpty);
    });
  });

  group('deleteDependent reassigns instead of orphaning (adversarial-review regression)', () {
    test('a deleted dependent\'s medicines become visible under self, not lost',
        () async {
      await ActiveProfileService().init();
      await ActiveProfileService().setActiveDependent('dep-a');
      await MedicineCleanStorageService.addMedicine(med('dep-a-med'));

      await MedicineCleanStorageService.deleteDependent('dep-a');

      await ActiveProfileService().setActiveDependent(null);
      final selfView = await MedicineCleanStorageService.getAllMedicines();
      expect(selfView.map((m) => m.id), contains('dep-a-med'));

      final reloaded =
          await MedicineCleanStorageService.getMedicine('dep-a-med');
      expect(reloaded!.dependentId, isNull);
    });

    test('a deleted dependent\'s dose logs become visible under self, not lost',
        () async {
      await ActiveProfileService().init();
      await ActiveProfileService().setActiveDependent('dep-a');
      await MedicineCleanStorageService.addMedicine(med('dep-a-med'));
      final log = await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'dep-a-med',
        scheduledTime: DateTime(2026, 1, 1, 8),
      );
      expect(log.dependentId, 'dep-a'); // sanity: was attributed before delete

      await MedicineCleanStorageService.deleteDependent('dep-a');

      await ActiveProfileService().setActiveDependent(null);
      final selfLogs = await MedicineCleanStorageService.getAllLogs();
      expect(selfLogs.map((l) => l.id), contains(log.id));
      expect(selfLogs.firstWhere((l) => l.id == log.id).dependentId, isNull);
    });
  });
}
