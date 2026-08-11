import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/diary_dao.dart';
import '../../../core/services/active_profile_service.dart';
import '../models/diary_entry.dart';

/// Drift-backed storage facade for the diary/journal feature, mirroring
/// VitalsStorageService's pattern: all-static, a `revision` notifier for live
/// refresh, ActiveProfileService-based scoping, and domain<->companion
/// mappers kept out of the model.
class DiaryStorageService {
  static DiaryDao get _dao => db.AppDatabase.instance.diaryDao;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static void _bump() => revision.value++;

  /// See MedicineCleanStorageService._inActiveProfile — same "null means
  /// self" contract.
  static bool _inActiveProfile(String? dependentId) {
    final active = ActiveProfileService().activeDependentId;
    return active == null ? dependentId == null : dependentId == active;
  }

  static String? _stampedDependentId(String? existing) {
    if (existing != null) return existing;
    return ActiveProfileService().activeDependentId;
  }

  static Future<List<DiaryEntry>> getAll({bool scopeToActiveProfile = true}) async {
    final rows = await _dao.getAll();
    final domain = rows.map(_toDomain).toList();
    return scopeToActiveProfile
        ? domain.where((e) => _inActiveProfile(e.dependentId)).toList()
        : domain;
  }

  static Future<List<DiaryEntry>> getForRange(
    DateTime from,
    DateTime to, {
    bool scopeToActiveProfile = true,
  }) async {
    final rows = await _dao.getForRange(from, to);
    final domain = rows.map(_toDomain).toList();
    return scopeToActiveProfile
        ? domain.where((e) => _inActiveProfile(e.dependentId)).toList()
        : domain;
  }

  /// [stampActiveProfile] must be false when restoring a backup — see
  /// MedicineCleanStorageService.saveMedicine's doc for why.
  static Future<void> save(DiaryEntry entry, {bool stampActiveProfile = true}) async {
    final toSave = stampActiveProfile
        ? entry.copyWith(dependentId: _stampedDependentId(entry.dependentId))
        : entry;
    await _dao.upsert(_toCompanion(toSave));
    _bump();
  }

  static Future<void> delete(String id) async {
    await _dao.deleteEntry(id);
    _bump();
  }

  // ============ BACKUP ============

  /// Unscoped: a backup taken while one profile is active must still
  /// capture every OTHER profile's entries too.
  static Future<List<Map<String, dynamic>>> exportJson() async {
    final all = await getAll(scopeToActiveProfile: false);
    return all.map((e) => e.toJson()).toList();
  }

  static Future<void> importJson(List<dynamic> data) async {
    for (final e in data) {
      try {
        await save(DiaryEntry.fromJson(Map<String, dynamic>.from(e)),
            stampActiveProfile: false);
      } catch (_) {/* skip malformed */}
    }
  }

  // ============ MAPPERS ============

  static DiaryEntry _toDomain(db.DiaryEntry d) {
    return DiaryEntry(
      id: d.id,
      dependentId: d.dependentId,
      title: d.title,
      body: d.body,
      entryAt: d.entryAt,
      createdAt: d.createdAt,
    );
  }

  static db.DiaryEntriesCompanion _toCompanion(DiaryEntry e) {
    return db.DiaryEntriesCompanion(
      id: drift.Value(e.id),
      dependentId: drift.Value(e.dependentId),
      title: drift.Value(e.title),
      body: drift.Value(e.body),
      entryAt: drift.Value(e.entryAt),
      createdAt: drift.Value(e.createdAt),
    );
  }
}
