/// "Delete all data" with a copy in the cloud.
///
/// It wiped the device and left cloud sync on, so at the next start the sync did
/// what it is for and brought every record back. The order below is the whole
/// point: the cloud first, sync off before the wipe, and a failed cloud step
/// stops everything before the device is touched.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/delete_all_data.dart';

void main() {
  group('whether a cloud copy is in play', () {
    test('needs sync on AND an account to sync to', () {
      expect(DeleteAllData.cloudCopyAtStake(syncOn: true, signedIn: true), isTrue);
      expect(DeleteAllData.cloudCopyAtStake(syncOn: true, signedIn: false), isFalse,
          reason: 'sync "on" with nobody signed in uploads nothing');
      expect(DeleteAllData.cloudCopyAtStake(syncOn: false, signedIn: true), isFalse,
          reason: 'signed in but never opted in: no copy was made');
      expect(DeleteAllData.cloudCopyAtStake(syncOn: false, signedIn: false), isFalse);
    });
  });

  group('running it', () {
    late List<String> calls;
    late List<String> cloudFailures;

    Future<String?> run(DeleteAllScope scope, {required bool atStake}) =>
        DeleteAllData.run(
          scope: scope,
          cloudCopyAtStake: atStake,
          deleteCloudCopy: () async {
            calls.add('cloud');
            return cloudFailures;
          },
          turnSyncOff: () async => calls.add('sync-off'),
          wipeLocal: () async => calls.add('wipe'),
        );

    setUp(() {
      calls = [];
      cloudFailures = [];
    });

    test('this device and the cloud: cloud first, then sync off, then the wipe',
        () async {
      expect(await run(DeleteAllScope.deviceAndCloud, atStake: true), isNull);
      expect(calls, ['cloud', 'sync-off', 'wipe']);
    });

    test('this device only, with a cloud copy: sync off before the wipe, the copy untouched',
        () async {
      expect(await run(DeleteAllScope.deviceOnly, atStake: true), isNull);
      expect(calls, ['sync-off', 'wipe'],
          reason: 'the wipe is never left standing with sync still on, or the next '
              'start brings it all back');
    });

    test('with no cloud copy it is just the wipe, and sync is not touched', () async {
      expect(await run(DeleteAllScope.deviceOnly, atStake: false), isNull);
      expect(calls, ['wipe']);
    });

    test('asking for the cloud when there is none to delete does not call it',
        () async {
      expect(await run(DeleteAllScope.deviceAndCloud, atStake: false), isNull);
      expect(calls, ['wipe']);
    });

    test('a cloud step that fails stops before anything on the device is touched',
        () async {
      cloudFailures = ['medicines', 'backups'];

      final message = await run(DeleteAllScope.deviceAndCloud, atStake: true);

      expect(message, contains('medicines, backups'));
      expect(message, contains('Nothing on this device was deleted'));
      expect(calls, ['cloud'],
          reason: 'an empty device over a surviving cloud copy reads as "gone" '
              'while a full record sits on a server');
    });

    test('a failure to turn sync off stops the wipe too', () async {
      Object? thrown;
      try {
        await DeleteAllData.run(
          scope: DeleteAllScope.deviceOnly,
          cloudCopyAtStake: true,
          deleteCloudCopy: () async => const [],
          turnSyncOff: () async => throw StateError('prefs unavailable'),
          wipeLocal: () async => calls.add('wipe'),
        );
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<StateError>());
      expect(calls, isEmpty, reason: 'wiping with sync still on is the bug itself');
    });
  });

  group('what it says afterwards', () {
    test('plainly, when there was nothing in the cloud', () {
      expect(
          DeleteAllData.doneMessage(
              scope: DeleteAllScope.deviceOnly, cloudCopyAtStake: false),
          'All data deleted.');
    });

    test('that the cloud copy went, and sync is off', () {
      final m = DeleteAllData.doneMessage(
          scope: DeleteAllScope.deviceAndCloud, cloudCopyAtStake: true);
      expect(m, contains('here and in the cloud'));
      expect(m, contains('Cloud sync is off'));
    });

    test('that the cloud copy is still there, when it was kept', () {
      final m = DeleteAllData.doneMessage(
          scope: DeleteAllScope.deviceOnly, cloudCopyAtStake: true);
      expect(m, contains('from this device'));
      expect(m, contains('cloud copy stays where it is'),
          reason: 'not saying so would let someone believe it was gone');
    });
  });
}
