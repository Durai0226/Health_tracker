import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/cloud_sync_service.dart';
import 'package:tablet_remainder/core/services/health_cloud_sync_service.dart';

/// Two phones, one account, one Firestore.
///
/// `test/core/lww_collection_sync_test.dart` proves the merge RULE against a
/// synthetic collection, and `medicine_cloud_sync_test.dart` proves the medicine
/// JSON survives a round trip. Neither runs the thing a user actually does:
/// edit on one device, edit on the other, sync both, and see whether the two
/// agree afterwards. The wiring between the rule and each table — which read
/// supplies `local`, which field supplies `updatedMs`, whether `apply` writes a
/// companion or a data class — is per collection, and every one of those is a
/// place the rule can be correct and the table still diverge.
///
/// So these drive the PUBLIC entry point, `CloudSyncService.syncUserData`,
/// against two real Drift databases and one fake Firestore, swapping which
/// database is "this device" between passes. Nothing here re-declares the
/// `local`/`id`/`updatedMs`/`toJson`/`apply` closures: a test that rebuilt them
/// would be measuring its own copy of the wiring rather than the app's.
///
/// The deletion cases are the ones that matter. A tombstone that does not
/// propagate is not a lost deletion — it is a RESURRECTION: the device that
/// still holds the live row re-uploads it, and the medicine the user deleted
/// comes back with its alarms.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase deviceA;
  late AppDatabase deviceB;
  late FakeFirebaseFirestore fs;

  // A fixed instant, so `updatedAt` ordering is stated by the test rather than
  // by how fast it happens to run.
  final t0 = DateTime(2026, 3, 10, 9);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    deviceA = AppDatabase.forTesting(NativeDatabase.memory());
    deviceB = AppDatabase.forTesting(NativeDatabase.memory());
    fs = FakeFirebaseFirestore();
    CloudSyncService().firestoreForTesting = fs;
    // The health syncer resolves its own Firestore. Left alone it reaches
    // `FirebaseFirestore.instance`, which throws `[core/no-app]` inside
    // `syncAll` — swallowed there, but it would fill every run with a failure
    // that has nothing to do with what is being measured.
    HealthCloudSyncService.instance.firestoreForTesting = fs;
  });

  tearDown(() async {
    CloudSyncService().firestoreForTesting = null;
    HealthCloudSyncService.instance.firestoreForTesting = null;
    await deviceA.close();
    await deviceB.close();
  });

  /// One sync pass "on" [device] — the whole public entry point, medicines and
  /// focus sessions included.
  Future<void> syncOn(AppDatabase device) async {
    AppDatabase.setInstanceForTesting(device);
    await CloudSyncService().syncUserData('u1');
  }

  /// A full round of gossip: A, then B, then A again.
  ///
  /// Three passes, not two, because one pass per device can only carry a change
  /// in one direction. A uploads, B merges and uploads its side, and the second
  /// A is where A learns what B had — a change that ORIGINATES on B (a session
  /// only B has logged, a deletion only B has made) cannot reach A until A
  /// syncs again, so a two-pass round could only ever test one direction.
  Future<void> gossip() async {
    await syncOn(deviceA);
    await syncOn(deviceB);
    await syncOn(deviceA);
  }

  // ------------------------------------------------------------------ medicines

  EnhancedMedicinesCompanion medicine(
    String id, {
    required DateTime updatedAt,
    double strength = 500,
    bool archived = false,
    String? notes,
  }) =>
      EnhancedMedicinesCompanion.insert(
        id: id,
        name: 'Metformin',
        dosageForm: 0,
        startDate: t0,
        createdAt: t0,
        updatedAt: updatedAt,
        scheduleJson: '{}',
        strength: Value(strength),
        isArchived: Value(archived),
        notes: Value(notes),
      );

  Future<void> putMedicine(AppDatabase db, EnhancedMedicinesCompanion m) =>
      db.into(db.enhancedMedicines).insertOnConflictUpdate(m);

  Future<EnhancedMedicine?> readMedicine(AppDatabase db, String id) async =>
      (await db.medicationDao.getAllMedicinesIncludingDeleted())
          .where((r) => r.id == id)
          .firstOrNull;

  group('medicines', () {
    test(
        'positive: A edits the dose while B archives — both land on the newer '
        'edit, field for field', () async {
      // Both devices already agree, as they would after any earlier sync.
      await putMedicine(deviceA,
          medicine('m1', updatedAt: t0, notes: 'Take with breakfast'));
      await putMedicine(deviceB,
          medicine('m1', updatedAt: t0, notes: 'Take with breakfast'));
      await gossip();

      // Now they diverge, offline. A's edit is the LATER one.
      await putMedicine(
          deviceA,
          medicine('m1',
              updatedAt: at(20), strength: 1000, notes: null));
      // B keeps the note. If B cleared it too, the null assertion below would
      // be satisfied by B's own write and would prove nothing about the merge.
      await putMedicine(
          deviceB,
          medicine('m1',
              updatedAt: at(10),
              archived: true,
              notes: 'Take with breakfast'));

      await gossip();

      final a = await readMedicine(deviceA, 'm1');
      final b = await readMedicine(deviceB, 'm1');
      expect(a, isNotNull);
      expect(b, isNotNull);

      // Convergence: not just "B changed", but B holding exactly A's row.
      expect(b!.strength, 1000,
          reason: 'A\'s dose change is the newer write and must win on both');
      expect(b.isArchived, isFalse,
          reason: 'last-write-wins is whole-row: B\'s archive is older, so it '
              'loses along with the rest of B\'s version');
      expect(b.updatedAt, a!.updatedAt);
      expect(a.strength, 1000, reason: 'A must not be talked out of its own '
          'newer edit by B\'s upload');

      // The null. `insertOnConflictUpdate(dataClass)` maps a null field to
      // `Value.absent()`, and ON CONFLICT DO UPDATE writes only the columns a
      // companion sets — so a cloud row that CLEARED a note could never clear
      // it on the other device. Nothing about the strength or the archive flag
      // can catch that: both are non-null on both sides.
      expect(b.notes, isNull,
          reason: 'A cleared the note; a merge that cannot transmit a cleared '
              'field leaves B showing instructions the user deleted');
    });

    test('negative: a medicine deleted on A does not come back from B',
        () async {
      await putMedicine(deviceA, medicine('m2', updatedAt: t0));
      await putMedicine(deviceB, medicine('m2', updatedAt: t0));
      await gossip();

      // The real delete path, not a hand-written tombstone: it is what bumps
      // `updatedAt`, and a tombstone that did not would lose every comparison.
      AppDatabase.setInstanceForTesting(deviceA);
      await deviceA.medicationDao.deleteMedicine('m2');

      await gossip();

      final onA = await readMedicine(deviceA, 'm2');
      final onB = await readMedicine(deviceB, 'm2');
      expect(onA?.deletedAt, isNotNull,
          reason: 'A must still hold its own tombstone after B has spoken. '
              'If A uploaded only live rows, the cloud copy would look like a '
              'row A has not downloaded yet and A would restore it.');
      expect(onB?.deletedAt, isNotNull,
          reason: 'the deletion has to reach B as a row, not as an absence — '
              'an absence is indistinguishable from "not synced yet"');
      // And through the reader the UI actually uses.
      expect(await deviceB.medicationDao.getMedicine('m2'), isNull);
      expect(await deviceA.medicationDao.getMedicine('m2'), isNull);

      // One more full round, because resurrection is a SECOND-pass bug: the
      // device holding the live row re-uploads it on the pass after the one
      // that deleted it.
      await gossip();
      expect((await readMedicine(deviceA, 'm2'))?.deletedAt, isNotNull);
      expect((await readMedicine(deviceB, 'm2'))?.deletedAt, isNotNull);
    });
  });

  // -------------------------------------------------------------- focus sessions

  FocusSessionsCompanion session(
    String id, {
    required DateTime updatedAt,
    int actualMinutes = 25,
  }) =>
      FocusSessionsCompanion.insert(
        id: id,
        dateKey: '2026-03-10',
        startedAt: t0,
        targetMinutes: 25,
        actualMinutes: Value(actualMinutes),
        wasCompleted: const Value(true),
        createdAt: t0,
        updatedAt: updatedAt,
      );

  Future<void> putSession(AppDatabase db, FocusSessionsCompanion s) =>
      db.into(db.focusSessions).insertOnConflictUpdate(s);

  Future<Set<String>> liveSessionIds(AppDatabase db) async =>
      (await db.focusDao.getAll()).map((r) => r.id).toSet();

  group('focus sessions', () {
    test('positive: sessions logged separately on each device all survive',
        () async {
      // Sessions accumulate with independent ids, which is why focus is LWW and
      // not "whichever side is newer replaces the collection".
      await putSession(deviceA, session('fa', updatedAt: t0));
      await putSession(deviceA, session('fb', updatedAt: t0));
      await putSession(deviceB, session('fc', updatedAt: t0));

      // A shared session the two devices disagree about.
      await putSession(deviceA, session('fx', updatedAt: at(30), actualMinutes: 50));
      await putSession(deviceB, session('fx', updatedAt: at(5), actualMinutes: 10));

      await gossip();

      expect(await liveSessionIds(deviceA), {'fa', 'fb', 'fc', 'fx'},
          reason: 'B\'s session has to reach A; a one-way sync would leave A '
              'with only its own three');
      expect(await liveSessionIds(deviceB), {'fa', 'fb', 'fc', 'fx'});
      expect((await deviceB.focusDao.getById('fx'))!.actualMinutes, 50,
          reason: 'A\'s edit is newer');
      expect((await deviceA.focusDao.getById('fx'))!.actualMinutes, 50);
    });

    test('negative: a session deleted on B stays deleted on A', () async {
      await putSession(deviceA, session('fd', updatedAt: t0));
      await putSession(deviceB, session('fd', updatedAt: t0));
      await gossip();

      await deviceB.focusDao.softDelete('fd', at(15));

      await gossip();

      expect(await deviceA.focusDao.getById('fd'), isNull,
          reason: 'the history on A must lose the session B deleted');
      final rowOnA = (await deviceA.focusDao.getAllIncludingDeleted())
          .singleWhere((r) => r.id == 'fd');
      expect(rowOnA.deletedAt, isNotNull);

      // The resurrection pass.
      await gossip();
      expect(await deviceA.focusDao.getById('fd'), isNull);
      expect(await deviceB.focusDao.getById('fd'), isNull);
    });
  });

  // ------------------------------------------------------------------ reminders

  group('reminders', () {
    /// Reminders have NO two-device merge, and this pins that rather than
    /// pretending otherwise.
    ///
    /// The finding this file answers asked for medicines, focus AND reminders.
    /// The first two have a merge seam; reminders do not. `RemindersCloudService`
    /// — the only thing that ever wrote `users/{uid}/reminders` — was deleted in
    /// `0dd3c72`, and `SyncService`, the listener that read it, went with it (see
    /// `dead_sync_paths_test.dart`). Reminders travel only in the backup payload
    /// (`CleanStorageService.exportAllData`), which is a restore, not a merge:
    /// `importData` loops `saveReminder` and never deletes, so a reminder
    /// deleted on one phone cannot be deleted on the other by any mechanism the
    /// app has.
    ///
    /// Asserted, not just written down, because the day someone adds a reminders
    /// collection this fails — and the right response to that failure is to come
    /// back here and write the merge tests above for it, which is precisely the
    /// gap that went unnoticed for medicines and focus.
    test('negative: a full sync writes no reminders collection at all',
        () async {
      AppDatabase.setInstanceForTesting(deviceA);
      await deviceA.into(deviceA.reminders).insertOnConflictUpdate(
            RemindersCompanion.insert(
              id: 'r1',
              title: 'Call the pharmacy',
              body: 'Repeat prescription',
              scheduledTime: at(60),
              createdAt: t0,
              updatedAt: t0,
            ),
          );

      // The setup has to be real: "the cloud has no reminders" is trivially
      // true of a device that has none either.
      expect(await deviceA.remindersDao.getAllReminders(), hasLength(1));

      await gossip();

      final snap =
          await fs.collection('users').doc('u1').collection('reminders').get();
      expect(snap.docs, isEmpty,
          reason: 'nothing writes users/{uid}/reminders. If that has changed, '
              'reminders now need the two-device merge and tombstone tests '
              'this group is standing in for — see the groups above.');
      expect(await deviceB.remindersDao.getAllReminders(), isEmpty,
          reason: 'and so a reminder created on A is simply not on B');
    });
  });
}
