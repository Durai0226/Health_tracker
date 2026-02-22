import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/storage_service.dart';
import '../models/note_model.dart';
import '../models/tag_model.dart';
import '../services/notes_cloud_service.dart';

class NotesRepository {
  final NotesCloudService _cloudService = NotesCloudService();
  final _uuid = const Uuid();

  // Notes
  List<NoteModel> getAllNotes() {
    return StorageService.getAllNotes();
  }

  Future<NoteModel?> getNote(String id) async {
    return StorageService.getNote(id);
  }

  ValueListenable<Box<NoteModel>> get notesListenable => StorageService.notesListenable;

  Future<String> createNote({
    required String title,
    required String content,
    List<String> tagIds = const [],
    String? color,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final note = NoteModel(
      id: id,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      tagIds: tagIds,
      color: color,
      isSynced: false,
    );
    
    await StorageService.saveNote(note);
    await _cloudService.syncNote(note.copyWith(isSynced: true));
    await StorageService.saveNote(note.copyWith(isSynced: true));
    return id;
  }

  Future<void> updateNote(NoteModel note) async {
    final noteToSave = note.copyWith(
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    
    await StorageService.saveNote(noteToSave);
    await _cloudService.syncNote(noteToSave.copyWith(isSynced: true));
    await StorageService.saveNote(noteToSave.copyWith(isSynced: true));
  }


  /// Soft delete - moves note to trash (can be restored)
  Future<void> deleteNote(String id, {bool permanent = false}) async {
    if (permanent) {
      await StorageService.deleteNote(id);
      await _cloudService.deleteNote(id);
    } else {
      final note = await getNote(id);
      if (note != null) {
        final deletedNote = note.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now(),
          isSynced: false,
        );
        await StorageService.saveNote(deletedNote);
        await _cloudService.syncNote(deletedNote.copyWith(isSynced: true));
        await StorageService.saveNote(deletedNote.copyWith(isSynced: true));
      }
    }
  }

  /// Restore a soft-deleted note from trash
  Future<void> restoreNote(String id) async {
    final note = await getNote(id);
    if (note != null && note.isDeleted) {
      final restoredNote = note.copyWith(
        isDeleted: false,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await StorageService.saveNote(restoredNote);
      await _cloudService.syncNote(restoredNote.copyWith(isSynced: true));
      await StorageService.saveNote(restoredNote.copyWith(isSynced: true));
    }
  }

  /// Permanently delete a note (from trash)
  Future<void> permanentlyDeleteNote(String id) async {
    await deleteNote(id, permanent: true);
  }

  /// Get all notes in trash
  List<NoteModel> getTrashNotes() {
    return getAllNotes().where((n) => n.isDeleted).toList();
  }

  /// Empty trash - permanently delete all trashed notes
  Future<void> emptyTrash() async {
    final trashNotes = getTrashNotes();
    for (final note in trashNotes) {
      await permanentlyDeleteNote(note.id);
    }
  }

  /// Archive a note
  Future<void> archiveNote(String id) async {
    final note = await getNote(id);
    if (note != null) {
      final archivedNote = note.copyWith(
        isArchived: true,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await StorageService.saveNote(archivedNote);
      await _cloudService.syncNote(archivedNote.copyWith(isSynced: true));
      await StorageService.saveNote(archivedNote.copyWith(isSynced: true));
    }
  }

  /// Unarchive a note
  Future<void> unarchiveNote(String id) async {
    final note = await getNote(id);
    if (note != null && note.isArchived) {
      final unarchivedNote = note.copyWith(
        isArchived: false,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await StorageService.saveNote(unarchivedNote);
      await _cloudService.syncNote(unarchivedNote.copyWith(isSynced: true));
      await StorageService.saveNote(unarchivedNote.copyWith(isSynced: true));
    }
  }

  /// Get all archived notes
  List<NoteModel> getArchivedNotes() {
    return getAllNotes().where((n) => n.isArchived && !n.isDeleted).toList();
  }

  /// Get active notes (not deleted, not archived)
  List<NoteModel> getActiveNotes() {
    return getAllNotes().where((n) => !n.isDeleted && !n.isArchived).toList();
  }

  Future<void> togglePin(String id) async {
    final note = StorageService.getNote(id);
    if (note != null) {
      final updatedNote = note.copyWith(
        isPinned: !note.isPinned,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await updateNote(updatedNote);
    }
  }

  Future<void> addTagToNote(String noteId, String tagId) async {
    final note = await getNote(noteId);
    if (note != null && !note.tagIds.contains(tagId)) {
      final updatedTags = [...note.tagIds, tagId];
      await updateNote(note.copyWith(tagIds: updatedTags));
    }
  }

  Future<void> removeTagFromNote(String noteId, String tagId) async {
    final note = await getNote(noteId);
    if (note != null && note.tagIds.contains(tagId)) {
      final updatedTags = note.tagIds.where((id) => id != tagId).toList();
      await updateNote(note.copyWith(tagIds: updatedTags));
    }
  }

  Future<void> setNoteColor(String noteId, String? color) async {
    final note = await getNote(noteId);
    if (note != null) {
      await updateNote(note.copyWith(color: color));
    }
  }

  Future<void> setNoteReminder(String noteId, String? reminderId) async {
    final note = await getNote(noteId);
    if (note != null) {
      await updateNote(note.copyWith(reminderId: reminderId));
    }
  }

  // Tags
  List<TagModel> getAllTags() {
    return StorageService.getAllTags();
  }

  Future<void> createTag(String name, {String? color}) async {
    final tag = TagModel(
      id: _uuid.v4(),
      name: name,
      color: color,
      isSynced: false,
    );
    
    await StorageService.saveTag(tag);
    await _cloudService.syncTag(tag.copyWith(isSynced: true));
    await StorageService.saveTag(tag.copyWith(isSynced: true));
  }

  Future<void> deleteTag(String id) async {
    await StorageService.deleteTag(id);
    await _cloudService.deleteTag(id);
  }
}
