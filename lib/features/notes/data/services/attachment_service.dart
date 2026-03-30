import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class AttachmentService {
  static final AttachmentService _instance = AttachmentService._internal();
  factory AttachmentService() => _instance;
  AttachmentService._internal();

  final ImagePicker _imagePicker = ImagePicker();

  Future<String?> getAttachmentsDirectory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final attachDir = Directory('${dir.path}/note_attachments');
      if (!await attachDir.exists()) {
        await attachDir.create(recursive: true);
      }
      return attachDir.path;
    } catch (e) {
      debugPrint('Error getting attachments directory: $e');
      return null;
    }
  }

  Future<String?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return null;

      final attachDir = await getAttachmentsDirectory();
      if (attachDir == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = image.path.split('.').last;
      final newPath = '$attachDir/img_$timestamp.$extension';

      final file = File(image.path);
      await file.copy(newPath);

      return newPath;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  Future<List<String>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isEmpty) return [];

      final attachDir = await getAttachmentsDirectory();
      if (attachDir == null) return [];

      final List<String> paths = [];
      for (final image in images) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = image.path.split('.').last;
        final newPath = '$attachDir/img_$timestamp.$extension';

        final file = File(image.path);
        await file.copy(newPath);
        paths.add(newPath);
      }

      return paths;
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  Future<String?> takePhoto() async {
    return pickImage(source: ImageSource.camera);
  }

  Future<String?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      if (file.path == null) return null;

      final attachDir = await getAttachmentsDirectory();
      if (attachDir == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '$attachDir/file_$timestamp.${file.extension}';

      final sourceFile = File(file.path!);
      await sourceFile.copy(newPath);

      return newPath;
    } catch (e) {
      debugPrint('Error picking file: $e');
      return null;
    }
  }

  Future<void> deleteAttachment(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting attachment: $e');
    }
  }

  bool isImage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext);
  }

  bool isPdf(String path) {
    return path.toLowerCase().endsWith('.pdf');
  }

  String getFileName(String path) {
    return path.split('/').last;
  }

  Future<int?> getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
