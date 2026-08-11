import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/diary/screens/diary_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const DiaryScreen()));
    await tester.pumpAndSettle();
  }

  /// The header's save button — the only Symbols.check_rounded icon on the
  /// editor screen.
  Finder saveButton() => find.byIcon(Symbols.check_rounded);

  testWidgets('empty state prompts to write the first entry', (tester) async {
    await pump(tester);
    expect(find.text('Your diary'), findsOneWidget);
    expect(find.text('Write your first entry'), findsOneWidget);
  });

  testWidgets('positive: writing an entry saves and shows in the list', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Write your first entry'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'A quiet, good day.');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Write your first entry'), findsNothing);
    expect(find.textContaining('A quiet, good day.'), findsWidgets);
  });

  testWidgets('positive: editing an existing entry updates it in place', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Write your first entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Original text.');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Original text.').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit entry'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'Updated text.');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('Updated text.'), findsWidgets);
    expect(find.textContaining('Original text.'), findsNothing);
  });

  testWidgets('negative: saving with an empty body is rejected', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Write your first entry'));
    await tester.pumpAndSettle();

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Write something before saving.'), findsOneWidget);
    // Still on the editor — the empty state is not visible.
    expect(find.text('New entry'), findsOneWidget);
  });
}
