/// [PinEntryScreen]'s side of the biometric session.
///
/// The service guarantees one session at a time; the screen has to guarantee it
/// asks for one at the right moments and cancels it when it goes away.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/settings/screens/pin_entry_screen.dart';

import '../../support/fake_local_auth_platform.dart';

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
    await AppLockService().setPin('1234');
    await AppLockService().setBiometricPreferred(true);
    AppLockService().lock();
  });
  tearDown(() async => db.close());

  /// Pumps the unlock screen and lets the 300ms auto-prompt delay elapse.
  Future<void> pumpUnlock(WidgetTester tester,
      {bool autoPrompt = true}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: PinEntryScreen(
          mode: PinEntryMode.unlock, autoPromptBiometrics: autoPrompt),
    ));
    await tester.pump(); // availability futures
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('auto-prompt fires once, and a tap while it is up adds nothing',
      (tester) async {
    await pumpUnlock(tester);
    expect(fake.accepted, hasLength(1));
    await tester.ensureVisible(find.byKey(const Key('pinBiometricButton')));
    await tester.tap(find.byKey(const Key('pinBiometricButton')));
    await tester.pump();
    expect(fake.accepted, hasLength(1),
        reason: '_tryBiometrics used to read _busy and never set it, so the '
            'auto-fire and the button could overlap');
    expect(fake.refused, 0);
    fake.complete(true);
    await tester.pump();
    expect(AppLockService().isLockedNotifier.value, isFalse);
  });

  testWidgets('the keypad stays usable while the prompt is up', (tester) async {
    await pumpUnlock(tester);
    expect(fake.inProgress, isTrue);
    for (final d in '1234'.split('')) {
      await tester.tap(find.byKey(Key('pinDigit_$d')));
      await tester.pump();
    }
    expect(AppLockService().isLockedNotifier.value, isFalse,
        reason: 'the PIN is the fallback this feature promises; a biometric '
            'in flight must never disable it');
    fake.complete(false);
    await tester.pump();
  });

  testWidgets('disposing the screen cancels the session it started',
      (tester) async {
    await pumpUnlock(tester);
    expect(fake.inProgress, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(fake.stopCalls, 1,
        reason: 'when the alarm route suppressed the overlay mid-prompt, the '
            'success landed on a disposed widget and nobody unlocked');
    expect(fake.inProgress, isFalse);
  });

  testWidgets('a cancelled prompt is re-offered exactly once on resume',
      (tester) async {
    await pumpUnlock(tester);
    fake.complete(false); // OS cancelled it — a pause, an incoming call
    await tester.pump();
    expect(fake.accepted, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(fake.accepted, hasLength(2),
        reason: 'this is the one thing stickyAuth bought, done without the '
            'process-wide flag it left behind');

    fake.complete(false);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    // Second cancel also re-offers once — each cancel earns one re-offer, so a
    // user who keeps backing out is not trapped in a loop of prompts.
    expect(fake.accepted, hasLength(3));
    fake.complete(true);
    await tester.pump();
  });

  testWidgets('autoPromptBiometrics: false issues no prompt on build',
      (tester) async {
    await pumpUnlock(tester, autoPrompt: false);
    expect(fake.accepted, isEmpty,
        reason: "Settings' identity check had just prompted; the pushed "
            'screen prompting again 300ms later collided with it');
    // The button still works.
    await tester.ensureVisible(find.byKey(const Key('pinBiometricButton')));
    await tester.tap(find.byKey(const Key('pinBiometricButton')));
    await tester.pump();
    expect(fake.accepted, hasLength(1));
    fake.complete(true);
    await tester.pump();
  });

  testWidgets('no sensor says so; a plain cancel says nothing', (tester) async {
    fake.enrolled = [];
    await pumpUnlock(tester);
    // canUseBiometrics is false, so no button and no prompt at all.
    expect(find.byKey(const Key('pinBiometricButton')), findsNothing);
    expect(fake.accepted, isEmpty);
  });

  testWidgets('a locked-out sensor surfaces a message in the error slot',
      (tester) async {
    await pumpUnlock(tester);
    // End the auto-prompt as cancelled, then make the NEXT prompt throw.
    fake.complete(false);
    await tester.pump();
    LocalAuthPlatform.instance = _ThrowingPlatform('LockedOut');
    await tester.ensureVisible(find.byKey(const Key('pinBiometricButton')));
    await tester.tap(find.byKey(const Key('pinBiometricButton')));
    await tester.pump();
    expect(find.textContaining('Too many attempts'), findsOneWidget);
  });
}

/// A platform whose next authenticate() throws the given code.
class _ThrowingPlatform extends FakeLocalAuthPlatform {
  _ThrowingPlatform(this.code);
  final String code;
  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    throw PlatformException(code: code);
  }
}
