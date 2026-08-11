import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase;
import 'package:tablet_remainder/core/services/app_lock_service.dart';
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
  });
}
