import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'lww_collection_sync.dart';
import '../database/app_database.dart';

/// Syncs the Period / Steps / Sleep features to Firestore under
/// `users/{uid}/<collection>` with **last-write-wins** (by `updatedAt`) and
/// soft-delete **tombstones** (`deletedAt` rows are synced as-is; local queries
/// already filter them out). Owner-scoped by `firestore.rules`.
///
/// PRIVACY: sensitive menstrual data only syncs when the user opts in
/// (`PeriodSettings.cloudSyncEnabled`, default OFF) — it never leaves the device
/// without consent. Drift is always the source of truth; this is additive.
class HealthCloudSyncService {
  HealthCloudSyncService._();
  static final HealthCloudSyncService instance = HealthCloudSyncService._();

  // Resolved on each use rather than in a field initializer — the same seam,
  // for the same reason, as `CloudSyncService`. This is a `static final`
  // singleton, so a field initializer ran `Firebase.app()` the first time
  // anything so much as NAMED the service. `CloudSyncService.syncUserData`
  // names it, so that entry point threw outside an initialised app and the
  // cache reloads it performs could not be tested at all.
  FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _fs => _firestoreOverride ?? FirebaseFirestore.instance;

  /// Point the service at a fake Firestore. `null` restores the real instance.
  @visibleForTesting
  set firestoreForTesting(FirebaseFirestore? fs) => _firestoreOverride = fs;

  bool _syncing = false;

  /// Every `apply` below writes `toCompanion(false)`, never the bare data class.
  ///
  /// `insertOnConflictUpdate(dataClass)` maps null fields to `Value.absent()`,
  /// and ON CONFLICT DO UPDATE writes only the columns a companion sets — so a
  /// cloud row carrying `deletedAt: null` could not clear a local tombstone.
  /// Deletions propagated (a non-null `deletedAt` IS written) but un-deletions
  /// did not. That matters most for `period_days` and `step_days`, whose ids
  /// ARE the calendar date: delete a day here, re-log it on another device, and
  /// the re-logged day stayed invisible on this one forever.
  Future<void> syncAll(String userId) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final db = AppDatabase.instance;
      final from = DateTime.now().subtract(const Duration(days: 60));
      final now = DateTime.now();

      // ---- Steps ----
      await _sync(
        userId, 'step_days',
        // Tombstones included — see the biometric_days note below.
        local: () async =>
            db.stepsDao.getDayRangeIncludingDeleted(from, now),
        id: (r) => (r as StepDayRow).id,
        updatedMs: (r) => (r as StepDayRow).updatedAt.millisecondsSinceEpoch,
        toJson: (r) => (r as StepDayRow).toJson(),
        apply: (m) async => db
            .into(db.stepDailyData)
            .insertOnConflictUpdate(StepDayRow.fromJson(m).toCompanion(false)),
      );

      // ---- Sleep ----
      await _sync(
        userId, 'sleep_sessions',
        // Tombstones included — see the biometric_days note below.
        local: () async =>
            db.sleepDao.getForRangeIncludingDeleted(from, now),
        id: (r) => (r as SleepSessionRow).id,
        updatedMs: (r) => (r as SleepSessionRow).updatedAt.millisecondsSinceEpoch,
        toJson: (r) => (r as SleepSessionRow).toJson(),
        apply: (m) async => db
            .into(db.sleepSessions)
            .insertOnConflictUpdate(SleepSessionRow.fromJson(m).toCompanion(false)),
      );

      // ---- Wearable biometrics (daily aggregates) ----
      //
      // Uses the *IncludingDeleted* reads so a tombstone can propagate: the
      // ordinary getters filter deletedAt, and a syncer that cannot see a
      // tombstone reads it as "missing on this device" and downloads the
      // deleted day straight back.
      await _sync(
        userId, 'biometric_days',
        local: () async =>
            db.biometricsDao.getDayRangeIncludingDeleted(from, now),
        id: (r) => (r as BiometricDayRow).id,
        updatedMs: (r) =>
            (r as BiometricDayRow).updatedAt.millisecondsSinceEpoch,
        toJson: (r) => (r as BiometricDayRow).toJson(),
        apply: (m) async => db
            .into(db.biometricDailyData)
            .insertOnConflictUpdate(BiometricDayRow.fromJson(m).toCompanion(false)),
      );

      // ---- Workout sessions ----
      await _sync(
        userId, 'workouts',
        local: () async =>
            db.biometricsDao.getWorkoutsForRangeIncludingDeleted(from, now),
        id: (r) => (r as WorkoutSessionRow).id,
        updatedMs: (r) =>
            (r as WorkoutSessionRow).updatedAt.millisecondsSinceEpoch,
        toJson: (r) => (r as WorkoutSessionRow).toJson(),
        apply: (m) async => db
            .into(db.workoutSessions)
            .insertOnConflictUpdate(WorkoutSessionRow.fromJson(m).toCompanion(false)),
      );

      // The device registry (`health_sources`) is deliberately NOT synced. It
      // is device-local by nature — which apps write to THIS phone's Health
      // Connect — cheap to rebuild from a single sync pass, and it carries
      // user-supplied device names. Uploading it would widen the health-data
      // blast radius for no user-visible benefit.

      // ---- Shared health profile (single doc) ----
      await _sync(
        userId, 'health_profile',
        local: () async {
          final p = await db.stepsDao.getProfile();
          return p == null ? const [] : [p];
        },
        id: (r) => (r as HealthProfileRow).id,
        updatedMs: (r) => (r as HealthProfileRow).updatedAt.millisecondsSinceEpoch,
        toJson: (r) => (r as HealthProfileRow).toJson(),
        apply: (m) async => db
            .into(db.healthProfiles)
            .insertOnConflictUpdate(HealthProfileRow.fromJson(m).toCompanion(false)),
      );

      // ---- Period (opt-in only) ----
      bool periodOptIn = false;
      try {
        periodOptIn =
            (await db.periodDao.getSettings())?.cloudSyncEnabled ?? false;
      } catch (_) {}
      if (periodOptIn) {
        await _sync(
          userId, 'period_days',
          // Tombstones included — see the biometric_days note above.
          local: () async => db.periodDao.getAllDaysIncludingDeleted(),
          id: (r) => (r as PeriodDayRow).id,
          updatedMs: (r) => (r as PeriodDayRow).updatedAt.millisecondsSinceEpoch,
          toJson: (r) => (r as PeriodDayRow).toJson(),
          apply: (m) async => db
              .into(db.periodDays)
              .insertOnConflictUpdate(PeriodDayRow.fromJson(m).toCompanion(false)),
        );
        // `menstrual_cycles` is deliberately NOT synced: a cycle is DERIVED
        // from the period_days above, never entered. `PeriodService`
        // recomputes the whole set after every mutation and persists it with
        // `replaceCycles`, which deletes every row and re-inserts — so a cycle
        // downloaded here survived only until the next log, and uploading them
        // spent a write per cycle on data the other device regenerates from
        // the days it already received. Nothing reads the cloud copy either:
        // the UI reads `PeriodService.getCycles()` (in memory), and
        // `periodDao.getAllCycles()` had exactly one caller — this sync.
      }
    } catch (e) {
      debugPrint('HealthCloudSyncService.syncAll failed: $e');
    } finally {
      _syncing = false;
    }
  }

  /// One collection, last-write-wins. See [syncLwwCollection], which this now
  /// delegates to — the rule moved out when focus sessions needed the same
  /// semantics without belonging to the health syncer.
  Future<void> _sync(
    String userId,
    String collection, {
    required Future<List<dynamic>> Function() local,
    required String Function(dynamic) id,
    required int Function(dynamic) updatedMs,
    required Map<String, dynamic> Function(dynamic) toJson,
    required Future<void> Function(Map<String, dynamic>) apply,
  }) =>
      syncLwwCollection(_fs, userId, collection,
          local: local,
          id: id,
          updatedMs: updatedMs,
          toJson: toJson,
          apply: apply);
}
