/// "Forgot PIN" is the one irreversible button on this screen, and it could
/// fail in silence.
///
/// `CleanStorageService.clearAllPersistentData()` deliberately rethrows — its
/// doc says the error is "rethrown for the caller to surface" — and
/// [AppLockService.resetForgottenPin] lets it through after its `finally` has
/// already turned the lock off. `_onForgotPin` caught nothing: the spinner
/// stayed up, the success toast never fired, no error took its place, and the
/// overlay dismissed itself anyway. The user confirmed "Erase everything",
/// was let straight into the app, and was never told the erase had stopped
/// half-way.
///
/// Settings' own "Delete all data" reports exactly this failure
/// (`_showResultSnack('Delete failed: $e')`); this path did not.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase;
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
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

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {/* several tests close it themselves, on purpose */}
  });

  testWidgets('a wipe that fails half-way says so instead of just letting you in',
      (tester) async {
    // Tall enough that the whole column, "Forgot PIN?" included, is laid out
    // — the screen scrolls, and a tap that lands off-stage proves nothing.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await AppLockService().setPin('1234');
    AppLockService().lock();

    // No AppTheme here on purpose: this test has to let real async work run
    // (see runAsync below), and AppTheme pulls Google Fonts, which this repo
    // does not bundle — every text style would then throw. `AppColorsExt.of`
    // falls back to the light palette when the extension is absent.
    await tester.pumpWidget(const MaterialApp(
      home: PinEntryScreen(mode: PinEntryMode.unlock),
    ));
    await tester.pumpAndSettle();

    // The failure the rethrow exists for: the database is gone by the time the
    // deletes run. Closing it is the only honest way to reach that from a test
    // — every write CleanStorageService makes on the way there swallows its
    // own error, so nothing else on this path can fail.
    await db.close();

    await tester.tap(find.byKey(const Key('pinForgotLink')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erase everything'));
    await tester.pumpAndSettle();
    // The reset crosses real platform channels (sign-out, SharedPreferences),
    // which never complete inside testWidgets' fake-async zone.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not be erased'), findsOneWidget,
        reason: 'the erase stopped half-way and nothing said so');
    expect(find.text('PIN reset. All local data was erased.'), findsNothing,
        reason: 'it was not erased');

    // And the screen is usable again rather than stuck behind its spinner.
    final forgot = tester.widget<TextButton>(
        find.ancestor(
                of: find.text('Forgot PIN?'), matching: find.byType(TextButton))
            .first);
    expect(forgot.onPressed, isNotNull,
        reason: '_busy was never cleared, so the screen stayed inert');

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
  });
}
