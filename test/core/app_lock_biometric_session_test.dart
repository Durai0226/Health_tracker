/// The biometric session, owned by [AppLockService].
///
/// The user's report was "works once, then never again". The mechanism is a
/// process-wide `authInProgress` flag in `local_auth_android` that sticky auth
/// could leave set forever, plus an app that turned the resulting
/// `auth_in_progress` refusal into a silent `false`. These tests pin the three
/// invariants that close it: one session at a time, an outcome the UI can act
/// on, and options that cannot orphan the flag.
library;

import 'package:drift/native.dart';
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

import '../support/fake_local_auth_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeLocalAuthPlatform fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AppLockService().resetForTesting();
    fake = FakeLocalAuthPlatform();
    LocalAuthPlatform.instance = fake;
  });
  tearDown(() async => db.close());

  test('sticky auth is OFF — the one option that could orphan the plugin flag',
      () async {
    final f = AppLockService().authenticateWithBiometrics();
    fake.complete(true);
    expect(await f, BiometricOutcome.success);
    expect(fake.accepted.single.stickyAuth, isFalse,
        reason: "with stickyAuth the plugin swallows ERROR_CANCELED while "
            "paused and never clears authInProgress; that is the bug");
    expect(fake.accepted.single.biometricOnly, isTrue,
        reason: 'a biometric failure must fall back to THIS app\'s PIN, '
            'never the device credential');
  });

  test('a second caller while a prompt is up is told BUSY and starts nothing',
      () async {
    final first = AppLockService().authenticateWithBiometrics();
    final second = await AppLockService().authenticateWithBiometrics();
    expect(second, BiometricOutcome.busy);
    expect(fake.accepted, hasLength(1),
        reason: 'the service must refuse before the plugin has to');
    expect(fake.refused, 0);
    fake.complete(true);
    expect(await first, BiometricOutcome.success,
        reason: 'the FIRST caller owns the result; busy is not shared');
  });

  test('the plugin\'s own refusal is surfaced as busy, not as a silent false',
      () async {
    // Simulate a session the plugin still thinks is live (another caller
    // started it outside this service's knowledge).
    fake.authenticate(localizedReason: 'x', authMessages: const []);
    expect(fake.inProgress, isTrue);
    AppLockService().resetForTesting(); // service has no _inFlight of its own
    final outcome = await AppLockService().authenticateWithBiometrics();
    expect(outcome, BiometricOutcome.busy);
    expect(fake.refused, 1);
  });

  test('after a session completes, the next prompt is accepted', () async {
    final a = AppLockService().authenticateWithBiometrics();
    fake.complete(false);
    expect(await a, BiometricOutcome.cancelled);
    final b = AppLockService().authenticateWithBiometrics();
    fake.complete(true);
    expect(await b, BiometricOutcome.success);
    expect(fake.accepted, hasLength(2));
  });

  test('cancelBiometrics stops the in-flight prompt and resolves it cancelled',
      () async {
    final f = AppLockService().authenticateWithBiometrics();
    await AppLockService().cancelBiometrics();
    expect(fake.stopCalls, 1);
    expect(await f, BiometricOutcome.cancelled);
    expect(fake.inProgress, isFalse);
  });

  test('cancelBiometrics with nothing in flight does not touch the plugin',
      () async {
    await AppLockService().cancelBiometrics();
    expect(fake.stopCalls, 0);
  });

  test('a pause during our own prompt does not start the grace-period clock',
      () async {
    await AppLockService().setPin('1234');
    await AppLockService().init();
    AppLockService().unlock();

    final f = AppLockService().authenticateWithBiometrics();
    // The OEM-prompt-as-activity case: showing the prompt pauses the host.
    AppLockService().didChangeAppLifecycleState(AppLifecycleState.paused);
    fake.complete(true);
    await f;
    AppLockService().didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(AppLockService().isLockedNotifier.value, isFalse,
        reason: 'a user who fumbled the sensor for 30s was re-locked the '
            'instant they succeeded');
  });

  test('a successful unlock is not undone by the pause that caused the lock',
      () async {
    // The sibling test above cannot fail on this: it round-trips in
    // milliseconds against a 30-SECOND grace period, so the re-lock branch is
    // never reached whether the guard is there or not. This one pins the clock
    // and walks the real OEM sequence.
    await AppLockService().setPin('1234');
    await AppLockService().init();
    AppLockService().unlock();

    final t0 = DateTime(2026, 3, 1, 9, 0);
    at(Duration d, void Function() body) =>
        withClock(Clock.fixed(t0.add(d)), body);

    // 1. The user backgrounds the app.
    at(Duration.zero,
        () => AppLockService()
            .didChangeAppLifecycleState(AppLifecycleState.paused));

    // 2. They come back a minute later — well past the grace period — so the
    //    app locks. This is the pause that justifies the lock.
    at(const Duration(minutes: 1),
        () => AppLockService()
            .didChangeAppLifecycleState(AppLifecycleState.resumed));
    expect(AppLockService().isLockedNotifier.value, isTrue,
        reason: 'sanity: a long background must lock, or the rest of this '
            'test proves nothing');

    // 3. The lock screen raises OUR biometric prompt. On an OEM whose prompt is
    //    its own activity, that pauses the host — and the _inFlight guard
    //    correctly refuses to restart the clock.
    final f = AppLockService().authenticateWithBiometrics();
    at(const Duration(minutes: 1, seconds: 1),
        () => AppLockService()
            .didChangeAppLifecycleState(AppLifecycleState.paused));
    fake.complete(true);
    await f;
    AppLockService().unlock(); // what PinEntryScreen does on success

    // 4. The prompt closing fires `resumed`.
    at(const Duration(minutes: 2),
        () => AppLockService()
            .didChangeAppLifecycleState(AppLifecycleState.resumed));

    expect(AppLockService().isLockedNotifier.value, isFalse,
        reason: 'the pause from step 1 was already acted on in step 2. '
            'Measuring this resume against it locks the user again the instant '
            'they authenticate — and it is guaranteed to, because that instant '
            'is by definition already past the grace period');
  });

  test('outcomes the UI must speak about are distinguished from a cancel', () {
    expect(BiometricOutcome.cancelled.deservesMessage, isFalse);
    expect(BiometricOutcome.busy.deservesMessage, isFalse);
    expect(BiometricOutcome.unavailable.deservesMessage, isTrue);
    expect(BiometricOutcome.lockedOut.deservesMessage, isTrue);
    expect(BiometricOutcome.error.deservesMessage, isTrue);
  });
}
