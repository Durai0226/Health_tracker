
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'clean_storage_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  Future<void> createBackup() async {
    final userId = _userId;
    if (userId == null) throw Exception('User not logged in');

    try {
      debugPrint('Creating backup...');
      final data = await CleanStorageService.exportAllData();
      final jsonString = jsonEncode(data);

      // Store backup metadata and data in Firestore
      // For large datasets, Firebase Storage is better, but for text JSON < 1MB, Firestore is fine.
      // Assuming dataset is reasonable size.

      final backupId = DateTime.now().toIso8601String();
      final backupRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('backups')
          .doc(backupId);

      await backupRef.set({
        'id': backupId,
        'createdAt': FieldValue.serverTimestamp(),
        // Real platform name (dart:io) — no device_info_plus dependency.
        'deviceName': Platform.operatingSystem,
        'data': jsonString, // Store as string to avoid map depth issues
        // True UTF-8 byte length, not the character count of the JSON string.
        'sizeBytes': utf8.encode(jsonString).length,
        'version': 1,
      });
      
      debugPrint('Backup created successfully: $backupId');
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    }
  }

  Future<List<BackupModel>> getBackups() async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('backups')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => BackupModel.fromSnapshot(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching backups: $e');
      return [];
    }
  }

  Future<void> restoreBackup(String backupId) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not logged in');

    try {
      debugPrint('Restoring backup: $backupId...');
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('backups')
          .doc(backupId)
          .get();

      if (!doc.exists) throw Exception('Backup not found');

      final jsonString = doc.data()?['data'] as String?;
      if (jsonString == null) throw Exception('Backup data is empty');

      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Overwrite restore with rollback protection: the current data is
      // snapshotted first, the kept tables are wiped, then the backup is
      // imported. If anything fails the snapshot is put back automatically.
      await CleanStorageService.restoreBackup(data, clearExisting: true);

      debugPrint('Backup restored successfully');
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      rethrow;
    }
  }
    
    Future<void> deleteBackup(String backupId) async {
        final userId = _userId;
        if (userId == null) return;
        
        try {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('backups')
                .doc(backupId)
                .delete();
        } catch (e) {
            debugPrint('Error deleting backup: $e');
            rethrow;
        }
    }
}

class BackupModel {
  final String id;
  final DateTime createdAt;
  final String deviceName;
  final int sizeBytes;

  BackupModel({
    required this.id,
    required this.createdAt,
    required this.deviceName,
    required this.sizeBytes,
  });

  factory BackupModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Prefer the stored real byte length; fall back to the UTF-8 byte length of
    // the payload for older backups that only persisted the JSON string.
    final storedSize = data['sizeBytes'];
    final sizeBytes = storedSize is int
        ? storedSize
        : utf8.encode((data['data'] as String?) ?? '').length;
    return BackupModel(
      id: doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deviceName: data['deviceName'] ?? 'Unknown Device',
      sizeBytes: sizeBytes,
    );
  }
}
