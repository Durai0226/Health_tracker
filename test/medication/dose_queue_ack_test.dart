/// A "Take" tapped on a notification is not lost on the way to the database.
///
/// The tap is queued by a background isolate that cannot reach Drift, and applied
/// by the main isolate on the next resume. The queue used to be cleared the moment
/// it was read, so anything that went wrong between that and the write — a locked
/// database, the process being killed half way down the list — lost the dose with
/// no log, no queue entry and no message. It is the record the adherence streak,
/// the stock count and a doctor's report are made of, and the one the person is
/// least able to notice missing: they never opened the app to see it.
///
/// Now it is read, applied one at a time, and each is forgotten only once it has
/// landed. A write that cannot be made is simulated with a trigger, so what is
/// exercised is the real path and not a stub.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/dose_action_queue.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Counts the writes to the dose queue.
class _CountingStore extends InMemorySharedPreferencesStore {
  _CountingStore.withData(super.data) : super.withData();

  int queueWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key.endsWith('pending_dose_actions')) queueWrites++;
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    if (key.endsWith('pending_dose_actions')) queueWrites++;
    return super.remove(key);
  }
}

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
  final slot = DateTime(now.year, now.month, now.day, 8);

  EnhancedMedicine med(String id) => EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        currentStock: 20,
        lowStockThreshold: 5,
        createdAt: now.subtract(const Duration(days: 30)),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
          startDate: now.subtract(const Duration(days: 10)),
        ),
      );

  Future<void> take(String id, {String action = DoseActionQueue.actionTake}) =>
      DoseActionQueue.enqueue(medicineId: id, scheduledTime: slot, action: action);

  /// Writes to the dose log of [id] fail, as a locked database would.
  Future<void> breakLogsFor(String id) => db.customStatement(
      "CREATE TRIGGER broken_$id BEFORE INSERT ON medicine_logs "
      "WHEN NEW.medicine_id = '$id' BEGIN SELECT RAISE(ABORT, 'database is locked'); END");

  Future<void> repairLogsFor(String id) =>
      db.customStatement('DROP TRIGGER broken_$id');

  /// Writes to the stock of [id] fail — the other half of one dose.
  Future<void> breakStockFor(String id) => db.customStatement(
      "CREATE TRIGGER broken_stock_$id BEFORE UPDATE ON enhanced_medicines "
      "WHEN NEW.id = '$id' BEGIN SELECT RAISE(ABORT, 'database is locked'); END");

  Future<void> repairStockFor(String id) =>
      db.customStatement('DROP TRIGGER broken_stock_$id');

  Future<int?> stockOf(String id) async =>
      (await MedicineCleanStorageService.getMedicine(id))?.currentStock;

  Future<List<String>> queued() async =>
      (await DoseActionQueue.drain()).map((a) => a.medicineId).toList();

  group('a dose that is applied', () {
    test('is logged, the stock goes down, and it is forgotten', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1));
      expect((await MedicineCleanStorageService.getLog(created.single))!.isTaken, isTrue);
      expect(await stockOf('m1'), 19);
      expect(await queued(), isEmpty);
    });

    test('and a skip is logged and forgotten too, leaving the stock alone', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1', action: DoseActionQueue.actionSkip);

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1));
      expect(await stockOf('m1'), 20);
      expect(await queued(), isEmpty);
    });
  });

  group('a tap that an earlier pass already applied', () {
    // The app was killed after the write and before the tap was forgotten. Applying it
    // again nets out; REPORTING it offered "Logged 1 dose · Undo" a second time — and
    // the Undo on that one takes the dose back.
    test('is forgotten, not reported again', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');
      final first = await MedicineCleanStorageService.drainPendingDoseActions();
      expect(first, hasLength(1), reason: 'the premise: it was reported once');
      expect(await stockOf('m1'), 19);

      // The same tap, queued as it was (the ack never happened).
      final tap = (await DoseActionQueue.drain());
      expect(tap, isEmpty, reason: 'the premise: the first pass forgot it');
      await DoseActionQueue.enqueue(
          medicineId: 'm1',
          scheduledTime: slot,
          action: DoseActionQueue.actionTake,
          tappedAt: (await MedicineCleanStorageService.getLog(
                  MedicineCleanStorageService.doseLogId('m1', slot)))!
              .actionTime);

      final again = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(again, isEmpty, reason: 'nothing new to tell them');
      expect(await stockOf('m1'), 19);
      expect(await queued(), isEmpty, reason: 'and it is forgotten');
    });

    test('a later tap on the same slot is a correction and is applied and reported', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');
      await MedicineCleanStorageService.drainPendingDoseActions();

      await DoseActionQueue.enqueue(
          medicineId: 'm1',
          scheduledTime: slot,
          action: DoseActionQueue.actionSkip,
          tappedAt: DateTime.now().add(const Duration(minutes: 5)));
      final later = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(later, hasLength(1));
      expect(await stockOf('m1'), 20);
    });

    test('is told by the second, which is all the log keeps of when it was tapped', () {
      final tapped = DateTime(2026, 3, 14, 9, 30, 15, 750);
      MedicineLog log(DateTime at) => MedicineLog.taken(
          id: 'x', medicineId: 'm1', scheduledTime: slot, actionTime: at);
      PendingDoseAction action(String kind) => PendingDoseAction(
          medicineId: 'm1', scheduledTime: slot, action: kind, tappedAt: tapped);

      final storedAsSeconds = DateTime(2026, 3, 14, 9, 30, 15);
      expect(MedicineCleanStorageService.appliedBy(log(storedAsSeconds), action('take')), isTrue);
      expect(MedicineCleanStorageService.appliedBy(log(tapped), action('take')), isTrue);
      expect(
          MedicineCleanStorageService.appliedBy(
              log(storedAsSeconds.add(const Duration(seconds: 1))), action('take')),
          isFalse,
          reason: 'a different second is a different tap');
      expect(MedicineCleanStorageService.appliedBy(null, action('take')), isFalse);
      expect(
          MedicineCleanStorageService.appliedBy(
              log(storedAsSeconds),
              PendingDoseAction(medicineId: 'm1', scheduledTime: slot, action: 'take')),
          isFalse,
          reason: 'a tap with no time cannot be told');
    });

    test('a take is not "applied" by a log that is a skip, nor a skip by a take', () {
      final tapped = DateTime(2026, 3, 14, 9, 30, 15);
      final skipped = MedicineLog.skipped(
          id: 'x',
          medicineId: 'm1',
          scheduledTime: slot,
          reason: SkipReason.other,
          actionTime: tapped);
      final taken = MedicineLog.taken(
          id: 'x', medicineId: 'm1', scheduledTime: slot, actionTime: tapped);
      PendingDoseAction action(String kind) => PendingDoseAction(
          medicineId: 'm1', scheduledTime: slot, action: kind, tappedAt: tapped);

      expect(MedicineCleanStorageService.appliedBy(skipped, action('take')), isFalse);
      expect(MedicineCleanStorageService.appliedBy(taken, action('skip')), isFalse);
      expect(MedicineCleanStorageService.appliedBy(skipped, action('skip')), isTrue);
      expect(MedicineCleanStorageService.appliedBy(taken, action('take')), isTrue);
    });
  });

  group('forgetting what was applied', () {
    // Forgetting is a read and a rewrite of the one stored list, which the alarm
    // isolate also appends to: a tap that lands between the two is lost. One window
    // for a whole pass, not one per action.
    test('is one write for the whole pass, however many doses it applied', () async {
      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        await MedicineCleanStorageService.addMedicine(med(id));
      }
      final store = _CountingStore.withData({});
      SharedPreferencesStorePlatform.instance = store;
      SharedPreferences.resetStatic();
      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        await take(id);
      }
      store.queueWrites = 0;

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(4));
      expect(store.queueWrites, 1, reason: 'one ack, not four');
      expect(await queued(), isEmpty);
    });

    test('and a failure part way still forgets what had been applied', () async {
      for (final id in ['m1', 'm2', 'm3']) {
        await MedicineCleanStorageService.addMedicine(med(id));
        await take(id);
      }
      await breakLogsFor('m2');

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(2));
      expect(await queued(), ['m2'], reason: 'only the one that could not be written is left');
    });

    test('and what is applied twice because the app was killed first changes nothing', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');
      await MedicineCleanStorageService.drainPendingDoseActions();
      expect(await stockOf('m1'), 19);

      // The pass ended without forgetting it: the same tap, queued as it was.
      await take('m1');
      await MedicineCleanStorageService.drainPendingDoseActions();

      expect(await stockOf('m1'), 19);
      final logs = await MedicineCleanStorageService.getAllLogs(scopeToActiveProfile: false);
      expect(logs.where((l) => l.medicineId == 'm1'), hasLength(1));
    });
  });

  group('a dose that is applied', () {
    test('tells the screens that follow the store, and its stock', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      final before = MedicineCleanStorageService.revision.value;

      await MedicineCleanStorageService.markMedicineTaken(
          medicineId: 'm1', scheduledTime: slot);

      expect(MedicineCleanStorageService.revision.value, greaterThan(before),
          reason: 'the log and the stock changed: whatever shows them must reload');
      expect(await stockOf('m1'), 19);
    });

    test('and one that could not be written tells them nothing changed', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await breakStockFor('m1');
      final before = MedicineCleanStorageService.revision.value;

      await expectLater(
          MedicineCleanStorageService.markMedicineTaken(medicineId: 'm1', scheduledTime: slot),
          throwsA(anything));

      expect(MedicineCleanStorageService.revision.value, before,
          reason: 'nothing was kept, so there is nothing to reload');
    });
  });

  group('a dose whose stock cannot be written', () {
    // The log and the stock of a take are one change. Written as two, a failure
    // between them left the dose logged and the stock untouched, and the retry —
    // which reasons "the slot is already logged, so the stock has already moved" —
    // gave back and took the dose in one step: net nothing, the dose never counted.
    test('is not half-applied: no log is left, so the retry counts it once', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');
      await breakStockFor('m1');

      final first = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(first, isEmpty);
      expect(
          await MedicineCleanStorageService.getLog(
              MedicineCleanStorageService.doseLogId('m1', slot)),
          isNull,
          reason: 'the log went with the stock: one change');
      expect(await stockOf('m1'), 20);
      expect(await queued(), ['m1']);

      await repairStockFor('m1');
      final second = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(second, hasLength(1));
      expect(await stockOf('m1'), 19, reason: 'taken off once — not zero times');
      expect(await queued(), isEmpty);
    });

    test('and one that failed after the write, with the tap not yet forgotten, is not counted twice',
        () async {
      // The other half: the log and the stock both landed, and then something
      // (the acknowledgement, the refill alert) failed, so the tap is applied again.
      await MedicineCleanStorageService.addMedicine(med('m1'));
      // ONE tap, queued twice: it is the same tap applied again, so it has the one
      // tap time. `take()` stamps each call with its own, and the log's time is kept
      // to the second — two taps a moment apart can straddle a second, and the
      // second then reads as a different tap and is reported as a new dose. That is
      // what made this test fail now and then under a loaded full run.
      final tapped = DateTime.now();
      Future<void> tap() => DoseActionQueue.enqueue(
          medicineId: 'm1',
          scheduledTime: slot,
          action: DoseActionQueue.actionTake,
          tappedAt: tapped);
      await tap();
      await MedicineCleanStorageService.drainPendingDoseActions();
      expect(await stockOf('m1'), 19);

      await tap();
      final again = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(again, isEmpty, reason: 'already in, so not reported to them a second time');
      expect(await stockOf('m1'), 19, reason: 'the same dose, still counted once');
    });

    test('a skip of a dose already taken: giving the units back and the skip are one change',
        () async {
      // The retry reasons from the slot's log. Written as two, a failure between
      // returning the units and writing the skip left the slot still "taken", and the
      // retry returned them again: the stock two doses too high.
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await MedicineCleanStorageService.markMedicineTaken(
          medicineId: 'm1', scheduledTime: slot);
      expect(await stockOf('m1'), 19, reason: 'the premise: it was taken');
      await take('m1', action: DoseActionQueue.actionSkip);
      await breakLogsFor('m1');

      final first = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(first, isEmpty);
      expect(await stockOf('m1'), 19, reason: 'nothing half-applied: not returned yet');
      expect(await queued(), ['m1']);

      await repairLogsFor('m1');
      final second = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(second, hasLength(1));
      expect(await stockOf('m1'), 20, reason: 'returned once — not twice');
      expect((await MedicineCleanStorageService.getLog(
              MedicineCleanStorageService.doseLogId('m1', slot)))!
          .isSkipped, isTrue);
    });

    test('a skip whose stock cannot be given back leaves the slot as it was', () async {
      // The other half: the skip is written and the units cannot be returned. Left
      // as a skip, the retry finds a slot that no longer counts as taken and returns
      // nothing — the stock short by a dose for good.
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await MedicineCleanStorageService.markMedicineTaken(
          medicineId: 'm1', scheduledTime: slot);
      await take('m1', action: DoseActionQueue.actionSkip);
      await breakStockFor('m1');

      final first = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(first, isEmpty);
      final id = MedicineCleanStorageService.doseLogId('m1', slot);
      expect((await MedicineCleanStorageService.getLog(id))!.isTaken, isTrue,
          reason: 'the skip went with the stock: one change');
      expect(await stockOf('m1'), 19);

      await repairStockFor('m1');
      await MedicineCleanStorageService.drainPendingDoseActions();

      expect((await MedicineCleanStorageService.getLog(id))!.isSkipped, isTrue);
      expect(await stockOf('m1'), 20, reason: 'given back once');
    });

    test('a medicine whose stock is not tracked has nothing to fail, and is logged', () async {
      await MedicineCleanStorageService.addMedicine(
          med('m1').copyWith(currentStock: null, lowStockThreshold: null));
      await take('m1');

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1));
      expect(await queued(), isEmpty);
    });
  });

  group('a dose that cannot be written', () {
    test('stays queued, and is applied on the next resume', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');
      await breakLogsFor('m1');

      final first = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(first, isEmpty);
      expect(await queued(), ['m1'], reason: 'the tap is not thrown away');
      expect(await stockOf('m1'), 20, reason: 'and nothing was half-applied');

      await repairLogsFor('m1');
      final second = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(second, hasLength(1));
      expect(await stockOf('m1'), 19);
      expect(await queued(), isEmpty);
    });

    test('does not hold back the ones behind it', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await MedicineCleanStorageService.addMedicine(med('m2'));
      await take('m1');
      await take('m2');
      await breakLogsFor('m1');

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1), reason: 'm2 went through');
      expect(await stockOf('m2'), 19);
      expect(await queued(), ['m1'], reason: 'only the one that failed is left');
    });

    test('a skip that cannot be written is kept just the same', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1', action: DoseActionQueue.actionSkip);
      await breakLogsFor('m1');

      await MedicineCleanStorageService.drainPendingDoseActions();

      expect(await queued(), ['m1']);
    });

    test('being retried later does not take the stock down twice', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');
      await breakLogsFor('m1');
      await MedicineCleanStorageService.drainPendingDoseActions();
      await MedicineCleanStorageService.drainPendingDoseActions();
      await repairLogsFor('m1');

      await MedicineCleanStorageService.drainPendingDoseActions();
      await MedicineCleanStorageService.drainPendingDoseActions();

      expect(await stockOf('m1'), 19, reason: 'one dose taken, however often it was tried');
    });
  });

  group('a dose that keeps failing', () {
    test('is kept for a week, in case it was only a locked database', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      final old = DateTime.now().subtract(const Duration(days: 6, hours: 23));
      await DoseActionQueue.enqueue(
          medicineId: 'm1', scheduledTime: old, action: DoseActionQueue.actionTake);
      await breakLogsFor('m1');

      await MedicineCleanStorageService.drainPendingDoseActions();

      expect(await queued(), ['m1']);
    });

    test('and then given up on, so it is not retried at every launch for ever', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      final old = DateTime.now().subtract(const Duration(days: 7, hours: 1));
      await DoseActionQueue.enqueue(
          medicineId: 'm1', scheduledTime: old, action: DoseActionQueue.actionTake);
      await breakLogsFor('m1');

      await MedicineCleanStorageService.drainPendingDoseActions();

      expect(await queued(), isEmpty);
    });

    test('but an old one that APPLIES is applied, whatever its age', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      final old = DateTime.now().subtract(const Duration(days: 20));
      await DoseActionQueue.enqueue(
          medicineId: 'm1', scheduledTime: old, action: DoseActionQueue.actionTake);

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1));
      expect(await stockOf('m1'), 19);
    });

    test('and a recent failure beside an old one is kept while the old one goes', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await MedicineCleanStorageService.addMedicine(med('m2'));
      await DoseActionQueue.enqueue(
          medicineId: 'm1',
          scheduledTime: DateTime.now().subtract(const Duration(days: 10)),
          action: DoseActionQueue.actionTake);
      await DoseActionQueue.enqueue(
          medicineId: 'm2', scheduledTime: slot, action: DoseActionQueue.actionTake);
      await breakLogsFor('m1');
      await breakLogsFor('m2');

      await MedicineCleanStorageService.drainPendingDoseActions();

      expect(await queued(), ['m2']);
    });
  });

  group('a medicine that cannot be read', () {
    test('keeps its dose queued, and does not stop the others', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await MedicineCleanStorageService.addMedicine(med('m2'));
      await take('m1');
      await take('m2');
      await db.customStatement(
          "UPDATE enhanced_medicines SET schedule_json = 'not json' WHERE id = 'm1'");

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1), reason: 'm2 went through');
      expect(await queued(), ['m1'], reason: 'm1 is not mistaken for a deleted medicine');
    });
  });

  group('a dose for a medicine that is gone', () {
    test('is dropped rather than retried for ever', () async {
      await take('ghost');

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, isEmpty);
      expect(await queued(), isEmpty);
    });

    test('and does not stop the real one beside it', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('ghost');
      await take('m1');

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1));
      expect(await queued(), isEmpty);
    });
  });

  group('a tap the person has since overtaken', () {
    // The tap can only be retried because it failed to apply. In the meantime the
    // person may have settled the same slot in the app — and replaying the tap
    // over that would overwrite their later decision.
    final tapped = DateTime.now().subtract(const Duration(minutes: 30));
    final later = DateTime.now().subtract(const Duration(minutes: 10));
    final earlier = DateTime.now().subtract(const Duration(minutes: 50));

    Future<MedicineLog?> logOf(String id) =>
        MedicineCleanStorageService.getLog(MedicineCleanStorageService.doseLogId(id, slot));

    Future<void> tap(String id, String action, DateTime at) => DoseActionQueue.enqueue(
        medicineId: id, scheduledTime: slot, action: action, tappedAt: at);

    test('a Skip that failed does not overwrite a dose taken in the app afterwards',
        () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await tap('m1', DoseActionQueue.actionSkip, tapped);
      await breakLogsFor('m1');
      await MedicineCleanStorageService.drainPendingDoseActions();
      await repairLogsFor('m1');
      await MedicineCleanStorageService.markMedicineTaken(
          medicineId: 'm1', scheduledTime: slot, takenAt: later);
      expect(await stockOf('m1'), 19, reason: 'the premise: taken in the app');

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, isEmpty);
      expect((await logOf('m1'))!.isTaken, isTrue, reason: 'their later decision stands');
      expect(await stockOf('m1'), 19, reason: 'and the stock the take removed stays removed');
      expect(await queued(), isEmpty, reason: 'the tap is let go, not retried for ever');
    });

    test('nor does a Take overwrite a dose skipped in the app afterwards', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await tap('m1', DoseActionQueue.actionTake, tapped);
      await breakLogsFor('m1');
      await MedicineCleanStorageService.drainPendingDoseActions();
      await repairLogsFor('m1');
      await MedicineCleanStorageService.addLog(MedicineLog.skipped(
        id: MedicineCleanStorageService.doseLogId('m1', slot),
        medicineId: 'm1',
        scheduledTime: slot,
        reason: SkipReason.other,
        actionTime: later,
      ));

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, isEmpty);
      expect((await logOf('m1'))!.isSkipped, isTrue);
      expect(await stockOf('m1'), 20, reason: 'a Take replayed over it would have used one');
      expect(await queued(), isEmpty);
    });

    test('but a tap made AFTER the earlier decision is a correction, and applies',
        () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await MedicineCleanStorageService.markMedicineTaken(
          medicineId: 'm1', scheduledTime: slot, takenAt: earlier);
      expect(await stockOf('m1'), 19);
      await tap('m1', DoseActionQueue.actionSkip, tapped);

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1));
      expect((await logOf('m1'))!.isSkipped, isTrue);
      expect(await stockOf('m1'), 20, reason: 'the dose it undid is given back');
    });

    test('two taps on one slot in the same drain: the later one wins', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await tap('m1', DoseActionQueue.actionTake, earlier);
      await tap('m1', DoseActionQueue.actionSkip, tapped);

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(2), reason: 'both are applied, in the order they were tapped');
      expect((await logOf('m1'))!.isSkipped, isTrue);
      expect(await stockOf('m1'), 20);
      expect(await queued(), isEmpty);
    });

    test('and when the later one is the Take, that is what is left', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await tap('m1', DoseActionQueue.actionSkip, earlier);
      await tap('m1', DoseActionQueue.actionTake, tapped);

      await MedicineCleanStorageService.drainPendingDoseActions();

      expect((await logOf('m1'))!.isTaken, isTrue);
      expect(await stockOf('m1'), 19);
    });

    test('a slot that was only marked missed is not a decision — the tap applies over it',
        () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await MedicineCleanStorageService.addLog(MedicineLog(
        id: MedicineCleanStorageService.doseLogId('m1', slot),
        medicineId: 'm1',
        scheduledTime: slot,
        actionTime: later,
        status: MedicineStatus.missed,
      ));
      await tap('m1', DoseActionQueue.actionTake, tapped);

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1));
      expect((await logOf('m1'))!.isTaken, isTrue);
    });

    test('an action queued by an older build has no tap time, and is applied as it was',
        () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      SharedPreferences.setMockInitialValues({
        'pending_dose_actions': [
          '{"medicineId":"m1","scheduledTime":"${slot.toIso8601String()}","action":"take"}',
        ],
      });
      // The in-app log is later than anything the tap could be compared with.
      await MedicineCleanStorageService.markMedicineSkipped(
          medicineId: 'm1', scheduledTime: slot, reason: SkipReason.other, skippedAt: later);

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1));
      expect((await logOf('m1'))!.isTaken, isTrue);
    });
  });

  group('the moment of the tap', () {
    test('is written with the action, now by default', () async {
      final before = DateTime.now();
      await take('m1');
      final after = DateTime.now();

      final t = (await DoseActionQueue.drain()).single.tappedAt!;

      expect(t.isBefore(before), isFalse);
      expect(t.isAfter(after), isFalse);
    });

    test('and is the time given when there is one', () async {
      final at = DateTime(2026, 3, 1, 8, 5, 7);
      await DoseActionQueue.enqueue(
          medicineId: 'm1', scheduledTime: slot, action: DoseActionQueue.actionTake, tappedAt: at);

      expect((await DoseActionQueue.drain()).single.tappedAt, at);
    });

    test('becomes the time on the log, not the time the app got round to it', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await MedicineCleanStorageService.addMedicine(med('m2'));
      // Whole seconds: that is the precision the database keeps a time to.
      final at = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000 - 3 * 3600 * 1000);
      await DoseActionQueue.enqueue(
          medicineId: 'm1', scheduledTime: slot, action: DoseActionQueue.actionTake, tappedAt: at);
      await DoseActionQueue.enqueue(
          medicineId: 'm2', scheduledTime: slot, action: DoseActionQueue.actionSkip, tappedAt: at);

      await MedicineCleanStorageService.drainPendingDoseActions();

      for (final id in ['m1', 'm2']) {
        final log = await MedicineCleanStorageService.getLog(
            MedicineCleanStorageService.doseLogId(id, slot));
        expect(log!.actionTime, at, reason: id);
      }
    });
  });

  group('whether a slot was settled since a tap', () {
    final tap = DateTime(2026, 3, 1, 8, 5);
    MedicineLog log(MedicineStatus status, DateTime? actionTime) => MedicineLog(
          id: 'x',
          medicineId: 'm',
          scheduledTime: DateTime(2026, 3, 1, 8),
          actionTime: actionTime,
          status: status,
        );
    final after = tap.add(const Duration(minutes: 1));
    final before = tap.subtract(const Duration(minutes: 1));

    test('taken, skipped or pre-logged after the tap: yes', () {
      for (final status in [
        MedicineStatus.taken,
        MedicineStatus.skipped,
        MedicineStatus.preLogged,
      ]) {
        expect(MedicineCleanStorageService.settledSince(log(status, after), tap), isTrue,
            reason: '$status');
      }
    });

    test('before it, or at the same instant: no', () {
      expect(MedicineCleanStorageService.settledSince(log(MedicineStatus.taken, before), tap),
          isFalse);
      expect(MedicineCleanStorageService.settledSince(log(MedicineStatus.skipped, tap), tap),
          isFalse);
    });

    test('missed or pending, however late: no — neither is a decision', () {
      expect(MedicineCleanStorageService.settledSince(log(MedicineStatus.missed, after), tap),
          isFalse);
      expect(MedicineCleanStorageService.settledSince(log(MedicineStatus.pending, after), tap),
          isFalse);
    });

    test('nothing logged, no tap time, or no time on the log: no', () {
      expect(MedicineCleanStorageService.settledSince(null, tap), isFalse);
      expect(MedicineCleanStorageService.settledSince(log(MedicineStatus.taken, after), null),
          isFalse);
      expect(MedicineCleanStorageService.settledSince(log(MedicineStatus.taken, null), tap),
          isFalse);
    });
  });

  group('a tap that arrives while a drain is under way', () {
    // "Take all" on a grouped notification queues one entry per medicine, and each
    // one nudges the app to drain. The first nudge starts a drain and the rest used
    // to be dropped; the drain under way had already read the queue, so the other
    // doses sat in it, with no log and no Undo, until the next resume.
    tearDown(() => MedicineCleanStorageService.doseDrainPassForTesting = null);

    test('is applied by a pass behind it, and reported with the first', () async {
      final gates = <Completer<void>>[];
      var passes = 0;
      MedicineCleanStorageService.doseDrainPassForTesting = () async {
        passes++;
        final n = passes;
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return ['pass$n'];
      };

      final first = MedicineCleanStorageService.drainPendingDoseActions();
      final second = MedicineCleanStorageService.drainPendingDoseActions();
      var secondDone = false;
      unawaited(second.then((_) => secondDone = true));
      await Future<void>.delayed(Duration.zero);
      expect(passes, 1);

      gates[0].complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(passes, 2, reason: 'it goes round again for what arrived meanwhile');
      expect(secondDone, isFalse, reason: 'and the one who asked waits for that, too');

      gates[1].complete();
      expect(await first, ['pass1', 'pass2'], reason: 'one report, for all of it');
      expect(await second, isEmpty, reason: 'the second has nothing of its own to say');
    });

    test('however many arrive, it is one more pass', () async {
      final gates = <Completer<void>>[];
      MedicineCleanStorageService.doseDrainPassForTesting = () async {
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return const <String>[];
      };

      final first = MedicineCleanStorageService.drainPendingDoseActions();
      for (var i = 0; i < 6; i++) {
        unawaited(MedicineCleanStorageService.drainPendingDoseActions());
      }
      gates[0].complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(gates, hasLength(2));
      gates[1].complete();
      await first;

      expect(gates, hasLength(2));
    });

    test('one that arrives during that second pass earns a third', () async {
      final gates = <Completer<void>>[];
      MedicineCleanStorageService.doseDrainPassForTesting = () async {
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return const <String>[];
      };

      final first = MedicineCleanStorageService.drainPendingDoseActions();
      unawaited(MedicineCleanStorageService.drainPendingDoseActions());
      gates[0].complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      unawaited(MedicineCleanStorageService.drainPendingDoseActions());
      gates[1].complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(gates, hasLength(3));
      gates[2].complete();
      await first;
    });

    for (var hops = 0; hops < 8; hops++) {
      test('one that arrives $hops microtasks after the last pass finished is not lost',
          () async {
        // The drain under way answers "is there more?" once its last pass is over, and
        // is then no longer running. A request that falls between those two moments is
        // told a drain is in progress and leaves its note for a pass that is not
        // coming — so wherever it falls, a pass must still happen for it.
        var passes = 0;
        final gate = Completer<void>();
        MedicineCleanStorageService.doseDrainPassForTesting = () async {
          passes++;
          if (passes == 1) await gate.future;
          return const <String>[];
        };

        final first = MedicineCleanStorageService.drainPendingDoseActions();
        await Future<void>.delayed(Duration.zero);
        gate.complete();
        for (var i = 0; i < hops; i++) {
          await Future<void>.value();
        }
        final late = MedicineCleanStorageService.drainPendingDoseActions();
        await Future.wait([first, late]);

        expect(passes, 2, reason: 'the late request was applied by a pass of its own');
      });
    }

    test('and with the real queue, everything is applied and the queue is empty', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await MedicineCleanStorageService.addMedicine(med('m2'));
      await MedicineCleanStorageService.addMedicine(med('m3'));
      await take('m1');

      final first = MedicineCleanStorageService.drainPendingDoseActions();
      await take('m2');
      final second = MedicineCleanStorageService.drainPendingDoseActions();
      await take('m3');
      final third = MedicineCleanStorageService.drainPendingDoseActions();
      final results = await Future.wait([first, second, third]);

      expect(results.expand((r) => r), hasLength(3),
          reason: 'every tap was applied, and reported once');
      expect(await queued(), isEmpty);
      for (final id in ['m1', 'm2', 'm3']) {
        expect(await stockOf(id), 19, reason: id);
      }
    });

    test('the guard is released afterwards', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');
      await MedicineCleanStorageService.drainPendingDoseActions();
      await take('m1', action: DoseActionQueue.actionSkip);

      final again = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(again, hasLength(1));
    });
  });

  group('two drains at once', () {
    test('apply a tap once: the second finds one already running', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');

      final results = await Future.wait([
        MedicineCleanStorageService.drainPendingDoseActions(),
        MedicineCleanStorageService.drainPendingDoseActions(),
      ]);

      expect(results.expand((r) => r), hasLength(1),
          reason: 'one "Logged 1 dose" to undo, not two');
      expect(await stockOf('m1'), 19);
      expect(await queued(), isEmpty);
    });

    test('and the guard is released afterwards, even after a failure', () async {
      await MedicineCleanStorageService.addMedicine(med('m1'));
      await take('m1');
      await breakLogsFor('m1');
      await MedicineCleanStorageService.drainPendingDoseActions();
      await repairLogsFor('m1');

      final created = await MedicineCleanStorageService.drainPendingDoseActions();

      expect(created, hasLength(1), reason: 'not stuck "already draining"');
    });
  });
}
