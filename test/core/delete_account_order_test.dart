import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/auth_service.dart';

/// `deleteAccount` destroyed the cloud data BEFORE it found out it was not
/// allowed to.
///
/// The order was: delete every subcollection in `kUserSubcollections` —
/// `backups` first, and each of those documents is a complete health export —
/// delete the `users/{uid}` profile, then call `user.delete()`. Only that last
/// call throws `requires-recent-login`, and only there did the method catch it
/// and return "please sign in again and then delete your account". By the time
/// the user read that sentence their cloud backups were already gone, and
/// signing in again could not bring them back. Every step is irreversible, so
/// the one step that can refuse has to come first.
///
/// `runAccountDeletion` takes the two irreversible steps as callbacks precisely
/// so the ORDER can be asserted without Firebase.
void main() {
  final fresh = DateTime(2026, 3, 1, 12);

  /// Records what ran, so the assertions are about sequence, not just outcome.
  late List<String> ran;

  Future<String?> run({
    required DateTime? lastSignInTime,
    List<String> cloudFailures = const [],
  }) {
    ran = [];
    return AuthService.runAccountDeletion(
      lastSignInTime: lastSignInTime,
      now: fresh,
      deleteCloudData: () async {
        ran.add('cloud');
        return cloudFailures;
      },
      deleteAuthUser: () async => ran.add('auth'),
    );
  }

  test('a stale session is refused before anything is deleted', () async {
    final message = await run(
        lastSignInTime: fresh.subtract(const Duration(hours: 2)));

    expect(message, AuthService.reauthRequiredMessage);
    expect(ran, isEmpty,
        reason: 'the backups must still be there when the user comes back '
            'from signing in again');
  });

  test('an unknown last sign-in is treated as stale', () async {
    final message = await run(lastSignInTime: null);

    expect(message, AuthService.reauthRequiredMessage);
    expect(ran, isEmpty,
        reason: 'not knowing when someone signed in is not a reason to start '
            'deleting');
  });

  test('a recent session deletes the cloud data, then the auth user', () async {
    final message = await run(
        lastSignInTime: fresh.subtract(const Duration(minutes: 1)));

    expect(message, isNull);
    expect(ran, ['cloud', 'auth']);
  });

  test('a cloud failure stops before the auth user is deleted', () async {
    final message = await run(
      lastSignInTime: fresh.subtract(const Duration(minutes: 1)),
      cloudFailures: const ['backups'],
    );

    // Deleting the Auth user orphans whatever is left — the client can no
    // longer authenticate as the owner the rules require.
    expect(message, contains('backups'));
    expect(ran, ['cloud'],
        reason: 'the account has to stay usable so a retry can finish');
  });

  group('requiresRecentLogin', () {
    test('is false inside the window and true outside it', () {
      expect(
          AuthService.requiresRecentLogin(
              fresh.subtract(AuthService.recentLoginWindow), fresh),
          isFalse);
      expect(
          AuthService.requiresRecentLogin(
              fresh.subtract(
                  AuthService.recentLoginWindow + const Duration(seconds: 1)),
              fresh),
          isTrue);
    });

    test('a clock that jumped backwards is not treated as stale', () {
      // A negative difference must not read as "older than the window".
      expect(
          AuthService.requiresRecentLogin(
              fresh.add(const Duration(hours: 1)), fresh),
          isFalse);
    });
  });
}
