/// Security regressions, pinned.
///
/// A security fix without a test is a security fix that comes back. Each group
/// below states the defect it guards and the one-line revert that must break
/// it.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  group('the app-lock PIN never leaves the device', () {
    test('export omits the PIN salt and hash', () async {
      await AppLockService().setPin('1234');

      // Sanity: they really are in the preference store.
      expect(
        CleanStorageService.getAppPreference(AppLockService.keyPinHash),
        isA<String>(),
        reason: 'setPin should have persisted a hash to verify against',
      );

      final export = await CleanStorageService.exportAllData();
      final prefs = export['preferences'] as Map;

      for (final key in CleanStorageService.kNeverLeaveTheDevice) {
        expect(
          prefs.containsKey(key),
          isFalse,
          reason: 'Backups are written to a shared ZIP and uploaded to '
              'Firestore. "$key" in that payload means anyone the user sends a '
              'backup to can recover their app-lock PIN — 10,000 hashes for a '
              '4-digit PIN with a known salt — and many people reuse it as '
              'their device PIN.',
        );
      }
    });

    test('import refuses to restore security or consent state', () async {
      await AppLockService().setPin('1234');
      final realHash =
          CleanStorageService.getAppPreference(AppLockService.keyPinHash);

      // A crafted backup: disable the lock, install the attacker's PIN, and
      // switch on the cloud upload the user opted out of.
      await CleanStorageService.restoreBackup({
        'preferences': {
          'securityLockEnabled': false,
          'securityPinHash': 'attacker-controlled-hash',
          'securityPinSalt': 'attacker-controlled-salt',
          'cloudSyncEnabled': true,
          'darkMode': true, // a legitimate key, must still restore
        },
      }, clearExisting: false);

      expect(
        CleanStorageService.getAppPreference(AppLockService.keyPinHash),
        realHash,
        reason: 'a restore file replaced the user\'s PIN',
      );
      expect(
        CleanStorageService.getAppPreference(AppLockService.keyLockEnabled),
        isNot(false),
        reason: 'a restore file switched off the app lock',
      );
      expect(
        CleanStorageService.cloudSyncEnabled,
        isFalse,
        reason: 'a restore file enabled cloud upload without consent',
      );
      expect(
        CleanStorageService.getAppPreference('darkMode'),
        true,
        reason: 'ordinary preferences must still restore — the denylist has to '
            'be surgical, not a blanket refusal',
      );
    });
  });

  group('the PIN resists brute force', () {
    test('a correct PIN verifies and a wrong one does not', () async {
      final lock = AppLockService();
      await lock.setPin('4321');
      expect(lock.verifyPin('4321'), isTrue);
      expect(lock.verifyPin('0000'), isFalse);
    });

    test('repeated failures trigger an escalating lockout', () async {
      final lock = AppLockService();
      await lock.setPin('4321');

      expect(AppLockService.lockoutFor(0), Duration.zero);
      expect(AppLockService.lockoutFor(4), Duration.zero,
          reason: 'the first few misses are fat fingers, not an attack');
      expect(AppLockService.lockoutFor(5), greaterThan(Duration.zero));
      expect(AppLockService.lockoutFor(11),
          greaterThan(AppLockService.lockoutFor(8)),
          reason: 'the delay must escalate, or guessing is only slowed, not '
              'stopped');

      for (var i = 0; i < 5; i++) {
        lock.verifyPin('0000');
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        lock.remainingLockout,
        greaterThan(Duration.zero),
        reason: 'There was no attempt counter, no lockout and no backoff at '
            'all — a 4-digit PIN is a 10,000-entry keyspace and nothing stood '
            'between an attacker holding the device and exhausting it.',
      );
      expect(lock.verifyPin('4321'), isFalse,
          reason: 'even the CORRECT pin must be refused while locked out, so a '
              'caller that forgets to check cannot be used as an oracle');
    });

    test('the hash is stretched, not a single round', () {
      expect(
        AppLockService.kPinHashRounds,
        greaterThanOrEqualTo(100000),
        reason: 'One SHA-256 round over 10,000 possible PINs is exhausted in '
            'microseconds once the hash leaks. Stretching is what makes an '
            'offline guess cost something.',
      );
    });
  });
}
