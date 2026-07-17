import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/vitals_dao.dart';
import '../../../core/ai/vitals_analyzer.dart';
import '../models/blood_pressure_reading.dart';
import '../models/glucose_reading.dart';

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

  // ============ BLOOD PRESSURE ============

  static Future<List<BloodPressureReading>> getAllBp() async {
    final rows = await _dao.getAllBp();
    return rows.map(_bpToDomain).toList();
  }

  static Future<List<BloodPressureReading>> getBpForRange(
      DateTime from, DateTime to) async {
    final rows = await _dao.getBpForRange(from, to);
    return rows.map(_bpToDomain).toList();
  }

  static Future<void> saveBp(BloodPressureReading r) async {
    await _dao.upsertBp(_bpToCompanion(r));
    _bump();
  }

  static Future<void> deleteBp(String id) async {
    await _dao.deleteBp(id);
    _bump();
  }

  // ============ BLOOD GLUCOSE ============

  static Future<List<GlucoseReading>> getAllGlucose() async {
    final rows = await _dao.getAllGlucose();
    return rows.map(_glucoseToDomain).toList();
  }

  static Future<List<GlucoseReading>> getGlucoseForRange(
      DateTime from, DateTime to) async {
    final rows = await _dao.getGlucoseForRange(from, to);
    return rows.map(_glucoseToDomain).toList();
  }

  static Future<void> saveGlucose(GlucoseReading r) async {
    await _dao.upsertGlucose(_glucoseToCompanion(r));
    _bump();
  }

  static Future<void> deleteGlucose(String id) async {
    await _dao.deleteGlucose(id);
    _bump();
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

  static List<String> _decodeTags(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      return List<String>.from(jsonDecode(json) as List);
    } catch (_) {
      return const [];
    }
  }
}
