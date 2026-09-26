import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase;
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/auth_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

/// [AppLockService] is a singleton backed by [CleanStorageService]'s
/// Drift-backed app-preferences store (never a Drift schema change of its
/// own — see the service's doc comment). Each test builds a fresh in-memory
/// DB — the same pattern `profile_isolation_test.dart` uses — and resets
/// [CleanStorageService]'s cached DB handle so the service actually re-reads
/// from it instead of a stale handle left by a previous test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AppLockService().resetForTesting();
  });

  tearDown(() async => db.close());

  group('PIN hash + verify', () {
    test('setPin then verifyPin with the SAME pin succeeds', () async {
      await AppLockService().setPin('1234');
      expect(AppLockService().verifyPin('1234'), isTrue);
    });

    test('verifyPin with a WRONG pin fails', () async {
      await AppLockService().setPin('1234');
      expect(AppLockService().verifyPin('4321'), isFalse);
    });

    test('verifyPin fails when no PIN has ever been set', () {
      expect(AppLockService().verifyPin('0000'), isFalse);
    });
  });

  group('lock-enabled flag persistence', () {
    test('setPin turns app lock on and it round-trips through persisted storage',
        () async {
      await AppLockService().setPin('1234');
      expect(AppLockService().isLockEnabled, isTrue);

      // Simulate a fresh process re-reading persisted state: drop every
      // in-memory cache but keep the same underlying (in-memory) database.
      CleanStorageService.resetForTesting();
      await CleanStorageService.loadAppPreferences();
      expect(AppLockService().isLockEnabled, isTrue);
    });

    test('disableLock turns it back off and that also round-trips', () async {
      await AppLockService().setPin('1234');
      await AppLockService().disableLock();
      expect(AppLockService().isLockEnabled, isFalse);

      CleanStorageService.resetForTesting();
      await CleanStorageService.loadAppPreferences();
      expect(AppLockService().isLockEnabled, isFalse);
    });
  });

  group('the PIN is never persisted in plaintext', () {
    test('the stored salt/hash preferences never equal the raw PIN string',
        () async {
      const rawPin = '1234';
      await AppLockService().setPin(rawPin);

      final storedHash =
          CleanStorageService.getAppPreference(AppLockService.keyPinHash);
      final storedSalt =
          CleanStorageService.getAppPreference(AppLockService.keyPinSalt);

      expect(storedHash, isNot(equals(rawPin)));
      expect(storedSalt, isNot(equals(rawPin)));
      expect(storedHash, isA<String>());
      expect((storedHash as String).contains(rawPin), isFalse);

      // Re-read from the underlying persisted store (not just the in-memory
      // cache) to guard against a bug that caches the hash but never actually
      // writes it through to storage.
      CleanStorageService.resetForTesting();
      await CleanStorageService.loadAppPreferences();
      final reread =
          CleanStorageService.getAppPreference(AppLockService.keyPinHash);
      expect(reread, equals(storedHash));
      expect(reread, isNot(equals(rawPin)));
    });
  });

  group('turning the lock off forgets the PIN', () {
    test('disableLock removes the salt/hash from PERSISTED storage', () async {
      await AppLockService().setPin('1234');
      expect(AppLockService().hasPinSet, isTrue);

      await AppLockService().disableLock();
      expect(AppLockService().hasPinSet, isFalse);

      // Fresh process: the credential has to be gone from storage, not merely
      // dropped from the in-memory cache.
      CleanStorageService.resetForTesting();
      await CleanStorageService.loadAppPreferences();
      expect(CleanStorageService.getAppPreference(AppLockService.keyPinSalt),
          isNull);
      expect(CleanStorageService.getAppPreference(AppLockService.keyPinHash),
          isNull);
      expect(AppLockService().hasPinSet, isFalse);
    });

    test('signing out does NOT re-arm a lock the user turned off', () async {
      await AppLockService().setPin('1234');
      await AppLockService().disableLock();

      // AuthService.signOut() re-arms app lock for anyone who still has a PIN
      // on disk. A lock the user deliberately switched off must therefore not
      // leave one behind for it to find.
      await AuthService().signOut();

      expect(AppLockService().isLockEnabled, isFalse,
          reason: 'sign-out re-armed a lock the user had turned off');
      expect(AppLockService().isLockedNotifier.value, isFalse);
    });

    test('signing out DOES still re-arm a lock the user left ON', () async {
      // The other half of the contract, so the fix above cannot be mistaken
      // for "sign-out no longer protects anything".
      await AppLockService().setPin('1234');
      await AuthService().signOut();
      expect(AppLockService().isLockEnabled, isTrue);
    });
  });

  group('forgot-PIN reset (no lockout trap)', () {
    test('resetForgottenPin clears the PIN, disables the lock, and unlocks',
        () async {
      await AppLockService().setPin('1234');
      AppLockService().lock();
      expect(AppLockService().isLockedNotifier.value, isTrue);

      await AppLockService().resetForgottenPin();

      expect(AppLockService().isLockEnabled, isFalse);
      expect(AppLockService().isLockedNotifier.value, isFalse);
      expect(AppLockService().verifyPin('1234'), isFalse);
    });

    test(
        'resetForgottenPin signs out and turns cloud sync OFF, so the cloud '
        'cannot restore what the wipe destroyed', () async {
      SharedPreferences.setMockInitialValues({
        'current_user_data': '{"id":"u1","name":"T","email":"t@example.com"}',
      });
      await CleanStorageService.setCloudSyncEnabled(true);
      await AppLockService().setPin('1234');
      AppLockService().lock();

      await AppLockService().resetForgottenPin();

      // Re-read from Drift the way the next launch does. Asserting on the live
      // value alone would be vacuous: clearAllData() empties the preference
      // CACHE, so `cloudSyncEnabled` falls back to its `false` default while
      // the stored row can still say true.
      CleanStorageService.resetForTesting();
      await CleanStorageService.loadAppPreferences();

      expect(CleanStorageService.cloudSyncEnabled, isFalse,
          reason: "sync left on means main.dart's next syncUserData pass "
              'downloads everything the wipe just destroyed — onto a device '
              'whose App Lock is now off');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('current_user_data'), isNull,
          reason: 'AuthService.signOut() must actually have run; flipping the '
              'sync flag alone would leave the user signed in');
    });

    test('a standing lockout does not survive the reset', () async {
      await AppLockService().setPin('1234');
      for (var i = 0; i < 5; i++) {
        AppLockService().verifyPin('9999');
        // verifyPin records the miss fire-and-forget; let the write land.
        await Future<void>.delayed(Duration.zero);
      }
      expect(AppLockService().remainingLockout, greaterThan(Duration.zero));

      await AppLockService().resetForgottenPin();

      // Next app launch: preferences are re-read from Drift, so a lockout left
      // in storage comes back — counted against a PIN that no longer exists.
      CleanStorageService.resetForTesting();
      await CleanStorageService.loadAppPreferences();
      await AppLockService().setPin('5678');
      expect(AppLockService().verifyPin('5678'), isTrue,
          reason: 'a lockout earned by the FORGOTTEN PIN locked the user out '
              'of the new one');
    });
  });
}
