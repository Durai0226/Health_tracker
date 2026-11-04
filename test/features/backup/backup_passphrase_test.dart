/// An exported backup can be protected with a passphrase, and opens again with it.
///
/// The cipher is proven in `backup_encryption_test.dart`. This is what the backup
/// does with it: that the file really is sealed, that restoring asks for the
/// passphrase and keeps asking while it is wrong, that giving up is not a failure,
/// and that an unencrypted backup still works exactly as before.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/backup_encryption.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/backup/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  const service = BackupService(encryptionIterations: BackupEncryption.minIterations);
  final seededAt = DateTime(2026, 3, 1, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await database.into(database.enhancedMedicines).insert(
          db.EnhancedMedicinesCompanion.insert(
            id: 'med-1',
            name: 'Metformin',
            dosageForm: 0,
            startDate: seededAt,
            createdAt: seededAt,
            updatedAt: seededAt,
            scheduleJson: '{}',
            currentStock: const Value(30),
          ),
        );
  });

  tearDown(() async => database.close());

  Future<List<String>> medicines() async =>
      [for (final m in await database.select(database.enhancedMedicines).get()) m.name];

  Future<void> wipe() => database.delete(database.enhancedMedicines).go();

  group('making one', () {
    test('without a passphrase it is a plain ZIP, as it always was', () async {
      final bytes = await service.buildBackupBytes();

      expect(String.fromCharCodes(bytes.take(2)), 'PK');
      expect(BackupEncryption.isEncrypted(bytes), isFalse);
      expect(latin1.decode(bytes, allowInvalid: true), contains('dlyminder_data.json'));
    });

    test('with one it is sealed: not a ZIP, and the records are not in it', () async {
      final bytes = await service.buildBackupBytes(passphrase: 'a long enough phrase');

      expect(BackupEncryption.isEncrypted(bytes), isTrue);
      expect(String.fromCharCodes(bytes.take(2)), isNot('PK'));
      final text = latin1.decode(bytes, allowInvalid: true);
      expect(text, isNot(contains('Metformin')));
      expect(text, isNot(contains('dlyminder_data')));
    });

    test('the passphrase is not kept anywhere', () async {
      await service.buildBackupBytes(passphrase: 'a very secret passphrase');

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        expect('${prefs.get(key)}', isNot(contains('a very secret passphrase')));
      }
    });
  });

  group('the details', () {
    test('the rounds the service was given are the rounds in the file', () async {
      final bytes = await service.buildBackupBytes(passphrase: 'a long enough phrase');
      expect(ByteData.sublistView(bytes).getUint32(7, Endian.big),
          BackupEncryption.minIterations);
    });

    test('by default a backup uses the full count', () {
      expect(const BackupService().encryptionIterations, BackupEncryption.defaultIterations);
    });

    test('the sealed file is named for what it is, not as a ZIP', () {
      final at = DateTime(2026, 3, 4, 5, 6);
      expect(BackupService.backupFileName(at, encrypted: false),
          'dlyminder_backup_20260304_0506.zip');
      expect(BackupService.backupFileName(at, encrypted: true),
          'dlyminder_backup_20260304_0506.dlyenc');
    });

    test('the picker does not filter by extension, so a .dlyenc file can be chosen', () {
      // Android's picker has no type for the extension and would hide the file. It
      // needs the plugin, so this is a scan; what a file IS is decided by its bytes.
      final source =
          File('lib/features/backup/services/backup_service.dart').readAsStringSync();
      expect(source, contains('FilePicker.pickFile(type: FileType.any)'));
      expect(source, isNot(contains("allowedExtensions: ['zip']")));
    });
  });

  group('opening one', () {
    test('the plain one restores as before, and never asks for a passphrase',
        () async {
      final bytes = await service.buildBackupBytes();
      await wipe();
      var asked = 0;

      final restored = await service.restoreFromBytes(bytes, askPassphrase: ({required wrong}) async {
        asked++;
        return 'x';
      });

      expect(restored, isTrue);
      expect(asked, 0);
      expect(await medicines(), ['Metformin']);
    });

    test('the sealed one asks, and restores with the right passphrase', () async {
      final bytes = await service.buildBackupBytes(passphrase: 'right passphrase');
      await wipe();
      final asks = <bool>[];

      final restored = await service.restoreFromBytes(bytes, askPassphrase: ({required wrong}) async {
        asks.add(wrong);
        return 'right passphrase';
      });

      expect(restored, isTrue);
      expect(asks, [false], reason: 'asked once, and not as a retry');
      expect(await medicines(), ['Metformin']);
    });

    test('a wrong passphrase is asked for again, saying it was wrong', () async {
      final bytes = await service.buildBackupBytes(passphrase: 'right passphrase');
      await wipe();
      final answers = ['nope nope', 'still wrong', 'right passphrase'];
      final asks = <bool>[];

      final restored = await service.restoreFromBytes(bytes, askPassphrase: ({required wrong}) async {
        asks.add(wrong);
        return answers.removeAt(0);
      });

      expect(restored, isTrue);
      expect(asks, [false, true, true]);
      expect(await medicines(), ['Metformin']);
    });

    test('giving up is not a failure, and restores nothing', () async {
      final bytes = await service.buildBackupBytes(passphrase: 'right passphrase');
      await wipe();

      final restored = await service.restoreFromBytes(bytes,
          askPassphrase: ({required wrong}) async => null);

      expect(restored, isFalse);
      expect(await medicines(), isEmpty);
    });

    test('giving up after a wrong one is also just giving up', () async {
      final bytes = await service.buildBackupBytes(passphrase: 'right passphrase');
      await wipe();
      var n = 0;

      final restored = await service.restoreFromBytes(bytes, askPassphrase: ({required wrong}) async {
        return n++ == 0 ? 'wrong wrong' : null;
      });

      expect(restored, isFalse);
      expect(await medicines(), isEmpty);
    });

    test('with no way to ask, an encrypted file says why it cannot be opened', () async {
      final bytes = await service.buildBackupBytes(passphrase: 'right passphrase');

      await expectLater(
          service.restoreFromBytes(bytes),
          throwsA(predicate((e) => '$e'.contains('protected by a passphrase'))));
    });

    test('a damaged one fails once, with its reason, and is not asked about again',
        () async {
      final bytes = await service.buildBackupBytes(passphrase: 'right passphrase');
      final cut = Uint8List.sublistView(bytes, 0, 20);
      var asked = 0;

      await expectLater(
          service.restoreFromBytes(cut, askPassphrase: ({required wrong}) async {
            asked++;
            return 'right passphrase';
          }),
          throwsA(predicate((e) => '$e'.contains('damaged'))));
      expect(asked, 1, reason: 'a passphrase cannot fix a damaged file');
    });

    test('one from a newer version says to update the app', () async {
      final bytes = Uint8List.fromList(
          await service.buildBackupBytes(passphrase: 'right passphrase'))
        ..[6] = BackupEncryption.version + 1;

      await expectLater(
          service.restoreFromBytes(bytes, askPassphrase: ({required wrong}) async => 'right passphrase'),
          throwsA(predicate((e) => '$e'.contains('newer version'))));
    });

    test('a file that is neither says so rather than crashing', () async {
      await expectLater(
          service.restoreFromBytes(Uint8List.fromList(utf8.encode('not a backup at all'))),
          throwsA(anything));
    });

    test('a restore does not duplicate what is already there', () async {
      final bytes = await service.buildBackupBytes(passphrase: 'right passphrase');

      await service.restoreFromBytes(bytes, askPassphrase: ({required wrong}) async => 'right passphrase');

      expect(await medicines(), ['Metformin']);
    });
  });
}
