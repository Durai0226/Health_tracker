import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:health/health.dart'
    show HealthDataPoint, HealthDataType, NumericHealthValue;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/vitals_dao.dart';
import '../../../core/health/health_record_ids.dart';
import '../../../core/health/health_sample_origin.dart';
import '../../../core/health/vitals_analyzer.dart';
import '../../../core/services/active_profile_service.dart';
import '../../../core/services/health_data_service.dart';
import '../models/blood_pressure_reading.dart';
import '../models/glucose_reading.dart';
import '../models/weight_reading.dart';
import '../models/mood_entry.dart';

/// Drift-backed storage facade for the vitals trackers (blood pressure + blood
/// glucose), mirroring `MedicineCleanStorageService`: all-static, a `revision`
/// notifier for live refresh, and domain↔companion mappers kept out of the
/// models. Denormalized category/class indices are recomputed on every write.
class VitalsStorageService {
  static VitalsDao get _dao => db.AppDatabase.instance.vitalsDao;

  /// Bumped on any vitals mutation so kept-alive screens can refresh live.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static int _batchDepth = 0;
  static bool _bumpOwed = false;

  static void _bump() {
    if (_batchDepth > 0) {
      _bumpOwed = true;
    } else {
      revision.value++;
    }
  }

  /// Runs [body], which saves many readings, as ONE transaction, and tells
  /// listeners ONCE when it is done instead of once per reading.
  ///
  /// Every save bumps [revision], and a screen that follows it reloads on each
  /// bump: an import of a few hundred readings was a few hundred reloads of the
  /// whole list while it was still being written. Inside this, the bumps are
  /// collected into one, sent when the outermost batch ends, after the commit.
  /// Nothing is sent if nothing was saved.
  ///
  /// If [body] throws, all of it is rolled back and the error goes on to the caller:
  /// an import that did not get as far as remembering what it had seen finds
  /// nothing half done, and tries the lot again. Listeners are still told, since
  /// another batch running at the same moment may have saved something, and a
  /// reload that finds nothing changed costs far less than one that was skipped.
  ///
  /// One transaction also means one write to disk rather than one per reading,
  /// which for an app that writes a reading every few minutes is the difference
  /// between a moment and minutes.
  ///
  /// Save with `syncToHealthConnect: false` in here: the share-out is started
  /// without being awaited and would run on after the transaction has closed. Every
  /// bulk save (an import, a restore) is a reading that came from somewhere else,
  /// and is not shared back out anyway.
  static Future<T> batch<T>(Future<T> Function() body) async {
    _batchDepth++;
    try {
      return await db.AppDatabase.instance.transaction(body);
    } finally {
      _batchDepth--;
      if (_batchDepth == 0 && _bumpOwed) {
        _bumpOwed = false;
        revision.value++;
      }
    }
  }

  static Future<void> init() async {
    // DB is initialized centrally (AppDatabase.instance); nothing to preload.
  }

  /// See `MedicineCleanStorageService._inActiveProfile` — same "null means
  /// self" contract, applied to vitals readings.
  static bool _inActiveProfile(String? dependentId) {
    final active = ActiveProfileService().activeDependentId;
    return active == null ? dependentId == null : dependentId == active;
  }

  /// A brand-new reading with no explicit owner belongs to whoever is
  /// currently active; one that already carries a `dependentId` is left
  /// alone. See `MedicineCleanStorageService._stampActiveProfile`.
  static String? _stampedDependentId(String? existing) {
    if (existing != null) return existing;
    return ActiveProfileService().activeDependentId;
  }

  // ============ HEALTH CONNECT / HEALTHKIT SYNC (opt-in) ============
  //
  // Duplicate-write avoidance is a Dart-level flag per reading id, set only
  // after a write actually succeeds — a failed write leaves the flag unset so
  // the next save/retry tries again. On Android the write ALSO carries a name
  // (clientRecordId, see HealthRecordIds), which is what lets an edit replace the
  // record and a delete remove it; the Dart flag stays the dedup mechanism because
  // the name is a Health Connect concept the iOS side ignores. See
  // HealthDataService.vitalsWriteTypes' doc.

  static const String _syncEnabledKey = 'health_connect_vitals_sync_enabled';

  static Future<bool> isHealthConnectSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncEnabledKey) ?? false;
  }

  static Future<void> setHealthConnectSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, enabled);
  }

  static String _syncedFlagKey(String readingId) =>
      'health_connect_synced_$readingId';

  static Future<bool> _alreadySynced(String readingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncedFlagKey(readingId)) ?? false;
  }

  static Future<void> _markSynced(String readingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncedFlagKey(readingId), true);
  }

  // A reading whose platform record was written under a name (HealthRecordIds) can
  // be replaced by an edit and deleted with the reading. Only those: a reading sent
  // before the names existed has a record nothing can find again, and rewriting it
  // would make a second one. Android only; see [HealthRecordIds].
  static String _namedFlagKey(String readingId) =>
      'health_connect_named_$readingId';

  static Future<bool> _isNamed(String readingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_namedFlagKey(readingId)) ?? false;
  }

  /// Both flags, once a write under a name has landed.
  static Future<void> _markWritten(String readingId) async {
    await _markSynced(readingId);
    if (HealthRecordIds.supported(defaultTargetPlatform)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_namedFlagKey(readingId), true);
    }
  }

  /// Whether [readingId] is to be written now: not yet sent, or sent under a name
  /// and so replaceable by this edit.
  static Future<bool> _shouldWrite(String readingId) async {
    if (!await _alreadySynced(readingId)) return true;
    return _isNamed(readingId);
  }

  /// A deleted reading comes out of the health store too, when it went in under a
  /// name. Both flags are cleared once it has, so that Undo — which saves the same id
  /// again — writes it afresh instead of finding it "already sent".
  ///
  /// Best-effort and never throws, like the write: a store that cannot be reached
  /// leaves the record where it is, and the flags with it, which is what the
  /// reading looked like before this existed.
  static Future<void> _withdraw(
      String readingId, HealthDataType type, String clientRecordId) async {
    try {
      if (!await _isNamed(readingId)) return;
      final ok = await HealthDataService.instance
          .deleteByClientId(type, clientRecordId);
      if (!ok) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_syncedFlagKey(readingId));
      await prefs.remove(_namedFlagKey(readingId));
    } catch (e) {
      debugPrint('⚠️ Health Connect withdraw failed: $e');
    }
  }

  /// Best-effort, never throws, never blocks the local save that triggered
  /// it — deliberately NOT awaited by [saveBp]/[saveGlucose] (fire-and-forget)
  /// since the underlying plugin call has no timeout; a slow/hanging Health
  /// Connect/HealthKit provider must never stall a save the user is waiting on.
  static Future<void> _syncBpIfEnabled(BloodPressureReading r) async {
    try {
      // A reading that came FROM the store is not sent back to it — not even when
      // the person edits it, which is a save like any other.
      if (HealthSampleOrigin.cameFromTheStore(r.id)) return;
      if (!await isHealthConnectSyncEnabled()) return;
      if (!await _shouldWrite(r.id)) return;
      final ok = await HealthDataService.instance.writeBloodPressure(r,
          clientRecordId: HealthRecordIds.bloodPressure(r.id));
      if (ok) await _markWritten(r.id);
    } catch (e) {
      debugPrint('⚠️ Health Connect BP sync failed: $e');
    }
  }

  /// See [_syncBpIfEnabled]'s doc.
  static Future<void> _syncGlucoseIfEnabled(GlucoseReading r) async {
    try {
      if (HealthSampleOrigin.cameFromTheStore(r.id)) return;
      if (!await isHealthConnectSyncEnabled()) return;
      if (!await _shouldWrite(r.id)) return;
      final ok = await HealthDataService.instance
          .writeGlucose(r, clientRecordId: HealthRecordIds.glucose(r.id));
      if (ok) await _markWritten(r.id);
    } catch (e) {
      debugPrint('⚠️ Health Connect glucose sync failed: $e');
    }
  }

  /// See [_syncBpIfEnabled]'s doc. Weight shares the same sync toggle as BP
  /// and glucose (one "Share with Health Connect" switch), not a separate one.
  static Future<void> _syncWeightIfEnabled(WeightReading r) async {
    try {
      if (HealthSampleOrigin.cameFromTheStore(r.id)) return;
      if (!await isHealthConnectSyncEnabled()) return;
      if (!await _shouldWrite(r.id)) return;
      final ok = await HealthDataService.instance
          .writeWeight(r, clientRecordId: HealthRecordIds.weight(r.id));
      if (ok) await _markWritten(r.id);
    } catch (e) {
      debugPrint('⚠️ Health Connect weight sync failed: $e');
    }
  }

  // ============ BLOOD PRESSURE ============

  static Future<List<BloodPressureReading>> getAllBp({
    bool scopeToActiveProfile = true,
  }) async {
    final rows = await _dao.getAllBp();
    final domain = rows.map(_bpToDomain).toList();
    return scopeToActiveProfile
        ? domain.where((r) => _inActiveProfile(r.dependentId)).toList()
        : domain;
  }

  static Future<List<BloodPressureReading>> getBpForRange(
    DateTime from,
    DateTime to, {
    bool scopeToActiveProfile = true,
  }) async {
    final rows = await _dao.getBpForRange(from, to);
    final domain = rows.map(_bpToDomain).toList();
    return scopeToActiveProfile
        ? domain.where((r) => _inActiveProfile(r.dependentId)).toList()
        : domain;
  }

  /// [stampActiveProfile] must be false when restoring a backup — see
  /// `MedicineCleanStorageService.saveMedicine`'s doc for why. [syncToHealthConnect]
  /// must be false there too, or restoring years of history would bulk-write
  /// every reading to Health Connect on first launch on a new device.
  ///
  /// On Android an edit is sent too: the reading's platform record was written under
  /// a name ([HealthRecordIds]) and the same name written again replaces it, so the
  /// store gets the corrected reading rather than a second one. A reading sent before
  /// the names existed, and any reading on an iPhone, is once-per-id as it always was:
  /// its record cannot be found again, and re-sending would pile up duplicates.
  static Future<void> saveBp(
    BloodPressureReading r, {
    bool stampActiveProfile = true,
    bool syncToHealthConnect = true,
  }) async {
    final toSave = stampActiveProfile
        ? r.copyWith(dependentId: _stampedDependentId(r.dependentId))
        : r;
    await _dao.upsertBp(_bpToCompanion(toSave));
    _bump();
    if (syncToHealthConnect) unawaited(_syncBpIfEnabled(toSave));
  }

  /// Does NOT clear the id's synced flag by itself (a prior version did, to avoid
  /// orphaned flags accumulating). That reopened a worse bug: the delete-confirmation
  /// SnackBar's Undo action re-saves the SAME id, which — with the flag cleared —
  /// passed the "already synced" check and pushed a brand-new, duplicate write to the
  /// store for data that was already there.
  ///
  /// What changed is that on Android the platform record can now be removed: one
  /// written under a name ([HealthRecordIds]) is deleted from the store along with
  /// the reading, and only THEN are the flags cleared, so Undo writes it afresh.
  /// A record written before the names existed (or on an iPhone) cannot be found
  /// again; it stays, with its flag, which is what keeps Undo from duplicating it. The
  /// flag answers "has the store already seen this id's data", which stays true
  /// regardless of whether the LOCAL row currently exists — a stale flag for a
  /// genuinely-deleted (never restored) reading is a harmless, small, slow-growing
  /// leftover, same class of trade-off already accepted for `expiry_notified_*`
  /// flags.
  static Future<void> deleteBp(String id) async {
    await _dao.deleteBp(id);
    _bump();
    unawaited(_withdraw(id, HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthRecordIds.bloodPressure(id)));
  }

  // ============ BLOOD GLUCOSE ============

  static Future<List<GlucoseReading>> getAllGlucose({
    bool scopeToActiveProfile = true,
  }) async {
    final rows = await _dao.getAllGlucose();
    final domain = rows.map(_glucoseToDomain).toList();
    return scopeToActiveProfile
        ? domain.where((r) => _inActiveProfile(r.dependentId)).toList()
        : domain;
  }

  static Future<List<GlucoseReading>> getGlucoseForRange(
    DateTime from,
    DateTime to, {
    bool scopeToActiveProfile = true,
  }) async {
    final rows = await _dao.getGlucoseForRange(from, to);
    final domain = rows.map(_glucoseToDomain).toList();
    return scopeToActiveProfile
        ? domain.where((r) => _inActiveProfile(r.dependentId)).toList()
        : domain;
  }

  /// See [saveBp]'s doc for [stampActiveProfile]/[syncToHealthConnect].
  static Future<void> saveGlucose(
    GlucoseReading r, {
    bool stampActiveProfile = true,
    bool syncToHealthConnect = true,
  }) async {
    final toSave = stampActiveProfile
        ? r.copyWith(dependentId: _stampedDependentId(r.dependentId))
        : r;
    await _dao.upsertGlucose(_glucoseToCompanion(toSave));
    _bump();
    if (syncToHealthConnect) unawaited(_syncGlucoseIfEnabled(toSave));
  }

  /// See [deleteBp]'s doc for why the synced flag is deliberately NOT cleared.
  static Future<void> deleteGlucose(String id) async {
    await _dao.deleteGlucose(id);
    _bump();
    unawaited(
        _withdraw(id, HealthDataType.BLOOD_GLUCOSE, HealthRecordIds.glucose(id)));
  }

  // ============ WEIGHT ============

  static Future<List<WeightReading>> getAllWeight({
    bool scopeToActiveProfile = true,
  }) async {
    final rows = await _dao.getAllWeight();
    final domain = rows.map(_weightToDomain).toList();
    return scopeToActiveProfile
        ? domain.where((r) => _inActiveProfile(r.dependentId)).toList()
        : domain;
  }

  static Future<List<WeightReading>> getWeightForRange(
    DateTime from,
    DateTime to, {
    bool scopeToActiveProfile = true,
  }) async {
    final rows = await _dao.getWeightForRange(from, to);
    final domain = rows.map(_weightToDomain).toList();
    return scopeToActiveProfile
        ? domain.where((r) => _inActiveProfile(r.dependentId)).toList()
        : domain;
  }

  /// See [saveBp]'s doc for [stampActiveProfile]/[syncToHealthConnect] —
  /// [_importWeightSamples] passes `syncToHealthConnect: false` for the same
  /// reason a backup restore does: a reading that came FROM Health
  /// Connect/HealthKit must never be written straight back to it (pointless,
  /// and it would let the write-direction's per-id synced flag get set for a
  /// reading whose id the write direction never actually produced).
  static Future<void> saveWeight(
    WeightReading r, {
    bool stampActiveProfile = true,
    bool syncToHealthConnect = true,
  }) async {
    final toSave = stampActiveProfile
        ? r.copyWith(dependentId: _stampedDependentId(r.dependentId))
        : r;
    await _dao.upsertWeight(_weightToCompanion(toSave));
    _bump();
    if (syncToHealthConnect) unawaited(_syncWeightIfEnabled(toSave));
  }

  /// See [deleteBp]'s doc for why the synced flag is deliberately NOT cleared.
  static Future<void> deleteWeight(String id) async {
    await _dao.deleteWeight(id);
    _bump();
    unawaited(_withdraw(id, HealthDataType.WEIGHT, HealthRecordIds.weight(id)));
  }

  // ---- Health Connect / HealthKit import (weight, read-direction) --------
  //
  // The reverse of [_syncWeightIfEnabled] above: a smart scale or another app
  // may log weight straight into Health Connect/HealthKit without this app
  // ever seeing it, so on request we pull those samples in. An imported
  // sample has no local id yet (unlike the write-direction's per-id synced
  // flag, which only makes sense once a LOCAL reading already exists), so
  // dedup instead works by giving each sample a DETERMINISTIC id derived from
  // its own timestamp: re-running the import over the same samples always
  // re-derives the same id, and [saveWeight]'s upsert-on-id
  // (`insertOnConflictUpdate`, see VitalsDao.upsertWeight) turns a re-import
  // into a no-op update rather than a duplicate row.

  static String _importedWeightId(DateTime sampleStart) =>
      '${HealthSampleOrigin.weightIdPrefix}${sampleStart.millisecondsSinceEpoch}';

  /// Pull weight samples logged directly into Health Connect/HealthKit (e.g.
  /// by a smart scale or another app) into the local Weight tracker. Never
  /// throws — a plugin/read failure yields 0 imported, matching
  /// [HealthDataService]'s own never-throw convention.
  ///
  /// [since] defaults to 90 days back, a reasonable first-import catch-up
  /// window. [samples], if provided, is used INSTEAD of querying the health
  /// plugin — this is the seam a test uses to inject synthetic points, since
  /// the real plugin has no platform channel registered in `flutter test`.
  /// Returns how many readings were newly imported (samples that map to an
  /// id already present locally are skipped and not counted).
  static Future<int> importFromHealthConnect({
    DateTime? since,
    List<HealthDataPoint>? samples,
  }) async {
    try {
      final points = samples ??
          await HealthDataService.instance.readWeightSamples(
            since ?? DateTime.now().subtract(const Duration(days: 90)),
            DateTime.now(),
          );
      return await _importWeightSamples(points);
    } catch (e) {
      debugPrint('⚠️ Health Connect weight import failed: $e');
      return 0;
    }
  }

  /// The testable persist+dedupe half of [importFromHealthConnect]: given
  /// already-fetched samples, saves each new one as a [WeightReading] under
  /// its deterministic id (`syncToHealthConnect: false` — see [saveWeight]'s
  /// doc for why an imported reading must never be written straight back
  /// out) and returns how many were actually new.
  static Future<int> _importWeightSamples(List<HealthDataPoint> points) async {
    final existingIds = (await getAllWeight(scopeToActiveProfile: false))
        .map((r) => r.id)
        .toSet();
    final now = DateTime.now();
    var imported = 0;
    // Never this app's own records: with sharing on, every weight logged here
    // is also in the health store under this app's name, and reading it back
    // would add each one a second time as an import.
    await batch(() async {
      for (final p in HealthSampleOrigin.fromOthers(points)) {
        final value = p.value;
        if (value is! NumericHealthValue) continue; // defensive: unexpected shape
        final id = _importedWeightId(p.dateFrom);
        if (existingIds.contains(id)) continue; // already imported previously
        final reading = WeightReading(
          id: id,
          valueKg: value.numericValue.toDouble(),
          takenAt: p.dateFrom,
          createdAt: now,
        );
        await saveWeight(reading, syncToHealthConnect: false);
        existingIds.add(id);
        imported++;
      }
    });
    return imported;
  }

  // ============ MOOD ============

  static Future<List<MoodEntry>> getAllMood({
    bool scopeToActiveProfile = true,
  }) async {
    final rows = await _dao.getAllMood();
    final domain = rows.map(_moodToDomain).toList();
    return scopeToActiveProfile
        ? domain.where((r) => _inActiveProfile(r.dependentId)).toList()
        : domain;
  }

  static Future<List<MoodEntry>> getMoodForRange(
    DateTime from,
    DateTime to, {
    bool scopeToActiveProfile = true,
  }) async {
    final rows = await _dao.getMoodForRange(from, to);
    final domain = rows.map(_moodToDomain).toList();
    return scopeToActiveProfile
        ? domain.where((r) => _inActiveProfile(r.dependentId)).toList()
        : domain;
  }

  /// Mood has no Health Connect/HealthKit equivalent record type (see
  /// HealthDataService's doc), so there is no sync param here — unlike
  /// [saveBp]/[saveGlucose]/[saveWeight], it is purely local.
  static Future<void> saveMood(
    MoodEntry r, {
    bool stampActiveProfile = true,
  }) async {
    final toSave = stampActiveProfile
        ? r.copyWith(dependentId: _stampedDependentId(r.dependentId))
        : r;
    await _dao.upsertMood(_moodToCompanion(toSave));
    _bump();
  }

  static Future<void> deleteMood(String id) async {
    await _dao.deleteMood(id);
    _bump();
  }

  // ============ BACKUP ============

  /// Snapshot of all vitals for the backup file. Unscoped: a backup taken
  /// while one profile is active must still capture every OTHER profile's
  /// readings too, or restoring it would silently lose them.
  static Future<Map<String, dynamic>> exportJson() async {
    final bp = await getAllBp(scopeToActiveProfile: false);
    final gl = await getAllGlucose(scopeToActiveProfile: false);
    final wt = await getAllWeight(scopeToActiveProfile: false);
    final md = await getAllMood(scopeToActiveProfile: false);
    return {
      'bloodPressure': bp.map((r) => r.toJson()).toList(),
      'glucose': gl.map((r) => r.toJson()).toList(),
      'weight': wt.map((r) => r.toJson()).toList(),
      'mood': md.map((r) => r.toJson()).toList(),
    };
  }

  /// Restore vitals from a backup snapshot (non-destructive upsert). Does not
  /// stamp the active profile — each reading's `dependentId` from the backup
  /// (including a legitimate null for a self-owned reading) is authoritative.
  static Future<void> importJson(Map<String, dynamic> data) => batch(() async {
        for (final r in (data['bloodPressure'] as List? ?? const [])) {
          try {
            await saveBp(BloodPressureReading.fromJson(Map<String, dynamic>.from(r)),
                stampActiveProfile: false, syncToHealthConnect: false);
          } catch (_) {/* skip malformed */}
        }
        for (final r in (data['glucose'] as List? ?? const [])) {
          try {
            await saveGlucose(GlucoseReading.fromJson(Map<String, dynamic>.from(r)),
                stampActiveProfile: false, syncToHealthConnect: false);
          } catch (_) {/* skip malformed */}
        }
        for (final r in (data['weight'] as List? ?? const [])) {
          try {
            await saveWeight(WeightReading.fromJson(Map<String, dynamic>.from(r)),
                stampActiveProfile: false, syncToHealthConnect: false);
          } catch (_) {/* skip malformed */}
        }
        for (final r in (data['mood'] as List? ?? const [])) {
          try {
            await saveMood(MoodEntry.fromJson(Map<String, dynamic>.from(r)),
                stampActiveProfile: false);
          } catch (_) {/* skip malformed */}
        }
      });

  // ============ MAPPERS ============

  static BloodPressureReading _bpToDomain(db.BloodPressureReading d) {
    return BloodPressureReading(
      id: d.id,
      dependentId: d.dependentId,
      systolic: d.systolic,
      diastolic: d.diastolic,
      pulse: d.pulse,
      arm: d.armIndex != null ? BpArm.values[d.armIndex!] : null,
      position:
          d.positionIndex != null ? BpPosition.values[d.positionIndex!] : null,
      takenAt: d.takenAt,
      tags: _decodeTags(d.tagsJson),
      note: d.note,
      createdAt: d.createdAt,
    );
  }

  static db.BloodPressureReadingsCompanion _bpToCompanion(
      BloodPressureReading r) {
    return db.BloodPressureReadingsCompanion(
      id: drift.Value(r.id),
      dependentId: drift.Value(r.dependentId),
      systolic: drift.Value(r.systolic),
      diastolic: drift.Value(r.diastolic),
      pulse: drift.Value(r.pulse),
      armIndex: drift.Value(r.arm?.index),
      positionIndex: drift.Value(r.position?.index),
      takenAt: drift.Value(r.takenAt),
      tagsJson: drift.Value(r.tags.isEmpty ? null : jsonEncode(r.tags)),
      note: drift.Value(r.note),
      categoryIndex: drift.Value(
          VitalsAnalyzer.classifyBp(r.systolic, r.diastolic).index),
      createdAt: drift.Value(r.createdAt),
      // ---- sync columns (schema v13) ----
      //
      // `deletedAt: null` is load-bearing, not tidiness. Deletes are tombstones
      // now and saves are insertOnConflictUpdate, so re-saving a previously
      // deleted id would otherwise leave the tombstone standing and the row
      // invisible forever. The delete-confirmation SnackBar's Undo re-saves the
      // SAME id (see deleteBp's doc), so that is the normal path here, not an
      // edge case. Same three lines on all four mappers below.
      updatedAt: drift.Value(DateTime.now()),
      deletedAt: const drift.Value(null),
      synced: const drift.Value(false),
    );
  }

  static GlucoseReading _glucoseToDomain(db.GlucoseReading d) {
    return GlucoseReading(
      id: d.id,
      dependentId: d.dependentId,
      valueMgdl: d.valueMgdl,
      context: GlucoseContext.values[d.contextIndex],
      takenAt: d.takenAt,
      carbs: d.carbs,
      insulinUnits: d.insulinUnits,
      medNote: d.medNote,
      tags: _decodeTags(d.tagsJson),
      note: d.note,
      createdAt: d.createdAt,
    );
  }

  static db.GlucoseReadingsCompanion _glucoseToCompanion(GlucoseReading r) {
    return db.GlucoseReadingsCompanion(
      id: drift.Value(r.id),
      dependentId: drift.Value(r.dependentId),
      valueMgdl: drift.Value(r.valueMgdl),
      contextIndex: drift.Value(r.context.index),
      takenAt: drift.Value(r.takenAt),
      carbs: drift.Value(r.carbs),
      insulinUnits: drift.Value(r.insulinUnits),
      medNote: drift.Value(r.medNote),
      tagsJson: drift.Value(r.tags.isEmpty ? null : jsonEncode(r.tags)),
      note: drift.Value(r.note),
      classIndex: drift.Value(
          VitalsAnalyzer.classifyGlucose(r.valueMgdl, r.context).index),
      createdAt: drift.Value(r.createdAt),
      updatedAt: drift.Value(DateTime.now()),
      deletedAt: const drift.Value(null), // clears a tombstone on Undo
      synced: const drift.Value(false),
    );
  }

  static WeightReading _weightToDomain(db.WeightReading d) {
    return WeightReading(
      id: d.id,
      dependentId: d.dependentId,
      valueKg: d.valueKg,
      takenAt: d.takenAt,
      tags: _decodeTags(d.tagsJson),
      note: d.note,
      createdAt: d.createdAt,
    );
  }

  static db.WeightReadingsCompanion _weightToCompanion(WeightReading r) {
    return db.WeightReadingsCompanion(
      id: drift.Value(r.id),
      dependentId: drift.Value(r.dependentId),
      valueKg: drift.Value(r.valueKg),
      takenAt: drift.Value(r.takenAt),
      tagsJson: drift.Value(r.tags.isEmpty ? null : jsonEncode(r.tags)),
      note: drift.Value(r.note),
      createdAt: drift.Value(r.createdAt),
      updatedAt: drift.Value(DateTime.now()),
      deletedAt: const drift.Value(null), // clears a tombstone on Undo
      synced: const drift.Value(false),
    );
  }

  static MoodEntry _moodToDomain(db.MoodEntry d) {
    return MoodEntry(
      id: d.id,
      dependentId: d.dependentId,
      moodIndex: d.moodIndex,
      takenAt: d.takenAt,
      tags: _decodeTags(d.tagsJson),
      note: d.note,
      createdAt: d.createdAt,
    );
  }

  static db.MoodEntriesCompanion _moodToCompanion(MoodEntry r) {
    return db.MoodEntriesCompanion(
      id: drift.Value(r.id),
      dependentId: drift.Value(r.dependentId),
      moodIndex: drift.Value(r.moodIndex),
      takenAt: drift.Value(r.takenAt),
      tagsJson: drift.Value(r.tags.isEmpty ? null : jsonEncode(r.tags)),
      note: drift.Value(r.note),
      createdAt: drift.Value(r.createdAt),
      updatedAt: drift.Value(DateTime.now()),
      deletedAt: const drift.Value(null), // clears a tombstone on Undo
      synced: const drift.Value(false),
    );
  }

  static List<String> _decodeTags(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      return List<String>.from(jsonDecode(json) as List);
    } catch (_) {
      return const [];
    }
  }
}
