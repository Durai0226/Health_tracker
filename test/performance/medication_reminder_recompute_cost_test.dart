@Tags(['performance'])
library;

/// PERF-05 — what ONE medicine edit costs.
///
/// Saving a medicine reschedules every Android alarm from scratch (a full
/// recompute, deliberately — see [MedicationReminderService]), so the cost of
/// that recompute is the cost of the Save button. It used to grow with the
/// user's history and with every windowed dose they own:
///
///  * `_adaptiveSuggestionMinutes` fetched dose history from inside the
///    per-(medicine, window-slot) loop, and `getLogsForMedicine` is an
///    UNRANGED full select — every log that medicine has ever had.
///  * both recomputes took their own `getScheduledAlarms()`, and each snapshot
///    re-reads and `jsonDecode`s every `alarm_*` preference on the device.
///
/// Measured here, with 3 medicines × 2 windowed doses each:
///
/// | | `medicine_logs` reads | alarm snapshots |
/// |---|---|---|
/// | before | 6 (unranged) | 2 |
/// | after | 1 (ranged) | 1 |
///
/// Both "before" figures come from a real run with the fix reverted in place,
/// not from reading the old code.
///
/// The assertions are EQUALITIES, not budgets. `scheduleReminders` only
/// reaches this path on Android (`debugForceAndroidPath` forces it here), and
/// a `lessThanOrEqualTo` would pass just as happily if the recompute never ran
/// at all — which is exactly how a perf test ends up measuring nothing.
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medication_reminder_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import '../support/counting_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingExecutor counter;
  late AppDatabase db;
  late int alarmSnapshots;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory())..recording = false;
    db = AppDatabase.forTesting(counter);
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    alarmSnapshots = 0;
    MedicationReminderService.debugForceAndroidPath = true;
    MedicationReminderService().debugAlarmReader = () async {
      alarmSnapshots++;
      // Empty: the prune loops only touch ids they find in the snapshot, so
      // nothing here reaches a platform channel.
      return <Map<String, dynamic>>[];
    };
  });

  tearDown(() async {
    MedicationReminderService.debugForceAndroidPath = false;
    MedicationReminderService().debugAlarmReader = null;
    await db.close();
  });

  // Morning slot already passed, evening still to come — an ordinary edit.
  final fixedNow = DateTime(2026, 3, 18, 9, 30);

  EnhancedMedicine med(String id, {required bool windowed}) => EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        currentStock: 40,
        createdAt: DateTime(2026, 1, 1),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.twiceDaily,
          times: [
            ScheduledTime(
                hour: 8, minute: 0, windowMinutes: windowed ? 120 : null),
            ScheduledTime(
                hour: 20, minute: 0, windowMinutes: windowed ? 120 : null),
          ],
        ),
      );

  /// [medicines] medicines, each with 20 logged doses of history — enough for
  /// AdaptiveTiming to have something to learn from, and enough that an
  /// unranged per-dose read is visibly different from one ranged read.
  Future<void> seed({required int medicines, required bool windowed}) async {
    for (var i = 0; i < medicines; i++) {
      final m = med('m$i', windowed: windowed);
      await MedicineCleanStorageService.addMedicine(m,
          stampActiveProfile: false);
      for (var d = 1; d <= 20; d++) {
        final slot = DateTime(2026, 3, 18 - d, 8, 0);
        await MedicineCleanStorageService.addLog(MedicineLog.taken(
          id: MedicineCleanStorageService.doseLogId(m.id, slot),
          medicineId: m.id,
          scheduledTime: slot,
          actionTime: slot.add(const Duration(minutes: 35)),
        ));
      }
    }
  }

  Future<Map<String, int>> editOneMedicine({required bool windowed}) async {
    counter.reset();
    counter.recording = true;
    await MedicationReminderService()
        .scheduleReminders(med('m1', windowed: windowed));
    counter.recording = false;
    return counter.tally;
  }

  test('an edit with six windowed doses takes ONE ranged log read', () async {
    await withClock(Clock.fixed(fixedNow), () async {
      await seed(medicines: 3, windowed: true);
      final t = await editOneMedicine(windowed: true);

      expect(t['medicine_logs'], 1,
          reason: 'medicine_logs was read ${t['medicine_logs']} times for one '
              'edit. Measured 6 with the per-dose read restored — one per '
              '(medicine, windowed dose). Full tally: $t');

      final logRead = counter.statements
          .firstWhere((s) => s.contains('FROM "medicine_logs"'));
      expect(logRead, contains('"scheduled_time" >='),
          reason: 'the one read must be RANGED. An unranged select of the '
              'whole table is one read too, and would pass a count-only '
              'assertion while loading every log the user has ever had: '
              '$logRead');
    });
  });

  test('a user with more windowed medicines still pays one log read', () async {
    await withClock(Clock.fixed(fixedNow), () async {
      // Twice the medicines of the test above. The old shape read once per
      // windowed dose, so this row is what made the cost personal: the more
      // carefully a user schedules, the slower their Save button got.
      await seed(medicines: 6, windowed: true);
      final t = await editOneMedicine(windowed: true);
      expect(t['medicine_logs'], 1, reason: 'full tally: $t');
      expect(t['enhanced_medicines'], 1, reason: 'full tally: $t');
    });
  });

  test('one edit takes ONE alarm snapshot', () async {
    await withClock(Clock.fixed(fixedNow), () async {
      await seed(medicines: 3, windowed: true);
      await editOneMedicine(windowed: true);
      expect(alarmSnapshots, 1,
          reason: 'both recomputes share one getScheduledAlarms(); each '
              'snapshot jsonDecodes every alarm_* preference. Measured 2 with '
              'the shared snapshot reverted.');
    });
  });

  test('no windowed dose issues no log query at all', () async {
    await withClock(Clock.fixed(fixedNow), () async {
      await seed(medicines: 3, windowed: false);
      final t = await editOneMedicine(windowed: false);

      // The common case. Hoisting the read must not turn "nothing to learn
      // from" into a query that the per-dose shape never issued either.
      expect(t['medicine_logs'] ?? 0, 0, reason: 'full tally: $t');
      // ...and the recompute really ran: without this, the assertion above is
      // satisfied by a path that did nothing.
      expect(alarmSnapshots, 1);
      expect(t['enhanced_medicines'], 1, reason: 'full tally: $t');
    });
  });
}
