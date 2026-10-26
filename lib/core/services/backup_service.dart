
import 'dart:convert';
import 'dart:io' show Platform, gzip;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'auth_service.dart';
import 'clean_storage_service.dart';
import 'backup_record.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  /// Marks a `data` field that holds base64(gzip(utf8(json))) rather than raw
  /// JSON. Absent on documents written before compression existed, which is
  /// exactly how [restoreBackup] tells the two apart.
  ///
  /// gzip **then** base64, not gzip into a Firestore `Blob`: `firestore.rules`
  /// requires `request.resource.data.data is string`, and a rules change has to
  /// be deployed separately from an app build. Switching the field's type would
  /// have made every cloud backup fail — silently, since the rejection surfaces
  /// only as a thrown write — on every device running until that deploy landed.
  /// base64 costs 33% back on top of a ~10x gzip win, which is still a large
  /// net reduction.
  static const String gzipBase64Encoding = 'gzip+base64';

  /// The most this app will put in one backup document.
  ///
  /// Firestore hard-caps a document at 1 MiB (1,048,576 bytes) counting field
  /// names and index overhead, not just the payload — and the cap is enforced
  /// by REJECTING the write. There was no check at all: a user with enough
  /// history simply got a thrown `set()`, a generic "Failed to create backup"
  /// toast, and no backup. The leftover ~148 KB of headroom covers the rest of
  /// the document.
  static const int maxBackupPayloadBytes = 900 * 1024;

  /// Uploads a full health export to Firestore.
  ///
  /// Both guards below are mandatory and neither existed. `_userId` is
  /// satisfied by the **anonymous** Firebase account that `AuthService.init()`
  /// creates silently on first launch, so a user who chose "Continue as guest"
  /// — and was told *"Private · on-device · no account"* — pushed every
  /// medicine, vitals reading, diary entry and period record to Google's
  /// servers by tapping Create backup.
  ///
  /// `lib/main.dart` already applies exactly this pair to `CloudSyncService`;
  /// it was simply never applied here.
  Future<void> createBackup() async {
    if (!AuthService().isAuthenticated) {
      throw StateError(
          'Cloud backup requires a real signed-in account. Guests and '
          'anonymous sessions stay on-device.');
    }
    if (!CleanStorageService.cloudSyncEnabled) {
      throw StateError(
          'Cloud sync is off. Enable it in Settings before backing up health '
          'data to the cloud.');
    }

    final userId = _userId;
    if (userId == null) throw Exception('User not logged in');

    try {
      debugPrint('Creating backup...');
      final data = await CleanStorageService.exportAllData();

      final backupId = DateTime.now().toIso8601String();
      final document = buildBackupDocument(
        backupId: backupId,
        jsonString: jsonEncode(data),
        deviceName: Platform.operatingSystem,
        createdAt: FieldValue.serverTimestamp(),
      );

      final backupRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('backups')
          .doc(backupId);

      await backupRef.set(document);
      await BackupRecord.markDone();

      debugPrint('Backup created successfully: '
          '$backupId (${document['sizeBytes']} B)');
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    }
  }

  /// The `users/{uid}/backups/{backupId}` document for [jsonString], or a
  /// [StateError] carrying [oversizeMessage] if it is too big to upload.
  ///
  /// **The size guard lives here, not at the call site, so that it cannot be
  /// skipped.** It used to be three inline statements in [createBackup]
  /// between the export and the `set()`; nothing pinned them, so the next
  /// refactor could drop them and every test would still pass — and the
  /// failure they prevent is silent by construction (a rejected write, a
  /// generic toast, and no backup). Building the document IS the check now:
  /// there is no way to produce something to upload without running it.
  ///
  /// [createdAt] is passed in rather than built here so this stays pure —
  /// `FieldValue.serverTimestamp()` needs an initialised Firebase app, which a
  /// unit test does not have. The field names are the ones `firestore.rules`
  /// validates on create (`data is string`, `sizeBytes is int`, `id` matching
  /// the path), so they are a contract with a separately deployed file.
  @visibleForTesting
  static Map<String, Object?> buildBackupDocument({
    required String backupId,
    required String jsonString,
    required String deviceName,
    required Object createdAt,
  }) {
    final payload = encodePayload(jsonString);
    // base64 is ASCII, so its character count IS its UTF-8 byte count.
    final payloadBytes = payload.length;

    // Checked BEFORE the write, so the failure is a sentence the user can act
    // on instead of a rejected `set()` they never see.
    final tooLarge = oversizeMessage(payloadBytes);
    if (tooLarge != null) throw StateError(tooLarge);

    return {
      'id': backupId,
      'createdAt': createdAt,
      // Real platform name (dart:io) — no device_info_plus dependency.
      'deviceName': deviceName,
      // Compressed, and a string to avoid map depth issues.
      'data': payload,
      'encoding': gzipBase64Encoding,
      // The stored payload's byte length — what the 1 MiB cap applies to,
      // and what the backup list shows as this backup's size.
      'sizeBytes': payloadBytes,
      'version': 2,
    };
  }

  /// Why a [payloadBytes]-byte payload cannot be uploaded, or null if it can.
  ///
  /// Says the actual numbers and names the way out, because "Failed to create
  /// backup: [cloud_firestore/invalid-argument] ..." is what the user got
  /// before and it tells them nothing about what to do. The local ZIP export
  /// has no such limit, so there IS a way out.
  ///
  /// **The way out comes first, and that ordering is load-bearing.** The only
  /// surface this reaches is `AppToast`, which is `maxLines: 2` with an
  /// ellipsis — roughly 80 characters. Written numbers-first, every actionable
  /// clause sat past the cut and the user saw a truncated complaint with no
  /// instruction in it: the sentence existed and did not arrive. The sizes are
  /// still here, last, for the person who reads the whole thing.
  @visibleForTesting
  static String? oversizeMessage(int payloadBytes) {
    if (payloadBytes <= maxBackupPayloadBytes) return null;
    return 'Backup too large for the cloud — use "Export a copy" in Settings '
        'instead. Nothing was uploaded and your existing backups are '
        'untouched. (${_formatKb(payloadBytes)} compressed, limit '
        '${_formatKb(maxBackupPayloadBytes)} per backup.)';
  }

  /// JSON → the string stored in the `data` field. Inverse of [decodePayload].
  @visibleForTesting
  static String encodePayload(String jsonString) =>
      base64Encode(gzip.encode(utf8.encode(jsonString)));

  /// The stored `data` field → JSON, for either encoding.
  ///
  /// [encoding] is the document's `encoding` field; anything other than
  /// [gzipBase64Encoding] — including the `null` on every document written
  /// before compression — means the payload is already plain JSON.
  @visibleForTesting
  static String decodePayload(String payload, String? encoding) =>
      encoding == gzipBase64Encoding
          ? utf8.decode(gzip.decode(base64Decode(payload)))
          : payload;

  static String _formatKb(int bytes) =>
      '${(bytes / 1024).toStringAsFixed(0)} KB';

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

      final stored = doc.data();
      final payload = stored?['data'] as String?;
      if (payload == null) throw Exception('Backup data is empty');

      // Documents written before compression carry no `encoding` field and
      // hold raw JSON — they must keep restoring.
      final jsonString =
          decodePayload(payload, stored?['encoding'] as String?);
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
