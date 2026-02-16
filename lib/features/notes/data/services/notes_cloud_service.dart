import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/auth_service.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../models/tag_model.dart';

class NotesCloudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users'; // Based on StorageService logic
  final String _notesCollection = 'notes';
  final String _foldersCollection = 'folders';
  final String _tagsCollection = 'tags';
  
  String? get _userId {
    // Assuming AuthService is singleton or accessible. 
    // Using simple approach given StorageService logic relies on FirebaseAuth instance directly.
    return AuthService().currentUser?.id;
  }

  Future<void> syncNote(NoteModel note) async {
    final uid = _userId;
    if (uid == null) return;
    
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_notesCollection)
          .doc(note.id)
          .set(note.toJson());
    } catch (e) {
      debugPrint('Error syncing note to cloud: $e');
    }
  }

  Future<void> deleteNote(String noteId) async {
    final uid = _userId;
    if (uid == null) return;
    
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_notesCollection)
          .doc(noteId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting note from cloud: $e');
    }
  }

  Future<void> syncFolder(FolderModel folder) async {
    final uid = _userId;
    if (uid == null) return;
    
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_foldersCollection)
          .doc(folder.id)
          .set(folder.toJson());
    } catch (e) {
      debugPrint('Error syncing folder to cloud: $e');
    }
  }

  Future<void> deleteFolder(String folderId) async {
    final uid = _userId;
    if (uid == null) return;
    
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_foldersCollection)
          .doc(folderId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting folder from cloud: $e');
    }
  }

  Future<void> syncTag(TagModel tag) async {
    final uid = _userId;
    if (uid == null) return;
    
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_tagsCollection)
          .doc(tag.id)
          .set(tag.toJson());
    } catch (e) {
      debugPrint('Error syncing tag to cloud: $e');
    }
  }

  Future<void> deleteTag(String tagId) async {
    final uid = _userId;
    if (uid == null) return;
    
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_tagsCollection)
          .doc(tagId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting tag from cloud: $e');
    }
  }
}
