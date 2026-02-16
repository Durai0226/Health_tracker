import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/storage_service.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../models/tag_model.dart';
import '../models/note_version_model.dart';
import '../services/notes_cloud_service.dart';
import '../services/notes_encryption_service.dart';

class NotesRepository {
  final NotesCloudService _cloudService = NotesCloudService();
  final NotesEncryptionService _encryptionService = NotesEncryptionService();
  final _uuid = const Uuid();

  // Notes
  List<NoteModel> getAllNotes() {
    return StorageService.getAllNotes();
  }

  Future<NoteModel?> getNote(String id) async {
    return StorageService.getNote(id);
  }

  ValueListenable<Box<NoteModel>> get notesListenable => StorageService.notesListenable;
  ValueListenable<Box<FolderModel>> get foldersListenable => StorageService.foldersListenable;

  Future<String> createNote({
    required String title,
    required String content,
    String? folderId,
    List<String> tagIds = const [],
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final note = NoteModel(
      id: id,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
      tagIds: tagIds,
      isSynced: false,
    );
    
    );
    
    // Encrypt content if creating a locked note (though usually created unlocked)
    // But if we support creating locked notes directly:
    // Actually, UI usually creates unlocked then user locks it? 
    // Let's safe guard anyway.
    if (note.isLocked) {
       final encrypted = await _encryptionService.encryptContent(note.content);
       // We can't modify 'note' variable directly as it's final?
       // note is a local variable, we can reassign or create new.
       // note = note.copyWith(content: encrypted); 
       // Swiftly, let's just save the encrypted version.
       
       final encryptedNote = note.copyWith(content: encrypted);
       await StorageService.saveNote(encryptedNote);
       await _cloudService.syncNote(encryptedNote.copyWith(isSynced: true));
       await StorageService.saveNote(encryptedNote.copyWith(isSynced: true));
       return id;
    }
    
    await StorageService.saveNote(note);
    await _cloudService.syncNote(note.copyWith(isSynced: true));
    
    // Update local synced status
    await StorageService.saveNote(note.copyWith(isSynced: true));
    return id;
  }

  Future<void> updateNote(NoteModel note) async {
    // 1. Save current state as a version before updating
    final currentNote = StorageService.getNote(note.id);
    if (currentNote != null) {
      final version = NoteVersionModel(
        id: _uuid.v4(),
        noteId: currentNote.id,
        content: currentNote.content,
        createdAt: DateTime.now(),
      );
      await StorageService.saveNoteVersion(version);
    }

    // 2. Proceed with update
    final updatedNote = note.copyWith(
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    
    // 2. Proceed with update
    var noteToSave = note.copyWith(
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    
    // If locked, ensure content is encrypted before saving
    if (noteToSave.isLocked) {
       // Check if already encrypted to avoid double encryption?
       // The UI should pass us PLAIN TEXT content when updating a locked note (because we unlocked it to edit).
       // So we ALWAYS encrypt here.
       final encrypted = await _encryptionService.encryptContent(noteToSave.content);
       noteToSave = noteToSave.copyWith(content: encrypted);
    }
    
    await StorageService.saveNote(noteToSave);
    await _cloudService.syncNote(noteToSave.copyWith(isSynced: true));
    
    // Update local synced status
    await StorageService.saveNote(noteToSave.copyWith(isSynced: true));
  }

  Future<String> unlockNoteContent(NoteModel note) async {
    if (!note.isLocked) return note.content;
    return _encryptionService.decryptContent(note.content);
  }

  Future<void> toggleLock(String noteId) async {
    final note = await getNote(noteId);
    if (note == null) return;

    if (note.isLocked) {
      // Unlock: Decrypt content and save as plain text
      try {
        final plainText = await _encryptionService.decryptContent(note.content);
        final unlockedNote = note.copyWith(
          isLocked: false,
          content: plainText,
          updatedAt: DateTime.now(),
          isSynced: false,
        );
        await updateNote(unlockedNote);
      } catch (e) {
        debugPrint("Failed to decrypt note during unlock: $e");
        // Force unlock but keep content as is? Or fail?
        // If we fail, user is stuck. 
        // If content is corrupted, we can't recover it anyway.
        throw e; 
      }
    } else {
      // Lock: Encrypt content and save
      final encrypted = await _encryptionService.encryptContent(note.content);
      final lockedNote = note.copyWith(
        isLocked: true,
        content: encrypted,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      // We use low-level save to avoid double encryption in updateNote?
      // updateNote checks isLocked. If we pass lockedNote (isLocked=true), it will encrypt AGAIN.
      // So we should call StorageService directly or refactor updateNote.
      
      // OPTION: Refactor updateNote to assume input is PLAIN TEXT?
      // Yes, updateNote usually comes from Editor which has Plain Text.
      // So if we pass a note with isLocked=true and CipherText to updateNote, it will re-encrypt the CipherText. 
      // Bad.
      
      // Let's use direct storage save here to bypass updateNote's encryption logic
      // But we need versioning? Locking/Unlocking might not need a version history entry?
      // Let's create a version just in case.
      
      // Actually, cleaner implementation:
      // updateNote expects PLAIN TEXT content always? 
      // If so, we can't pass the already encrypted note to it.
      // We should pass the plain text note with isLocked=true?
      // YES.
      
      final noteToLock = note.copyWith(
         isLocked: true,
         // content currently plain text
         updatedAt: DateTime.now(),
         isSynced: false,
      );
      await updateNote(noteToLock);
    }

  Future<void> restoreVersion(NoteVersionModel version) async {
    final currentNote = StorageService.getNote(version.noteId);
    if (currentNote != null) {
        // This update call will trigger the logic above, saving the "bad" state as a version too, which is desirable.
        await updateNote(currentNote.copyWith(
            content: version.content,
            // We keep the current title? Or should version store title too?
            // Model check: NoteVersionModel has (id, noteId, content, createdAt). No title.
            // So we only restore content.
            updatedAt: DateTime.now(),
        ));
    }
  }

  List<NoteVersionModel> getNoteVersions(String noteId) {
    return StorageService.getNoteVersions(noteId)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
  }

  Future<void> deleteNote(String id) async {
    await StorageService.deleteNote(id);
    await _cloudService.deleteNote(id);
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

  // Folders
  List<FolderModel> getAllFolders() {
    return StorageService.getAllFolders();
  }

  Future<void> createFolder(String name, {String? parentId, String? color, String? icon}) async {
    final folder = FolderModel(
      id: _uuid.v4(),
      name: name,
      parentId: parentId,
      createdAt: DateTime.now(),
      color: color,
      icon: icon,
      isSynced: false,
    );
    
    await StorageService.saveFolder(folder);
    await _cloudService.syncFolder(folder.copyWith(isSynced: true));
    await StorageService.saveFolder(folder.copyWith(isSynced: true));
  }

  Future<void> deleteFolder(String id) async {
    await StorageService.deleteFolder(id);
    await _cloudService.deleteFolder(id);
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
