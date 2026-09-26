import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Stock could be decremented twice for one swallowed dose.
///
/// `addLog` is an upsert on `doseLogId(medicineId, scheduledTime)`, so a second
/// take of the same slot correctly replaces one log row — but `reduceStock` ran
/// unconditionally afterwards. Two ordinary paths hit this: taking a dose in the
/// app and then the queue draining the notification action for the same slot, or
/// Take on the full-screen alarm followed by Take in the app.
///
/// The visible consequence is a refill date that drifts early and a low-stock
/// alert for stock the patient still has.
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

  final slot = DateTime(2026, 3, 10, 8);

  Future<void> seed({double dosageAmount = 2, int stock = 30}) =>
      MedicineCleanStorageService.saveMedicine(EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: dosageAmount,
        currentStock: stock,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
          startDate: DateTime(2026, 3, 1),
        ),
        createdAt: DateTime(2026, 3, 1),
      ));

  Future<int?> stockNow() async =>
      (await MedicineCleanStorageService.getMedicine('m1'))?.currentStock;

  test('positive: taking a 2-tablet dose removes 2', () async {
    await seed();
    await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'm1', scheduledTime: slot, dosageTaken: 2);
    expect(await stockNow(), 28);
  });

  test('negative: taking the SAME slot twice still removes only 2', () async {
    await seed();
    await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'm1', scheduledTime: slot, dosageTaken: 2);
    // The queue drain for the same slot, or Take on the alarm screen.
    await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'm1', scheduledTime: slot, dosageTaken: 2);

    expect(await stockNow(), 28,
        reason: 'one swallowed dose must cost one dose of stock, however many '
            'paths report it');
    final logs = await MedicineCleanStorageService.getLogsForMedicine('m1');
    expect(logs.where((l) => l.scheduledTime == slot), hasLength(1),
        reason: 'the log itself was always upserted correctly');
  });

  test('positive: a corrected amount nets out to the difference', () async {
    await seed();
    await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'm1', scheduledTime: slot, dosageTaken: 2);
    // The user corrects it: they actually took 1.
    await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'm1', scheduledTime: slot, dosageTaken: 1);
    expect(await stockNow(), 29,
        reason: 'the first decrement is given back before the new one');
  });

  test('negative: two DIFFERENT slots both decrement', () async {
    await seed();
    await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'm1', scheduledTime: slot, dosageTaken: 2);
    await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'm1',
        scheduledTime: slot.add(const Duration(days: 1)),
        dosageTaken: 2);
    expect(await stockNow(), 26,
        reason: 'the fix must not swallow genuinely separate doses');
  });

  test('negative: a skip after a take gives the stock back', () async {
    await seed();
    await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'm1', scheduledTime: slot, dosageTaken: 2);
    await MedicineCleanStorageService.markMedicineSkipped(
        medicineId: 'm1', scheduledTime: slot, reason: SkipReason.other);
    expect(await stockNow(), 30,
        reason: 'a skipped dose was never swallowed');
  });
}
