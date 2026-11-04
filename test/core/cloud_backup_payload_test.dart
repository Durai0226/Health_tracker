import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/backup_service.dart';
import 'package:tablet_remainder/features/settings/screens/backup_screen.dart';

/// The cloud backup was written to Firestore as one uncompressed JSON string
/// with no size check at all.
///
/// Firestore refuses a document over 1 MiB. `backupRef.set()` therefore threw
/// for any user with enough history, the screen showed "Failed to create
/// backup: `<SDK error>`", and the backup they thought they had did not exist —
/// a failure that shows up precisely on the accounts with the most to lose.
/// The comment above the write said "for text JSON < 1MB, Firestore is fine.
/// Assuming dataset is reasonable size."
///
/// Two changes, both pinned here: the payload is gzipped so far fewer users
/// reach the cap, and the ones who still do are told so in a sentence they can
/// act on, before anything is uploaded.
void main() {
  /// A health export's shape: many near-identical records. Compression ratios
  /// on real backups look like this, not like random bytes.
  String exportOfSize(int rows) => jsonEncode({
        'version': 6,
        'sleep': [
          for (var i = 0; i < rows; i++)
            {
              'id': 'sleep-$i',
              'dateKey': '2026-03-01',
              'bedtime': 1772400000000 + i,
              'wakeTime': 1772430000000 + i,
              'inBedMinutes': 470,
              'asleepMinutes': 441,
              'sleepScore': 82,
              'efficiency': 93.8,
              'note': 'woke once',
            },
        ],
      });

  group('payload encoding', () {
    test('a payload round-trips through gzip+base64 unchanged', () {
      final json = exportOfSize(50);
      final encoded = BackupService.encodePayload(json);

      expect(
        BackupService.decodePayload(
            encoded, BackupService.gzipBase64Encoding),
        json,
      );
    });

    test('a pre-compression backup still restores', () {
      // Documents written before this change have no `encoding` field and hold
      // raw JSON. Reading them as gzip would make every existing cloud backup
      // unrestorable.
      const legacy = '{"version":5,"medicines":[]}';

      expect(BackupService.decodePayload(legacy, null), legacy);
    });

    test('compression is what buys the headroom', () {
      final json = exportOfSize(400);
      final rawBytes = utf8.encode(json).length;
      final storedBytes = BackupService.encodePayload(json).length;

      expect(storedBytes, lessThan(rawBytes ~/ 2),
          reason: 'if the stored payload were not much smaller than the raw '
              'JSON, gzip+base64 would be cost without benefit and the plain '
              'string should come back');
    });
  });

  group('size guard', () {
    test('leaves real headroom under the Firestore document limit', () {
      const firestoreDocumentLimit = 1048576; // 1 MiB, hard.

      expect(BackupService.maxBackupPayloadBytes,
          lessThan(firestoreDocumentLimit),
          reason: 'the limit counts field names and index overhead too, not '
              'just the payload');
      expect(firestoreDocumentLimit - BackupService.maxBackupPayloadBytes,
          greaterThanOrEqualTo(64 * 1024),
          reason: 'a few bytes of headroom is not headroom');
    });

    test('all the parts of a backup fit in one batch write', () {
      const batchLimit = 10 * 1024 * 1024; // 10 MiB, hard.
      expect(BackupService.maxTotalPayloadBytes, lessThan(batchLimit),
          reason: 'the parts are committed together or not at all, so they '
              'must fit in one batch with room for their field names');
      expect(batchLimit - BackupService.maxTotalPayloadBytes,
          greaterThanOrEqualTo(1024 * 1024));
    });

    test('a payload at the limit is allowed', () {
      expect(
          BackupService.oversizeMessage(BackupService.maxTotalPayloadBytes),
          isNull);
    });

    test('a payload bigger than one document, but within the parts, is allowed', () {
      expect(
          BackupService.oversizeMessage(BackupService.maxBackupPayloadBytes + 1),
          isNull,
          reason: 'it used to be refused here; it is split into parts now');
    });

    test('a payload over the limit is refused with an actionable message', () {
      final message =
          BackupService.oversizeMessage(BackupService.maxTotalPayloadBytes + 1);

      expect(message, isNotNull);
      expect(message, contains('7200 KB'),
          reason: 'the user should be able to see how far over they are');
      expect(message, contains('Export a copy'),
          reason: 'a refusal with no way forward is just a dead end — the '
              'local ZIP export has no size limit');
      expect(message, contains('existing backups are untouched'),
          reason: 'the first thing someone fears on a backup error is that '
              'they just lost the backups they had');
    });

    test('the way out survives the two lines a toast actually shows', () {
      // The only surface this message reaches is AppToast: maxLines: 2 with an
      // ellipsis, which is roughly 80 characters of bodyMedium. Written
      // numbers-first the instruction sat past the cut, so the user got a
      // truncated complaint and no way to act on it — a guard whose
      // user-facing half never arrives.
      const visibleBudget = 80;
      final message =
          BackupService.oversizeMessage(BackupService.maxTotalPayloadBytes + 1)!;

      expect(message.substring(0, visibleBudget), contains('Export a copy'),
          reason: 'the instruction has to be inside the part that is rendered, '
              'not merely inside the string');
    });
  });

  group('what the screen shows when the guard fires', () {
    test("a deliberate refusal is shown as itself, not as 'Bad state:'", () {
      // These StateErrors are sentences written for the user. Interpolating one
      // into 'Failed to create backup: $e' prepends 36 characters of noise to a
      // message the toast then clips at two lines — so the prefix was paid for
      // out of the instruction's budget.
      final shown = BackupScreen.failureMessage(
          StateError(BackupService.oversizeMessage(
              BackupService.maxTotalPayloadBytes + 1)!));

      expect(shown, startsWith('Backup too large'));
      expect(shown, isNot(contains('Bad state')));
      expect(shown.substring(0, 80), contains('Export a copy'));
    });

    test('an unexpected failure still says which operation failed', () {
      // The prefix earns its place here: an SDK exception is not a sentence,
      // and without it the toast would be a bare error code.
      final shown = BackupScreen.failureMessage(
          Exception('[cloud_firestore/unavailable] backend unreachable'));

      expect(shown, startsWith('Failed to create backup:'));
      expect(shown, contains('backend unreachable'));
    });
  });

  /// The two tests above are about the guard. These are about it being WIRED:
  /// a guard the upload path doesn't run is decoration, and the inline version
  /// it replaced was three statements nothing pinned.
  group('the document that gets uploaded', () {
    Map<String, Object?> build(String json,
            {int chunkBytes = BackupService.maxBackupPayloadBytes,
            int maxParts = BackupService.maxBackupParts}) =>
        BackupService.buildBackupDocuments(
          backupId: '2026-03-01T09:00:00.000',
          jsonString: json,
          deviceName: 'android',
          // A stand-in for FieldValue.serverTimestamp(), which needs a live
          // Firebase app.
          createdAt: 'server-timestamp',
          chunkBytes: chunkBytes,
          maxParts: maxParts,
        ).first;

    test('carries the compressed payload and its real byte length', () {
      final json = exportOfSize(50);
      final doc = build(json);

      expect(doc['encoding'], BackupService.gzipBase64Encoding);
      expect(
        BackupService.decodePayload(
            doc['data'] as String, doc['encoding'] as String?),
        json,
        reason: 'what lands in Firestore has to be what restoreBackup reads '
            'back out',
      );
      expect(doc['sizeBytes'], (doc['data'] as String).length,
          reason: 'the backup list shows this number as the backup size');
      // firestore.rules validates exactly these on create — see the `backups`
      // match block. A rename here is a silently rejected write.
      expect(doc['id'], '2026-03-01T09:00:00.000');
      expect(doc['data'], isA<String>());
      expect(doc['sizeBytes'], isA<int>());
    });

    test('an oversized export never becomes a document at all', () {
      // Genuinely incompressible, so the gzip win cannot rescue it — a fixed
      // seed keeps it deterministic. A repeating pattern would not do: gzip
      // would flatten it and the payload would come in under the cap.
      final random = Random(7);
      final incompressible = String.fromCharCodes([
        for (var i = 0; i < 4000; i++) 33 + random.nextInt(94),
      ]);

      // Two parts of a thousand bytes: the payload is far past both.
      expect(
        () => build(incompressible, chunkBytes: 1000, maxParts: 2),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('too large for the cloud'))),
        reason: 'the write must not be attempted — Firestore rejects it and '
            'the user is left believing they have a backup',
      );
    });
  });

  /// A backup bigger than one document used to be refused outright ("Capped at
  /// 900 KB per backup"). It is now split into parts, stored beside the backup's
  /// own document in the same collection — which `firestore.rules` already lets the
  /// owner write, so no deploy is needed.
  group('a backup bigger than one document', () {
    const id = '2026-03-01T09:00:00.000';
    final json = exportOfSize(300);
    final payloadLength = BackupService.encodePayload(json).length;
    // About three parts' worth.
    final chunk = (payloadLength / 3).ceil();

    List<Map<String, Object?>> docs({int? chunkBytes}) =>
        BackupService.buildBackupDocuments(
          backupId: id,
          jsonString: json,
          deviceName: 'android',
          createdAt: 'server-timestamp',
          chunkBytes: chunkBytes ?? chunk,
        );

    group('splitting', () {
      test('is lossless and every piece is within the size', () {
        final payload = BackupService.encodePayload(json);
        final pieces = BackupService.splitPayload(payload, chunkBytes: chunk);
        expect(pieces.join(), payload);
        expect(pieces.every((p) => p.length <= chunk), isTrue);
        expect(pieces.length, 3);
      });

      test('a payload that fits is one piece, and an empty one too', () {
        expect(BackupService.splitPayload('abc', chunkBytes: 3), ['abc']);
        expect(BackupService.splitPayload('', chunkBytes: 3), ['']);
      });

      test('an exact multiple has no empty piece at the end', () {
        expect(BackupService.splitPayload('abcdef', chunkBytes: 3),
            ['abc', 'def']);
        expect(BackupService.splitPayload('abcdefg', chunkBytes: 3),
            ['abc', 'def', 'g']);
      });
    });

    group('the documents', () {
      test('the first is the backup, with the whole size and how many parts', () {
        final all = docs();
        expect(all.length, 3);
        final first = all.first;
        expect(first['id'], id);
        expect(first['parts'], 3);
        expect(first['sizeBytes'], payloadLength,
            reason: 'the backup list shows this as the backup\'s size');
        expect(first['encoding'], BackupService.gzipBase64Encoding);
        expect(first['createdAt'], 'server-timestamp');
        expect((first['data'] as String).length, chunk);
      });

      test('the others say which backup they belong to, and carry no createdAt', () {
        final all = docs();
        for (var i = 1; i < all.length; i++) {
          final part = all[i];
          expect(part['id'], BackupService.partId(id, i + 1));
          expect(part['partOf'], id);
          expect(part['part'], i + 1);
          expect(part.containsKey('createdAt'), isFalse,
              reason: 'the list is ordered by createdAt, so a part without one '
                  'is never listed as a backup of its own');
          expect(part.containsKey('deviceName'), isFalse);
        }
      });

      test('every one meets what firestore.rules asks on create', () {
        for (final d in docs()) {
          expect(d['id'], isA<String>());
          expect(d['data'], isA<String>());
          expect(d['sizeBytes'], isA<int>());
          expect(d.keys.length, lessThanOrEqualTo(100));
        }
      });

      test('a backup that fits is exactly what it always was', () {
        final one = docs(chunkBytes: payloadLength);
        expect(one.length, 1);
        expect(one.single.containsKey('parts'), isFalse,
            reason: 'older builds read this document and must find what they expect');
        expect(one.single['sizeBytes'], payloadLength);
      });

      test('the part ids are not another backup\'s id', () {
        expect(BackupService.partId(id, 2), isNot(id));
        expect(BackupService.partId(id, 2), isNot(BackupService.partId(id, 3)));
      });
    });

    group('in Firestore', () {
      late FakeFirebaseFirestore firestore;
      late BackupService service;

      CollectionReference<Map<String, dynamic>> backups() =>
          firestore.collection('users').doc('u1').collection('backups');

      setUp(() {
        firestore = FakeFirebaseFirestore();
        service = BackupService.forTesting(firestore: firestore);
      });

      test('what is uploaded restores to the same JSON', () async {
        await service.uploadForTesting(id, json, chunkBytes: chunk);
        expect((await backups().get()).docs.length, 3);
        expect(await service.loadBackupJson(id), json);
      });

      test('a backup that fits restores as before', () async {
        await service.uploadForTesting(id, json);
        expect((await backups().get()).docs.length, 1);
        expect(await service.loadBackupJson(id), json);
      });

      test('the list shows one backup, at its whole size', () async {
        await service.uploadForTesting(id, json, chunkBytes: chunk);
        await service.uploadForTesting('2026-03-02T09:00:00.000', json);

        final listed = await service.getBackups();
        expect(listed.map((b) => b.id).toSet(),
            {id, '2026-03-02T09:00:00.000'});
        expect(listed.length, 2, reason: 'a part is not a backup');
        expect(listed.firstWhere((b) => b.id == id).sizeBytes, payloadLength);
      });

      test('deleting takes every part with it', () async {
        await service.uploadForTesting(id, json, chunkBytes: chunk);
        await service.uploadForTesting('2026-03-02T09:00:00.000', json);

        await service.deleteBackup(id);

        final left = (await backups().get()).docs.map((d) => d.id).toList();
        expect(left, ['2026-03-02T09:00:00.000']);
      });

      test('deleting one that is already gone is harmless', () async {
        await service.deleteBackup('nope');
        expect((await backups().get()).docs, isEmpty);
      });

      test('a missing part is said, and nothing is guessed', () async {
        await service.uploadForTesting(id, json, chunkBytes: chunk);
        await backups().doc(BackupService.partId(id, 2)).delete();

        expect(
          service.loadBackupJson(id),
          throwsA(isA<Exception>().having((e) => '$e', 'message',
              allOf(contains('incomplete'), contains('part 2 of 3'),
                  contains('Nothing on this phone was changed')))),
        );
      });

      test('a part that belongs to another backup is not joined in', () async {
        await service.uploadForTesting(id, json, chunkBytes: chunk);
        await backups()
            .doc(BackupService.partId(id, 3))
            .update({'partOf': '2020-01-01T00:00:00.000'});

        expect(service.loadBackupJson(id),
            throwsA(isA<Exception>().having((e) => '$e', 'message', contains('incomplete'))));
      });

      test('a part numbered wrongly is not joined in', () async {
        await service.uploadForTesting(id, json, chunkBytes: chunk);
        await backups().doc(BackupService.partId(id, 2)).update({'part': 3});

        expect(service.loadBackupJson(id),
            throwsA(isA<Exception>().having((e) => '$e', 'message', contains('incomplete'))));
      });

      test('more parts than this app writes means a newer app made it', () async {
        await backups().doc(id).set({
          'id': id,
          'data': 'x',
          'sizeBytes': 1,
          'parts': BackupService.maxBackupParts + 1,
          'encoding': BackupService.gzipBase64Encoding,
          'createdAt': Timestamp.now(),
        });
        expect(service.loadBackupJson(id),
            throwsA(isA<Exception>().having((e) => '$e', 'message', contains('newer version'))));
      });

      test('a backup from before compression, with no parts, still loads', () async {
        const legacy = '{"version":5,"medicines":[]}';
        await backups().doc(id).set({
          'id': id,
          'data': legacy,
          'sizeBytes': legacy.length,
          'createdAt': Timestamp.now(),
        });
        expect(await service.loadBackupJson(id), legacy);
      });

      test('one that is not there, or has no data, says so', () async {
        expect(service.loadBackupJson('nope'),
            throwsA(isA<Exception>().having((e) => '$e', 'message', contains('not found'))));
        await backups().doc(id).set({'id': id, 'sizeBytes': 0});
        expect(service.loadBackupJson(id),
            throwsA(isA<Exception>().having((e) => '$e', 'message', contains('empty'))));
      });

      test('too big even for the parts uploads nothing', () async {
        final random = Random(3);
        final noise = String.fromCharCodes(
            [for (var i = 0; i < 6000; i++) 33 + random.nextInt(94)]);
        await expectLater(
          service.uploadForTesting(id, noise, chunkBytes: 1000, maxParts: 2),
          throwsA(isA<StateError>()),
        );
        expect((await backups().get()).docs, isEmpty);
      });
    });
  });
}
