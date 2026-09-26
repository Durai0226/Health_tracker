/// The brute-force lockout has to be VISIBLE, and it was not.
///
/// [AppLockService.remainingLockout] existed from the day the lockout was
/// added and had no reader outside the service. `verifyPin` refuses every PIN
/// while a lockout stands — including the right one — so [PinEntryScreen] told
/// the user 'Incorrect PIN' for up to 30 minutes when their PIN was correct,
/// with nothing on screen to say there was anything to wait for.
///
/// Every test here drives the lockout the way a user does: five wrong PINs on
/// the keypad. The clock is faked so the countdown is exact rather than
/// "roughly 30s", and so the expiry can be reached without waiting for it.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase;
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/settings/screens/pin_entry_screen.dart';

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

  Future<void> pump(WidgetTester tester, Widget home,
      {double textScale = 1.0}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale, maxScaleFactor: textScale, child: child!),
      home: home,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.byKey(Key('pinDigit_$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// Five misses is the first count [AppLockService.lockoutFor] punishes.
  Future<void> failUntilLockedOut(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await enterPin(tester, '9999');
    }
  }

  /// Unmounts the screen, which is what cancels the countdown's timer.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
  }

  testWidgets('the lockout is named and counted down, not called a wrong PIN',
      (tester) async {
    final now = DateTime(2026, 3, 14, 9, 30);
    await withClock(Clock(() => now), () async {
      await AppLockService().setPin('1234');
      AppLockService().lock();

      var successCalled = false;
      await pump(
        tester,
        PinEntryScreen(
          mode: PinEntryMode.unlock,
          onSuccess: () => successCalled = true,
        ),
      );

      await failUntilLockedOut(tester);

      // The miss that ARMS the lockout is the one that has to say so: from
      // here on every PIN is refused, so 'Incorrect PIN' is no longer true of
      // what the app is doing.
      expect(AppLockService().remainingLockout, const Duration(seconds: 30),
          reason: 'sanity: five misses is a 30s lockout');
      expect(find.text('Too many attempts — try again in 30s'), findsOneWidget);
      expect(find.text('Incorrect PIN'), findsNothing);

      // The user now types the RIGHT PIN. It cannot work — the service refuses
      // it — and the screen must not blame them for it.
      await enterPin(tester, '1234');

      expect(successCalled, isFalse);
      expect(AppLockService().isLockedNotifier.value, isTrue);
      expect(find.text('Incorrect PIN'), findsNothing,
          reason: 'the PIN was correct; only the lockout refused it');
      expect(find.text('Too many attempts — try again in 30s'), findsOneWidget);

      await close(tester);
    });
  });

  testWidgets('the countdown ticks down and lets go when it expires',
      (tester) async {
    var now = DateTime(2026, 3, 14, 9, 30);
    await withClock(Clock(() => now), () async {
      await AppLockService().setPin('1234');
      AppLockService().lock();

      var successCalled = false;
      await pump(
        tester,
        PinEntryScreen(
          mode: PinEntryMode.unlock,
          onSuccess: () => successCalled = true,
        ),
      );
      await failUntilLockedOut(tester);
      expect(find.text('Too many attempts — try again in 30s'), findsOneWidget);

      now = now.add(const Duration(seconds: 25));
      await tester.pump(const Duration(seconds: 1)); // one tick of the ticker
      expect(find.text('Too many attempts — try again in 5s'), findsOneWidget,
          reason: 'a countdown that does not count down is just a label');

      now = now.add(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Too many attempts'), findsNothing,
          reason: 'the lockout is over — the warning has to go with it');

      // And the keypad is live again: the correct PIN unlocks.
      await enterPin(tester, '1234');
      expect(successCalled, isTrue);
      expect(AppLockService().isLockedNotifier.value, isFalse);

      await close(tester);
    });
  });

  testWidgets('the message line grows to fit the countdown instead of cropping it',
      (tester) async {
    // 320pt is the narrowest phone this app supports, and 1.6x is well inside
    // the range Android and iOS offer. The countdown is a whole sentence; the
    // slot it went into was 20 logical pixels tall, full stop.
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 3, 14, 9, 30);
    await withClock(Clock(() => now), () async {
      await AppLockService().setPin('1234');
      AppLockService().lock();
      await pump(tester, const PinEntryScreen(mode: PinEntryMode.unlock),
          textScale: 1.6);
      await failUntilLockedOut(tester);

      final message = find.text('Too many attempts — try again in 30s');
      expect(message, findsOneWidget);
      expect(tester.getSize(message).height, greaterThan(20),
          reason: 'the message was laid out into a fixed 20px box, so every '
              'line of it past the first was cropped away');
      expect(tester.takeException(), isNull);

      await close(tester);
    });
  });
}
