import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  bool _syncing = false;

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
        local: () async => db.stepsDao.getDayRange(from, now),
        id: (r) => (r as StepDayRow).id,
        updatedMs: (r) => (r as StepDayRow).updatedAt.millisecondsSinceEpoch,
        toJson: (r) => (r as StepDayRow).toJson(),
        apply: (m) async => db
            .into(db.stepDailyData)
            .insertOnConflictUpdate(StepDayRow.fromJson(m)),
      );

      // ---- Sleep ----
      await _sync(
        userId, 'sleep_sessions',
        local: () async => db.sleepDao.getForRange(from, now),
        id: (r) => (r as SleepSessionRow).id,
        updatedMs: (r) => (r as SleepSessionRow).updatedAt.millisecondsSinceEpoch,
        toJson: (r) => (r as SleepSessionRow).toJson(),
        apply: (m) async => db
            .into(db.sleepSessions)
            .insertOnConflictUpdate(SleepSessionRow.fromJson(m)),
      );

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
            .insertOnConflictUpdate(HealthProfileRow.fromJson(m)),
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
          local: () async => db.periodDao.getAllDays(),
          id: (r) => (r as PeriodDayRow).id,
          updatedMs: (r) => (r as PeriodDayRow).updatedAt.millisecondsSinceEpoch,
          toJson: (r) => (r as PeriodDayRow).toJson(),
          apply: (m) async => db
              .into(db.periodDays)
              .insertOnConflictUpdate(PeriodDayRow.fromJson(m)),
        );
        await _sync(
          userId, 'menstrual_cycles',
          local: () async => db.periodDao.getAllCycles(),
          id: (r) => (r as MenstrualCycleRow).id,
          updatedMs: (r) =>
              (r as MenstrualCycleRow).updatedAt.millisecondsSinceEpoch,
          toJson: (r) => (r as MenstrualCycleRow).toJson(),
          apply: (m) async => db
              .into(db.menstrualCycles)
              .insertOnConflictUpdate(MenstrualCycleRow.fromJson(m)),
        );
      }
    } catch (e) {
      debugPrint('HealthCloudSyncService.syncAll failed: $e');
    } finally {
      _syncing = false;
    }
  }

  /// One collection, last-write-wins by `updatedMs` (mirrored as `updatedAtMs`
  /// on the cloud doc for cheap comparison). Tombstones (`deletedAt`) ride along
  /// as ordinary rows.
  Future<void> _sync(
    String userId,
    String collection, {
    required Future<List<dynamic>> Function() local,
    required String Function(dynamic) id,
    required int Function(dynamic) updatedMs,
    required Map<String, dynamic> Function(dynamic) toJson,
    required Future<void> Function(Map<String, dynamic>) apply,
  }) async {
    try {
      final ref =
          _fs.collection('users').doc(userId).collection(collection);
      final locals = await local();
      final localById = {for (final r in locals) id(r): r};
      final snap = await ref.limit(1000).get();
      final cloudById = <String, Map<String, dynamic>>{
        for (final d in snap.docs) d.id: {...d.data(), 'id': d.id},
      };
      final ids = {...localById.keys, ...cloudById.keys};
      for (final docId in ids) {
        final r = localById[docId];
        final cloud = cloudById[docId];
        final lMs = r == null ? -1 : updatedMs(r);
        final cMs = (cloud?['updatedAtMs'] as int?) ?? -1;
        if (r != null && lMs >= cMs) {
          final data = toJson(r);
          data['updatedAtMs'] = lMs;
          data['id'] = docId;
          await ref.doc(docId).set(data);
        } else if (cloud != null && cMs > lMs) {
          await apply(cloud);
        }
      }
    } catch (e) {
      debugPrint('HealthCloudSync[$collection] failed: $e');
    }
  }
}
