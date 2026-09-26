import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// A carer tracking a parent's medicines got no refill warning for them.
///
/// `RefillReminderService.rescheduleAll` reads the FULL cross-profile medicine
/// list, but read its dose history through `getLogsForMedicine`'s default
/// active-profile scoping. While the carer's own profile was selected, every
/// one of the parent's logs was filtered out, so `taken` came back empty and
/// the loop `continue`d before ever predicting a run-out date: the reminder for
/// the medicine that actually matters never armed at all, on any profile.
///
/// The arming itself cannot be driven headlessly — `NotificationService`'s
/// singleton cannot even be constructed in a test (it throws on its lazy
/// static) and the plugin channel is unregistered, which is why
/// `exact_alarm_fallback_guard_test.dart` also asserts against the source. So
/// the mechanism is covered behaviourally (the default scoping really does
/// hide a dependent's logs) and the call site is pinned by a grep bounded to
/// this one method.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  /// Mum's blood-pressure tablet, owned by dependent `dep1`, with a week of
  /// real dose history — everything the refill forecast needs.
  Future<void> seedDependentMedicineWithHistory() async {
    final now = DateTime.now();
    await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
      id: 'mum-bp',
      name: 'Amlodipine',
      strength: '5mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      currentStock: 6,
      refillReminderEnabled: true,
      dependentId: 'dep1',
      createdAt: DateTime(now.year, now.month, now.day - 10),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 9, minute: 0)],
      ),
    ));
    for (var i = 1; i <= 7; i++) {
      final slot = DateTime(now.year, now.month, now.day - i, 9);
      await MedicineCleanStorageService.addLog(MedicineLog.taken(
        id: 'mum-bp-$i',
        medicineId: 'mum-bp',
        scheduledTime: slot,
        actionTime: slot,
        dosageTaken: 1,
        dependentId: 'dep1',
      ));
    }
  }

  // CHARACTERIZATION, not regression.
  //
  // These two document the PRECONDITION the fix relies on — that an unscoped
  // read does return a dependent's logs while "Me" is active, and that the
  // default scoping does not. They pass with the fix reverted, because they
  // exercise `getLogsForMedicine`'s scoping parameter (never broken) rather
  // than `RefillReminderService.rescheduleAll` (which is what was passing the
  // wrong argument). The regression guard is the source group below, which
  // fails when the argument is changed back — verified by mutation.
  group('a dependent\'s dose history is visible to the refill sweep '
      '(precondition)', () {
    test('the unscoped read the sweep uses returns the dependent\'s logs while '
        '"Me" is active', () async {
      await seedDependentMedicineWithHistory();

      // The sweep's own view of the world: the full medicine list...
      final medicines = await MedicineCleanStorageService.getAllMedicines(
          scopeToActiveProfile: false);
      expect(medicines.map((m) => m.id), contains('mum-bp'));

      // ...and, with the fix, the logs that go with it.
      final logs = await MedicineCleanStorageService.getLogsForMedicine(
          'mum-bp',
          scopeToActiveProfile: false);
      expect(logs.where((l) => l.countsAsTaken), hasLength(7),
          reason: 'no taken logs means no consumption rate and no forecast');
    });

    test('the DEFAULT scoping hides them — which is why the override is needed',
        () async {
      await seedDependentMedicineWithHistory();

      final scoped =
          await MedicineCleanStorageService.getLogsForMedicine('mum-bp');
      expect(scoped, isEmpty,
          reason: 'active profile is "Me", so dep1\'s logs are filtered out; '
              'the sweep must not read through this default');
    });
  });

  group('the refill sweep reads logs unscoped', () {
    /// The body of `rescheduleAll`, bounded by the next declaration rather
    /// than a character count so the window cannot silently stop covering the
    /// method.
    String rescheduleAllBody() {
      final source = File(
              'lib/features/medication/services/refill_reminder_service.dart')
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      final from = source.indexOf('static Future<int> rescheduleAll()');
      expect(from, greaterThan(-1), reason: 'rescheduleAll was renamed');
      final next = source.indexOf('\n  static ', from + 1);
      return source.substring(from, next > from ? next : source.length);
    }

    test('every log read in it opts out of active-profile scoping', () {
      final body = rescheduleAllBody();
      final reads = RegExp(r'getLogsForMedicine\(').allMatches(body).length;
      expect(reads, greaterThan(0), reason: 'the forecast needs dose history');
      final unscoped = RegExp(
              r'getLogsForMedicine\([^;]*scopeToActiveProfile:\s*false')
          .allMatches(body)
          .length;
      expect(unscoped, reads,
          reason: 'a default-scoped read returns zero logs for a dependent\'s '
              'medicine, so its refill reminder never arms');
    });

    test('the medicine list it iterates is unscoped too', () {
      // Both halves have to agree: an unscoped medicine list read with scoped
      // logs is exactly the mismatch that produced the bug.
      expect(
          RegExp(r'getAllMedicines\(\s*scopeToActiveProfile:\s*false')
              .hasMatch(rescheduleAllBody()),
          isTrue);
    });
  });
}
