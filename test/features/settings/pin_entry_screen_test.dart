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

/// Unlock-mode coverage: a correct PIN calls the success path (and actually
/// unlocks [AppLockService]); an incorrect PIN shows an inline error and
/// leaves the app locked. Biometrics are left untouched — `biometricPreferred`
/// defaults to false, so [PinEntryScreen] never reaches the (unmockable in a
/// headless test) `local_auth` plugin channel.
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

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.byKey(Key('pinDigit_$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  group('PinEntryScreen — unlock mode', () {
    testWidgets('positive: the correct PIN calls the success path and unlocks',
        (tester) async {
      await AppLockService().setPin('1234');
      AppLockService().lock();
      expect(AppLockService().isLockedNotifier.value, isTrue);

      var successCalled = false;
      await pump(
        tester,
        PinEntryScreen(
          mode: PinEntryMode.unlock,
          onSuccess: () => successCalled = true,
        ),
      );

      await enterPin(tester, '1234');

      expect(successCalled, isTrue);
      expect(AppLockService().isLockedNotifier.value, isFalse);
      expect(find.text('Incorrect PIN'), findsNothing);
    });

    testWidgets(
        'negative: an incorrect PIN shows an error and does not unlock',
        (tester) async {
      await AppLockService().setPin('1234');
      AppLockService().lock();
      expect(AppLockService().isLockedNotifier.value, isTrue);

      var successCalled = false;
      await pump(
        tester,
        PinEntryScreen(
          mode: PinEntryMode.unlock,
          onSuccess: () => successCalled = true,
        ),
      );

      await enterPin(tester, '9999');

      expect(successCalled, isFalse);
      expect(AppLockService().isLockedNotifier.value, isTrue);
      expect(find.text('Incorrect PIN'), findsOneWidget);
    });
  });
}
