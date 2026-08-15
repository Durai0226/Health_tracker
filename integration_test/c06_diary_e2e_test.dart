import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/features/diary/screens/diary_entry_screen.dart';
import 'package:tablet_remainder/features/diary/screens/diary_screen.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// Diary: a full CRUD round-trip on the device.
///
/// The shape every suite in this pass follows — create, assert it appears,
/// edit, assert the edit SURVIVES leaving and returning, delete, assert it is
/// gone — rather than a presence check. Presence checks are what let four
/// integration suites rot into uselessness while still reporting green.
///
/// Diary goes first because it is the simplest write path in the app: no
/// wizard, no scheduling, no platform permissions. If the harness cannot drive
/// this, it cannot drive anything, so a failure here is about the harness; a
/// failure in a later suite is about the feature.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Unique per run, so a failed run that leaves rows behind cannot make the
  // next one pass (or fail) for the wrong reason.
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final title = 'E2E entry $stamp';
  const body = 'Written by the device suite.';
  const editedBody = 'Edited by the device suite.';

  Future<void> openDiary(WidgetTester t) async {
    await E2E.launch(t);
    await E2E.goTab(t, NavTab.health);
    await E2E.tapWhenHittable(t, find.text(kDiaryTile), 'Diary tile');
    E2E.at(find.byType(DiaryScreen), where: 'Diary');
  }

  testWidgets('create → edit → delete → undo, all persisted', (t) async {
    await openDiary(t);

    // ---- create ------------------------------------------------------------
    await E2E.tapWhenHittable(t, find.text(kDiaryNewEntry), 'New entry FAB');
    E2E.at(find.byType(DiaryEntryScreen), where: 'New entry');

    await t.enterText(find.byType(TextField).first, title);
    await t.enterText(find.byType(TextField).last, body);
    await settle(t);
    await E2E.tapWhenHittable(
        t, find.byIcon(Symbols.check_rounded), 'save entry');

    E2E.at(find.byType(DiaryScreen), where: 'Diary after save');
    expect(find.text(title), findsOneWidget,
        reason: 'the new entry must appear in the list immediately');

    // ---- edit, and prove it persisted --------------------------------------
    await E2E.tapWhenHittable(t, find.text(title), 'the new entry');
    E2E.at(find.byType(DiaryEntryScreen), where: 'Edit entry');
    expect(find.text(kDiaryEditEntry), findsOneWidget,
        reason: 'tapping an existing entry must open it for EDIT, not create '
            'a second one');

    await t.enterText(find.byType(TextField).last, editedBody);
    await settle(t);
    await E2E.tapWhenHittable(
        t, find.byIcon(Symbols.check_rounded), 'save edit');

    // Leave the screen entirely and come back. An edit that only updates the
    // in-memory list looks identical to one that was written, until you do.
    await E2E.tapWhenHittable(
        t, find.byIcon(Symbols.arrow_back_rounded), 'back to Health');
    E2E.at(NavTab.health.marker, where: 'Health hub');
    await E2E.tapWhenHittable(t, find.text(kDiaryTile), 'Diary tile');

    expect(find.text(title), findsOneWidget,
        reason: 'the entry did not survive leaving and re-entering Diary');
    expect(
      find.textContaining(editedBody.substring(0, 20)),
      findsWidgets,
      reason: 'the EDIT did not persist — the list still shows the original '
          'body, so the save updated memory rather than storage',
    );

    // ---- delete, then undo -------------------------------------------------
    await t.drag(find.text(title), const Offset(-400, 0));
    await settle(t);

    expect(find.text(title), findsNothing,
        reason: 'swipe-to-dismiss must remove the row');
    expect(find.text(kDiaryEntryDeleted), findsOneWidget,
        reason: 'a destructive action must be confirmed with a way back');

    await E2E.tapWhenHittable(t, find.text(kUndo), 'Undo');
    expect(
      find.text(title),
      findsOneWidget,
      reason: 'Undo must restore the entry. An Undo that only dismisses the '
          'snackbar is worse than no Undo — the user believes their data came '
          'back.',
    );

    // ---- delete for real, and leave the database as we found it ------------
    await t.drag(find.text(title), const Offset(-400, 0));
    await settle(t);
    expect(find.text(title), findsNothing);

    await E2E.assertToastGone(t);
    E2E.assertClean('diary CRUD round-trip');
  });
}
