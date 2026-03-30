import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/notes_tables.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes, Folders, Tags])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(AppDatabase db) : super(db);

  // ============ NOTES ============

  Future<List<Note>> getAllNotes() async {
    return await (select(notes)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .get();
  }

  Future<List<Note>> getPinnedNotes() async {
    return await (select(notes)
      ..where((t) => t.isDeleted.equals(false) & t.isPinned.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .get();
  }

  Future<List<Note>> getArchivedNotes() async {
    return await (select(notes)
      ..where((t) => t.isDeleted.equals(false) & t.isArchived.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .get();
  }

  Future<Note?> getNote(String id) async {
    return await (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> saveNote(NotesCompanion note) async {
    await into(notes).insertOnConflictUpdate(note);
  }

  Future<void> deleteNote(String id) async {
    await (delete(notes)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Note>> watchNotes() {
    return (select(notes)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();
  }

  // ============ FOLDERS ============

  Future<List<Folder>> getAllFolders() async {
    return await select(folders).get();
  }

  Future<void> saveFolder(FoldersCompanion folder) async {
    await into(folders).insertOnConflictUpdate(folder);
  }

  Future<void> deleteFolder(String id) async {
    await (delete(folders)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Folder>> watchFolders() => select(folders).watch();

  // ============ TAGS ============

  Future<List<Tag>> getAllTags() async {
    return await select(tags).get();
  }

  Future<void> saveTag(TagsCompanion tag) async {
    await into(tags).insertOnConflictUpdate(tag);
  }

  Future<void> deleteTag(String id) async {
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Tag>> watchTags() => select(tags).watch();
}
