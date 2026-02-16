import '../../../../core/services/storage_service.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../models/tag_model.dart';

class NotesLocalService {
  // Notes
  List<NoteModel> getAllNotes() {
    return StorageService.getAllNotes();
  }

  Future<void> saveNote(NoteModel note) async {
    await StorageService.saveNote(note);
  }

  Future<void> deleteNote(String id) async {
    await StorageService.deleteNote(id);
  }

  // Folders
  List<FolderModel> getAllFolders() {
    return StorageService.getAllFolders();
  }

  Future<void> saveFolder(FolderModel folder) async {
    await StorageService.saveFolder(folder);
  }

  Future<void> deleteFolder(String id) async {
    await StorageService.deleteFolder(id);
  }

  // Tags
  List<TagModel> getAllTags() {
    return StorageService.getAllTags();
  }

  Future<void> saveTag(TagModel tag) async {
    await StorageService.saveTag(tag);
  }

  Future<void> deleteTag(String id) async {
    await StorageService.deleteTag(id);
  }
}
