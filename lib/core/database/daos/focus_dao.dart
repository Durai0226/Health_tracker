import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../app_database.dart';
import '../tables/focus_tables.dart';

part 'focus_dao.g.dart';

/// Focus session history.
///
/// Same contract as the other DAOs: `insertOnConflictUpdate` everywhere (never
/// insert-then-update), soft deletes, and ordinary reads filter
/// `deletedAt.isNull()`. The `*IncludingDeleted` variant exists only for cloud
/// sync, which has to see tombstones to propagate a deletion.
///
/// Note what is deliberately absent: any `LIMIT`. The whole reason this table
/// exists is that the preference blob it replaces was capped at 100 sessions and
/// silently destroyed the rest.
@DriftAccessor(tables: [FocusSessions])
class FocusDao extends DatabaseAccessor<AppDatabase> with _$FocusDaoMixin {
  FocusDao(AppDatabase db) : super(db);

  /// Newest first — the order every caller already assumes, because
  /// `FocusService` prepends.
  Future<List<FocusSessionRow>> getAll() {
    return (select(focusSessions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<FocusSessionRow?> getById(String id) {
    return (select(focusSessions)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Cloud-sync only — tombstones included.
  Future<List<FocusSessionRow>> getAllIncludingDeleted() {
    return (select(focusSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<void> upsert(FocusSessionsCompanion row) =>
      into(focusSessions).insertOnConflictUpdate(row);

  /// One transaction for the whole batch.
  ///
  /// Used by the migration off the preference blob and by backup restore. A row
  /// at a time would make a partial import possible; batched, either the whole
  /// set lands or none of it does.
  Future<void> upsertAll(List<FocusSessionsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(focusSessions, rows));
  }

  /// Soft delete, so a cloud sync can propagate the removal.
  Future<void> softDelete(String id, DateTime now) {
    return (update(focusSessions)..where((t) => t.id.equals(id))).write(
      FocusSessionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }

  Future<int> countAll() async {
    final q = selectOnly(focusSessions)
      ..addColumns([focusSessions.id.count()])
      ..where(focusSessions.deletedAt.isNull());
    final row = await q.getSingle();
    return row.read(focusSessions.id.count()) ?? 0;
  }

  /// Apply a cloud document.
  ///
  /// `FocusSessionRow.fromJson` is Drift-generated and strict about types, so a
  /// malformed or partially-written cloud doc would throw here. Caught and
  /// logged rather than propagated: one bad remote row must not abort the sync
  /// for every other session.
  Future<void> upsertRaw(Map<String, dynamic> json) async {
    try {
      await into(focusSessions)
          .insertOnConflictUpdate(FocusSessionRow.fromJson(json).toCompanion(false));
    } catch (e) {
      debugPrint('Skipping unreadable cloud focus session: $e');
    }
  }

  /// Everything, tombstones included. Test and delete-all-data support.
  Future<void> deleteEverything() => delete(focusSessions).go();
}
