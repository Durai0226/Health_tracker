/// Focus tags can be renamed.
///
/// A tag was fixed at the name it was created with: the only way to fix a typo
/// or a changed mind was to delete it, which loses the sessions already filed
/// under it. Sessions point at a tag by id, so a rename carries through to all
/// of them.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppButton;
import 'package:tablet_remainder/features/focus/screens/custom_tags_screen.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final tags = TagService();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    FocusService().resetForTesting();
    tags.resetForTesting();
    await tags.init();
  });

  tearDown(() async {
    tags.resetForTesting();
    await db.close();
  });

  String nameOf(String id) => tags.tags.firstWhere((t) => t.id == id).name;

  group('TagService.renameTag', () {
    test('a custom tag takes the new name', () async {
      final t = await tags.createTag(name: 'Deep wrk', colorValue: 0xFF2196F3);
      expect(await tags.renameTag(t.id, 'Deep work'), TagRename.renamed);
      expect(nameOf(t.id), 'Deep work');
    });

    test('so does a starter tag: they are the person\'s to word', () async {
      expect(await tags.renameTag('study', 'Revision'), TagRename.renamed);
      expect(nameOf('study'), 'Revision');
      expect(tags.tags.firstWhere((t) => t.id == 'study').isDefault, isTrue,
          reason: 'a rename does not make it a different kind of tag');
    });

    test('the name is trimmed', () async {
      final t = await tags.createTag(name: 'x', colorValue: 0xFF2196F3);
      await tags.renameTag(t.id, '   Admin   ');
      expect(nameOf(t.id), 'Admin');
    });

    test('everything else about the tag, and how often it was used, is kept',
        () async {
      final t = await tags.createTag(
          name: 'Plan', colorValue: 0xFF4CAF50, emoji: '📚');
      await tags.tagSession('s1', [t.id]);
      final before = tags.tags.firstWhere((x) => x.id == t.id);

      await tags.renameTag(t.id, 'Planning');

      final after = tags.tags.firstWhere((x) => x.id == t.id);
      expect(after.id, before.id);
      expect(after.color, before.color);
      expect(after.emoji, '📚');
      expect(after.usageCount, before.usageCount);
      expect(tags.getTagObjectsForSession('s1').map((x) => x.name), ['Planning'],
          reason: 'sessions point at the id, so they carry the new name');
    });

    test('an empty name is refused and nothing changes', () async {
      final t = await tags.createTag(name: 'Keep', colorValue: 0xFF2196F3);
      expect(await tags.renameTag(t.id, '   '), TagRename.empty);
      expect(nameOf(t.id), 'Keep');
    });

    test('a name another tag already has is refused, ignoring case', () async {
      final t = await tags.createTag(name: 'Gym', colorValue: 0xFF2196F3);
      expect(await tags.renameTag(t.id, 'study'), TagRename.duplicate);
      expect(await tags.renameTag(t.id, '  WORK '), TagRename.duplicate);
      expect(nameOf(t.id), 'Gym');
    });

    test('changing only the case of a tag\'s OWN name is allowed', () async {
      final t = await tags.createTag(name: 'deep work', colorValue: 0xFF2196F3);
      expect(await tags.renameTag(t.id, 'Deep Work'), TagRename.renamed);
      expect(nameOf(t.id), 'Deep Work');
    });

    test('the same name again is unchanged', () async {
      final t = await tags.createTag(name: 'Gym', colorValue: 0xFF2196F3);
      expect(await tags.renameTag(t.id, 'Gym'), TagRename.unchanged);
    });

    test('an unknown tag is not found', () async {
      expect(await tags.renameTag('nope', 'Anything'), TagRename.notFound);
    });

    test('and it is saved: a fresh load sees the new name', () async {
      final t = await tags.createTag(name: 'Old', colorValue: 0xFF2196F3);
      await tags.renameTag(t.id, 'New');

      await tags.init(); // reads back from preferences
      expect(nameOf(t.id), 'New');
    });
  });

  group('on the Tags screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(500, 1800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const CustomTagsScreen()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpFor(WidgetTester tester, [int n = 6]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> startRename(WidgetTester tester, String chip) async {
      await tester.tap(find.text(chip).first);
      await pumpFor(tester);
      await tester.tap(find.text('Rename'));
      await pumpFor(tester);
    }

    testWidgets('a tag\'s sheet offers Rename, and the new name shows',
        (tester) async {
      await open(tester);
      await startRename(tester, 'Study');

      expect(find.text('Rename tag'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Revision');
      await tester.tap(find.text('Save'));
      await pumpFor(tester);

      expect(nameOf('study'), 'Revision');
      expect(find.text('Revision'), findsWidgets);
      expect(find.text('Study'), findsNothing);
    });

    testWidgets('a name that is already used stays open and says why',
        (tester) async {
      await open(tester);
      await startRename(tester, 'Study');

      await tester.enterText(find.byType(TextField).last, 'work');
      await tester.tap(find.text('Save'));
      await pumpFor(tester);

      expect(find.text('You already have a tag with that name.'),
          findsOneWidget);
      expect(find.text('Rename tag'), findsOneWidget,
          reason: 'still open, with what was typed');
      expect(nameOf('study'), 'Study');
    });

    testWidgets('creating a tag closes its sheet cleanly: the controller is '
        'not disposed under a field still on screen', (tester) async {
      await open(tester);
      await tester.tap(find.text('Create tag'));
      await pumpFor(tester);
      await tester.enterText(find.byType(TextField).last, 'Gym');
      await tester.tap(find.widgetWithText(AppButton, 'Create tag'));
      await pumpFor(tester, 10);

      expect(tester.takeException(), isNull);
      expect(tags.tags.map((t) => t.name), contains('Gym'));
    });

    testWidgets('an empty name stays open and says why', (tester) async {
      await open(tester);
      await startRename(tester, 'Study');

      await tester.enterText(find.byType(TextField).last, '  ');
      await tester.tap(find.text('Save'));
      await pumpFor(tester);

      expect(find.text('Give the tag a name.'), findsOneWidget);
      expect(nameOf('study'), 'Study');
    });
  });
}
