/// Correcting a dose that is already in the history.
///
/// The history was the last five doses with nothing to tap, so a dose logged as
/// skipped that had been taken, one logged at the wrong time, or one logged twice
/// stayed wrong. Every correction goes through the writes a dose is recorded
/// with, so the tablets left and the adherence figure follow it.
library;

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
import 'package:tablet_remainder/features/medication/services/dose_history_edit.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final slot = DateTime(2026, 3, 10, 8);
  final today = DateTime(2026, 3, 11, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  /// Two tablets a dose, so a default of one unit shows.
  EnhancedMedicine medicine({int? stock = 30}) => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 2,
        currentStock: stock,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
          startDate: DateTime(2026, 3, 9),
        ),
        createdAt: DateTime(2026, 3, 9),
      );

  Future<void> seed({int? stock = 30}) =>
      MedicineCleanStorageService.saveMedicine(medicine(stock: stock));

  Future<int?> stock() async =>
      (await MedicineCleanStorageService.getMedicine('m1'))?.currentStock;

  Future<MedicineLog?> stored() => MedicineCleanStorageService.getLog(
      MedicineCleanStorageService.doseLogId('m1', slot));

  /// The slot as the sweep wrote it: missed.
  Future<MedicineLog> missed() async {
    await MedicineCleanStorageService.reconcileMissedDoses();
    final l = await stored();
    expect(l!.isMissed, isTrue, reason: 'the premise');
    return l;
  }

  /// The slot taken ten minutes late, with a note and a mood.
  Future<MedicineLog> taken() => MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'm1',
        scheduledTime: slot,
        takenAt: slot.add(const Duration(minutes: 10)),
        dosageTaken: 2,
        notes: 'with breakfast',
        moodRating: 2,
      );

  Future<MedicineLog> skipped() => MedicineCleanStorageService.markMedicineSkipped(
      medicineId: 'm1', scheduledTime: slot, reason: SkipReason.other);

  Future<void> inDay(Future<void> Function() body) =>
      withClock(Clock.fixed(today), body);

  group('what can be done', () {
    final base = MedicineLog(
        id: 'x', medicineId: 'm1', scheduledTime: slot, status: MedicineStatus.taken);

    test('a taken dose: change its time, say it was not taken, or remove it', () {
      expect(DoseHistoryEdit.optionsFor(base), [
        DoseCorrection.tookAt,
        DoseCorrection.didNotTake,
        DoseCorrection.remove,
      ]);
      expect(
          DoseHistoryEdit.optionsFor(base.copyWith(status: MedicineStatus.preLogged)),
          DoseHistoryEdit.optionsFor(base),
          reason: 'a pre-logged dose was swallowed too');
    });

    test('a skipped dose: it was taken after all, or remove it', () {
      expect(DoseHistoryEdit.optionsFor(base.copyWith(status: MedicineStatus.skipped)), [
        DoseCorrection.tookAtSlot,
        DoseCorrection.tookAt,
        DoseCorrection.remove,
      ]);
    });

    test('a missed dose: it was taken, or it was not', () {
      expect(DoseHistoryEdit.optionsFor(base.copyWith(status: MedicineStatus.missed)), [
        DoseCorrection.tookAtSlot,
        DoseCorrection.tookAt,
        DoseCorrection.didNotTake,
      ]);
    });

    test('a missed dose cannot be "removed": the next sweep would only write it again',
        () {
      expect(
          DoseHistoryEdit.optionsFor(base.copyWith(status: MedicineStatus.missed)),
          isNot(contains(DoseCorrection.remove)));
    });

    test('a dose that has not happened has nothing to correct', () {
      expect(DoseHistoryEdit.optionsFor(base.copyWith(status: MedicineStatus.pending)),
          isEmpty);
    });
  });

  group('it was taken after all', () {
    test('missed → at the scheduled minute: taken, the whole two-tablet dose used',
        () async {
      await inDay(() async {
        await seed();
        final r = await DoseHistoryEdit.apply(
            await missed(), medicine(), const DoseEdit(DoseCorrection.tookAtSlot));

        final l = (await stored())!;
        expect(l.isTaken, isTrue);
        expect(l.actionTime, slot);
        expect(l.dosageTaken, 2, reason: 'the schedule calls for two, not a default of one');
        expect(await stock(), 28);
        expect(r.before.isMissed, isTrue);
        expect(r.after!.isTaken, isTrue);

        await MedicineCleanStorageService.reconcileMissedDoses();
        expect((await stored())!.isTaken, isTrue,
            reason: 'and the next sweep must not write the missed row back');
      });
    });

    test('missed → at a time they name', () async {
      await inDay(() async {
        await seed();
        final at = DateTime(2026, 3, 10, 9, 40);
        await DoseHistoryEdit.apply(await missed(), medicine(),
            DoseEdit(DoseCorrection.tookAt, at: at));
        expect((await stored())!.actionTime, at);
        expect(await stock(), 28);
      });
    });

    test('skipped → taken: the dose is used', () async {
      await inDay(() async {
        await seed();
        final s = await skipped();
        expect(await stock(), 30, reason: 'the premise: a skip used nothing');
        await DoseHistoryEdit.apply(s, medicine(), const DoseEdit(DoseCorrection.tookAtSlot));
        expect((await stored())!.isTaken, isTrue);
        expect(await stock(), 28);
      });
    });
  });

  group('it was taken at another time', () {
    test('only the time changes: the note, the mood and the stock stay', () async {
      await inDay(() async {
        await seed();
        final t = await taken();
        expect(await stock(), 28);

        final at = DateTime(2026, 3, 10, 7, 30);
        final r = await DoseHistoryEdit.apply(
            t, medicine(), DoseEdit(DoseCorrection.tookAt, at: at));

        final l = (await stored())!;
        expect(l.isTaken, isTrue);
        expect(l.actionTime, at);
        expect(l.notes, 'with breakfast', reason: 'a note is not thrown away by a time change');
        expect(l.moodRating, 2);
        expect(l.dosageTaken, 2);
        expect(await stock(), 28, reason: 'the dose was already counted');
        expect(r.before.actionTime, slot.add(const Duration(minutes: 10)));
      });
    });
  });

  group('it was not taken', () {
    test('taken → not taken: written as skipped, and the tablets come back', () async {
      await inDay(() async {
        await seed();
        final t = await taken();
        expect(await stock(), 28);

        final r = await DoseHistoryEdit.apply(
            t, medicine(), const DoseEdit(DoseCorrection.didNotTake));

        final l = (await stored())!;
        expect(l.isSkipped, isTrue);
        expect(l.skipReason, SkipReason.forgotToTake);
        expect(await stock(), 30);
        expect(r.after!.isSkipped, isTrue);
      });
    });

    test('missed → not taken: skipped, nothing used', () async {
      await inDay(() async {
        await seed();
        await DoseHistoryEdit.apply(
            await missed(), medicine(), const DoseEdit(DoseCorrection.didNotTake));
        expect((await stored())!.isSkipped, isTrue);
        expect(await stock(), 30);
      });
    });
  });

  group('removing an entry', () {
    test('a taken one: gone, and the tablets come back', () async {
      await inDay(() async {
        await seed();
        final t = await taken();
        final r = await DoseHistoryEdit.apply(
            t, medicine(), const DoseEdit(DoseCorrection.remove));

        expect(await stored(), isNull);
        expect(await stock(), 30);
        expect(r.after, isNull);
      });
    });

    test('a skipped one: gone, the stock untouched', () async {
      await inDay(() async {
        await seed();
        final s = await skipped();
        await DoseHistoryEdit.apply(s, medicine(), const DoseEdit(DoseCorrection.remove));
        expect(await stored(), isNull);
        expect(await stock(), 30);
      });
    });

    test('a scheduled dose comes back as missed at the next sweep: nothing is hidden',
        () async {
      await inDay(() async {
        await seed();
        final t = await taken();
        await DoseHistoryEdit.apply(t, medicine(), const DoseEdit(DoseCorrection.remove));
        await MedicineCleanStorageService.reconcileMissedDoses();
        expect((await stored())!.isMissed, isTrue,
            reason: 'removing the entry for a dose that was due is not the same as '
                'it never having been due');
      });
    });
  });

  group('taking it back', () {
    test('a change of time: the old time returns, the stock was never touched', () async {
      await inDay(() async {
        await seed();
        final t = await taken();
        final r = await DoseHistoryEdit.apply(t, medicine(),
            DoseEdit(DoseCorrection.tookAt, at: DateTime(2026, 3, 10, 7, 30)));

        await DoseHistoryEdit.undo(r);

        final l = (await stored())!;
        expect(l.actionTime, slot.add(const Duration(minutes: 10)));
        expect(l.notes, 'with breakfast');
        expect(await stock(), 28);
      });
    });

    test('"it was taken": back to missed, and the tablets are returned', () async {
      await inDay(() async {
        await seed();
        final r = await DoseHistoryEdit.apply(
            await missed(), medicine(), const DoseEdit(DoseCorrection.tookAtSlot));
        expect(await stock(), 28);

        await DoseHistoryEdit.undo(r);

        expect((await stored())!.isMissed, isTrue);
        expect(await stock(), 30);
      });
    });

    test('"it was not taken": back to taken as it was, tablets used again', () async {
      await inDay(() async {
        await seed();
        final t = await taken();
        final r = await DoseHistoryEdit.apply(
            t, medicine(), const DoseEdit(DoseCorrection.didNotTake));
        expect(await stock(), 30);

        await DoseHistoryEdit.undo(r);

        final l = (await stored())!;
        expect(l.isTaken, isTrue);
        expect(l.notes, 'with breakfast', reason: 'the entry comes back whole');
        expect(l.moodRating, 2);
        expect(await stock(), 28);
      });
    });

    test('a removal: the entry and the tablets it used both come back', () async {
      await inDay(() async {
        await seed();
        final t = await taken();
        final r = await DoseHistoryEdit.apply(
            t, medicine(), const DoseEdit(DoseCorrection.remove));
        expect(await stored(), isNull);

        await DoseHistoryEdit.undo(r);

        expect((await stored())!.isTaken, isTrue);
        expect((await stored())!.notes, 'with breakfast');
        expect(await stock(), 28);
      });
    });

    test('a removal of a skip: the skip returns, the stock is as it was', () async {
      await inDay(() async {
        await seed();
        final s = await skipped();
        final r = await DoseHistoryEdit.apply(
            s, medicine(), const DoseEdit(DoseCorrection.remove));
        await DoseHistoryEdit.undo(r);
        expect((await stored())!.isSkipped, isTrue);
        expect(await stock(), 30);
      });
    });
  });

  group('a medicine whose stock is not tracked', () {
    // The stock column is not nullable, so "not tracked" is a stock of 0 with no
    // refill reminder — and it must stay that way through a correction and its Undo.
    test('every correction works, and an Undo does not invent a stock', () async {
      await inDay(() async {
        await seed(stock: null);
        expect(await stock(), 0, reason: 'the premise: nothing is counted');

        final r = await DoseHistoryEdit.apply(await missed(), medicine(stock: null),
            const DoseEdit(DoseCorrection.tookAtSlot));
        expect((await stored())!.isTaken, isTrue);
        expect(await stock(), 0);

        await DoseHistoryEdit.undo(r);
        expect((await stored())!.isMissed, isTrue);
        expect(await stock(), 0,
            reason: 'giving two tablets back to a medicine that never had a count '
                'made it one that had, and low-stock alerts followed');
      });
    });
  });
}
