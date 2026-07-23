// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_dao.dart';

// ignore_for_file: type=lint
mixin _$AiDaoMixin on DatabaseAccessor<AppDatabase> {
  $KnowledgeChunksTable get knowledgeChunks => attachedDatabase.knowledgeChunks;
  $AssistantMemoriesTable get assistantMemories =>
      attachedDatabase.assistantMemories;
  AiDaoManager get managers => AiDaoManager(this);
}

class AiDaoManager {
  final _$AiDaoMixin _db;
  AiDaoManager(this._db);
  $$KnowledgeChunksTableTableManager get knowledgeChunks =>
      $$KnowledgeChunksTableTableManager(
        _db.attachedDatabase,
        _db.knowledgeChunks,
      );
  $$AssistantMemoriesTableTableManager get assistantMemories =>
      $$AssistantMemoriesTableTableManager(
        _db.attachedDatabase,
        _db.assistantMemories,
      );
}
