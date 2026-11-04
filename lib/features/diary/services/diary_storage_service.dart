import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/diary_dao.dart';
import '../../../core/services/active_profile_service.dart';
import '../../../core/services/photo_store.dart';
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

  /// Delete an entry. Its photo is NOT deleted here: the Diary offers Undo, which saves
  /// the entry back with the photo it had, and a file already gone would leave it
  /// pointing at nothing. The file is nothing's once the entry stays deleted, and
  /// `PhotoSweep` removes it the next time the app starts.
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
    // A photo is not in a backup file, only its name. An entry restored over one that
    // is here keeps the photo it has; one restored into an empty table (an overwrite
    // restore, or the rollback of a failed one, both clear the rows first) gets back
    // the photo the file names, if that file is still on this phone. On another phone
    // it is not, and the entry simply has no photo.
    final photos = {
      for (final r in await _dao.getAll())
        if (r.photoPath != null) r.id: r.photoPath!,
    };
    for (final e in data) {
      try {
        final raw = Map<String, dynamic>.from(e);
        final entry = DiaryEntry.fromJson(raw);
        final photo = photos[entry.id] ?? await PhotoStore.locate(raw['photoFile'] as String?);
        await save(entry.copyWith(photoPath: photo), stampActiveProfile: false);
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
      moodIndex: d.moodIndex,
      tags: _decodeTags(d.tagsJson),
      photoPath: d.photoPath,
    );
  }

  /// A malformed value reads as no tags rather than failing the whole list.
  static List<String> _decodeTags(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final v = jsonDecode(json);
      return v is List ? v.whereType<String>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  static db.DiaryEntriesCompanion _toCompanion(DiaryEntry e) {
    return db.DiaryEntriesCompanion(
      id: drift.Value(e.id),
      dependentId: drift.Value(e.dependentId),
      title: drift.Value(e.title),
      body: drift.Value(e.body),
      entryAt: drift.Value(e.entryAt),
      createdAt: drift.Value(e.createdAt),
      moodIndex: drift.Value(e.moodIndex),
      tagsJson: drift.Value(e.tags.isEmpty ? null : jsonEncode(e.tags)),
      photoPath: drift.Value(e.photoPath),
    );
  }
}
