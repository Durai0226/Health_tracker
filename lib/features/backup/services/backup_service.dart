import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/services/storage_service.dart';

class BackupService {
  
  /// Creates a backup file (ZIP) containing all app data in JSON format.
  /// Returns the file path of the created backup.
  Future<File?> createBackup() async {
    try {
      // 1. Export data from Hive
      final data = await StorageService.exportAllData();
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
    await Share.shareXFiles([XFile(file.path)], text: 'Dlyminder Backup');
  }

  /// Allow user to pick a backup file and restore data
  Future<bool> restoreBackup() async {
    try {
      // 1. Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return false; // User canceled
      }

      final file = File(result.files.single.path!);
      
      // 2. Read and Unzip
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final jsonFile = archive.findFile('dlyminder_data.json');
      if (jsonFile == null) {
        throw Exception("Invalid backup file: missing data.json");
      }
      
      final jsonContent = utf8.decode(jsonFile.content);
      final data = jsonDecode(jsonContent);
      
      // 3. Import to Hive
      await StorageService.importData(data);
      return true;
      
    } catch (e) {
      debugPrint("Restore failed: $e");
      return false; // Or rethrow to show error in UI
    }
  }
}
