/// The one destructive action on the Focus tags screen, asked and answered.
///
/// DS-13 moved `_showDeleteConfirmation` off a raw `AlertDialog` and onto
/// `ConfirmationBottomSheet.showDelete`. That swap changes what the confirm
/// button *returns*: the dialog deleted from inside its own button callback,
/// while the sheet hands a `bool?` back to the caller, which then branches. A
/// branch is a thing that can be written backwards, and both ways of getting it
/// wrong are silent — a tag that vanishes on Cancel, or a Delete that does
/// nothing at all. Nothing else in the suite touches this screen's delete path,
/// so this pins all three answers: dismissed, cancelled, confirmed.
///
/// The sheet is dismissible on purpose: the `AlertDialog` it replaced did not
/// pass `barrierDismissible: false`, so a tap on the barrier has to keep
/// meaning "no" — which is exactly what the first test asserts.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/focus/models/custom_tag.dart';
import 'package:tablet_remainder/features/focus/screens/custom_tags_screen.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

void main() {
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    FocusService().resetForTesting();
    TagService().resetForTesting();
  });

  tearDown(() async {
    TagService().resetForTesting();
    FocusService().resetForTesting();
    await db.close();
  });

  /// Seeds one custom tag and puts the screen on a viewport tall enough to show
  /// it without scrolling.
  ///
  /// The chip has to be long-pressed to reach the confirmation at all, and
  /// `scrollUntilVisible` throws on this app's scrolling screens — so the
  /// viewport is sized around the content instead. `tester.view.physicalSize`,
  /// not a `MediaQuery` override: only the view changes the size the screen is
  /// actually laid out at.
  Future<void> pumpTagsScreen(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 2000);
    addTearDown(tester.view.reset);

    await TagService().createTag(
      name: 'Deep Work',
      colorValue: FocusTag.availableColors.first.value,
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const AccentScope(
          feature: FeatureAccent.focus, child: CustomTagsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openDeleteSheet(WidgetTester tester) async {
    await tester.longPress(find.text('Deep Work'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Tag?'), findsOneWidget,
        reason: 'the long-press must still open the confirmation');
    expect(find.text('Are you sure you want to delete "Deep Work"?'),
        findsOneWidget,
        reason: 'the tag being deleted must still be named in the question — '
            "showDelete's generic copy does not name it");
  }

  testWidgets('dismissing the sheet deletes nothing', (tester) async {
    await pumpTagsScreen(tester);
    await openDeleteSheet(tester);

    // The barrier, not a button: a dismissed sheet completes with null, and
    // null must read as "no".
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Delete Tag?'), findsNothing);
    expect(TagService().customTags.map((t) => t.name), ['Deep Work']);
    expect(find.text('Deep Work'), findsOneWidget);
  });

  testWidgets('Cancel deletes nothing', (tester) async {
    await pumpTagsScreen(tester);
    await openDeleteSheet(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Tag?'), findsNothing);
    expect(TagService().customTags.map((t) => t.name), ['Deep Work']);
    expect(find.text('Deep Work'), findsOneWidget);
  });

  testWidgets('Delete removes the tag', (tester) async {
    await pumpTagsScreen(tester);
    await openDeleteSheet(tester);

    // 'Delete' is the button; 'Delete Tag?' is the title, and `find.text`
    // matches the whole string, so this cannot pick up the header.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Tag?'), findsNothing);
    expect(TagService().customTags, isEmpty);
    expect(find.text('Deep Work'), findsNothing,
        reason: 'the chip must go with the tag — the service notifies and the '
            'ListenableBuilder rebuilds');
    // The defaults are untouched: this deletes one tag, not the list.
    expect(TagService().defaultTags, isNotEmpty);
  });
}
