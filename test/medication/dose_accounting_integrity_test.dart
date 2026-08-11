import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/dose_action_queue.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Adversarial-review regressions for the three ways a dose could be counted
/// or stored WRONGLY — each one is a number a patient (or their doctor) would
/// read as fact:
///
/// 1. the adherence streak matched taken doses by clock time only, so one
///    medicine's 08:00 dose satisfied every other medicine due at 08:00;
/// 2. a dose taken from a notification always recorded 1 unit, under-
///    decrementing stock for any medicine dosed in more than one unit;
/// 3. dose history was in no backup at all, so a restore returned every
///    medicine with an empty adherence record.
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

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);

  /// A medicine whose only slot is midnight TODAY, created at that same
  /// instant — so exactly one day (today) is in the streak window and its
  /// single slot is always already due, whatever time the suite runs.
  EnhancedMedicine dueAtMidnight(
    String id, {
    bool isPRN = false,
    bool isArchived = false,
  }) =>
      EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: startOfToday,
        isArchived: isArchived,
        isActive: !isArchived,
        schedule: MedicineSchedule(
          frequencyType:
              isPRN ? FrequencyType.asNeeded : FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 0, minute: 0)],
          isPRN: isPRN,
        ),
      );

  group('adherence streak counts doses PER MEDICINE, not per clock minute', () {
    test(
        'two medicines share an 08:00-style slot: taking only one does NOT '
        'complete the day', () async {
      await MedicineCleanStorageService.addMedicine(dueAtMidnight('statin'));
      await MedicineCleanStorageService.addMedicine(dueAtMidnight('metformin'));

      await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'statin',
        scheduledTime: startOfToday,
      );

      // Pre-fix this returned 1: the taken key was 'y-m-d-H-M' with no
      // medicine id, so the statin's dose also resolved the metformin slot and
      // the patient was told the day was perfect while never taking one drug.
      final partial = await MedicineCleanStorageService.getStreakResult();
      expect(partial.current, 0);

      await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'metformin',
        scheduledTime: startOfToday,
      );

      final complete = await MedicineCleanStorageService.getStreakResult();
      expect(complete.current, 1);
    });

    test('a PRN dose logged at the same minute does not resolve a scheduled dose',
        () async {
      await MedicineCleanStorageService.addMedicine(dueAtMidnight('statin'));
      await MedicineCleanStorageService.addMedicine(
          dueAtMidnight('ibuprofen', isPRN: true));

      await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'ibuprofen',
        scheduledTime: startOfToday,
      );

      final result = await MedicineCleanStorageService.getStreakResult();
      expect(result.current, 0);
    });

    test('an ARCHIVED medicine\'s dose does not resolve a scheduled dose',
        () async {
      await MedicineCleanStorageService.addMedicine(dueAtMidnight('statin'));
      await MedicineCleanStorageService.addMedicine(
          dueAtMidnight('old-med', isArchived: true));

      await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'old-med',
        scheduledTime: startOfToday,
      );

      final result = await MedicineCleanStorageService.getStreakResult();
      expect(result.current, 0);
    });

    test('taking the one due dose still completes the day (no regression)',
        () async {
      await MedicineCleanStorageService.addMedicine(dueAtMidnight('statin'));
      await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'statin',
        scheduledTime: startOfToday,
      );

      final result = await MedicineCleanStorageService.getStreakResult();
      expect(result.current, 1);
    });
  });

  group('a dose queued from a notification records the REAL dose amount', () {
    EnhancedMedicine twoTablets(String id, {List<TitrationStep>? titration}) =>
        EnhancedMedicine(
          id: id,
          name: 'Med $id',
          dosageForm: DosageForm.tablet,
          dosageAmount: 2,
          currentStock: 20,
          lowStockThreshold: 5,
          createdAt: now.subtract(const Duration(days: 30)),
          schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)],
            startDate: now.subtract(const Duration(days: 10)),
            titrationSteps: titration,
          ),
        );

    test('a 2-tablet dose decrements stock by 2, not by 1', () async {
      await MedicineCleanStorageService.addMedicine(twoTablets('m1'));
      final slot = now.subtract(const Duration(hours: 1));

      await DoseActionQueue.enqueue(
        medicineId: 'm1',
        scheduledTime: slot,
        action: DoseActionQueue.actionTake,
      );
      final created =
          await MedicineCleanStorageService.drainPendingDoseActions();
      expect(created, hasLength(1));

      final log = await MedicineCleanStorageService.getLog(created.single);
      // Pre-fix: 1 — the queued path hardcoded the default dose amount.
      expect(log!.dosageTaken, 2);

      final med = await MedicineCleanStorageService.getMedicine('m1');
      expect(med!.currentStock, 18);
    });

    test('a titrating medicine uses the CURRENT step, like the in-app path',
        () async {
      await MedicineCleanStorageService.addMedicine(twoTablets(
        'm2',
        titration: [
          TitrationStep(startDayOffset: 0, dosageAmount: 1),
          TitrationStep(startDayOffset: 7, dosageAmount: 3),
        ],
      ));
      final slot = now.subtract(const Duration(hours: 1));

      await DoseActionQueue.enqueue(
        medicineId: 'm2',
        scheduledTime: slot,
        action: DoseActionQueue.actionTake,
      );
      final created =
          await MedicineCleanStorageService.drainPendingDoseActions();

      final log = await MedicineCleanStorageService.getLog(created.single);
      expect(log!.dosageTaken, 3); // 10 days in → the week-2 step
      final med = await MedicineCleanStorageService.getMedicine('m2');
      expect(med!.currentStock, 17);
    });

    test('a queued SKIP still logs a skip and leaves stock alone', () async {
      await MedicineCleanStorageService.addMedicine(twoTablets('m3'));

      await DoseActionQueue.enqueue(
        medicineId: 'm3',
        scheduledTime: now.subtract(const Duration(hours: 1)),
        action: DoseActionQueue.actionSkip,
      );
      final created =
          await MedicineCleanStorageService.drainPendingDoseActions();

      final log = await MedicineCleanStorageService.getLog(created.single);
      expect(log!.isSkipped, isTrue);
      final med = await MedicineCleanStorageService.getMedicine('m3');
      expect(med!.currentStock, 20);
    });
  });

  group('dose history survives a backup/restore round trip', () {
    test('taken and skipped logs come back with the medicine', () async {
      await MedicineCleanStorageService.addMedicine(dueAtMidnight('statin'));
      await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'statin',
        scheduledTime: startOfToday,
        dosageTaken: 2,
        notes: 'with breakfast',
      );
      await MedicineCleanStorageService.markMedicineSkipped(
        medicineId: 'statin',
        scheduledTime: startOfToday.subtract(const Duration(days: 1)),
        reason: SkipReason.values.first,
      );

      final backup = await MedicineCleanStorageService.exportMedicinesJson();

      // Wipe: deleteMedicine cascade-deletes the medicine's logs, so this is
      // the same empty state a restore onto a fresh install starts from.
      await MedicineCleanStorageService.deleteMedicine('statin');
      expect(await MedicineCleanStorageService.getAllLogs(), isEmpty);

      await MedicineCleanStorageService.importMedicinesJson(backup);

      final logs = await MedicineCleanStorageService.getAllLogs();
      expect(logs, hasLength(2));
      final taken = logs.firstWhere((l) => l.isTaken);
      expect(taken.dosageTaken, 2);
      expect(taken.notes, 'with breakfast');
      expect(logs.where((l) => l.isSkipped), hasLength(1));
    });

    test('restoring the same backup twice never duplicates a dose', () async {
      await MedicineCleanStorageService.addMedicine(dueAtMidnight('statin'));
      await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'statin',
        scheduledTime: startOfToday,
      );

      final backup = await MedicineCleanStorageService.exportMedicinesJson();
      await MedicineCleanStorageService.importMedicinesJson(backup);
      await MedicineCleanStorageService.importMedicinesJson(backup);

      expect(await MedicineCleanStorageService.getAllLogs(), hasLength(1));
    });

    test('an older backup with no dose history restores the medicine unchanged',
        () async {
      final legacy = dueAtMidnight('statin').toJson(); // no doseLogs key
      await MedicineCleanStorageService.importMedicinesJson([legacy]);

      expect(await MedicineCleanStorageService.getMedicine('statin'), isNotNull);
      expect(await MedicineCleanStorageService.getAllLogs(), isEmpty);
    });
  });
}
