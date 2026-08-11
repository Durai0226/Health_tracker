import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import 'clean_storage_service.dart';

/// App-wide PIN + optional biometric lock.
///
/// PIN is the base requirement; biometrics are an optional accelerant on top
/// of it — never biometric-only, so a biometric failure (sensor glitch, no
/// enrolled face/finger after an OS update, …) can never lock the user out
/// permanently. The PIN itself is stored as a salted SHA-256 hash (never in
/// plaintext) via [CleanStorageService.getAppPreference] /
/// [CleanStorageService.setAppPreference] — no new Drift table.
///
/// Mirrors [ActiveProfileService] / `FocusService`'s singleton pattern (a
/// bare factory constructor returning one shared instance) rather than an
/// all-static class, because this service also needs to be a
/// [WidgetsBindingObserver] to react to app lifecycle changes.
class AppLockService with WidgetsBindingObserver {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  static const String keyLockEnabled = 'securityLockEnabled';
  static const String keyPinSalt = 'securityPinSalt';
  static const String keyPinHash = 'securityPinHash';
  static const String keyBiometricPreferred = 'securityBiometricPreferred';

  /// Quick app-switches (a permission dialog, sharing to another app, the
  /// notification shade, …) never re-prompt for the PIN — only a background
  /// stay longer than this does.
  static const Duration gracePeriod = Duration(seconds: 30);

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isInitialized = false;
  bool _observerRegistered = false;

  /// Set when the app is paused; cleared by nothing (only overwritten by the
  /// NEXT pause) — [didChangeAppLifecycleState] reads it on the matching
  /// resume to decide whether the grace period has elapsed. Staying `null`
  /// for this whole process (i.e. the app was never backgrounded) is exactly
  /// the "cold start" case, which [init] already locks eagerly.
  DateTime? _lastBackgroundedAt;

  /// Transient runtime lock state for the current process. `true` means
  /// [AppLockGate] should show the PIN entry overlay.
  final ValueNotifier<bool> isLockedNotifier = ValueNotifier<bool>(false);

  /// Whether app lock is turned on at all. When `false`, [isLockedNotifier]
  /// is never flipped to `true` by this service.
  bool get isLockEnabled =>
      CleanStorageService.getAppPreference(keyLockEnabled, false) == true;

  /// Whether the user has opted into a biometric shortcut on top of the PIN.
  bool get isBiometricPreferred =>
      CleanStorageService.getAppPreference(keyBiometricPreferred, false) ==
      true;

  /// Whether a PIN has ever been set on this device.
  bool get hasPinSet =>
      CleanStorageService.getAppPreference(keyPinSalt) != null &&
      CleanStorageService.getAppPreference(keyPinHash) != null;

  /// Call once, alongside the other critical services in `main.dart`.
  /// Idempotent. On a genuine cold start (this process has never seen a
  /// `paused` lifecycle event) the lock is engaged immediately when enabled —
  /// there is no prior [_lastBackgroundedAt] to check a grace period against.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    if (isLockEnabled) {
      isLockedNotifier.value = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastBackgroundedAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    if (!isLockEnabled) return;

    final last = _lastBackgroundedAt;
    // No pause recorded yet this process => already handled by init()'s
    // cold-start check; a resume with nothing to compare against is not the
    // "backgrounded too long" case this method exists to catch.
    if (last == null) return;
    if (DateTime.now().difference(last) > gracePeriod) {
      lock();
    }
  }

  /// Engages the overlay (no-op when lock isn't enabled).
  void lock() {
    if (!isLockEnabled) return;
    isLockedNotifier.value = true;
  }

  /// Dismisses the overlay. Does not touch whether lock is enabled.
  void unlock() {
    isLockedNotifier.value = false;
  }

  // ---- PIN ----

  String _generateSalt([int lengthBytes = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(lengthBytes, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  /// Hashes and persists a new PIN (salted SHA-256 — never the raw digits)
  /// and turns app lock on. Used for both first-time setup and "Change PIN".
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await CleanStorageService.setAppPreference(keyPinSalt, salt);
    await CleanStorageService.setAppPreference(keyPinHash, hash);
    await CleanStorageService.setAppPreference(keyLockEnabled, true);
  }

  /// Constant-shape comparison against the stored salted hash. Returns
  /// `false` (never throws) when no PIN has been set yet.
  bool verifyPin(String pin) {
    final salt = CleanStorageService.getAppPreference(keyPinSalt) as String?;
    final hash = CleanStorageService.getAppPreference(keyPinHash) as String?;
    if (salt == null || hash == null) return false;
    return _hashPin(pin, salt) == hash;
  }

  /// Turns app lock off. The caller is responsible for verifying the current
  /// PIN/biometric first — this method itself does not re-check identity.
  Future<void> disableLock() async {
    await CleanStorageService.setAppPreference(keyLockEnabled, false);
    isLockedNotifier.value = false;
  }

  Future<void> setBiometricPreferred(bool preferred) async {
    await CleanStorageService.setAppPreference(
        keyBiometricPreferred, preferred);
  }

  // ---- Biometrics (optional accelerant, never the only path) ----

  /// Whether this device can actually offer a biometric prompt right now
  /// (hardware present, OS support, and at least one biometric enrolled).
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('AppLockService: biometric availability check failed: $e');
      return false;
    }
  }

  /// Prompts the OS biometric UI. `biometricOnly: true` so a failure here
  /// never silently falls back to the device's OWN pin/pattern — this app's
  /// PIN screen stays the fallback shown underneath.
  Future<bool> authenticateWithBiometrics(
      {String reason = 'Unlock DailyMinder'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options:
            const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (e) {
      debugPrint('AppLockService: biometric authentication failed: $e');
      return false;
    }
  }

  // ---- Forgot PIN (no server-side recovery for a local PIN) ----

  /// The only way out of a forgotten PIN: wipes all local app data via the
  /// same path Settings' "Delete all data" uses, then clears the PIN itself
  /// and turns app lock off, so the user is never left stuck behind a locked
  /// overlay with no way back in. Callers MUST have already shown the user a
  /// clear, explicit warning before calling this — it is irreversible.
  Future<void> resetForgottenPin() async {
    try {
      await CleanStorageService.clearAllData();
      await CleanStorageService.clearAllPersistentData();
    } finally {
      await CleanStorageService.removeAppPreference(keyPinSalt);
      await CleanStorageService.removeAppPreference(keyPinHash);
      await CleanStorageService.setAppPreference(keyBiometricPreferred, false);
      await disableLock();
    }
  }

  /// Test-only: drops in-memory runtime state so a test's `init()` re-runs
  /// the cold-start check instead of no-op'ing because a PRIOR test in the
  /// same run already flipped [_isInitialized]. Persisted preferences (in
  /// whatever storage the test itself set up) are untouched.
  @visibleForTesting
  void resetForTesting() {
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
    _isInitialized = false;
    _lastBackgroundedAt = null;
    isLockedNotifier.value = false;
  }
}
