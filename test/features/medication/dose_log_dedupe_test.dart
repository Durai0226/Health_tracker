import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// `app_database.dart` also exports a Drift-generated `MedicineLog` row class;
// hide it so `MedicineLog` unambiguously means the domain model under test.
import 'package:tablet_remainder/core/database/app_database.dart' hide MedicineLog;
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/today_schedule_service.dart';

/// Regression cover for the reported bug: *"when I skip the medication, the Today
/// page doesn't scroll properly."*
///
/// Root cause was in the data layer, not the layout. Both `markMedicineTaken` and
/// `markMedicineSkipped` built their log id from `DateTime.now()`, and the DAO
/// used a plain `insert`. So every tap **appended** a row. `getDailySummaryAsync`
/// counts rows, and the Today hero computes `taken + skipped + missed` against
/// the scheduled total — so skipping one dose twice made "resolved" exceed
/// "scheduled", the hero flipped into its all-done branch with a
/// greater-than-100% progress value, and the card's height changed underneath a
/// scroll view that was already mid-correction.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final slot = DateTime(2026, 8, 3, 9, 0);
  final otherSlot = DateTime(2026, 8, 3, 21, 0);

  group('doseLogId', () {
    test('is derived from the slot, never from the wall clock', () {
      final a = MedicineCleanStorageService.doseLogId('med-1', slot);
      final b = MedicineCleanStorageService.doseLogId('med-1', slot);
      expect(a, b, reason: 'the same dose must always map to the same row');
    });

    test('separates different slots of the same medicine', () {
      expect(MedicineCleanStorageService.doseLogId('med-1', slot),
          isNot(MedicineCleanStorageService.doseLogId('med-1', otherSlot)));
    });

    test('separates different medicines in the same slot', () {
      expect(MedicineCleanStorageService.doseLogId('med-1', slot),
          isNot(MedicineCleanStorageService.doseLogId('med-2', slot)));
    });

    test('take and skip of one slot share an id, so one replaces the other', () {
      // This is the actual fix: previously skip used a `_skip_` infix plus a
      // timestamp, so a taken row and a skipped row for the SAME dose coexisted
      // and were both counted as resolved.
      final taken = MedicineCleanStorageService.doseLogId('med-1', slot);
      final skipped = MedicineCleanStorageService.doseLogId('med-1', slot);
      expect(taken, skipped);
    });
  });

  group('dedupeByDose — heals rows written before the id fix', () {
    MedicineLog taken(String id, DateTime at) =>
        MedicineLog.taken(id: id, medicineId: 'med-1', scheduledTime: at);
    MedicineLog skipped(String id, DateTime at) => MedicineLog.skipped(
        id: id,
        medicineId: 'med-1',
        scheduledTime: at,
        reason: SkipReason.other);
    MedicineLog missed(String id, DateTime at) =>
        MedicineLog.missed(id: id, medicineId: 'med-1', scheduledTime: at);

    test('two skips of one dose collapse to a single skip', () {
      final out = MedicineCleanStorageService.dedupeByDose([
        skipped('legacy_skip_1', slot),
        skipped('legacy_skip_2', slot),
      ]);
      expect(out, hasLength(1));
      expect(out.single.isSkipped, isTrue);
    });

    test('an explicit take wins over a skip for the same dose', () {
      final out = MedicineCleanStorageService.dedupeByDose([
        skipped('legacy_skip', slot),
        taken('legacy_take', slot),
      ]);
      expect(out, hasLength(1));
      expect(out.single.isTaken, isTrue,
          reason: 'if the user did eventually take it, that is the truth');
    });

    test('auto-generated "missed" never overrides a real user action', () {
      // `missed` rows come from the reconciler, not the user.
      for (final order in <List<MedicineLog>>[
        [missed('m', slot), taken('t', slot)],
        [taken('t', slot), missed('m', slot)],
      ]) {
        final out = MedicineCleanStorageService.dedupeByDose(order);
        expect(out.single.isTaken, isTrue);
      }
      final s = MedicineCleanStorageService.dedupeByDose(
          [missed('m', slot), skipped('s', slot)]);
      expect(s.single.isSkipped, isTrue);
    });

    test('distinct slots are all preserved', () {
      final out = MedicineCleanStorageService.dedupeByDose([
        taken('a', slot),
        skipped('b', otherSlot),
      ]);
      expect(out, hasLength(2));
    });

    test('is order-independent', () {
      final forward = MedicineCleanStorageService.dedupeByDose(
          [skipped('s', slot), taken('t', slot)]);
      final reverse = MedicineCleanStorageService.dedupeByDose(
          [taken('t', slot), skipped('s', slot)]);
      expect(forward.single.isTaken, isTrue);
      expect(reverse.single.isTaken, isTrue);
    });

    test('empty in, empty out', () {
      expect(MedicineCleanStorageService.dedupeByDose(const []), isEmpty);
    });
  });

  group('missed-dose id collision (the OVERDUE-forever bug)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
    });

    tearDown(() async => db.close());

    // reconcileMissedDoses used to write `<medId>_missed_<slot>` while take/skip
    // write `<medId>_<slot>`. Different primary keys → the upsert could not
    // collapse them, so one slot held two rows; the slot join picked the older
    // `missed` one and Home showed a dose you had just taken as OVERDUE, while
    // re-decrementing stock on every further tap.
    test('the reconciler id is now the SAME id take/skip use', () {
      final canonical = MedicineCleanStorageService.doseLogId('med-1', slot);
      const legacy = 'med-1_missed_';
      expect(canonical.contains('_missed_'), isFalse,
          reason: 'a missed row must not get its own id namespace');
      expect(canonical, isNot(startsWith(legacy)));
      // And the source no longer builds the legacy form anywhere.
      final src = File('lib/features/medication/services/'
              'medicine_storage_service.dart')
          .readAsStringSync();
      expect(src.contains("_missed_\${slot"), isFalse,
          reason: 'reconcileMissedDoses must call doseLogId(med.id, slot)');
    });

    test('taking an already-missed dose leaves ONE row, marked taken', () async {
      final dao = db.medicationDao;
      final id = MedicineCleanStorageService.doseLogId('med-1', slot);

      // The reconciler marks the slot missed...
      await dao.addLog(MedicineLogsCompanion.insert(
        id: id,
        medicineId: 'med-1',
        scheduledTime: slot,
        isMissed: const Value(true),
      ));
      // ...then the user actually takes it.
      await dao.addLog(MedicineLogsCompanion.insert(
        id: id,
        medicineId: 'med-1',
        scheduledTime: slot,
        isTaken: const Value(true),
        isMissed: const Value(false),
      ));

      final rows = (await dao.getLogsForDate(slot))
          .where((l) => l.medicineId == 'med-1')
          .toList();
      expect(rows, hasLength(1), reason: 'the upsert must collapse them now');
      expect(rows.single.isTaken, isTrue);
      expect(rows.single.isMissed, isFalse);
    });
  });

  group('mostAuthoritative — read-time healing for pre-fix installs', () {
    MedicineLog mk(String id, {bool taken = false, bool skipped = false, bool missed = false}) {
      if (taken) return MedicineLog.taken(id: id, medicineId: 'm', scheduledTime: slot);
      if (skipped) {
        return MedicineLog.skipped(
            id: id, medicineId: 'm', scheduledTime: slot, reason: SkipReason.other);
      }
      if (missed) return MedicineLog.missed(id: id, medicineId: 'm', scheduledTime: slot);
      return MedicineLog(
          id: id,
          medicineId: 'm',
          scheduledTime: slot,
          status: MedicineStatus.pending);
    }

    test('an explicit taken beats an auto-generated missed, either order', () {
      for (final order in <List<MedicineLog>>[
        [mk('a', missed: true), mk('b', taken: true)],
        [mk('b', taken: true), mk('a', missed: true)],
      ]) {
        expect(TodayScheduleService.mostAuthoritative(order)!.isTaken, isTrue);
      }
    });

    test('an explicit skipped also beats missed', () {
      final r = TodayScheduleService.mostAuthoritative(
          [mk('a', missed: true), mk('b', skipped: true)]);
      expect(r!.isSkipped, isTrue);
    });

    test('taken beats skipped', () {
      final r = TodayScheduleService.mostAuthoritative(
          [mk('a', skipped: true), mk('b', taken: true)]);
      expect(r!.isTaken, isTrue);
    });

    test('a lone missed row is still reported (real history)', () {
      expect(TodayScheduleService.mostAuthoritative([mk('a', missed: true)])!.isMissed,
          isTrue);
    });

    test('empty and single-element inputs behave', () {
      expect(TodayScheduleService.mostAuthoritative([]), isNull);
      expect(TodayScheduleService.mostAuthoritative([mk('a', taken: true)])!.isTaken,
          isTrue);
    });
  });

  group('addLog upsert (DAO)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
    });

    tearDown(() async => db.close());

    test('writing the same dose twice leaves ONE row, not two', () async {
      final dao = db.medicationDao;
      final id = MedicineCleanStorageService.doseLogId('med-1', slot);

      for (var i = 0; i < 3; i++) {
        await dao.addLog(MedicineLogsCompanion.insert(
          id: id,
          medicineId: 'med-1',
          scheduledTime: slot,
          isSkipped: const Value(true),
        ));
      }

      final logs = await dao.getLogsForDate(slot);
      expect(logs.where((l) => l.id == id), hasLength(1),
          reason: 'a plain insert appended; the upsert must replace');
    });

    test('a later take overwrites an earlier skip for the same dose', () async {
      final dao = db.medicationDao;
      final id = MedicineCleanStorageService.doseLogId('med-1', slot);

      await dao.addLog(MedicineLogsCompanion.insert(
        id: id,
        medicineId: 'med-1',
        scheduledTime: slot,
        isSkipped: const Value(true),
      ));
      await dao.addLog(MedicineLogsCompanion.insert(
        id: id,
        medicineId: 'med-1',
        scheduledTime: slot,
        isTaken: const Value(true),
        isSkipped: const Value(false),
      ));

      final logs = await dao.getLogsForDate(slot);
      final row = logs.singleWhere((l) => l.id == id);
      expect(row.isTaken, isTrue);
      expect(row.isSkipped, isFalse);
    });
  });
}
