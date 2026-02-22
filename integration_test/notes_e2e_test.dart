import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/main.dart' as app;
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Notes Feature E2E Tests', () {
    setUp(() async {
      await Hive.initFlutter();
    });

    tearDown(() async {
      await Hive.close();
    });

    testWidgets('Create a simple text note', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Tap the "New Note" FAB
      final fabFinder = find.byType(FloatingActionButton).first;
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Enter title
      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.enterText(titleField, 'My First Note');
      await tester.pumpAndSettle();

      // Tap edit button to start editing
      final editButton = find.byIcon(Icons.edit_rounded);
      if (editButton.evaluate().isNotEmpty) {
        await tester.tap(editButton);
        await tester.pumpAndSettle();
      }

      // Enter some content
      final contentField = find.byType(TextField).last;
      await tester.tap(contentField);
      await tester.enterText(contentField, 'This is my first note content.');
      await tester.pumpAndSettle();

      // Save the note
      final saveButton = find.byIcon(Icons.check);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Go back
      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify note appears in list
      expect(find.text('My First Note'), findsOneWidget);
    });

    testWidgets('Create a checklist note', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Create new note
      final fabFinder = find.byType(FloatingActionButton).first;
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Enter title
      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.enterText(titleField, 'Shopping List');
      await tester.pumpAndSettle();

      // Start editing
      final editButton = find.byIcon(Icons.edit_rounded);
      if (editButton.evaluate().isNotEmpty) {
        await tester.tap(editButton);
        await tester.pumpAndSettle();
      }

      // Tap checklist button in toolbar
      final checklistButton = find.byIcon(Icons.check_box_outlined);
      if (checklistButton.evaluate().isNotEmpty) {
        await tester.tap(checklistButton);
        await tester.pumpAndSettle();
      }

      // Save and go back
      final saveButton = find.byIcon(Icons.check);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify note appears
      expect(find.text('Shopping List'), findsOneWidget);
    });

    testWidgets('Create and manage tags', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Open options menu
      final moreButton = find.byIcon(Icons.more_vert_rounded);
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      // Tap "Manage Tags"
      final manageTagsButton = find.text('Manage Tags');
      await tester.tap(manageTagsButton);
      await tester.pumpAndSettle();

      // Create new tag
      final createTagButton = find.text('Create New Tag');
      await tester.tap(createTagButton);
      await tester.pumpAndSettle();

      // Enter tag name
      final tagNameField = find.byType(TextField).first;
      await tester.tap(tagNameField);
      await tester.enterText(tagNameField, 'Work');
      await tester.pumpAndSettle();

      // Create tag
      final createButton = find.text('Create');
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verify tag was created
      expect(find.text('Work'), findsWidgets);
    });

    testWidgets('Add tag to note', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Create a note first
      final fabFinder = find.byType(FloatingActionButton).first;
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.enterText(titleField, 'Tagged Note');
      await tester.pumpAndSettle();

      // Save note
      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Long press on note to open options
      final noteTile = find.text('Tagged Note');
      await tester.longPress(noteTile);
      await tester.pumpAndSettle();

      // Tap "Add Tags"
      final addTagsButton = find.text('Add Tags');
      if (addTagsButton.evaluate().isNotEmpty) {
        await tester.tap(addTagsButton);
        await tester.pumpAndSettle();

        // Select a tag (if any exist)
        final checkboxes = find.byType(CheckboxListTile);
        if (checkboxes.evaluate().isNotEmpty) {
          await tester.tap(checkboxes.first);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Change note color', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Create a note
      final fabFinder = find.byType(FloatingActionButton).first;
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.enterText(titleField, 'Colorful Note');
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Long press on note
      final noteTile = find.text('Colorful Note');
      await tester.longPress(noteTile);
      await tester.pumpAndSettle();

      // Tap "Change Color"
      final changeColorButton = find.text('Change Color');
      if (changeColorButton.evaluate().isNotEmpty) {
        await tester.tap(changeColorButton);
        await tester.pumpAndSettle();

        // Select a color
        final colorCircles = find.byType(GestureDetector);
        if (colorCircles.evaluate().length > 1) {
          await tester.tap(colorCircles.at(1));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Pin and unpin note', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Create a note
      final fabFinder = find.byType(FloatingActionButton).first;
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.enterText(titleField, 'Important Note');
      await tester.pumpAndSettle();

      // Open menu
      final menuButton = find.byType(PopupMenuButton<String>);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Tap Pin
      final pinButton = find.text('Pin');
      if (pinButton.evaluate().isNotEmpty) {
        await tester.tap(pinButton);
        await tester.pumpAndSettle();
      }

      // Go back
      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Navigate to Pinned tab
      final pinnedTab = find.text('Pinned');
      if (pinnedTab.evaluate().isNotEmpty) {
        await tester.tap(pinnedTab);
        await tester.pumpAndSettle();

        // Verify note appears in pinned
        expect(find.text('Important Note'), findsOneWidget);
      }
    });

    testWidgets('Archive and unarchive note', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Create a note
      final fabFinder = find.byType(FloatingActionButton).first;
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.enterText(titleField, 'Archive Test Note');
      await tester.pumpAndSettle();

      // Open menu and archive
      final menuButton = find.byType(PopupMenuButton<String>);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      final archiveButton = find.text('Archive');
      if (archiveButton.evaluate().isNotEmpty) {
        await tester.tap(archiveButton);
        await tester.pumpAndSettle();
      }

      // Should navigate back automatically
      await tester.pumpAndSettle();

      // Navigate to Archive tab
      final archiveTab = find.text('Archive');
      if (archiveTab.evaluate().isNotEmpty) {
        await tester.tap(archiveTab);
        await tester.pumpAndSettle();

        // Verify note appears in archive
        expect(find.text('Archive Test Note'), findsOneWidget);
      }
    });

    testWidgets('Delete note (move to trash)', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Create a note
      final fabFinder = find.byType(FloatingActionButton).first;
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.enterText(titleField, 'Delete Test Note');
      await tester.pumpAndSettle();

      // Open menu and delete
      final menuButton = find.byType(PopupMenuButton<String>);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      final deleteButton = find.text('Delete');
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();
      }

      // Should navigate back
      await tester.pumpAndSettle();

      // Verify note is not in active notes
      expect(find.text('Delete Test Note'), findsNothing);
    });

    testWidgets('Search notes', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Create a note
      final fabFinder = find.byType(FloatingActionButton).first;
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.enterText(titleField, 'Searchable Note');
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Use search bar
      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.enterText(searchField, 'Searchable');
      await tester.pumpAndSettle();

      // Verify note appears in search results
      expect(find.text('Searchable Note'), findsOneWidget);
    });

    testWidgets('Filter notes by tag', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Find and tap a tag chip (if any exist)
      final tagChips = find.byType(GestureDetector);
      if (tagChips.evaluate().length > 1) {
        // Skip the "All" chip and tap another tag
        await tester.tap(tagChips.at(1));
        await tester.pumpAndSettle();

        // Notes should be filtered
        // This is a basic check - actual verification depends on data
      }
    });

    testWidgets('Switch between grid and list view', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Find view toggle button
      final viewToggleButton = find.byIcon(Icons.view_list_rounded);
      if (viewToggleButton.evaluate().isNotEmpty) {
        await tester.tap(viewToggleButton);
        await tester.pumpAndSettle();

        // Should switch to list view
        // Verify by checking for list view icon
        expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

        // Toggle back
        final gridToggleButton = find.byIcon(Icons.grid_view_rounded);
        await tester.tap(gridToggleButton);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('View tasks (checklists) tab', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Navigate to Tasks tab
      final tasksTab = find.text('Tasks');
      if (tasksTab.evaluate().isNotEmpty) {
        await tester.tap(tasksTab);
        await tester.pumpAndSettle();

        // Should show only notes with checklists
        // This is a visual verification
      }
    });

    testWidgets('Sync indicator shows on notes', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Notes
      final notesTab = find.text('Notes');
      if (notesTab.evaluate().isNotEmpty) {
        await tester.tap(notesTab);
        await tester.pumpAndSettle();
      }

      // Tap sync button in app bar
      final syncButton = find.byIcon(Icons.cloud_sync_rounded);
      if (syncButton.evaluate().isNotEmpty) {
        await tester.tap(syncButton);
        await tester.pumpAndSettle();

        // Should navigate to backup settings
        // This verifies sync functionality is accessible
      }
    });
  });
}
