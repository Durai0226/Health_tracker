/// Restore looks at a picked file before it reads it.
///
/// The picker offers any file — an encrypted backup has an extension Android's has
/// no type for, and would hide — so a wrong one is easy to pick. The whole file was
/// read into memory before a single byte of it was looked at, so a video of a few
/// gigabytes could end the app on a small phone before it said "not a backup".
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/constants/app_strings.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/backup_encryption.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/backup/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    dir = Directory.systemTemp.createTempSync('backup_picked_');
  });

  tearDown(() async {
    dir.deleteSync(recursive: true);
    await db.close();
  });

  Future<String> write(String name, List<int> bytes) async {
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  group('what looks like a backup', () {
    test('a zip', () {
      expect(BackupService.looksLikeBackup([0x50, 0x4B, 0x03, 0x04, 0, 0]), isTrue);
    });

    test('a copy sealed with a passphrase', () async {
      final sealed = await BackupEncryption.encrypt(
          Uint8List.fromList([1, 2, 3]), 'correct horse',
          iterations: BackupEncryption.minIterations);

      expect(BackupService.looksLikeBackup(sealed.sublist(0, 16)), isTrue);
    });

    test('nothing else does', () {
      expect(BackupService.looksLikeBackup(const []), isFalse);
      expect(BackupService.looksLikeBackup([0x50]), isFalse);
      expect(BackupService.looksLikeBackup('just some text'.codeUnits), isFalse);
      expect(BackupService.looksLikeBackup([0x89, 0x50, 0x4E, 0x47]), isFalse,
          reason: 'a PNG, not a zip');
      expect(BackupService.looksLikeBackup([0x50, 0x4C, 0x00, 0x01]), isFalse,
          reason: 'starts like a zip and is not one');
      expect(BackupService.looksLikeBackup('DLYEN'.codeUnits), isFalse,
          reason: 'the start of the mark is not the mark');
    });
  });

  group('what a backup may expand to', () {
    // A few megabytes that declare themselves a gigabyte are damaged or not a backup,
    // and decompressing one would end the app on a small phone before it said so.
    tearDown(() => BackupService.restoreContentLimit = BackupService.maxRestoreContentBytes);

    test('the limit is 128 MB, far above any backup of text', () {
      expect(BackupService.maxRestoreContentBytes, 128 * 1024 * 1024);
      expect(BackupService.restoreContentLimit, BackupService.maxRestoreContentBytes);
    });

    test('a backup whose data is over it is refused before anything is read or restored',
        () async {
      final bytes = await const BackupService().buildBackupBytes();
      BackupService.restoreContentLimit = 10;

      await expectLater(
          const BackupService().restoreFromBytes(bytes),
          throwsA(predicate((e) => '$e'.contains('far too large'))));
    });

    test('and nothing was restored: the data on the phone is as it was', () async {
      final bytes = await const BackupService().buildBackupBytes();
      // Everything but the moment each export was taken.
      Future<Map<String, dynamic>> snapshot() async =>
          {...await CleanStorageService.exportAllData()}..remove('timestamp');
      final before = await snapshot();
      BackupService.restoreContentLimit = 10;

      await expectLater(const BackupService().restoreFromBytes(bytes), throwsException);

      expect(await snapshot(), before);
    });

    test('a backup under it restores as it always did', () async {
      final bytes = await const BackupService().buildBackupBytes();

      expect(await const BackupService().restoreFromBytes(bytes), isTrue);
    });

    group('counted as it comes out, not as the header says', () {
      // The size an entry declares is a number in its header. A damaged or crafted
      // file sets it as low as it likes while the data inflates to gigabytes — and
      // `ArchiveFile.content` inflates all of it, with nothing to stop it.
      Uint8List zipOf(Uint8List data, {bool compress = true}) {
        final archive = Archive()
          ..addFile(compress
              ? ArchiveFile('dlyminder_data.json', data.length, data)
              : ArchiveFile.noCompress('dlyminder_data.json', data.length, data));
        return Uint8List.fromList(ZipEncoder().encode(archive));
      }

      ArchiveFile entryOf(Uint8List zip) =>
          ZipDecoder().decodeBytes(zip).findFile('dlyminder_data.json')!;

      /// The zip with the uncompressed size in both of its headers rewritten.
      Uint8List declaring(Uint8List zip, int declared) {
        final patched = Uint8List.fromList(zip);
        final view = ByteData.sublistView(patched);
        for (var i = 0; i + 30 < patched.length; i++) {
          final signature = view.getUint32(i, Endian.little);
          if (signature == 0x04034b50) view.setUint32(i + 22, declared, Endian.little);
          if (signature == 0x02014b50) view.setUint32(i + 24, declared, Endian.little);
        }
        return patched;
      }

      final json = Uint8List.fromList(
          List<int>.generate(5000, (i) => 0x61 + (i % 26)));

      test('what fits is returned whole', () {
        expect(BackupService.inflateWithin(entryOf(zipOf(json)), 5000), json);
      });

      test('one byte over the limit is refused, and the limit itself is not', () {
        expect(BackupService.inflateWithin(entryOf(zipOf(json)), 5000), hasLength(5000));
        expect(() => BackupService.inflateWithin(entryOf(zipOf(json)), 4999),
            throwsA(predicate((e) => '$e'.contains('far too large'))));
      });

      test('an entry that DECLARES far less than it holds is refused all the same', () {
        final lying = declaring(zipOf(json), 10);
        expect(entryOf(lying).size, 10, reason: 'the premise: the header says ten bytes');

        expect(() => BackupService.inflateWithin(entryOf(lying), 1000),
            throwsA(predicate((e) => '$e'.contains('far too large'))));
      });

      test('and so is a whole restore of one: nothing is restored', () async {
        final real = await const BackupService().buildBackupBytes();
        final lying = declaring(real, 10);
        BackupService.restoreContentLimit = 100;
        Future<Map<String, dynamic>> snapshot() async =>
            {...await CleanStorageService.exportAllData()}..remove('timestamp');
        final before = await snapshot();

        await expectLater(const BackupService().restoreFromBytes(lying),
            throwsA(predicate((e) => '$e'.contains('far too large'))));

        expect(await snapshot(), before);
      });

      test('a few hundred kilobytes that inflate to fifty megabytes are stopped at the limit', () {
        final bomb = zipOf(Uint8List(50 * 1024 * 1024));
        expect(bomb.length, lessThan(300 * 1024), reason: 'the premise: it is small');

        expect(() => BackupService.inflateWithin(entryOf(bomb), 1024 * 1024),
            throwsA(predicate((e) => '$e'.contains('far too large'))));
      });

      test('a stored entry is held to the limit too', () {
        final stored = entryOf(zipOf(json, compress: false));

        expect(BackupService.inflateWithin(stored, 5000), json);
        expect(() => BackupService.inflateWithin(stored, 4999),
            throwsA(predicate((e) => '$e'.contains('far too large'))));
      });

      test('an entry stored some other way than this app stores it is refused', () {
        final zip = zipOf(json);
        final view = ByteData.sublistView(zip);
        for (var i = 0; i + 30 < zip.length; i++) {
          final signature = view.getUint32(i, Endian.little);
          if (signature == 0x04034b50) view.setUint16(i + 8, 12, Endian.little); // bzip2
          if (signature == 0x02014b50) view.setUint16(i + 10, 12, Endian.little);
        }

        expect(() => BackupService.inflateWithin(entryOf(zip), 1000000),
            throwsA(predicate((e) => '$e'.contains('not stored the way'))));
      });

      test('data that is not deflate at all is refused with a message, not a crash', () {
        final broken = zipOf(json);
        // Overwrite the middle of the compressed data.
        for (var i = broken.length ~/ 2 - 10; i < broken.length ~/ 2 + 10; i++) {
          broken[i] = 0xFF;
        }

        expect(() => BackupService.inflateWithin(entryOf(broken), 1000000),
            throwsA(predicate((e) => '$e'.contains('Invalid backup file'))));
      });
    });
  });

  group('a picked file', () {
    test('a real backup is read in full', () async {
      final bytes = await const BackupService().buildBackupBytes();
      final path = await write('real.zip', bytes);

      expect(await BackupService.readPickedBackup(path), bytes);
    });

    test('so is a real encrypted one', () async {
      final bytes = await const BackupService(
              encryptionIterations: BackupEncryption.minIterations)
          .buildBackupBytes(passphrase: 'correct horse');
      final path = await write('real.dlyenc', bytes);

      expect(await BackupService.readPickedBackup(path), bytes);
    });

    test('a file that is not one is refused, and says so', () async {
      final path = await write('notes.txt', 'Dear diary'.codeUnits);

      await expectLater(
          BackupService.readPickedBackup(path),
          throwsA(predicate((e) => '$e'.contains('not a ${AppStrings.productName} backup'))));
    });

    test('an empty file is refused too', () async {
      final path = await write('empty', const []);

      await expectLater(BackupService.readPickedBackup(path), throwsException);
    });

    test('one that is too large is refused before anything is read of it', () async {
      final path = await write('big.zip', [0x50, 0x4B, 3, 4, ...List.filled(200, 0)]);

      await expectLater(
          BackupService.readPickedBackup(path, maxBytes: 100),
          throwsA(predicate((e) => '$e'.contains('too large'))));
    });

    test('exactly the limit is allowed', () async {
      final bytes = [0x50, 0x4B, 3, 4, ...List.filled(96, 0)];
      final path = await write('edge.zip', bytes);

      expect(await BackupService.readPickedBackup(path, maxBytes: 100), bytes);
    });

    test('the limit is a hundred megabytes, far above any backup of text', () {
      expect(BackupService.maxRestoreBytes, 100 * 1024 * 1024);
    });
  });
}
