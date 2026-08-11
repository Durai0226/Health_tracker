import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/app_check_service.dart';

/// App Check is the ONLY credential Firebase AI Logic accepts — it holds the
/// Gemini key server-side and trusts attestation instead. So when attestation
/// fails, Gemini refuses before it is ever reached, and without a diagnostic that
/// is indistinguishable from "the AI is broken".
///
/// These assertions cover the wording, because the wording IS the feature here:
/// each failure has a different fix and the message has to name it.
void main() {
  group('provider selection', () {
    test('a debug build uses the debug provider', () {
      // Tests run in debug, so this is the debug-build path.
      expect(kDebugMode, isTrue);
      expect(AppCheckService.usingDebugProvider, isTrue);
    });

    test('the release override defaults OFF', () {
      // APPCHECK_DEBUG must never be on unless explicitly dart-defined — a
      // debug-provider release build accepts any registered debug token, which
      // discards the abuse protection App Check exists to provide.
      expect(AppCheckService.forceDebugProvider, isFalse);
    });
  });

  group('failure wording names the fix', () {
    test('no-token guidance points at the debug-token registration', () {
      final r = AppCheckService.noTokenReason();
      expect(r.toLowerCase(), contains('debug token'));
      expect(r, contains('Firebase console'));
    });

    test('a timeout is reported as a connection problem, not a broken AI', () {
      final r = AppCheckService.explain(Exception('TimeoutException after 15s'));
      expect(r.toLowerCase(), contains('timed out'));
    });

    test('rate limiting says to retry rather than to reconfigure', () {
      final r = AppCheckService.explain(Exception('Too many attempts'));
      expect(r.toLowerCase(), contains('again'));
      expect(r.toLowerCase(), isNot(contains('debug token')),
          reason: 'a 429 is transient — do not send the user to the console');
    });

    test('an unregistered app is named as such', () {
      final r = AppCheckService.explain(Exception('App not registered (403)'));
      expect(r, contains('App Check'));
      expect(r.toLowerCase(), contains('registered'));
    });

    test('every path returns actionable, non-empty prose', () {
      for (final e in <Object>[
        Exception('kaboom'),
        Exception('403 forbidden'),
        Exception('network unreachable'),
        StateError('unexpected'),
      ]) {
        final r = AppCheckService.explain(e);
        expect(r, isNotEmpty);
        expect(r, isNot(contains('Exception')),
            reason: 'never surface a raw exception to a user');
        expect(r.trim().endsWith('.'), isTrue,
            reason: 'complete sentences: "$r"');
      }
    });
  });

  group('AppCheckStatus', () {
    test('carries both the verdict and the reason', () {
      const ok = AppCheckStatus(ok: true, reason: 'Attestation OK');
      expect(ok.ok, isTrue);
      expect(ok.reason, isNotEmpty);

      const bad = AppCheckStatus(ok: false, reason: 'nope');
      expect(bad.ok, isFalse);
    });
  });
}
