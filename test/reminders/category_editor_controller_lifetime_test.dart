/// Creating or editing a reminder category threw a use-after-dispose.
///
/// The editor sheet's `TextEditingController` was created in `_showEditor` and
/// released with `AppBottomSheet.show(...).whenComplete(nameController.dispose)`.
/// That future completes when `Navigator.pop` is CALLED, not when the sheet has
/// finished animating out — so the controller was disposed while the framework
/// still held it, and the rebuilds during the exit transition threw
///
///   A TextEditingController was used after being disposed.
///
/// `docs/e2e-findings.md` records the identical shape on the Smart Add sheet,
/// where it "threw a use-after-dispose on every single use". The sheet body is
/// now a `StatefulWidget` that owns the controller and disposes it at unmount —
/// which happens after the transition.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_category_model.dart';
import 'package:tablet_remainder/features/reminders/screens/category_management_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    // The service caches the DB handle and its own category/reminder caches
    // across tests; without this the second test writes through a closed
    // database.
    CleanStorageService.resetForTesting();
    ActiveProfileService().resetForTesting();
  });
  tearDown(() async => db.close());

  /// Fixed-frame pump, never `pumpAndSettle`: this screen shows a
  /// `CircularProgressIndicator` until its stream emits, and that never
  /// settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const CategoryManagementScreen(),
    ));
    await settle(tester);
  }

  /// Unmount the tree INSIDE the test.
  ///
  /// Drift's stream-query cancel schedules a zero-duration timer when the
  /// `StreamBuilder` is disposed; left to teardown it is reported as "a Timer
  /// is still pending even after the widget tree was disposed" and fails the
  /// test. Same workaround as test/responsive/responsive_overflow_test.dart.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.byIcon(Symbols.add_rounded).hitTestable().first);
    await settle(tester);
  }

  testWidgets('saving a new category never touches a disposed controller',
      (tester) async {
    await openScreen(tester);
    await openEditor(tester);

    expect(find.byType(TextField), findsOneWidget,
        reason: 'the editor sheet did not open');
    await tester.enterText(find.byType(TextField), 'Errands');
    await settle(tester);

    await tester.tap(find.text('Save'));
    // The exit transition is exactly when the old code rebuilt the sheet with
    // an already-disposed controller.
    await settle(tester);

    expect(tester.takeException(), isNull,
        reason: 'the sheet was rebuilt with a disposed TextEditingController');
    final saved = await CleanStorageService.getAllCategoriesAsync();
    expect(saved.map((c) => c.name), contains('Errands'),
        reason: 'the sheet must still do its job');
    await unmount(tester);
  });

  testWidgets('dismissing the editor without saving is also clean',
      (tester) async {
    await openScreen(tester);
    await openEditor(tester);
    expect(find.byType(TextField), findsOneWidget);

    // A tap on the barrier — the ordinary way a sheet is abandoned, and the
    // path with no `Navigator.pop` of our own at all.
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    await unmount(tester);
  });

  testWidgets('editing an existing category prefills its name and colour',
      (tester) async {
    // The state the controller now lives in is seeded from `widget.category`;
    // if that seeding were lost the editor would silently rename the category
    // to blank, so it is asserted rather than assumed.
    await CleanStorageService.saveCategory(ReminderCategory(
      id: 'cat-1',
      name: 'Chores',
      color: ReminderCategory.availableColors.last,
      icon: ReminderCategory.availableIcons.first.codePoint,
    ));
    await openScreen(tester);

    await tester.tap(find.text('Chores'));
    await settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'Chores');

    await tester.enterText(find.byType(TextField), 'Chores & errands');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    final saved = await CleanStorageService.getAllCategoriesAsync();
    expect(saved.single.name, 'Chores & errands');
    expect(saved.single.color, ReminderCategory.availableColors.last,
        reason: 'the unedited colour selection must survive the edit');
    await unmount(tester);
  });
}
