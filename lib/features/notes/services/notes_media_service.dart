import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class NotesMediaService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  /// Pick an image from gallery or camera
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Upload file to Firebase Storage and return the download URL
  Future<String?> uploadMedia(File file, {String? folder}) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final String fileName = '${_uuid.v4()}.jpg';
      final String path = 'users/${user.uid}/notes/${folder ?? 'media'}/$fileName';
      
      final Reference ref = _storage.ref().child(path);
      final UploadTask task = ref.putFile(file);
      
      final TaskSnapshot snapshot = await task;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return null;
    }
  }
}
