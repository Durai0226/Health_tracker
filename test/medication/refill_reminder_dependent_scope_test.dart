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
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/refill_reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

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
  ///
  /// [stock] defaults to a week's worth, which is already past its refill date
  /// at one a day; the arming tests ask for more so there is a date to arm.
  Future<void> seedDependentMedicineWithHistory({int stock = 6}) async {
    final now = DateTime.now();
    await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
      id: 'mum-bp',
      name: 'Amlodipine',
      strength: '5mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      currentStock: stock,
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
    // The sweep itself can now be driven headlessly through the notification
    // scheduler seam, so the behaviour is asserted directly; the source scan
    // below stays as a second, cheaper guard on the exact argument.
    test('a dependent\'s refill reminder arms while "Me" is active', () async {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
      final scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;

      await seedDependentMedicineWithHistory(stock: 40);
      final armed = await RefillReminderService.rescheduleAll();

      expect(armed, 1,
          reason: 'with the logs filtered out, `taken` is empty and the '
              "parent's reminder never arms at all");
      expect(scheduler.scheduled.single.id,
          RefillReminderService.notificationIdFor('mum-bp'));
    });

    test('and so does re-arming just that medicine', () async {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
      final scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;

      await seedDependentMedicineWithHistory(stock: 40);
      expect(await RefillReminderService.rescheduleFor('mum-bp'), isTrue);
    });

    /// Every non-comment line of the service, so a read added anywhere in it is
    /// held to the same rule.
    String serviceSource() => File(
            'lib/features/medication/services/refill_reminder_service.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('every log read in the service opts out of active-profile scoping', () {
      final src = serviceSource();
      final reads =
          RegExp(r'getLogsFor(?:Medicine|DateRange)\(').allMatches(src).length;
      expect(reads, greaterThan(0), reason: 'the forecast needs dose history');
      final unscoped = RegExp(
              r'getLogsFor(?:Medicine|DateRange)\([^;]*scopeToActiveProfile:\s*false')
          .allMatches(src)
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
              .hasMatch(serviceSource()),
          isTrue);
    });
  });
}
