
import 'dart:convert';
import 'dart:io' show Platform, gzip;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'auth_service.dart';
import 'clean_storage_service.dart';
import 'backup_record.dart';
import 'lww_collection_sync.dart' show commitInChunks;

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal()
      : _firestoreOverride = null,
        _uidOverride = null;
  BackupService._forTesting(this._firestoreOverride, this._uidOverride);

  /// A service on [firestore] for [uid], for tests: the real one needs an
  /// initialised Firebase app and a signed-in account.
  @visibleForTesting
  factory BackupService.forTesting(
          {required FirebaseFirestore firestore, String? uid = 'u1'}) =>
      BackupService._forTesting(firestore, uid);

  final FirebaseFirestore? _firestoreOverride;
  final String? _uidOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  firebase_auth.FirebaseAuth get _auth => firebase_auth.FirebaseAuth.instance;

  String? get _userId =>
      _firestoreOverride != null ? _uidOverride : _auth.currentUser?.uid;

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
  ///
  /// A backup bigger than this is split into parts (see [maxBackupParts]), each
  /// at most this long, so this is the size of a PART, not of a backup.
  static const int maxBackupPayloadBytes = 900 * 1024;

  /// The most parts one backup is split into.
  ///
  /// The parts are written in one batch, and a batch is capped at 10 MiB in all:
  /// eight parts of at most 900 KB is about 7.2 MB, which leaves room for the
  /// field names. Past it the person is pointed at "Export a copy", which has no
  /// limit.
  static const int maxBackupParts = 8;

  /// The most compressed payload a backup may hold, over all its parts.
  static int get maxTotalPayloadBytes => maxBackupPayloadBytes * maxBackupParts;

  /// The document that holds part [part] (2 or more) of the backup [backupId].
  ///
  /// The first part is the backup's own document, under [backupId] itself, so a
  /// backup that fits in one document is exactly what it always was. The others
  /// sit beside it in the same collection, which `firestore.rules` already lets
  /// the owner create: the rule asks only that `id` match the path, `data` be a
  /// string and `sizeBytes` an int. Putting them in a subcollection would have
  /// needed a rules change, and a rules deploy is separate from the app build.
  static String partId(String backupId, int part) => '$backupId~p$part';

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
      final size =
          await _upload(userId, backupId, jsonEncode(data), Platform.operatingSystem);
      await BackupRecord.markDone();

      debugPrint('Backup created successfully: $backupId ($size B)');
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    }
  }

  /// Build [jsonString] into documents and write them, all or none. Returns the
  /// stored payload's size.
  Future<int> _upload(
    String userId,
    String backupId,
    String jsonString,
    String deviceName, {
    int chunkBytes = maxBackupPayloadBytes,
    int maxParts = maxBackupParts,
  }) async {
    final documents = buildBackupDocuments(
      backupId: backupId,
      jsonString: jsonString,
      deviceName: deviceName,
      createdAt: FieldValue.serverTimestamp(),
      chunkBytes: chunkBytes,
      maxParts: maxParts,
    );
    final backups =
        _firestore.collection('users').doc(userId).collection('backups');
    if (documents.length == 1) {
      await backups.doc(backupId).set(documents.single);
    } else {
      // One batch: a backup with some of its parts is worse than none, since it
      // would be listed and then fail to restore. Nothing lands unless all do.
      // Through the shared helper, as every batch is; with at most
      // [maxBackupParts] operations it commits exactly one, far under its limit.
      await commitInChunks(_firestore, [
        for (final doc in documents)
          (WriteBatch batch) => batch.set(backups.doc(doc['id'] as String), doc),
      ]);
    }
    return documents.first['sizeBytes'] as int;
  }

  /// [_upload] for a test.
  @visibleForTesting
  Future<int> uploadForTesting(
    String backupId,
    String jsonString, {
    int chunkBytes = maxBackupPayloadBytes,
    int maxParts = maxBackupParts,
  }) =>
      _upload(_userId!, backupId, jsonString, 'test',
          chunkBytes: chunkBytes, maxParts: maxParts);

  /// The documents to write for [jsonString]: the backup's own, first, then one
  /// for each further part — or a [StateError] carrying [oversizeMessage] if it
  /// is too big to upload at all.
  ///
  /// **The size guard lives here, not at the call site, so that it cannot be
  /// skipped.** It used to be three inline statements in [createBackup]
  /// between the export and the `set()`; nothing pinned them, so the next
  /// refactor could drop them and every test would still pass — and the
  /// failure they prevent is silent by construction (a rejected write, a
  /// generic toast, and no backup). Building the documents IS the check now:
  /// there is no way to produce something to upload without running it.
  ///
  /// The first document carries `sizeBytes` for the WHOLE payload (the backup
  /// list shows it as the backup's size) and, only when there is more than one
  /// part, `parts`. A backup that fits in one document therefore has exactly the
  /// fields it always had. A further part has no `createdAt`, so the list, which
  /// is ordered by that field, never shows it as a backup of its own.
  ///
  /// [createdAt] is passed in rather than built here so this stays pure —
  /// `FieldValue.serverTimestamp()` needs an initialised Firebase app, which a
  /// unit test does not have. The field names are the ones `firestore.rules`
  /// validates on create (`data is string`, `sizeBytes is int`, `id` matching
  /// the path), so they are a contract with a separately deployed file.
  @visibleForTesting
  static List<Map<String, Object?>> buildBackupDocuments({
    required String backupId,
    required String jsonString,
    required String deviceName,
    required Object createdAt,
    int chunkBytes = maxBackupPayloadBytes,
    int maxParts = maxBackupParts,
  }) {
    final payload = encodePayload(jsonString);
    // base64 is ASCII, so its character count IS its UTF-8 byte count.
    final payloadBytes = payload.length;

    // Checked BEFORE the write, so the failure is a sentence the user can act
    // on instead of a rejected `set()` they never see.
    final tooLarge =
        oversizeMessage(payloadBytes, limitBytes: chunkBytes * maxParts);
    if (tooLarge != null) throw StateError(tooLarge);

    final chunks = splitPayload(payload, chunkBytes: chunkBytes);
    return [
      {
        'id': backupId,
        'createdAt': createdAt,
        // Real platform name (dart:io) — no device_info_plus dependency.
        'deviceName': deviceName,
        // Compressed, and a string to avoid map depth issues.
        'data': chunks.first,
        'encoding': gzipBase64Encoding,
        // The whole stored payload's byte length — what the backup list shows
        // as this backup's size.
        'sizeBytes': payloadBytes,
        'version': 2,
        if (chunks.length > 1) 'parts': chunks.length,
      },
      for (var part = 2; part <= chunks.length; part++)
        {
          'id': partId(backupId, part),
          'partOf': backupId,
          'part': part,
          'data': chunks[part - 1],
          'sizeBytes': chunks[part - 1].length,
        },
    ];
  }

  /// [payload] cut into pieces of at most [chunkBytes], in order; one piece, even
  /// when empty, if it fits. Inverse: joining them.
  @visibleForTesting
  static List<String> splitPayload(String payload,
      {int chunkBytes = maxBackupPayloadBytes}) {
    if (payload.length <= chunkBytes) return [payload];
    return [
      for (var at = 0; at < payload.length; at += chunkBytes)
        payload.substring(
            at, at + chunkBytes < payload.length ? at + chunkBytes : payload.length),
    ];
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
  static String? oversizeMessage(int payloadBytes, {int? limitBytes}) {
    final limit = limitBytes ?? maxTotalPayloadBytes;
    if (payloadBytes <= limit) return null;
    return 'Backup too large for the cloud — use "Export a copy" in Settings '
        'instead. Nothing was uploaded and your existing backups are '
        'untouched. (${_formatKb(payloadBytes)} compressed, limit '
        '${_formatKb(limit)} per backup.)';
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

      return snapshot.docs
          // A further part of a large backup is not a backup of its own.
          .where((doc) => (doc.data())['partOf'] == null)
          .map((doc) => BackupModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching backups: $e');
      return [];
    }
  }

  /// The backup [backupId] as JSON: its own document and, for a backup that was
  /// split, every further part, joined in order.
  ///
  /// A part that is missing or is not the one expected stops the restore with a
  /// sentence, before anything on the phone is touched: stitching the rest
  /// together would hand a truncated gzip stream to the decoder and the person a
  /// "FormatException" instead of the reason.
  @visibleForTesting
  Future<String> loadBackupJson(String backupId) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not logged in');

    final backups =
        _firestore.collection('users').doc(userId).collection('backups');
    final doc = await backups.doc(backupId).get();
    if (!doc.exists) throw Exception('Backup not found');

    final stored = doc.data();
    final first = stored?['data'] as String?;
    if (first == null) throw Exception('Backup data is empty');

    var payload = first;
    final parts = stored?['parts'];
    if (parts is int && parts > 1) {
      // More than this app ever writes: not something to join blindly.
      if (parts > maxBackupParts) {
        throw Exception('This backup was made by a newer version of the app. '
            'Update the app to restore it.');
      }
      final rest = await Future.wait([
        for (var part = 2; part <= parts; part++)
          backups.doc(partId(backupId, part)).get(),
      ]);
      final joined = StringBuffer(first);
      for (var i = 0; i < rest.length; i++) {
        final part = i + 2;
        final data = rest[i].data();
        if (!rest[i].exists ||
            data?['partOf'] != backupId ||
            data?['part'] != part ||
            data?['data'] is! String) {
          throw Exception('This backup is incomplete: part $part of $parts is '
              'missing. Nothing on this phone was changed.');
        }
        joined.write(data!['data'] as String);
      }
      payload = joined.toString();
    }

    // Documents written before compression carry no `encoding` field and
    // hold raw JSON — they must keep restoring.
    return decodePayload(payload, stored?['encoding'] as String?);
  }

  Future<void> restoreBackup(String backupId) async {
    try {
      debugPrint('Restoring backup: $backupId...');
      final jsonString = await loadBackupJson(backupId);
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
    
    /// Delete the backup and every part of it, together: a backup left with some of
    /// its parts would still be listed and then fail to restore.
    Future<void> deleteBackup(String backupId) async {
        final userId = _userId;
        if (userId == null) return;

        try {
            final backups =
                _firestore.collection('users').doc(userId).collection('backups');
            final own = await backups.doc(backupId).get();
            final parts = own.data()?['parts'];
            // One batch, so the backup is never left with some of its parts.
            await commitInChunks(_firestore, [
              (WriteBatch batch) => batch.delete(backups.doc(backupId)),
              if (parts is int)
                for (var part = 2; part <= parts && part <= maxBackupParts; part++)
                  (WriteBatch batch) =>
                      batch.delete(backups.doc(partId(backupId, part))),
            ]);
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
