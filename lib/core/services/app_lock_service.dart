import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_service.dart';
import 'clean_storage_service.dart';
import 'package:clock/clock.dart';
import '../../core/constants/app_strings.dart';

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

  /// The one biometric session that may be in flight, app-wide.
  ///
  /// `local_auth_android` keeps a process-wide `authInProgress` flag and answers
  /// every `authenticate()` made while it is set with
  /// `PlatformException('auth_in_progress')`. Two callers in this app can race
  /// for it — the lock gate's auto-prompt and Settings' identity check — so
  /// the service owns the session and a second caller is told [BiometricOutcome.busy]
  /// rather than being allowed to start a prompt that will be refused.
  ///
  /// Deliberately NOT shared between callers: a success belongs to whoever
  /// started it. When Settings' session completed over the gate, the gate stayed
  /// locked and Settings ran `disableLock()` — App Lock switched off behind a
  /// PIN pad that never went away.
  Future<BiometricOutcome>? _inFlight;

  bool _isInitialized = false;
  bool _observerRegistered = false;

  /// Set when the app is paused, and cleared once that pause has been acted
  /// on — by [lock] and by [unlock], so one pause can never justify a second
  /// re-lock (see [unlock] for the loop that made this necessary).
  /// [didChangeAppLifecycleState] reads it on the matching resume to decide
  /// whether the grace period has elapsed. `null` therefore means "no
  /// unhandled pause to measure against"; staying `null` for a whole process
  /// (i.e. the app was never backgrounded) is the "cold start" case, which
  /// [init] already locks eagerly.
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
      // Not while our own prompt is up. On stock Android BiometricPrompt does
      // not pause the host activity, so this never fires; on an OEM whose
      // prompt IS an activity it does — and a user who fumbled the sensor for
      // 30s was re-locked the instant they succeeded, because the grace period
      // had been ticking against a pause the app itself caused.
      if (_inFlight != null) return;
      _lastBackgroundedAt = clock.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    if (!isLockEnabled) return;

    final last = _lastBackgroundedAt;
    // No pause recorded yet this process => already handled by init()'s
    // cold-start check; a resume with nothing to compare against is not the
    // "backgrounded too long" case this method exists to catch.
    if (last == null) return;
    if (clock.now().difference(last) > gracePeriod) {
      lock();
    }
  }

  /// Engages the overlay (no-op when lock isn't enabled).
  void lock() {
    if (!isLockEnabled) return;
    // The pause that justified this lock has now been acted on. Leaving it set
    // means the NEXT resume re-measures against the same instant — see unlock().
    _lastBackgroundedAt = null;
    isLockedNotifier.value = true;
  }

  /// Dismisses the overlay. Does not touch whether lock is enabled.
  void unlock() {
    // Clearing here is what stops a successful unlock being undone.
    //
    // `_lastBackgroundedAt` was only ever set, never cleared, so on an OEM whose
    // biometric prompt is its own activity: background at T0 -> resume late ->
    // lock() -> our prompt raises -> `paused` fires but the _inFlight guard
    // returns, so T0 SURVIVES -> the user authenticates -> `resumed` fires and
    // measures against T0, which is by definition already past the grace period
    // -> lock() again, racing this very call. The guard stopped the timestamp
    // being refreshed; it did nothing about the stale one.
    _lastBackgroundedAt = null;
    isLockedNotifier.value = false;
  }

  // ---- PIN ----

  String _generateSalt([int lengthBytes = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(lengthBytes, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Iteration count for [_hashPin].
  ///
  /// A single SHA-256 round over a 4-digit PIN is 10,000 hashes to exhaust —
  /// microseconds. Stretching turns an offline guess of the whole keyspace
  /// from instant into seconds-to-minutes, which is the difference between
  /// "trivial" and "not worth it" for a device thief. 120k is chosen to stay
  /// under ~150ms on a low-end phone, since it runs on the unlock path.
  static const int kPinHashRounds = 120000;

  /// Salted, stretched hash. Not raw SHA-256 — see [kPinHashRounds].
  ///
  /// Iterated SHA-256 rather than PBKDF2-HMAC because `crypto` is already a
  /// dependency and this needs no new package; the security property that
  /// matters here (cost per guess) is the same.
  String _hashPin(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$pin'));
    for (var i = 1; i < kPinHashRounds; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return digest.toString();
  }

  /// Legacy single-round hash, kept ONLY so existing installs can still unlock
  /// and be transparently upgraded on their next successful entry.
  String _legacyHashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  // ---- brute-force throttling ----------------------------------------------
  //
  // There was none: `_submitUnlock` called `verifyPin` with no counter, no
  // lockout and no backoff, so an attacker holding the device could try all
  // 10,000 PINs by hand or by automation with nothing stopping them.

  static const String keyFailedAttempts = 'securityPinFailedAttempts';
  static const String keyLockedUntil = 'securityPinLockedUntilMs';

  /// How long unlocking stays blocked after [failures] consecutive misses.
  /// Nothing for the first 4 (fat fingers), then escalating.
  static Duration lockoutFor(int failures) {
    if (failures < 5) return Duration.zero;
    if (failures < 8) return const Duration(seconds: 30);
    if (failures < 11) return const Duration(minutes: 5);
    return const Duration(minutes: 30);
  }

  /// Remaining lockout, or [Duration.zero] when entry is allowed.
  Duration get remainingLockout {
    final until =
        (CleanStorageService.getAppPreference(keyLockedUntil) as num?)?.toInt();
    if (until == null) return Duration.zero;
    final ms = until - clock.now().millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
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
    // Refuse outright while locked out, so a caller that forgets to check
    // [remainingLockout] still cannot be used as a guessing oracle.
    if (remainingLockout > Duration.zero) return false;

    final salt = CleanStorageService.getAppPreference(keyPinSalt) as String?;
    final hash = CleanStorageService.getAppPreference(keyPinHash) as String?;
    if (salt == null || hash == null) return false;

    var ok = _hashPin(pin, salt) == hash;

    // Transparent upgrade: an install created before stretching still holds a
    // single-round hash. Accept it once, then immediately re-hash at the new
    // cost so the weak form is gone after the next unlock.
    if (!ok && _legacyHashPin(pin, salt) == hash) {
      ok = true;
      unawaited(setPin(pin));
    }

    unawaited(_recordAttempt(success: ok));
    return ok;
  }

  /// One batched write, not two awaited ones — and that is load-bearing, not
  /// tidiness. [CleanStorageService.setAppPreferences] fills the preference
  /// cache synchronously before it touches the database, so by the time
  /// [verifyPin] returns to its caller [remainingLockout] is already true of
  /// the world. Written as a write, an await, then a second write, the lockout
  /// a miss had just armed did not exist yet for the screen that had to
  /// announce it: it became visible only on the attempt AFTER it.
  Future<void> _recordAttempt({required bool success}) async {
    if (success) {
      await CleanStorageService.setAppPreferences(
          {keyFailedAttempts: 0, keyLockedUntil: 0});
      return;
    }
    final failures =
        ((CleanStorageService.getAppPreference(keyFailedAttempts) as num?)
                    ?.toInt() ??
                0) +
            1;
    final lockout = lockoutFor(failures);
    await CleanStorageService.setAppPreferences({
      keyFailedAttempts: failures,
      if (lockout > Duration.zero)
        keyLockedUntil: clock.now().add(lockout).millisecondsSinceEpoch,
    });
  }

  /// Turns app lock off and forgets the PIN along with it. The caller is
  /// responsible for verifying the current PIN/biometric first — this method
  /// itself does not re-check identity.
  ///
  /// The salt/hash have to go, not just the enabled flag. [hasPinSet] is what
  /// `AuthService.signOut()` consults to decide whether to re-arm the lock on
  /// the way out, and a PIN left on disk made that `true` forever — so a user
  /// who had deliberately turned App Lock OFF was silently locked behind it
  /// again by signing out. Nothing is lost by forgetting it: the only way back
  /// on is the switch in App lock settings, and that already pushes PIN setup
  /// rather than reusing whatever was stored.
  Future<void> disableLock() async {
    await CleanStorageService.setAppPreference(keyLockEnabled, false);
    await CleanStorageService.removeAppPreference(keyPinSalt);
    await CleanStorageService.removeAppPreference(keyPinHash);
    await CleanStorageService.setAppPreference(keyBiometricPreferred, false);
    // A lockout is counted against a specific PIN. Left standing it outlives
    // the PIN it punished and blocks the NEXT one — which is precisely the
    // user who just came through "Forgot PIN" after failing repeatedly.
    await CleanStorageService.setAppPreference(keyFailedAttempts, 0);
    await CleanStorageService.setAppPreference(keyLockedUntil, 0);
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

  /// Prompts the OS biometric UI and says what happened, not just whether.
  ///
  /// ## Why the options changed
  ///
  /// This used to pass `stickyAuth: true` inside `try { } catch (e) { return
  /// false; }`, and that combination is the whole bug the user reported as
  /// "biometrics work once, then never again".
  ///
  /// Sticky auth asks the plugin to re-show the prompt after a transient pause.
  /// To do that, `local_auth_android`'s `AuthenticationHelper` SWALLOWS
  /// `ERROR_CANCELED` while the activity is paused — no completion, no
  /// `stop()` — and re-creates a prompt on every resume. Its process-wide
  /// `authInProgress` flag therefore stays set until that re-shown prompt
  /// delivers a terminal result. If it never does (the session's owner is gone,
  /// or on OEMs whose prompt is itself an activity, so every cancel arrives
  /// "while paused"), every later `authenticate()` from any screen is refused
  /// with `auth_in_progress`, which the catch-all turned into a silent `false`.
  ///
  /// `stopAuthentication()` is not a way out: in 1.0.56 it cancels only the
  /// ORIGINAL prompt and never removes the lifecycle observer, so the
  /// re-created prompts are untouchable and the observer re-prompts forever.
  ///
  /// With `stickyAuth: false` the swallow branch is never taken: a pause
  /// delivers `ERROR_CANCELED` → completion → `stop()`, the flag clears, and
  /// the observer is removed. `PinEntryScreen` re-offers the prompt once on the
  /// next resume, which is the only thing sticky bought us.
  ///
  /// `biometricOnly: true` stays: a biometric failure must fall back to THIS
  /// app's PIN screen, never to the device's own credential.
  Future<BiometricOutcome> authenticateWithBiometrics(
      {String reason = 'Unlock ${AppStrings.productName}'}) {
    final pending = _inFlight;
    if (pending != null) {
      // Refuse to start a second prompt. The plugin would refuse it anyway,
      // and telling the caller WHY lets the UI leave the PIN pad usable
      // instead of showing nothing.
      return Future.value(BiometricOutcome.busy);
    }
    final run = _authenticate(reason);
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  Future<BiometricOutcome> _authenticate(String reason) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
        ),
      );
      return ok ? BiometricOutcome.success : BiometricOutcome.cancelled;
    } on PlatformException catch (e) {
      debugPrint('AppLockService: biometric prompt failed: ${e.code} ${e.message}');
      return switch (e.code) {
        'auth_in_progress' => BiometricOutcome.busy,
        'NotAvailable' || 'NotEnrolled' || 'PasscodeNotSet' =>
          BiometricOutcome.unavailable,
        'LockedOut' || 'PermanentlyLockedOut' => BiometricOutcome.lockedOut,
        _ => BiometricOutcome.error,
      };
    } catch (e) {
      debugPrint('AppLockService: biometric prompt threw: $e');
      return BiometricOutcome.error;
    }
  }

  /// Cancels an in-flight prompt. Called when the screen that started it goes
  /// away, so a session never outlives its owner.
  ///
  /// Safe only because sticky auth is off: the non-sticky cancel path in the
  /// plugin completes the session AND removes its lifecycle observer.
  Future<void> cancelBiometrics() async {
    if (_inFlight == null) return;
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('AppLockService: stopAuthentication failed: $e');
    }
  }

  // ---- Forgot PIN (no server-side recovery for a local PIN) ----

  /// The only way out of a forgotten PIN: signs out, wipes all local app data
  /// via the same path Settings' "Delete all data" uses, then clears the PIN
  /// itself and turns app lock off, so the user is never left stuck behind a
  /// locked overlay with no way back in. Callers MUST have already shown the
  /// user a clear, explicit warning before calling this — it is irreversible.
  ///
  /// The sign-out is not incidental. Wiping alone left the user signed in with
  /// cloud sync still on, so `main.dart`'s next `syncUserData` pass downloaded
  /// everything this method had just destroyed — onto a device whose App Lock
  /// is now off. The erase the user asked for undid itself and handed the data
  /// back unprotected. `AuthService.signOut()` is what turns cloud sync off.
  Future<void> resetForgottenPin() async {
    // Sever the cloud FIRST, before a single local row is deleted: if the wipe
    // below fails half-way, there must no longer be a synced copy able to
    // restore the remainder. signOut() re-arms the lock while a PIN still
    // exists — the `finally` below is what settles the final state.
    try {
      await AuthService().signOut();
    } catch (e) {
      // A sign-out failure must never strand someone behind a PIN they have
      // forgotten, so this is not rethrown. Cloud sync is the part that has to
      // be off either way; set it directly.
      debugPrint('AppLockService: sign-out during PIN reset failed: $e');
      await CleanStorageService.setCloudSyncEnabled(false);
    }
    try {
      await CleanStorageService.clearAllData();
      await CleanStorageService.clearAllPersistentData();
    } finally {
      // disableLock() also forgets the PIN, the biometric preference and any
      // standing lockout — see its doc comment.
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
    _inFlight = null;
    isLockedNotifier.value = false;
  }
}

/// What a biometric prompt actually did. A `bool` collapsed "the user backed
/// out" with "the plugin refused to start" and "there is no sensor", and only
/// the first of those is something the UI should stay silent about.
enum BiometricOutcome {
  success,

  /// The user dismissed the prompt, or the OS cancelled it (a pause).
  cancelled,

  /// No hardware, nothing enrolled, or no device credential set.
  unavailable,

  /// Too many failed attempts at the OS level.
  lockedOut,

  /// A prompt is already in flight — ours or one the plugin still thinks is.
  busy,

  /// Anything else, logged with its code.
  error;

  /// Whether the PIN screen should say something. Silence for a cancel is
  /// right — the user knows they cancelled — but silence for "no sensor" leaves
  /// them tapping a button that does nothing.
  bool get deservesMessage =>
      this == unavailable || this == lockedOut || this == error;
}
