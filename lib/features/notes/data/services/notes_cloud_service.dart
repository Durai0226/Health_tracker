import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/auth_service.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../models/tag_model.dart';

/// Cloud service for syncing notes data to Firestore
/// Handles Firebase exceptions gracefully, especially on Flutter Web
class NotesCloudService {
  FirebaseFirestore? _firestore;
  final String _usersCollection = 'users';
  final String _notesCollection = 'notes';
  final String _foldersCollection = 'note_folders';
  final String _tagsCollection = 'note_tags';
  
  FirebaseFirestore? get _db {
    try {
      _firestore ??= FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      debugPrint('NotesCloudService: Firestore not available: $e');
      return null;
    }
  }
  
  String? get _userId {
    try {
      return AuthService().currentUser?.id;
    } catch (e) {
      debugPrint('NotesCloudService: Error getting user ID: $e');
      return null;
    }
  }
  
  bool get _canSync {
    final uid = _userId;
    final db = _db;
    if (uid == null || db == null) return false;
    // Don't sync for anonymous/guest users
    try {
      return !AuthService().isGuest;
    } catch (e) {
      return false;
    }
  }

  /// Safely execute a Firestore operation with proper error handling for web
  Future<void> _safeFirestoreOperation(
    String operation,
    Future<void> Function() action,
  ) async {
    if (!_canSync) return;
    
    try {
      await action();
    } on FirebaseException catch (e) {
      debugPrint('NotesCloudService: Firebase error in $operation: ${e.code} - ${e.message}');
    } catch (e, stackTrace) {
      // On Flutter Web, Firebase exceptions may not be caught by FirebaseException
      // They can appear as JS interop errors
      debugPrint('NotesCloudService: Error in $operation: $e');
      if (kDebugMode) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  Future<void> syncNote(NoteModel note) async {
    await _safeFirestoreOperation('syncNote', () async {
      await _db!
          .collection(_usersCollection)
          .doc(_userId)
          .collection(_notesCollection)
          .doc(note.id)
          .set(note.toJson(), SetOptions(merge: true));
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _safeFirestoreOperation('deleteNote', () async {
      await _db!
          .collection(_usersCollection)
          .doc(_userId)
          .collection(_notesCollection)
          .doc(noteId)
          .delete();
    });
  }

  Future<void> syncFolder(FolderModel folder) async {
    await _safeFirestoreOperation('syncFolder', () async {
      await _db!
          .collection(_usersCollection)
          .doc(_userId)
          .collection(_foldersCollection)
          .doc(folder.id)
          .set(folder.toJson(), SetOptions(merge: true));
    });
  }

  Future<void> deleteFolder(String folderId) async {
    await _safeFirestoreOperation('deleteFolder', () async {
      await _db!
          .collection(_usersCollection)
          .doc(_userId)
          .collection(_foldersCollection)
          .doc(folderId)
          .delete();
    });
  }

  Future<void> syncTag(TagModel tag) async {
    await _safeFirestoreOperation('syncTag', () async {
      await _db!
          .collection(_usersCollection)
          .doc(_userId)
          .collection(_tagsCollection)
          .doc(tag.id)
          .set(tag.toJson(), SetOptions(merge: true));
    });
  }

  Future<void> deleteTag(String tagId) async {
    await _safeFirestoreOperation('deleteTag', () async {
      await _db!
          .collection(_usersCollection)
          .doc(_userId)
          .collection(_tagsCollection)
          .doc(tagId)
          .delete();
    });
  }
}
