import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart' as db;

/// The sleep / period / steps / health-profile half of the app backup.
///
/// `CleanStorageService.exportAllData()` carried eight sections — settings,
/// medicines (with their dose logs), focus, reminders, water, vitals, diary and
/// preferences — and nothing else. Everything the Sleep, Period and Steps
/// features store was outside the backup entirely: "Export a copy" produced a
/// file with no nights slept, no cycle history, no hand-typed step entries and
/// no body profile, and restoring it on a new phone brought none of them back.
/// Hand-typed step entries are the sharpest loss — unlike sensor steps they
/// cannot be re-fetched from Health Connect/HealthKit, so there is no second
/// copy anywhere.
///
/// **Why Drift rows and not the domain models.** `SleepSession`, `PeriodDay`,
/// `StepDailyData`, `StepManualEntry` and `HealthProfile` have `fromRow` /
/// `toCompanion` but no `toJson`/`fromJson`, and several of them drop columns
/// on the way through (`dataJson`, `schemaVer`, `synced`). The generated row
/// classes serialize every column losslessly, and `HealthCloudSyncService`
/// already ships exactly these maps to Firestore — so this reuses a seam that
/// is in production rather than inventing a parallel one. Importing the
/// database file with a `db.` prefix is what lets this live outside
/// `CleanStorageService`, which imports the domain models unprefixed and would
/// clash on `StepDailyData` and `HealthProfile`.
///
/// **Export, import and clear live in one file on purpose.** They are three
/// halves of one contract: a table that `clearRestorableRows` wipes but
/// `importJson` cannot put back is data destroyed by a restore. Keeping them
/// side by side is the cheapest way to make that impossible to get wrong —
/// see the same warning on `CleanStorageService.clearRestorableData`.
class HealthBackupSerializer {
  HealthBackupSerializer._();

  /// Top-level keys this serializer owns inside the backup map.
  static const String sleepKey = 'sleep';
  static const String periodKey = 'period';
  static const String stepsKey = 'steps';
  static const String healthProfileKey = 'healthProfile';

  /// Consent, not data. `PeriodSettingsTable.cloudSyncEnabled` is the opt-in
  /// that decides whether menstrual data leaves the device at all, so a restore
  /// file must never be able to set it — same rule, and the same reasoning, as
  /// `CleanStorageService.kNeverLeaveTheDevice`. It is dropped on export and
  /// the device's own value is re-applied on import.
  static const String periodConsentField = 'cloudSyncEnabled';

  static db.AppDatabase get _db => db.AppDatabase.instance;

  /// Live rows only — tombstones (`deletedAt`) are deliberately left out. A
  /// backup is the user's data, not the record of what they deleted.
  ///
  /// Derived `menstrual_cycles` are also left out: `PeriodService` recomputes
  /// the whole set from the period days below after every mutation, so backing
  /// them up would store a cache next to the thing it is derived from.
  static Future<Map<String, dynamic>> exportJson() async {
    final d = _db;

    final sleep = await (d.select(d.sleepSessions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.wakeTime)]))
        .get();

    final periodDays = await (d.select(d.periodDays)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    final periodSettings = await d.periodDao.getSettings();

    final stepDays = await (d.select(d.stepDailyData)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    final manualEntries = await (d.select(d.stepManualEntries)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.time)]))
        .get();

    final profile = await d.stepsDao.getProfile();

    return <String, dynamic>{
      sleepKey: sleep.map((r) => r.toJson()).toList(),
      periodKey: <String, dynamic>{
        'days': periodDays.map((r) => r.toJson()).toList(),
        if (periodSettings != null)
          'settings': Map<String, dynamic>.from(periodSettings.toJson())
            ..remove(periodConsentField),
      },
      stepsKey: <String, dynamic>{
        'days': stepDays.map((r) => r.toJson()).toList(),
        'manualEntries': manualEntries.map((r) => r.toJson()).toList(),
      },
      if (profile != null) healthProfileKey: profile.toJson(),
    };
  }

  /// Restore whatever of [data] this serializer owns. Non-destructive and
  /// idempotent, matching the rest of `importData`: every row is upserted on
  /// its own primary key, a section that is ABSENT is left untouched, and a
  /// malformed row is skipped rather than failing the whole restore.
  ///
  /// `toCompanion(false)` — never the bare data class — for the reason spelled
  /// out on `HealthCloudSyncService.syncAll`: `insertOnConflictUpdate` writes
  /// only the columns a companion sets, so a row carrying `deletedAt: null`
  /// could not otherwise clear a local tombstone. Backup wins, which is what
  /// "restore" means.
  static Future<void> importJson(Map<String, dynamic> data) async {
    final d = _db;

    for (final raw in (data[sleepKey] as List? ?? const [])) {
      try {
        await d.into(d.sleepSessions).insertOnConflictUpdate(
            db.SleepSessionRow.fromJson(Map<String, dynamic>.from(raw as Map))
                .toCompanion(false));
      } catch (e) {
        debugPrint('Import sleep session failed: $e');
      }
    }

    final period = data[periodKey];
    if (period is Map) {
      for (final raw in (period['days'] as List? ?? const [])) {
        try {
          await d.into(d.periodDays).insertOnConflictUpdate(
              db.PeriodDayRow.fromJson(Map<String, dynamic>.from(raw as Map))
                  .toCompanion(false));
        } catch (e) {
          debugPrint('Import period day failed: $e');
        }
      }
      final settings = period['settings'];
      if (settings is Map) {
        try {
          final json = Map<String, dynamic>.from(settings);
          // The device's own consent, never the file's — see
          // [periodConsentField]. Read before the write, and defaulting to
          // OFF when there is nothing local to read: a restore may only ever
          // leave cloud sync where it found it or off, never switch it on.
          final local = await d.periodDao.getSettings();
          json[periodConsentField] = local?.cloudSyncEnabled ?? false;
          await d.into(d.periodSettingsTable).insertOnConflictUpdate(
              db.PeriodSettingsRow.fromJson(json).toCompanion(false));
        } catch (e) {
          debugPrint('Import period settings failed: $e');
        }
      }
    }

    final steps = data[stepsKey];
    if (steps is Map) {
      // Days before entries: a manual entry's `dailyDataId` points at the day
      // it belongs to, and restoring entries first would leave them dangling
      // for the length of the restore.
      for (final raw in (steps['days'] as List? ?? const [])) {
        try {
          await d.into(d.stepDailyData).insertOnConflictUpdate(
              db.StepDayRow.fromJson(Map<String, dynamic>.from(raw as Map))
                  .toCompanion(false));
        } catch (e) {
          debugPrint('Import step day failed: $e');
        }
      }
      for (final raw in (steps['manualEntries'] as List? ?? const [])) {
        try {
          await d.into(d.stepManualEntries).insertOnConflictUpdate(
              db.StepManualEntryRow.fromJson(
                      Map<String, dynamic>.from(raw as Map))
                  .toCompanion(false));
        } catch (e) {
          debugPrint('Import manual step entry failed: $e');
        }
      }
    }

    final profile = data[healthProfileKey];
    if (profile is Map) {
      try {
        await d.into(d.healthProfiles).insertOnConflictUpdate(
            db.HealthProfileRow.fromJson(Map<String, dynamic>.from(profile))
                .toCompanion(false));
      } catch (e) {
        debugPrint('Import health profile failed: $e');
      }
    }
  }

  /// The tables an OVERWRITE restore may wipe first, and no others.
  ///
  /// `period_settings` and `health_profiles` are deliberately absent. Both are
  /// single-row configuration keyed by a fixed id, so [importJson]'s upsert
  /// already replaces them outright — clearing first would buy nothing and
  /// would destroy the local `cloudSyncEnabled` consent this import is
  /// supposed to preserve by reading it back.
  ///
  /// `menstrual_cycles` is absent for the mirror-image reason: [exportJson]
  /// does not carry it, so wiping it here would delete data the restore cannot
  /// put back.
  ///
  /// [forBackup] applies that same rule per FILE rather than per format — see
  /// `CleanStorageService.clearRestorableData`. A v5 backup, written before
  /// these sections existed, carries none of these keys: wiping the tables for
  /// it would delete every night slept and every hand-typed step entry with
  /// nothing to restore them. Null means "a current export", where all three
  /// keys are always present.
  static Future<void> clearRestorableRows({
    Map<String, dynamic>? forBackup,
  }) async {
    final d = _db;
    bool carries(String key) => forBackup == null || forBackup.containsKey(key);
    if (carries(sleepKey)) await d.delete(d.sleepSessions).go();
    if (carries(periodKey)) await d.delete(d.periodDays).go();
    if (carries(stepsKey)) {
      // Entries before days: the entries reference the day id.
      await d.delete(d.stepManualEntries).go();
      await d.delete(d.stepDailyData).go();
    }
  }
}
