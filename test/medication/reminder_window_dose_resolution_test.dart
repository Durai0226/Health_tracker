import 'package:clock/clock.dart';
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
///
/// TQ-22 — the prune test's clock is pinned.
///
/// It used to seed its two flags off `DateTime.now()`, with a comment claiming
/// `reconcileMissedDoses` "always uses DateTime.now() internally". That stopped
/// being true: the reconciler reads `clock.now()`, so the seeds and the cutoff
/// can now be pinned to the same instant instead of both chasing the real one.
/// Pinning also lets the boundary itself be tested — 47h59m survives, 48h01m
/// does not — which a wall-clock seed could only approach, never land on.
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
    // The cutoff is `clock.now() - 48h`, so both the seeds and the sweep are
    // pinned to one instant. Nothing here is relative to the real clock any
    // more, and the two flags are placed either side of the boundary by
    // minutes rather than by days.
    final at = DateTime(2026, 3, 12, 14, 30);
    await withClock(Clock.fixed(at), () async {
      final prefs = await SharedPreferences.getInstance();
      final old = at.subtract(const Duration(hours: 72));
      final justOld = at.subtract(const Duration(hours: 48, minutes: 1));
      final justRecent = at.subtract(const Duration(hours: 47, minutes: 59));
      final recent = at.subtract(const Duration(hours: 2));
      for (final t in [old, justOld, justRecent, recent]) {
        await prefs.setBool(nudgeResolvedKey('m1', t), true);
      }

      await MedicineCleanStorageService.reconcileMissedDoses();

      expect(prefs.getBool(nudgeResolvedKey('m1', old)), isNull,
          reason: 'a 72h-old flag must be pruned');
      expect(prefs.getBool(nudgeResolvedKey('m1', justOld)), isNull,
          reason: '48h01m is past the cutoff and must be pruned');
      expect(prefs.getBool(nudgeResolvedKey('m1', justRecent)), isTrue,
          reason: '47h59m is inside the cutoff and must survive');
      expect(prefs.getBool(nudgeResolvedKey('m1', recent)), isTrue,
          reason: 'a 2h-old flag must survive');
    });
  });

  test('the prune leaves every other preference alone', () async {
    // `prefs.getKeys()` is walked in full, so a prefix check that is too loose
    // would delete unrelated keys — silently, and only for users old enough to
    // have any.
    final at = DateTime(2026, 3, 12, 14, 30);
    await withClock(Clock.fixed(at), () async {
      final prefs = await SharedPreferences.getInstance();
      final stale = at.subtract(const Duration(hours: 72));
      await prefs.setBool(nudgeResolvedKey('m1', stale), true);
      await prefs.setBool('darkMode', true);
      await prefs.setInt(
          'some_other_${stale.millisecondsSinceEpoch}', 1);

      await MedicineCleanStorageService.reconcileMissedDoses();

      expect(prefs.getBool(nudgeResolvedKey('m1', stale)), isNull);
      expect(prefs.getBool('darkMode'), isTrue,
          reason: 'an unrelated preference was pruned');
      expect(prefs.getInt('some_other_${stale.millisecondsSinceEpoch}'), 1,
          reason: 'a key that merely ends in a timestamp was pruned');
    });
  });
}
