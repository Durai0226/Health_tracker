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
import 'package:tablet_remainder/features/medication/services/late_dose_recovery.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('takenAtFor', () {
    final slot = DateTime(2026, 3, 10, 8);
    final now = DateTime(2026, 3, 11, 9);

    test('reads the time on the scheduled day', () {
      expect(
          LateDoseRecovery.takenAtFor(
              scheduled: slot, hour: 9, minute: 40, now: now),
          DateTime(2026, 3, 10, 9, 40));
    });

    test('a time earlier than the schedule is the next day, not before it', () {
      final late = DateTime(2026, 3, 10, 23);
      expect(
          LateDoseRecovery.takenAtFor(
              scheduled: late, hour: 0, minute: 30, now: now),
          DateTime(2026, 3, 11, 0, 30));
    });

    test('a time that has not happened yet is refused', () {
      expect(
          LateDoseRecovery.takenAtFor(
              scheduled: slot, hour: 8, minute: 0, now: DateTime(2026, 3, 10, 7)),
          isNull);
      // The rolled-over case can land in the future too.
      expect(
          LateDoseRecovery.takenAtFor(
              scheduled: DateTime(2026, 3, 10, 23),
              hour: 1,
              minute: 0,
              now: DateTime(2026, 3, 10, 23, 30)),
          isNull);
    });

    test('exactly the scheduled minute is allowed', () {
      expect(
          LateDoseRecovery.takenAtFor(
              scheduled: slot, hour: 8, minute: 0, now: now),
          slot);
    });
  });

  group('against the database', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
    });

    tearDown(() async => db.close());

    final slot = DateTime(2026, 3, 10, 8);
    final today = DateTime(2026, 3, 11, 9);

    Future<void> seed() => MedicineCleanStorageService.saveMedicine(
          EnhancedMedicine(
            id: 'm1',
            name: 'Metformin',
            dosageForm: DosageForm.tablet,
            dosageAmount: 1,
            currentStock: 30,
            schedule: MedicineSchedule(
              frequencyType: FrequencyType.onceDaily,
              times: [ScheduledTime(hour: 8, minute: 0)],
              startDate: DateTime(2026, 3, 9),
            ),
            createdAt: DateTime(2026, 3, 9),
          ),
        );

    Future<MissedDose> missedYesterday() async {
      await MedicineCleanStorageService.reconcileMissedDoses();
      final logs = await MedicineCleanStorageService.getLogsForDate(slot);
      final meds = await MedicineCleanStorageService.getAllMedicines();
      final missed = LateDoseRecovery.missedOn(slot, logs, meds);
      expect(missed, hasLength(1), reason: 'the sweep should have written one');
      return missed.single;
    }

    Future<int?> stock() async =>
        (await MedicineCleanStorageService.getMedicine('m1'))?.currentStock;

    Future<MedicineLog?> logNow() =>
        MedicineCleanStorageService.getLog(
            MedicineCleanStorageService.doseLogId('m1', slot));

    test('the sweep writes it as missed, and missedOn finds it', () async {
      await withClock(Clock.fixed(today), () async {
        await seed();
        final d = await missedYesterday();
        expect(d.log.isMissed, isTrue);
        expect(d.medicine.name, 'Metformin');
      });
    });

    test('Took it on time: taken at the scheduled minute, one dose of stock',
        () async {
      await withClock(Clock.fixed(today), () async {
        await seed();
        final d = await missedYesterday();
        await LateDoseRecovery.apply(d, const LateChoice(LateOutcome.tookOnTime));
        final l = (await logNow())!;
        expect(l.isTaken, isTrue);
        expect(l.actionTime, slot);
        expect(await stock(), 29);
        // And the next sweep must not write the missed row back over it.
        await MedicineCleanStorageService.reconcileMissedDoses();
        expect((await logNow())!.isTaken, isTrue);
      });
    });

    test('Took it at…: records the time the person named', () async {
      await withClock(Clock.fixed(today), () async {
        await seed();
        final d = await missedYesterday();
        final at = DateTime(2026, 3, 10, 9, 40);
        await LateDoseRecovery.apply(
            d, LateChoice(LateOutcome.tookAt, at: at));
        expect((await logNow())!.actionTime, at);
        expect((await logNow())!.timeDifference, const Duration(hours: 1, minutes: 40));
      });
    });

    test('Take now: taken at the current instant', () async {
      await withClock(Clock.fixed(today), () async {
        await seed();
        final d = await missedYesterday();
        await LateDoseRecovery.apply(d, const LateChoice(LateOutcome.takeNow));
        expect((await logNow())!.actionTime, today);
        expect(await stock(), 29);
      });
    });

    test('a two-tablet dose uses two tablets, however it is recovered', () async {
      await withClock(Clock.fixed(today), () async {
        await MedicineCleanStorageService.saveMedicine(EnhancedMedicine(
          id: 'm1',
          name: 'Metformin',
          dosageForm: DosageForm.tablet,
          dosageAmount: 2,
          currentStock: 30,
          schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)],
            startDate: DateTime(2026, 3, 9),
          ),
          createdAt: DateTime(2026, 3, 9),
        ));
        for (final (choice, expected) in [
          (const LateChoice(LateOutcome.tookOnTime), 28),
          (LateChoice(LateOutcome.tookAt, at: DateTime(2026, 3, 10, 9)), 28),
          (const LateChoice(LateOutcome.takeNow), 28),
        ]) {
          final d = await missedYesterday();
          final log = await LateDoseRecovery.apply(d, choice);
          expect(log.dosageTaken, 2,
              reason: 'the default of one unit under-counted every recovered dose '
                  'of a medicine taken two at a time');
          expect(await stock(), expected, reason: '${choice.outcome}');
          await LateDoseRecovery.undo(log);
          expect(await stock(), 30);
        }
      });
    });

    test('Skip: no stock is used', () async {
      await withClock(Clock.fixed(today), () async {
        await seed();
        final d = await missedYesterday();
        await LateDoseRecovery.apply(d, const LateChoice(LateOutcome.skipped));
        expect((await logNow())!.isSkipped, isTrue);
        expect(await stock(), 30);
      });
    });

    test('Undo hands the stock back and the slot returns to missed', () async {
      await withClock(Clock.fixed(today), () async {
        await seed();
        final d = await missedYesterday();
        final log = await LateDoseRecovery.apply(
            d, const LateChoice(LateOutcome.tookOnTime));
        expect(await stock(), 29);
        await LateDoseRecovery.undo(log);
        expect(await stock(), 30);
        await MedicineCleanStorageService.reconcileMissedDoses();
        expect((await logNow())!.isMissed, isTrue,
            reason: 'unaccounted-for doses must still count against adherence');
      });
    });

    test('missedOn ignores other days, other statuses and unknown medicines',
        () async {
      await withClock(Clock.fixed(today), () async {
        await seed();
        await MedicineCleanStorageService.reconcileMissedDoses();
        final logs = await MedicineCleanStorageService.getLogsForDateRange(
            DateTime(2026, 3, 9), today);
        final meds = await MedicineCleanStorageService.getAllMedicines();
        expect(LateDoseRecovery.missedOn(slot, logs, meds).map((m) => m.log.scheduledTime),
            [slot]);
        expect(LateDoseRecovery.missedOn(slot, logs, const []), isEmpty);
        final taken = logs.map((l) => l.copyWith(status: MedicineStatus.taken));
        expect(LateDoseRecovery.missedOn(slot, taken.toList(), meds), isEmpty);
      });
    });
  });
}
