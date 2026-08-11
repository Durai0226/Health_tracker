import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/reminder_window_nudges.dart';

/// Phase 4's suppression contract: taking or skipping a dose — via EITHER
/// path the main isolate exposes — must set the SAME resolved-flag key a
/// window nudge checks before firing, and stale flags must eventually be
/// pruned rather than accumulating forever.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  EnhancedMedicine med(String id, {DateTime? createdAt}) => EnhancedMedicine(
        id: id,
        name: 'Windowed med',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: createdAt,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0, windowMinutes: 60)],
        ),
      );

  test('markMedicineTaken sets the exact key a window nudge checks', () async {
    final medicine = med('m1');
    await MedicineCleanStorageService.addMedicine(medicine);
    final scheduled = DateTime(2026, 3, 1, 8, 0);

    await MedicineCleanStorageService.markMedicineTaken(
      medicineId: 'm1',
      scheduledTime: scheduled,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(nudgeResolvedKey('m1', scheduled)), isTrue);
  });

  test('markMedicineSkipped also sets it', () async {
    final medicine = med('m1');
    await MedicineCleanStorageService.addMedicine(medicine);
    final scheduled = DateTime(2026, 3, 1, 8, 0);

    await MedicineCleanStorageService.markMedicineSkipped(
      medicineId: 'm1',
      scheduledTime: scheduled,
      reason: SkipReason.values.first,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(nudgeResolvedKey('m1', scheduled)), isTrue);
  });

  test('an unresolved dose has no flag at all (not merely false)', () async {
    final prefs = await SharedPreferences.getInstance();
    final scheduled = DateTime(2026, 3, 1, 8, 0);
    expect(prefs.getBool(nudgeResolvedKey('never-taken', scheduled)), isNull);
  });

  test('reconcileMissedDoses prunes resolved flags older than 48h but '
      'leaves recent ones alone', () async {
    final prefs = await SharedPreferences.getInstance();
    // reconcileMissedDoses always uses DateTime.now() internally for the
    // prune cutoff, so the flags must be seeded relative to the REAL now, or
    // the test would depend on when it happens to run.
    final now = DateTime.now();
    final old = now.subtract(const Duration(hours: 72));
    final recent = now.subtract(const Duration(hours: 2));
    await prefs.setBool(nudgeResolvedKey('m1', old), true);
    await prefs.setBool(nudgeResolvedKey('m1', recent), true);

    await MedicineCleanStorageService.reconcileMissedDoses();

    expect(prefs.getBool(nudgeResolvedKey('m1', old)), isNull,
        reason: 'a 72h-old flag must be pruned');
    expect(prefs.getBool(nudgeResolvedKey('m1', recent)), isTrue,
        reason: 'a 2h-old flag must survive');
  });
}
