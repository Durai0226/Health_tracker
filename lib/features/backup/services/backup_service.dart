import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/services/clean_storage_service.dart';

class BackupService {
  
  /// Creates a backup file (ZIP) containing all app data in JSON format.
  /// Returns the file path of the created backup.
  Future<File?> createBackup() async {
    try {
      // 1. Export data from Hive
      final data = await CleanStorageService.exportAllData();
      final jsonString = jsonEncode(data);
      
      // 2. Create Archive
      final archive = Archive();
      final dataBytes = utf8.encode(jsonString);
      archive.addFile(ArchiveFile('dlyminder_data.json', dataBytes.length, dataBytes));
      
      // 3. Save to file
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'dlyminder_backup_$dateStr.zip';
      final file = File('${tempDir.path}/$fileName');
      
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      
      await file.writeAsBytes(zipBytes);
      return file;
      
    } catch (e) {
      debugPrint("Backup creation failed: $e");
      return null;
    }
  }

  /// Share the backup file using system share sheet
  Future<void> shareBackup(File file) async {
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: 'DailyMinder Backup');
  }

  /// Allow user to pick a backup file and restore data.
  ///
  /// Returns `true` on a successful restore and `false` ONLY when the user
  /// cancels the file picker. Any real failure (bad file, decode/import error)
  /// is rethrown so the caller can surface a clear error message — it is NOT
  /// swallowed as `false`, which previously made restore failures invisible.
  Future<bool> restoreBackup() async {
    // 1. Pick file — a null/empty result means the user canceled.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) {
      return false; // User canceled — not an error.
    }

    final file = File(result.files.single.path!);

    // 2. Read and Unzip. Any failure here throws to the caller.
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final jsonFile = archive.findFile('dlyminder_data.json');
    if (jsonFile == null) {
      throw Exception('Invalid backup file: missing dlyminder_data.json');
    }

    final jsonContent = utf8.decode(jsonFile.content);
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid backup file: unexpected data format');
    }

    // 3. Restore (merge) with rollback protection: the current data is
    // snapshotted first so a failed/partial import is rolled back instead of
    // leaving the app in a half-imported state. Errors are rethrown after
    // rollback by CleanStorageService.restoreBackup.
    await CleanStorageService.restoreBackup(decoded);
    return true;
  }
}
