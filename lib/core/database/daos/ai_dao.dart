import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/knowledge_tables.dart';
import '../tables/memory_tables.dart';

part 'ai_dao.g.dart';

/// DAO for the on-device RAG knowledge base (with FTS5/BM25 search) + the
/// user-curated assistant memory store.
@DriftAccessor(tables: [KnowledgeChunks, AssistantMemories])
class AiDao extends DatabaseAccessor<AppDatabase> with _$AiDaoMixin {
  AiDao(AppDatabase db) : super(db);

  // ============ KNOWLEDGE BASE ============
  Future<int> kbVersionStored() async {
    final row = await (select(knowledgeChunks)..limit(1)).getSingleOrNull();
    return row?.kbVersion ?? 0;
  }

  Future<int> kbCount() async {
    final c = countAll();
    final q = selectOnly(knowledgeChunks)..addColumns([c]);
    final r = await q.getSingle();
    return r.read(c) ?? 0;
  }

  Future<void> clearKb() async {
    await delete(knowledgeChunks).go();
    await customStatement('DELETE FROM knowledge_fts');
  }

  Future<void> insertChunk(KnowledgeChunksCompanion row) =>
      into(knowledgeChunks).insertOnConflictUpdate(row);

  Future<void> insertFts(
          String chunkId, String title, String body, String topic) =>
      customStatement(
          'INSERT INTO knowledge_fts(chunk_id, title, body, topic) VALUES (?, ?, ?, ?)',
          [chunkId, title, body, topic]);

  /// FTS5 MATCH + bm25 ranking (title weighted highest). [ftsQuery] must already
  /// be an FTS5 expression (e.g. `"follicular" OR "phase"`). Returns [] when
  /// nothing matches — the caller then ABSTAINS (never guesses).
  Future<List<KnowledgeChunkRow>> searchKb(String ftsQuery, int k) async {
    if (ftsQuery.trim().isEmpty) return const [];
    try {
      final rows = await customSelect(
        'SELECT c.* FROM knowledge_fts f '
        'JOIN knowledge_chunks c ON c.id = f.chunk_id '
        'WHERE knowledge_fts MATCH ? '
        'ORDER BY bm25(knowledge_fts, 5.0, 1.0, 2.0) LIMIT ?',
        variables: [Variable.withString(ftsQuery), Variable.withInt(k)],
        readsFrom: {knowledgeChunks},
      ).get();
      return rows.map((r) => knowledgeChunks.map(r.data)).toList();
    } catch (_) {
      return const [];
    }
  }

  // ============ MEMORIES ============
  Future<List<AssistantMemoryRow>> allMemories() =>
      (select(assistantMemories)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<List<AssistantMemoryRow>> activeMemories() => (select(assistantMemories)
        ..where((t) => t.active.equals(true))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .get();

  Future<void> upsertMemory(AssistantMemoriesCompanion row) =>
      into(assistantMemories).insertOnConflictUpdate(row);

  Future<void> deleteMemory(String id) =>
      (delete(assistantMemories)..where((t) => t.id.equals(id))).go();

  Future<void> clearMemories() => delete(assistantMemories).go();

  /// Supersede prior active memories of the same kind (goal/preference) so a new
  /// one replaces the old instead of contradicting it.
  Future<void> deactivateKind(String kind) =>
      (update(assistantMemories)
            ..where((t) => t.kind.equals(kind) & t.active.equals(true)))
          .write(const AssistantMemoriesCompanion(active: Value(false)));
}
