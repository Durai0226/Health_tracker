import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A `LocalAuthPlatform` that behaves like `local_auth_android` 1.0.56 does.
///
/// The property that matters is the process-wide flag: the real plugin refuses
/// every `authenticate()` made while one is unresolved, with
/// `PlatformException('auth_in_progress')`. A fake that just returned `true`
/// could not reproduce the bug this exists to pin, so this one keeps the same
/// flag and the same refusal.
///
/// Injected with `LocalAuthPlatform.instance = FakeLocalAuthPlatform()`. The
/// app-facing `LocalAuthentication` delegates every call to that instance, so
/// `AppLockService` needs no test seam of its own.
class FakeLocalAuthPlatform extends LocalAuthPlatform
    with MockPlatformInterfaceMixin {
  /// Every `authenticate()` that was ACCEPTED (not refused as in-progress).
  final List<AuthenticationOptions> accepted = [];

  /// How many calls were refused with `auth_in_progress`.
  int refused = 0;

  int stopCalls = 0;

  bool supported = true;
  List<BiometricType> enrolled = [BiometricType.fingerprint];

  Completer<bool>? _pending;

  /// True while a prompt is "showing" — the Java flag.
  bool get inProgress => _pending != null && !_pending!.isCompleted;

  /// Resolve the showing prompt the way the OS would.
  void complete(bool success) {
    final c = _pending;
    if (c == null || c.isCompleted) return;
    c.complete(success);
    _pending = null;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) {
    if (inProgress) {
      refused++;
      throw PlatformException(
          code: 'auth_in_progress', message: 'Authentication in progress');
    }
    accepted.add(options);
    final c = Completer<bool>();
    _pending = c;
    return c.future;
  }

  @override
  Future<bool> stopAuthentication() async {
    stopCalls++;
    // Non-sticky cancel: the prompt completes as cancelled and the flag clears.
    complete(false);
    return true;
  }

  @override
  Future<bool> deviceSupportsBiometrics() async => supported;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => enrolled;
}
