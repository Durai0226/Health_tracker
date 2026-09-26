import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/reminder_slot_grouping.dart';

/// The per-medicine "Reminders" toggle could not persist: `enhanced_medicines`
/// had no column for it, so `_mapToMedicineCompanion` dropped it on write and
/// `_mapToDomainMedicine` never set it, leaving the constructor default
/// (`true`) on every read.
///
/// Turning reminders off therefore worked exactly once — the save cancelled the
/// scheduled alarms — and then `ReminderRescheduleService` re-armed them on the
/// next cold start, because it reads medicines back from Drift and every one of
/// them said `reminderEnabled: true`. A user who keeps a pill box and wanted no
/// 08:00 alarm got one every morning, and the Edit screen showed the toggle
/// back ON.
///
/// Schema v20 adds the column. These tests pin both halves: the round trip, and
/// the scheduling decision that depends on it.
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

  EnhancedMedicine med(String id, {required bool reminderEnabled}) =>
      EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        reminderEnabled: reminderEnabled,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
          startDate: now.subtract(const Duration(days: 1)),
        ),
        createdAt: now.subtract(const Duration(days: 1)),
      );

  test('negative: reminderEnabled=false survives a save/read round trip',
      () async {
    await MedicineCleanStorageService.saveMedicine(
        med('off', reminderEnabled: false));

    final read = await MedicineCleanStorageService.getMedicine('off');
    expect(read, isNotNull);
    expect(read!.reminderEnabled, isFalse,
        reason: 'a medicine whose reminders the user turned off must not come '
            'back armed — this is what re-armed alarms on every cold start');
  });

  test('positive: the default (true) still round-trips', () async {
    await MedicineCleanStorageService.saveMedicine(
        med('on', reminderEnabled: true));

    final read = await MedicineCleanStorageService.getMedicine('on');
    expect(read!.reminderEnabled, isTrue);
  });

  test('negative: a disabled medicine produces no reminder slot', () async {
    final slots = groupRemindersBySlot([med('off', reminderEnabled: false)], now);
    expect(slots, isEmpty,
        reason: 'groupRemindersBySlot already honours the flag; persisting it '
            'is what makes that decision reachable after a restart');
  });

  test('positive: an enabled medicine still produces its slot', () async {
    final slots = groupRemindersBySlot([med('on', reminderEnabled: true)], now);
    expect(slots, isNotEmpty);
  });

  test('the toggle survives a round trip THROUGH the database into scheduling',
      () async {
    await MedicineCleanStorageService.saveMedicine(
        med('off', reminderEnabled: false));
    await MedicineCleanStorageService.saveMedicine(
        med('on', reminderEnabled: true));

    // Exactly what the app-start reschedule pass does: read from Drift, group.
    final all = await MedicineCleanStorageService.getAllMedicines(
        scopeToActiveProfile: false);
    final slots = groupRemindersBySlot(all, now);

    final scheduledIds = slots
        .expand((s) => s.medicines.map((m) => m.medicineId))
        .toSet();
    expect(scheduledIds, contains('on'));
    expect(scheduledIds, isNot(contains('off')),
        reason: 'the cold-start reschedule must not re-arm a medicine the user '
            'silenced');
  });
}
