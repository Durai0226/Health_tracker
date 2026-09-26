import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/cloud_sync_service.dart';
import 'package:tablet_remainder/core/services/health_cloud_sync_service.dart';
import 'package:tablet_remainder/features/biometrics/services/biometrics_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

/// A cloud download landed in Drift and nowhere else.
///
/// Every one of these services is all-static with a `ValueNotifier` cache
/// loaded exactly once, from an `init()` guarded by `_isInitialized` that
/// `main.dart` awaits before `runApp`. The sync runs afterwards and applies
/// each downloaded row with `insertOnConflictUpdate` straight on the table —
/// so the rows were there, correct, and completely invisible: a returning user
/// saw the sync report success with an empty dashboard, and got their data only
/// on the next cold launch. Medicines were the one collection that already
/// reloaded.
///
/// Each test writes the row exactly the way the syncer's `apply` does, then
/// pins BOTH halves: the cache does not notice on its own, and the reload the
/// sync now performs makes it visible.
///
/// The first five call the reload directly, so they pin the reload itself. The
/// tests after them drive the two PUBLIC entry points — `downloadDataFromCloud`
/// and `syncUserData` — against a fake Firestore, which is what pins the reload
/// CALLS: every reload site in `CloudSyncService` can be deleted with the first
/// five still green.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeFirebaseFirestore fs;
  final today = DateTime.now();
  final dayOnly = DateTime(today.year, today.month, today.day);
  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    // A clean, EMPTY cache without running init() — init fires a best-effort
    // health import at a platform channel that does not exist under test.
    await StepService.resetForTesting();
    await SleepService.resetForTesting();
    await BiometricsService.resetForTesting();
    await PeriodService.resetForTesting();

    fs = FakeFirebaseFirestore();
    CloudSyncService().firestoreForTesting = fs;
  });

  tearDown(() async {
    CloudSyncService().firestoreForTesting = null;
    await db.close();
  });

  test('a downloaded step day reaches the dashboard', () async {
    await db.into(db.stepDailyData).insert(StepDailyDataCompanion.insert(
          id: key(dayOnly),
          date: dayOnly,
          sensorSteps: const Value(7321),
          createdAt: dayOnly,
          updatedAt: dayOnly,
        ));

    expect(StepService.getDataForDate(dayOnly), isNull,
        reason: 'the cache cannot see a row written behind its back');

    await CloudSyncService.reloadCachesAfterHealthSync();

    expect(StepService.getDataForDate(dayOnly)?.effectiveSteps, 7321);
  });

  test('a downloaded night reaches the sleep dashboard', () async {
    await db.into(db.sleepSessions).insert(SleepSessionsCompanion.insert(
          id: 'night-1',
          dateKey: key(dayOnly),
          bedtime: dayOnly.subtract(const Duration(hours: 2)),
          wakeTime: dayOnly.add(const Duration(hours: 7)),
          inBedMinutes: 480,
          asleepMinutes: 455,
          createdAt: dayOnly,
          updatedAt: dayOnly,
        ));

    expect(SleepService.getForDate(dayOnly), isNull);

    await CloudSyncService.reloadCachesAfterHealthSync();

    expect(SleepService.getForDate(dayOnly)?.asleepMinutes, 455);
  });

  test('a downloaded biometric day reaches the wearable cards', () async {
    await db
        .into(db.biometricDailyData)
        .insert(BiometricDailyDataCompanion.insert(
          id: key(dayOnly),
          date: dayOnly,
          restingHr: const Value(52),
          createdAt: dayOnly,
          updatedAt: dayOnly,
        ));

    expect(BiometricsService.getForDate(dayOnly), isNull);

    await CloudSyncService.reloadCachesAfterHealthSync();

    expect(BiometricsService.getForDate(dayOnly)?.restingHr, 52);
  });

  test('a downloaded period day reaches the calendar', () async {
    await db.into(db.periodDays).insert(PeriodDaysCompanion.insert(
          id: key(dayOnly),
          date: dayOnly,
          flowIndex: const Value(2),
          createdAt: dayOnly,
          updatedAt: dayOnly,
        ));

    expect(PeriodService.getDay(dayOnly), isNull);

    await CloudSyncService.reloadCachesAfterHealthSync();

    expect(PeriodService.getDay(dayOnly)?.flowIndex, 2);
  });

  test('a downloaded focus session reaches the history', () async {
    final focus = FocusService();
    // The same table write `_syncFocusSessions`' apply performs — its
    // `focusDao.upsertRaw` decodes the cloud JSON and inserts this companion.
    await db.into(db.focusSessions).insert(FocusSessionsCompanion.insert(
          id: 'fs-1',
          dateKey: key(dayOnly),
          startedAt: dayOnly,
          targetMinutes: 25,
          actualMinutes: const Value(25),
          wasCompleted: const Value(true),
          createdAt: dayOnly,
          updatedAt: dayOnly,
        ));

    expect(focus.sessions.where((s) => s.id == 'fs-1'), isEmpty);

    await focus.reloadSessionsFromDb();

    expect(focus.sessions.map((s) => s.id), contains('fs-1'));
  });

  /// Drives the PUBLIC `downloadDataFromCloud` end to end, so it pins the
  /// reload CALL rather than the reload itself — the five above would all stay
  /// green with every call site deleted.
  test('a restored medicine reaches the list the UI renders from', () async {
    // The cloud document is built from a real row, so its shape is exactly
    // what the syncer writes and what `EnhancedMedicine.fromJson` reads back.
    await db
        .into(db.enhancedMedicines)
        .insert(EnhancedMedicinesCompanion.insert(
          id: 'm1',
          name: 'Metformin',
          dosageForm: 0,
          startDate: dayOnly,
          createdAt: dayOnly,
          updatedAt: dayOnly,
          scheduleJson: '{}',
        ));
    final cloudDoc = (await db.medicationDao.getMedicine('m1'))!.toJson();
    // A hard delete, not `deleteMedicine` — a tombstone is a different state,
    // and this device is meant to look like one that has never seen the row.
    await db.delete(db.enhancedMedicines).go();

    await fs
        .collection('users')
        .doc('u1')
        .collection('medicines')
        .doc('m1')
        .set(cloudDoc);

    // The cache as `main.dart` leaves it: loaded once, from the empty database
    // this device has before the restore.
    await CleanStorageService.getAllMedicinesAsync();
    expect(CleanStorageService.getAllMedicines(), isEmpty);

    await CloudSyncService().downloadDataFromCloud('u1');

    expect(CleanStorageService.getAllMedicines().map((m) => m.id),
        contains('m1'),
        reason: 'the restore wrote the row straight onto the table; only the '
            'reload makes it visible before the next cold launch');
  });

  /// The other public entry point — `main.dart:167` on every launch — and the
  /// one carrying the three reload call sites the tests above cannot see:
  /// `_syncMedicines`, `_syncFocusSessions`, and the
  /// `reloadCachesAfterHealthSync` that ends the pass.
  ///
  /// It was untestable until `HealthCloudSyncService` was given the same
  /// injectable Firestore seam `CloudSyncService` already had. Merely NAMING
  /// its `instance` ran `FirebaseFirestore.instance` in a field initialiser and
  /// threw without a Firebase app, so all three of those call sites could be
  /// deleted with the whole of `test/core` staying green.
  group('syncUserData reloads what the pass downloaded', () {
    setUp(() => HealthCloudSyncService.instance.firestoreForTesting = fs);
    tearDown(() => HealthCloudSyncService.instance.firestoreForTesting = null);

    /// The cloud document built from a REAL Drift row, then that row removed:
    /// the shape is exactly what the syncer writes, and this device is left
    /// looking like one that has never seen it. `updatedAtMs` is the mirror
    /// field `syncLwwCollection` compares on — without it the cloud copy reads
    /// as older than a missing local row and is never applied.
    Future<void> publish(
      String collection,
      String id,
      Map<String, dynamic> json,
      DateTime updatedAt,
    ) async {
      json['updatedAtMs'] = updatedAt.millisecondsSinceEpoch;
      await fs
          .collection('users')
          .doc('u1')
          .collection(collection)
          .doc(id)
          .set(json);
    }

    test('a downloaded step day is on the dashboard when the pass returns',
        () async {
      await db.into(db.stepDailyData).insert(StepDailyDataCompanion.insert(
            id: key(dayOnly),
            date: dayOnly,
            sensorSteps: const Value(9142),
            createdAt: dayOnly,
            updatedAt: dayOnly,
          ));
      final row = (await db.select(db.stepDailyData).get()).single;
      await db.delete(db.stepDailyData).go();
      await publish('step_days', row.id, row.toJson(), row.updatedAt);

      expect(StepService.getDataForDate(dayOnly), isNull);

      await CloudSyncService().syncUserData('u1');

      expect(StepService.getDataForDate(dayOnly)?.effectiveSteps, 9142,
          reason: 'syncAll wrote the row with insertOnConflictUpdate; only '
              'the reloadCachesAfterHealthSync that ends syncUserData puts it '
              'in front of the user this launch');
    });

    test('a downloaded focus session is in the history when the pass returns',
        () async {
      await db.into(db.focusSessions).insert(FocusSessionsCompanion.insert(
            id: 'fs-sync',
            dateKey: key(dayOnly),
            startedAt: dayOnly,
            targetMinutes: 25,
            actualMinutes: const Value(25),
            wasCompleted: const Value(true),
            createdAt: dayOnly,
            updatedAt: dayOnly,
          ));
      final row = (await db.focusDao.getAllIncludingDeleted()).single;
      await db.delete(db.focusSessions).go();
      await publish('focus_sessions', row.id, row.toJson(), row.updatedAt);

      final focus = FocusService();
      // The cache as a device that has never seen this session holds it.
      await focus.reloadSessionsFromDb();
      expect(focus.sessions.where((s) => s.id == 'fs-sync'), isEmpty);

      await CloudSyncService().syncUserData('u1');

      expect(focus.sessions.map((s) => s.id), contains('fs-sync'),
          reason: '_syncFocusSessions applies through focusDao.upsertRaw, '
              'which the service that renders the history cannot see');
    });

    test('a downloaded medicine is in the list when the pass returns',
        () async {
      await db
          .into(db.enhancedMedicines)
          .insert(EnhancedMedicinesCompanion.insert(
            id: 'm-sync',
            name: 'Levothyroxine',
            dosageForm: 0,
            startDate: dayOnly,
            createdAt: dayOnly,
            updatedAt: dayOnly,
            scheduleJson: '{}',
          ));
      final row = (await db.medicationDao.getMedicine('m-sync'))!;
      await db.delete(db.enhancedMedicines).go();
      await publish('medicines', row.id, row.toJson(), row.updatedAt);

      await CleanStorageService.getAllMedicinesAsync();
      expect(CleanStorageService.getAllMedicines(), isEmpty);

      await CloudSyncService().syncUserData('u1');

      expect(CleanStorageService.getAllMedicines().map((m) => m.id),
          contains('m-sync'));
    });
  });
}
