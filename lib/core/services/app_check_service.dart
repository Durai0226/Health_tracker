import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Owns Firebase App Check: activation, and — the part that matters — telling you
/// *why* attestation failed.
///
/// App Check is the only credential behind the zero-setup "Smart answers" tier:
/// Firebase AI Logic holds the Gemini key server-side and trusts App Check to
/// prove the request came from a genuine build. Per Firebase's docs, App Check
/// enforcement for AI Logic is automatic. So when attestation fails, Gemini
/// refuses — and without a diagnostic that looks identical to "the AI is broken".
///
/// The failure that actually bites: a **release build signed with debug keys**
/// (no `android/key.properties`) selects the Play Integrity provider but isn't
/// Play-distributed, so attestation can never succeed. [forceDebugProvider] exists
/// for exactly that case.
class AppCheckService {
  const AppCheckService._();

  /// Use the App Check *debug* provider even in a release build.
  ///
  /// For testing a locally-built release APK (which is debug-signed and therefore
  /// cannot pass Play Integrity):
  ///   flutter build apk --release --dart-define=APPCHECK_DEBUG=true
  ///
  /// Never ship this enabled — a debug-provider build accepts any registered
  /// debug token, which is precisely the abuse protection App Check provides.
  static const bool forceDebugProvider =
      bool.fromEnvironment('APPCHECK_DEBUG', defaultValue: false);

  /// True when the debug provider is in play (debug build, or the override).
  static bool get usingDebugProvider => kDebugMode || forceDebugProvider;

  /// Activate App Check. Never throws — a failure here must not block startup,
  /// it just means the AI tier stays unavailable and the built-in engine answers.
  static Future<void> activate() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: usingDebugProvider
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider:
            usingDebugProvider ? AppleProvider.debug : AppleProvider.appAttest,
      );
      debugPrint('✓ Firebase App Check activated '
          '(${usingDebugProvider ? 'debug' : 'production'} provider)');
      if (usingDebugProvider) _explainDebugToken();
    } catch (e) {
      debugPrint('⚠️ App Check activation failed: $e');
    }
  }

  /// The debug secret is printed by the *native* SDK, not by Dart, so it can't be
  /// surfaced in-app. Tell the developer where to find it instead of leaving them
  /// to guess why every AI call is rejected.
  static void _explainDebugToken() {
    debugPrint(
      '\n──── App Check: debug provider active ────\n'
      'Smart answers will be REJECTED until this device\'s debug token is\n'
      'registered. The token is printed by the native SDK — find it with:\n'
      '    adb logcat -s DebugAppCheckProvider:D\n'
      'then add it in Firebase console →\n'
      '    Build → App Check → Apps → (your app) ⋮ → Manage debug tokens\n'
      '─────────────────────────────────────────\n',
    );
  }

  /// Whether attestation actually works right now.
  ///
  /// This is a real round trip, and it isolates the failure: if this succeeds but
  /// Gemini still refuses, the problem is the Firebase project (AI Logic not
  /// enabled); if this fails, the problem is the build's attestation.
  static Future<AppCheckStatus> verify() async {
    try {
      final token = await FirebaseAppCheck.instance
          .getToken(true)
          .timeout(const Duration(seconds: 15));
      if (token == null || token.isEmpty) {
        return AppCheckStatus(ok: false, reason: _noTokenReason());
      }
      return const AppCheckStatus(ok: true, reason: 'Attestation OK');
    } catch (e) {
      debugPrint('App Check verify failed: $e');
      return AppCheckStatus(ok: false, reason: explain(e));
    }
  }

  /// Map an attestation failure onto the action that fixes it. Pure + exposed so
  /// the wording is unit-tested without a Firebase binding.
  @visibleForTesting
  static String noTokenReason() => _noTokenReason();

  static String _noTokenReason() => usingDebugProvider
      ? 'App Check returned no token. Register this device\'s debug token in '
          'the Firebase console (Build → App Check → Manage debug tokens).'
      : 'App Check returned no token. A release build signed with debug keys '
          'cannot pass Play Integrity — sign it properly, or rebuild with '
          '--dart-define=APPCHECK_DEBUG=true to test.';

  @visibleForTesting
  static String explain(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('timeout')) {
      return 'App Check timed out. Check your connection.';
    }
    if (s.contains('too many attempts') || s.contains('429')) {
      return 'App Check is rate-limiting this device. Try again shortly.';
    }
    if (s.contains('app not registered') ||
        s.contains('not registered') ||
        s.contains('403')) {
      return 'This app isn\'t registered for App Check in the Firebase project. '
          'Add it under Build → App Check.';
    }
    return _noTokenReason();
  }
}

/// Result of [AppCheckService.verify] — surfaced by the AI engine screen so a
/// failure is diagnosable instead of silent.
class AppCheckStatus {
  final bool ok;
  final String reason;
  const AppCheckStatus({required this.ok, required this.reason});
}
