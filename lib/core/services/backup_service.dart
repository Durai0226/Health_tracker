
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'storage_service.dart';

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
      final data = StorageService.exportAllData();
      
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
        'deviceName': 'Device', // Could use device_info_plus if needed
        'data': jsonEncode(data), // Store as string to avoid map depth issues
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

      // Clear existing data
      await StorageService.clearAllData();
      
      // Restore data
      await StorageService.importData(data);
      
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
    return BackupModel(
      id: doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deviceName: data['deviceName'] ?? 'Unknown Device',
      sizeBytes: (data['data'] as String?)?.length ?? 0,
    );
  }
}
