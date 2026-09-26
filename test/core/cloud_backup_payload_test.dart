import 'dart:convert';
import 'dart:math';

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

    test('a payload at the limit is allowed', () {
      expect(
          BackupService.oversizeMessage(BackupService.maxBackupPayloadBytes),
          isNull);
    });

    test('a payload over the limit is refused with an actionable message', () {
      final message =
          BackupService.oversizeMessage(BackupService.maxBackupPayloadBytes + 1);

      expect(message, isNotNull);
      expect(message, contains('900 KB'),
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
          BackupService.oversizeMessage(BackupService.maxBackupPayloadBytes + 1)!;

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
              BackupService.maxBackupPayloadBytes + 1)!));

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
    Map<String, Object?> build(String json) => BackupService.buildBackupDocument(
          backupId: '2026-03-01T09:00:00.000',
          jsonString: json,
          deviceName: 'android',
          // A stand-in for FieldValue.serverTimestamp(), which needs a live
          // Firebase app.
          createdAt: 'server-timestamp',
        );

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
        for (var i = 0; i < BackupService.maxBackupPayloadBytes * 2; i++)
          33 + random.nextInt(94),
      ]);

      expect(
        () => build(incompressible),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('too large for the cloud'))),
        reason: 'the write must not be attempted — Firestore rejects it and '
            'the user is left believing they have a backup',
      );
    });
  });
}
