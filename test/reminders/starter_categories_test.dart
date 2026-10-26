import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_category_model.dart';
import 'package:tablet_remainder/features/reminders/screens/category_management_screen.dart';

/// The three built-in reminder categories were seeded without `isDefault`, so
/// the "Default" chip and the guard it implied never applied: every category,
/// built-in or not, swiped away, stripping the label from every reminder using
/// it with nothing to bring the starter set back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  ReminderCategory custom() => ReminderCategory(
      id: 'gym', name: 'Gym', color: 0xFF9C27B0, icon: 0xe532);

  test('a fresh install seeds the starters as defaults', () async {
    final rows = await db.select(db.reminderCategories).get();
    expect(rows.map((r) => r.id).toSet(), ReminderCategory.starterIds);
    expect(rows.every((r) => r.isDefault), isTrue);
  });

  test('an existing install, whose rows lack the flag, still counts them as '
      'starters', () {
    for (final id in ReminderCategory.starterIds) {
      final c = ReminderCategory(id: id, name: id, color: 0, icon: 0);
      expect(c.isDefault, isFalse, reason: 'premise: the old seed never set it');
      expect(c.isStarter, isTrue, reason: id);
    }
    expect(custom().isStarter, isFalse);
  });

  test('a starter cannot be deleted; a custom category can', () async {
    await CleanStorageService.deleteCategory('work');
    expect((await db.select(db.reminderCategories).get()).map((r) => r.id),
        contains('work'));

    await CleanStorageService.saveCategory(custom());
    expect((await db.select(db.reminderCategories).get()).map((r) => r.id),
        contains('gym'));
    await CleanStorageService.deleteCategory('gym');
    expect((await db.select(db.reminderCategories).get()).map((r) => r.id),
        isNot(contains('gym')));
  });

  testWidgets('the screen marks starters and only lets custom ones be swiped',
      (tester) async {
    await CleanStorageService.saveCategory(custom());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme, home: const CategoryManagementScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Default'), findsNWidgets(3));
    DismissDirection dir(String id) =>
        tester.widget<Dismissible>(find.byKey(Key(id))).direction;
    for (final id in ReminderCategory.starterIds) {
      expect(dir(id), DismissDirection.none, reason: id);
    }
    expect(dir('gym'), DismissDirection.endToStart);

    // Drift's stream schedules a cleanup timer when its listener goes away.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
