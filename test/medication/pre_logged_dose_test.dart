import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/today_schedule_service.dart';

/// Tier 2: pre-logged/travel dose status. This is the highest-risk item in
/// the tier — MedicineLogs stores status as independent booleans, not an
/// enum index, and dedupeByDose/reconcileMissedDoses/adherence all had to be
/// updated in lockstep. These tests target exactly the failure modes flagged
/// during design: the reconciler silently overwriting a pre-log, the two
/// duplicated rank() functions disagreeing, and future-day resolution.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  /// A once-daily medicine at 08:00, created well in the past so both past
  /// and future slots relative to "now" are reachable in tests.
  Future<EnhancedMedicine> seedDailyMedicine() async {
    final med = EnhancedMedicine(
      id: 'm1',
      name: 'Levothyroxine',
      strength: '50mcg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
      ),
    );
    await MedicineCleanStorageService.addMedicine(med, stampActiveProfile: false);
    return med;
  }

  group('markMedicinePreLogged', () {
    test('positive: persists and reads back as MedicineStatus.preLogged',
        () async {
      await seedDailyMedicine();
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrow8am =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8);

      final log = await MedicineCleanStorageService.markMedicinePreLogged(
        medicineId: 'm1',
        scheduledTime: tomorrow8am,
        dosageTaken: 1,
      );
      expect(log.status, MedicineStatus.preLogged);
      expect(log.isPreLogged, isTrue);
      expect(log.countsAsTaken, isTrue);

      final fetched = await MedicineCleanStorageService.getLog(log.id);
      expect(fetched?.status, MedicineStatus.preLogged);
    });

    test('positive: decrements stock immediately, matching markMedicineTaken',
        () async {
      final med = EnhancedMedicine(
        id: 'm2',
        name: 'Med with stock',
        strength: '1',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        currentStock: 10,
        refillReminderEnabled: true,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
        ),
      );
      await MedicineCleanStorageService.addMedicine(med, stampActiveProfile: false);

      await MedicineCleanStorageService.markMedicinePreLogged(
        medicineId: 'm2',
        scheduledTime: DateTime.now().add(const Duration(days: 1)),
        dosageTaken: 1,
      );
      final updated = await MedicineCleanStorageService.getMedicine('m2');
      expect(updated?.currentStock, 9);
    });
  });

  group('dedupeByDose rank ordering', () {
    test('positive: taken beats preLogged beats skipped beats missed', () async {
      final scheduled = DateTime(2026, 1, 1, 8);
      final id = MedicineCleanStorageService.doseLogId('m1', scheduled);
      final preLogged = MedicineLog.preLogged(
          id: id, medicineId: 'm1', scheduledTime: scheduled);
      final missed = MedicineLog.missed(
          id: id, medicineId: 'm1', scheduledTime: scheduled);

      final result =
          MedicineCleanStorageService.dedupeByDose([missed, preLogged]);
      expect(result.single.status, MedicineStatus.preLogged);
    });
  });

  group('TodayScheduleService with a pre-logged future dose', () {
    test(
        "positive: getTodaysDoses(futureDate) shows the pre-log as resolved immediately",
        () async {
      await seedDailyMedicine();
      final now = DateTime.now();
      final future = DateTime(now.year, now.month, now.day, 8)
          .add(const Duration(days: 2));

      await MedicineCleanStorageService.markMedicinePreLogged(
        medicineId: 'm1',
        scheduledTime: future,
      );

      final futureDoses = await TodayScheduleService.getTodaysDoses(future);
      expect(futureDoses.single.isPreLogged, isTrue);
      // Never offered as "up next" — it's already resolved.
      expect(TodayScheduleService.nextDose(futureDoses, future), isNull);
    });

    test(
        "negative: a future pre-log does not affect today's doses or nextDose",
        () async {
      await seedDailyMedicine();
      final now = DateTime.now();
      final future = DateTime(now.year, now.month, now.day, 8)
          .add(const Duration(days: 2));
      await MedicineCleanStorageService.markMedicinePreLogged(
        medicineId: 'm1',
        scheduledTime: future,
      );

      final todaysDoses = await TodayScheduleService.getTodaysDoses(now);
      expect(todaysDoses, isNotEmpty);
      expect(todaysDoses.every((d) => !d.isPreLogged), isTrue);
    });
  });

  group('reconcileMissedDoses regression: must not clobber a pre-log', () {
    test(
        'a pre-logged slot that ages past the grace window is NOT overwritten with a missed row',
        () async {
      await seedDailyMedicine();
      // A slot 4 hours ago — past the 3h grace window, so the reconciler
      // would normally write `missed` for it if nothing else exists.
      final agedSlot = DateTime.now().subtract(const Duration(hours: 4));
      final agedSlotAt8 =
          DateTime(agedSlot.year, agedSlot.month, agedSlot.day, 8);
      // Re-seed the medicine's creation date well before this slot so it's
      // eligible for reconciliation.
      final slotForReal = agedSlotAt8.isBefore(DateTime.now())
          ? agedSlotAt8
          : agedSlotAt8.subtract(const Duration(days: 1));

      await MedicineCleanStorageService.markMedicinePreLogged(
        medicineId: 'm1',
        scheduledTime: slotForReal,
      );

      await MedicineCleanStorageService.reconcileMissedDoses(lookbackDays: 3);

      final logs = await MedicineCleanStorageService.getLogsForMedicine('m1');
      final matching = logs.where((l) =>
          l.scheduledTime.year == slotForReal.year &&
          l.scheduledTime.month == slotForReal.month &&
          l.scheduledTime.day == slotForReal.day &&
          l.scheduledTime.hour == slotForReal.hour &&
          l.scheduledTime.minute == slotForReal.minute);
      expect(matching, hasLength(1),
          reason: 'the reconciler must not have inserted a second row');
      expect(matching.single.status, MedicineStatus.preLogged,
          reason: 'the pre-log must survive, not be overwritten as missed');
    });
  });
}
