import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/backup_encryption.dart';
import '../../../core/services/backup_record.dart';
import '../../../core/utils/share_file.dart';

/// Asks for the passphrase of an encrypted backup; null when the person gives up.
/// [wrong] is true when the last one did not open it.
typedef AskBackupPassphrase = Future<String?> Function({required bool wrong});

/// Collects what is written to it, and throws [tooLarge] the moment it holds more
/// than [limit] — which stops the decompression that is feeding it.
class _CappedBytes extends ByteConversionSinkBase {
  _CappedBytes(this.limit, this.tooLarge);

  final int limit;
  final Exception tooLarge;
  final _bytes = BytesBuilder(copy: false);
  var _length = 0;

  @override
  void add(List<int> chunk) {
    _length += chunk.length;
    if (_length > limit) throw tooLarge;
    _bytes.add(chunk);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _bytes.takeBytes();
}

class BackupService {
  const BackupService({this.encryptionIterations = BackupEncryption.defaultIterations});

  /// PBKDF2 rounds for a new encrypted backup. The default is the one to use; a
  /// test passes the minimum so the key derivation does not dominate its time.
  @visibleForTesting
  final int encryptionIterations;

  /// The backup as bytes: a ZIP of everything, and — with a [passphrase] — that
  /// ZIP sealed with it (see [BackupEncryption]).
  ///
  /// Split from [createBackup] so the part that matters is testable without a
  /// temp directory or a share sheet.
  Future<Uint8List> buildBackupBytes({String? passphrase}) async {
    // 1. Export data from Hive
    final data = await CleanStorageService.exportAllData();
    final jsonString = jsonEncode(data);

    // 2. Create Archive
    final archive = Archive();
    final dataBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('dlyminder_data.json', dataBytes.length, dataBytes));

    final zip = Uint8List.fromList(ZipEncoder().encode(archive));
    if (passphrase == null) return zip;
    return BackupEncryption.encrypt(zip, passphrase, iterations: encryptionIterations);
  }

  /// The name a backup made at [at] is saved under.
  ///
  /// A different extension for the sealed one: it is not a ZIP, and a file that
  /// says it is would be opened by an archive app and reported broken.
  @visibleForTesting
  static String backupFileName(DateTime at, {required bool encrypted}) =>
      'dlyminder_backup_${DateFormat('yyyyMMdd_HHmm').format(at)}.${encrypted ? 'dlyenc' : 'zip'}';

  /// Creates a backup file containing all app data in JSON format: a ZIP, or with
  /// a [passphrase] an encrypted `.dlyenc` file. Returns the created file.
  Future<File?> createBackup({String? passphrase}) async {
    try {
      final bytes = await buildBackupBytes(passphrase: passphrase);

      // 3. Save to file
      final tempDir = await getTemporaryDirectory();
      final fileName = backupFileName(DateTime.now(), encrypted: passphrase != null);
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(bytes);
      // The file exists, so a backup was made. (Whether it was then shared is
      // the share sheet's business; making it is what the checklist asks of
      // the user.)
      await BackupRecord.markDone();
      return file;

    } catch (e) {
      debugPrint("Backup creation failed: $e");
      return null;
    }
  }

  /// Share the backup file using system share sheet
  Future<void> shareBackup(File file) async {
    await shareFile(file, text: '${AppStrings.productName} Backup');
  }

  /// Allow user to pick a backup file and restore data.
  ///
  /// Returns `true` on a successful restore and `false` ONLY when the user
  /// cancels the file picker (or the passphrase prompt). Any real failure (bad
  /// file, decode/import error) is rethrown so the caller can surface a clear
  /// error message — it is NOT swallowed as `false`, which previously made
  /// restore failures invisible.
  Future<bool> restoreBackup({AskBackupPassphrase? askPassphrase}) async {
    // 1. Pick file — a null result means the user canceled. `path` is null for
    // a non-`file:` URI (web), which this app never hits but must not crash on.
    //
    // Any type: an encrypted backup is `.dlyenc`, which Android's picker has no
    // type for and would filter out. What the file IS is decided by its bytes.
    final picked = await FilePicker.pickFile(type: FileType.any);

    final pickedPath = picked?.path;
    if (pickedPath == null) {
      return false; // User canceled — not an error.
    }

    return restoreFromBytes(await readPickedBackup(pickedPath),
        askPassphrase: askPassphrase);
  }

  /// The most restore will read into memory. A backup is a zip of text — years of
  /// logs are a few megabytes — so anything past this is not one, and reading it
  /// whole to find out could end the app on a small phone.
  static const int maxRestoreBytes = 100 * 1024 * 1024;

  /// The most the data inside a backup may expand to. A backup is text: years of
  /// logs, a CGM's readings included, come to tens of megabytes. A few megabytes
  /// that declare themselves a gigabyte are damaged, or are not a backup, and
  /// decompressing one would end the app on a small phone before saying so.
  static const int maxRestoreContentBytes = 128 * 1024 * 1024;

  /// The limit in force; a test lowers it to prove the check is made.
  @visibleForTesting
  static int restoreContentLimit = maxRestoreContentBytes;

  /// The bytes of a zip entry, decompressed — and refused the moment they pass
  /// [limit].
  ///
  /// Not the size the entry DECLARES: that is a number in its header, which a
  /// damaged or crafted file can set as low as it likes while the data inflates to
  /// gigabytes — and `ArchiveFile.content` inflates it all, with nothing to stop it.
  /// This counts what actually comes out and stops there. Only what this app writes
  /// is accepted: deflated or stored.
  @visibleForTesting
  static Uint8List inflateWithin(ArchiveFile file, int limit) {
    final tooLarge = Exception('Invalid backup file: its data is far too large to be '
        'a ${AppStrings.productName} backup.');
    final Uint8List stored;
    try {
      final raw = file.rawContent;
      if (raw == null) return Uint8List(0);
      stored = raw.getStream(decompress: false).toUint8List();
    } catch (_) {
      throw Exception('Invalid backup file: its data could not be read.');
    }
    if (!file.isCompressed) {
      if (stored.length > limit) throw tooLarge;
      return stored;
    }
    if (file.compression != CompressionType.deflate) {
      throw Exception('Invalid backup file: its data is not stored the way a '
          '${AppStrings.productName} backup stores it.');
    }
    final out = _CappedBytes(limit, tooLarge);
    try {
      final inflater = ZLibCodec(raw: true).decoder.startChunkedConversion(out);
      inflater.add(stored);
      inflater.close();
    } on Exception catch (e) {
      if (identical(e, tooLarge)) rethrow;
      throw Exception('Invalid backup file: its data could not be read.');
    }
    return out.takeBytes();
  }

  /// Whether the first bytes of a file are those of a backup: a zip, or a copy
  /// sealed with a passphrase ([BackupEncryption]).
  @visibleForTesting
  static bool looksLikeBackup(List<int> head) =>
      (head.length >= 2 && head[0] == 0x50 && head[1] == 0x4B) ||
      BackupEncryption.isEncrypted(Uint8List.fromList(head));

  /// The bytes of a file the person picked — after checking, without reading it,
  /// that it could be a backup.
  ///
  /// The picker offers any file (an encrypted backup has an extension Android's
  /// has no type for, and would hide), so the wrong one — a video, an archive of
  /// something else — is easy to pick. Its size and its first bytes are looked at
  /// before the rest is read.
  @visibleForTesting
  static Future<Uint8List> readPickedBackup(String path,
      {int maxBytes = maxRestoreBytes}) async {
    final file = File(path);
    if (await file.length() > maxBytes) {
      throw Exception('That file is too large to be a ${AppStrings.productName} '
          'backup.');
    }
    final head = <int>[];
    await for (final chunk in file.openRead(0, 16)) {
      head.addAll(chunk);
    }
    if (!looksLikeBackup(head)) {
      throw Exception('That is not a ${AppStrings.productName} backup file.');
    }
    return file.readAsBytes();
  }

  /// Restore from the bytes of a backup, opening it first when it is encrypted.
  ///
  /// Asks for the passphrase again for as long as it is wrong; `false` when the
  /// person gives up. A file this app cannot open at all — damaged, or from a
  /// newer version — throws with a message that says which.
  Future<bool> restoreFromBytes(Uint8List bytes,
      {AskBackupPassphrase? askPassphrase}) async {
    var zipBytes = bytes;
    if (BackupEncryption.isEncrypted(bytes)) {
      if (askPassphrase == null) {
        throw Exception('This backup is protected by a passphrase.');
      }
      var wrong = false;
      while (true) {
        final passphrase = await askPassphrase(wrong: wrong);
        if (passphrase == null) return false; // Gave up — not an error.
        try {
          zipBytes = await BackupEncryption.decrypt(bytes, passphrase);
          break;
        } on BackupDecryptException catch (e) {
          if (e.failure != BackupDecryptFailure.wrongPassphrase) {
            throw Exception(e.message);
          }
          wrong = true;
        }
      }
    }

    // 2. Read and Unzip. Any failure here throws to the caller.
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final jsonFile = archive.findFile('dlyminder_data.json');
    if (jsonFile == null) {
      throw Exception('Invalid backup file: missing dlyminder_data.json');
    }
    // The size the entry declares is looked at first, so an obvious one is refused
    // without decompressing a byte — but it is only what the entry says about itself.
    if (jsonFile.size > restoreContentLimit) {
      throw Exception('Invalid backup file: its data is far too large to be a '
          '${AppStrings.productName} backup.');
    }

    final jsonContent = utf8.decode(inflateWithin(jsonFile, restoreContentLimit));
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
