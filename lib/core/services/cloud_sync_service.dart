
import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../features/biometrics/services/biometrics_service.dart';
import '../../features/focus/services/focus_service.dart';
import '../../features/period/services/period_service.dart';
import '../../features/sleep/services/sleep_service.dart';
import '../../features/steps/services/step_service.dart';
import '../../features/water/services/water_service.dart';
import '../../features/water/models/enhanced_water_log.dart';
// `EnhancedMedicine` here is the DRIFT ROW, not the domain model of the same
// name in features/medication/models — this file deliberately no longer imports
// the latter, nor the legacy `Medicine` whose fromJson could not parse a row.
import '../database/app_database.dart';
import 'clean_storage_service.dart';
import 'health_cloud_sync_service.dart';
import 'lww_collection_sync.dart';

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  // Resolved on each use rather than in a field initializer. This is a
  // `static final` singleton, so a field initializer runs `Firebase.app()` the
  // first time anything so much as names the service — which throws outside an
  // initialised app, and takes every test of the download path with it.
  FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Point the service at a fake Firestore. `null` restores the real instance.
  @visibleForTesting
  set firestoreForTesting(FirebaseFirestore? fs) => _firestoreOverride = fs;

  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  Future<void> syncUserData(String userId) async {
    if (_isSyncing) {
      debugPrint('Sync already in progress, skipping...');
      return;
    }

    try {
      _isSyncing = true;
      debugPrint('Starting cloud sync for user: $userId');

      await Future.wait([
        _syncMedicines(userId),
        _syncWaterIntake(userId),
        _syncFocusSessions(userId),
        // Period (opt-in) / Steps / Sleep — LWW + tombstones.
        HealthCloudSyncService.instance.syncAll(userId),
      ]);

      await reloadCachesAfterHealthSync();

      debugPrint('Cloud sync completed successfully');
    } catch (e) {
      debugPrint('Cloud sync error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Re-read the in-memory caches the UI renders from, after a sync pass wrote
  /// rows straight into Drift.
  ///
  /// `HealthCloudSyncService` applies every downloaded row with
  /// `insertOnConflictUpdate` on the Drift table. The services that own those
  /// rows are all-static, hold a `ValueNotifier` cache, and load it exactly once
  /// from an `init()` guarded by `_isInitialized` — which `main.dart` has
  /// already run by the time this sync starts. So without this, a returning user
  /// watches the sync report success and sees none of their steps, nights,
  /// wearable days or cycles until the next cold launch: the one thing "restore
  /// my data" is supposed to avoid.
  ///
  /// Unconditional, because `syncAll` reports nothing back about which of its
  /// collections downloaded anything — and five ranged Drift reads on the tail
  /// of a network round trip are not worth a second signalling mechanism.
  /// Medicines and focus each reload from their own pass, where the count IS
  /// available.
  @visibleForTesting
  static Future<void> reloadCachesAfterHealthSync() async {
    // Each is independently best-effort: one service failing to reload must not
    // leave the other four showing stale data. They are all-static with a
    // ValueNotifier cache, so a throw here would otherwise abort the rest.
    for (final reload in <Future<void> Function()>[
      StepService.reloadFromDb,
      SleepService.reloadFromDb,
      BiometricsService.reloadFromDb,
      PeriodService.reloadFromDb,
    ]) {
      try {
        await reload();
      } catch (e) {
        debugPrint('⚠️ Cache reload after sync failed: $e');
      }
    }
  }

  /// Focus sessions — last-write-wins, tombstones included.
  ///
  /// Here rather than in `HealthCloudSyncService`, on purpose. Focus is not
  /// Health Connect / HealthKit data: it is read from no health permission,
  /// appears in no per-permission justification, and is not covered by the Play
  /// "Health apps" declaration. Syncing it through the health service would pull
  /// a productivity timer into that declaration and its Data-safety rows for no
  /// benefit, so it rides beside medicines and water — which are equally not
  /// health-platform data.
  ///
  /// LWW rather than whole-collection replacement, because sessions ACCUMULATE
  /// independently: two devices both generate new ids, and replacing the
  /// collection in either direction would throw away one side's history. The
  /// same reasoning now applies to [_syncMedicines] below, which went through
  /// this seam too.
  Future<void> _syncFocusSessions(String userId) async {
    final db = AppDatabase.instance;
    final result = await syncLwwCollection(
      _firestore,
      userId,
      'focus_sessions',
      // Tombstones included: a deletion has to propagate like any other change.
      local: () async => db.focusDao.getAllIncludingDeleted(),
      id: (r) => (r as FocusSessionRow).id,
      updatedMs: (r) =>
          (r as FocusSessionRow).updatedAt.millisecondsSinceEpoch,
      toJson: (r) => (r as FocusSessionRow).toJson(),
      apply: (m) async => db.focusDao.upsertRaw(m),
    );
    // `upsertRaw` writes the table directly, so the service that renders the
    // history has no idea anything arrived.
    if (result.appliedLocally) {
      await FocusService().reloadSessionsFromDb();
    }
  }

  /// Medicines — last-write-wins on the Drift row, tombstones included.
  ///
  /// What this replaced was a facade that could not work in either direction:
  ///
  ///  * it uploaded ONLY when the cloud collection was empty, so the moment one
  ///    document existed every later local change stopped being uploaded;
  ///  * it uploaded `EnhancedMedicine` (Drift-shaped, `scheduleJson`, epoch-ms
  ///    dates) and parsed the result with the LEGACY `Medicine.fromJson`, whose
  ///    first act is `DateTime.parse(json['time'])` — a key that shape does not
  ///    have, so every download threw;
  ///  * and the thing it threw into, `CleanStorageService.addMedicineFromModel`,
  ///    was a stub whose entire body was a `debugPrint`.
  ///
  /// So a returning user on a new phone got zero medicines while the log said
  /// "Successfully downloaded all data from cloud", and Settings said
  /// "Cloud sync on". Syncing the generated row through the shared helper is
  /// what every other collection here already does.
  Future<void> _syncMedicines(String userId) async {
    final db = AppDatabase.instance;
    final result = await syncLwwCollection(
      _firestore,
      userId,
      'medicines',
      // Archived AND tombstoned rows included: both are states the other
      // device has to learn about.
      local: () async => db.medicationDao.getAllMedicinesIncludingDeleted(),
      id: (r) => (r as EnhancedMedicine).id,
      updatedMs: (r) =>
          (r as EnhancedMedicine).updatedAt.millisecondsSinceEpoch,
      toJson: (r) => (r as EnhancedMedicine).toJson(),
      // `toCompanion(false)` — NOT the bare data class.
      //
      // `insertOnConflictUpdate(dataClass)` maps every null field to
      // `Value.absent()`, and ON CONFLICT DO UPDATE writes only the columns a
      // companion sets. A cloud row with `deletedAt: null` could therefore
      // never clear a local tombstone: a medicine deleted here and then
      // restored on another device would stay invisible on this one forever.
      // `toCompanion(false)` makes null an explicit SET NULL, which is what a
      // last-write-wins apply has to mean.
      apply: (m) async => db
          .into(db.enhancedMedicines)
          .insertOnConflictUpdate(EnhancedMedicine.fromJson(m).toCompanion(false)),
    );
    // The cache the UI reads is populated at startup; a download that lands
    // after that would otherwise not be visible until the next launch. An
    // upload-only pass changed nothing locally, so it needs no reload.
    if (result.appliedLocally) {
      await CleanStorageService.getAllMedicinesAsync();
    }
  }

  /// Two-way sync of today's water.
  ///
  /// This was cloud-wins-unconditionally: whenever the cloud document existed,
  /// the local day was replaced by it with no comparison. Drink four glasses on
  /// your phone while the cloud still holds one, sync, and three are gone. It
  /// also wrote through `saveDailyData`, which persists only the day row, so
  /// whichever logs did arrive were never stored. And the document id was built
  /// as `'${y}-${m}-${d}'` — unpadded — so in single-digit months it addressed
  /// `2026-8-21` while every local reader expects `2026-08-21`.
  ///
  /// Now: union-merge by log id — minus the drinks either side records as
  /// deleted — recompute totals from the merged set, then push the merged
  /// result back up so the other device converges too. See
  /// [WaterService.mergeCloudDay] for how deletions travel.
  Future<void> _syncWaterIntake(String userId) async {
    try {
      final today = clock.now();
      // The SAME key the local store uses — zero-padded.
      final key = WaterService.dateKeyFor(today);
      final cloudRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('water_intake')
          .doc(key);

      final cloudDoc = await cloudRef.get();
      // Not `getTodayData()`: the upload has to carry the day's tombstones, and
      // those are read lazily — see [WaterService.todayDataForSync].
      final localWater = await WaterService.todayDataForSync();

      if (!cloudDoc.exists || cloudDoc.data() == null) {
        if (localWater.totalIntakeMl > 0 || localWater.logs.isNotEmpty) {
          debugPrint('Uploading today\'s water intake to cloud');
          await cloudRef.set(localWater.toJson());
        }
        return;
      }

      final data = cloudDoc.data()!;
      DailyWaterData cloudWater;
      try {
        cloudWater = DailyWaterData.fromJson(data);
      } catch (e) {
        // Legacy shape: a flat currentIntakeMl with no logs. Force the local
        // key rather than trusting `data['id']`, which older builds wrote in
        // the unpadded form.
        debugPrint('Migrating legacy water data: $e');
        cloudWater = DailyWaterData(
          id: key,
          date: DateTime.tryParse(data['date']?.toString() ?? '') ?? today,
          dailyGoalMl: (data['dailyGoalMl'] as num?)?.toInt() ?? 2500,
          totalIntakeMl: (data['currentIntakeMl'] as num?)?.toInt() ?? 0,
          effectiveHydrationMl: (data['currentIntakeMl'] as num?)?.toInt() ?? 0,
        );
      }

      final merged = await WaterService.mergeCloudDay(cloudWater);

      // Push the merge back so the peer device converges instead of re-sending
      // its stale copy on the next round.
      //
      // The tombstone count is part of that test, not decoration: the merged
      // set is a superset of the cloud's, so a differing size means the cloud
      // copy has not learnt about a deletion yet. Length and total alone miss
      // it — delete a 250 ml drink, log another, and both sides agree on both
      // numbers while the cloud still holds the deleted one.
      if (merged.logs.length != cloudWater.logs.length ||
          merged.totalIntakeMl != cloudWater.totalIntakeMl ||
          merged.deletedLogIds.length != cloudWater.deletedLogIds.length) {
        await cloudRef.set(merged.toJson());
      }
    } catch (e) {
      debugPrint('Water intake sync error: $e');
    }
  }

  Future<void> uploadDataToCloud(String userId) async {
    try {
      debugPrint('Uploading all local data to cloud for user: $userId');

      final localMedicines =
          await AppDatabase.instance.medicationDao.getAllMedicinesIncludingDeleted();
      // Tombstones included, same as the two-way sync above.
      final localWater = await WaterService.todayDataForSync();

      // commitInChunks, not one raw batch: Firestore caps a batch at 500 writes
      // and throws the whole thing away past that. This list is every medicine
      // INCLUDING tombstones, so it only ever grows — a long-standing user with
      // 500 rows had their entire first upload fail, and the catch below only
      // debugPrints, so "Successfully uploaded" was never reached and nothing
      // told them.
      final ops = <void Function(WriteBatch)>[];
      final userRef = _firestore.collection('users').doc(userId);

      for (final medicine in localMedicines) {
        // The generated row's JSON, matching what _syncMedicines writes and
        // what the download below parses. The legacy `Medicine.toJson` used
        // here before produced a shape nothing could read back.
        final data = medicine.toJson();
        data['updatedAtMs'] = medicine.updatedAt.millisecondsSinceEpoch;
        ops.add((b) =>
            b.set(userRef.collection('medicines').doc(medicine.id), data));
      }

      if (localWater.totalIntakeMl > 0 || localWater.logs.isNotEmpty) {
        // Zero-padded, same as the local store — see _syncWaterIntake.
        final key = WaterService.dateKeyFor(clock.now());
        ops.add((b) => b.set(
            userRef.collection('water_intake').doc(key), localWater.toJson()));
      }

      await commitInChunks(_firestore, ops);
      debugPrint('Successfully uploaded all data to cloud');
    } catch (e) {
      debugPrint('Upload to cloud error: $e');
      rethrow;
    }
  }

  Future<void> downloadDataFromCloud(String userId) async {
    try {
      debugPrint('Downloading all data from cloud for user: $userId');

      final userRef = _firestore.collection('users').doc(userId);

      final db = AppDatabase.instance;
      final medicinesSnapshot =
          await userRef.collection('medicines').limit(500).get();
      var restored = 0;
      for (final doc in medicinesSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        try {
          await db.into(db.enhancedMedicines).insertOnConflictUpdate(
              EnhancedMedicine.fromJson(data).toCompanion(false));
          restored++;
        } catch (e) {
          // One unreadable document must not cost the user every other
          // medicine — the old code let the first throw abort the whole loop.
          debugPrint('Skipping unreadable cloud medicine ${doc.id}: $e');
        }
      }
      await CleanStorageService.getAllMedicinesAsync();
      debugPrint('Restored $restored of ${medicinesSnapshot.docs.length} medicines');

      // The THIRTY MOST RECENT days. `.limit(30)` alone is not that: Firestore
      // orders by document id ascending when nothing else is asked for, and the
      // ids here are `YYYY-MM-DD`, so a plain limit returns the user's THIRTY
      // OLDEST days. A returning user with a year of history restored January
      // and never saw this month. Descending by document id is the same sort in
      // reverse, which for a zero-padded date key is newest-first.
      //
      // Merged, not overwritten, and via mergeCloudDay so the per-drink logs are
      // actually persisted — `saveDailyData` writes the day row only, which is
      // what left downloaded days showing totals with an empty history.
      final waterSnapshot = await userRef
          .collection('water_intake')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(30)
          .get();
      for (final doc in waterSnapshot.docs) {
        final data = doc.data();
        try {
          await WaterService.mergeCloudDay(DailyWaterData.fromJson(data));
        } catch (e) {
          final date = DateTime.tryParse(data['date']?.toString() ?? '');
          if (date == null) {
            debugPrint('Skipping undated cloud water doc ${doc.id}: $e');
            continue;
          }
          final amount = (data['currentIntakeMl'] as num?)?.toInt() ?? 0;
          // Derive the id from the date rather than trusting doc.id: older
          // builds wrote unpadded ids like `2026-8-21`, and a row stored under
          // that key is invisible to every local reader.
          await WaterService.mergeCloudDay(DailyWaterData(
            id: WaterService.dateKeyFor(date),
            date: date,
            dailyGoalMl: (data['dailyGoalMl'] as num?)?.toInt() ?? 2500,
            totalIntakeMl: amount,
            effectiveHydrationMl: amount,
          ));
        }
      }

      debugPrint('Successfully downloaded all data from cloud');
    } catch (e) {
      debugPrint('Download from cloud error: $e');
      rethrow;
    }
  }

  Future<bool> hasCloudData(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      final medicinesSnapshot = await userRef.collection('medicines').limit(1).get();
      if (medicinesSnapshot.docs.isNotEmpty) return true;

      final waterSnapshot = await userRef.collection('water_intake').limit(1).get();
      if (waterSnapshot.docs.isNotEmpty) return true;

      return false;
    } catch (e) {
      debugPrint('Error checking cloud data: $e');
      return false;
    }
  }
}
