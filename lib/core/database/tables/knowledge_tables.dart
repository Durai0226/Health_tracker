import 'package:drift/drift.dart';

/// Curated, versioned knowledge base for the on-device RAG assistant. Records
/// are seeded from the bundled `assets/ai/knowledge_base.json`. A companion FTS5
/// virtual table `knowledge_fts(chunk_id UNINDEXED, title, body, topic)` is
/// created via raw SQL in the DB migration (Drift's DSL can't declare FTS5) and
/// queried with `MATCH` + `bm25()` from `AiDao.searchKb`.
@DataClassName('KnowledgeChunkRow')
class KnowledgeChunks extends Table {
  TextColumn get id => text()();
  TextColumn get topic => text()(); // cycle, hydration, sleep, activity, medication, vitals
  TextColumn get title => text()();
  TextColumn get body => text()(); // 1–3 curated, non-diagnostic sentences
  TextColumn get source => text().nullable()();
  IntColumn get kbVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
