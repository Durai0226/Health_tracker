import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:health/health.dart' show HealthDataPoint, NumericHealthValue;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/vitals_dao.dart';
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
  static void _bump() => revision.value++;

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
  // `package:health` has no clientRecordId/upsert support (see
  // HealthDataService.vitalsWriteTypes' doc), so duplicate-write avoidance is
  // a Dart-level flag per reading id, set only after a write actually
  // succeeds — a failed write leaves the flag unset so the next save/retry
  // tries again.

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

  /// Best-effort, never throws, never blocks the local save that triggered
  /// it — deliberately NOT awaited by [saveBp]/[saveGlucose] (fire-and-forget)
  /// since the underlying plugin call has no timeout; a slow/hanging Health
  /// Connect/HealthKit provider must never stall a save the user is waiting on.
  static Future<void> _syncBpIfEnabled(BloodPressureReading r) async {
    try {
      if (!await isHealthConnectSyncEnabled()) return;
      if (await _alreadySynced(r.id)) return;
      final ok = await HealthDataService.instance.writeBloodPressure(r);
      if (ok) await _markSynced(r.id);
    } catch (e) {
      debugPrint('⚠️ Health Connect BP sync failed: $e');
    }
  }

  /// See [_syncBpIfEnabled]'s doc.
  static Future<void> _syncGlucoseIfEnabled(GlucoseReading r) async {
    try {
      if (!await isHealthConnectSyncEnabled()) return;
      if (await _alreadySynced(r.id)) return;
      final ok = await HealthDataService.instance.writeGlucose(r);
      if (ok) await _markSynced(r.id);
    } catch (e) {
      debugPrint('⚠️ Health Connect glucose sync failed: $e');
    }
  }

  /// See [_syncBpIfEnabled]'s doc. Weight shares the same sync toggle as BP
  /// and glucose (one "Share with Health Connect" switch), not a separate one.
  static Future<void> _syncWeightIfEnabled(WeightReading r) async {
    try {
      if (!await isHealthConnectSyncEnabled()) return;
      if (await _alreadySynced(r.id)) return;
      final ok = await HealthDataService.instance.writeWeight(r);
      if (ok) await _markSynced(r.id);
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
  /// Sync is once-per-id: a later edit to an already-synced reading does NOT
  /// push the correction, since the plugin gives us no way to update or
  /// delete a specific prior write (see HealthDataService.vitalsWriteTypes'
  /// doc) — re-syncing on every edit would instead pile up duplicates.
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

  /// Deliberately does NOT clear the id's synced flag (a prior version of
  /// this method did, to avoid orphaned flags accumulating). That reopened a
  /// worse bug: the delete-confirmation SnackBar's Undo action re-saves the
  /// SAME id, which — with the flag cleared — passed the "already synced"
  /// check and pushed a brand-new, duplicate write to Health Connect/HealthKit
  /// for data that was already there (the plugin has no delete/update API, so
  /// the original write is never actually removed by a local delete anyway).
  /// The flag answers "has Health Connect already seen this id's data",
  /// which stays true regardless of whether the LOCAL row currently exists —
  /// a stale flag for a genuinely-deleted (never restored) reading is a
  /// harmless, small, unbounded-but-slow-growing leftover, same class of
  /// trade-off already accepted for `expiry_notified_*` flags.
  static Future<void> deleteBp(String id) async {
    await _dao.deleteBp(id);
    _bump();
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
      'hc_import_${sampleStart.millisecondsSinceEpoch}';

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
    for (final p in points) {
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
  static Future<void> importJson(Map<String, dynamic> data) async {
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
  }

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
