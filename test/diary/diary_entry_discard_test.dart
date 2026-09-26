/// PV-20 — the diary editor threw away everything you typed, silently.
///
/// `leading: AppHeader.backButton(context)` pops the route immediately; there
/// was no dirty flag, no [PopScope] and no confirmation, so a paragraph typed
/// into the one screen in the app whose entire content is free text vanished
/// on a single tap with no message and no undo.
///
/// The shape of the fix is the add-medicine wizard's: confirm WHEN DIRTY, pop
/// straight through when not — a prompt on a form nobody has typed into is its
/// own annoyance, and it teaches people to dismiss the sheet unread.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/diary/models/diary_entry.dart';
import 'package:tablet_remainder/features/diary/screens/diary_entry_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  /// Pushes the editor onto a host route, so the back arrow is rendered and
  /// `Navigator.canPop` is true — the real arrangement, not the editor as a
  /// route root.
  Future<void> pushEditor(WidgetTester tester, {DiaryEntry? existing}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DiaryEntryScreen(existing: existing),
                ),
              ),
              child: const Text('open editor'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
  }

  Finder bodyField() => find.byType(TextFormField).last;
  Finder backArrow() => find.byTooltip('Back');

  testWidgets('backing out of typed text asks before discarding it',
      (tester) async {
    await pushEditor(tester);
    await tester.enterText(bodyField(), 'A long, careful paragraph.');
    await tester.pumpAndSettle();

    await tester.tap(backArrow());
    await tester.pumpAndSettle();

    expect(find.text('Discard this entry?'), findsOneWidget,
        reason: 'the tap must not silently destroy what was typed');
  });

  testWidgets('"Keep editing" leaves the text exactly where it was',
      (tester) async {
    await pushEditor(tester);
    await tester.enterText(bodyField(), 'A long, careful paragraph.');
    await tester.pumpAndSettle();

    await tester.tap(backArrow());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('New entry'), findsOneWidget, reason: 'still on the editor');
    expect(tester.widget<TextFormField>(bodyField()).controller!.text,
        'A long, careful paragraph.');
  });

  testWidgets('"Discard" is the only way the text actually goes away',
      (tester) async {
    await pushEditor(tester);
    await tester.enterText(bodyField(), 'A long, careful paragraph.');
    await tester.pumpAndSettle();

    await tester.tap(backArrow());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('New entry'), findsNothing);
    expect(find.text('open editor'), findsOneWidget);
  });

  testWidgets('an untouched new entry pops straight through, no prompt',
      (tester) async {
    await pushEditor(tester);

    await tester.tap(backArrow());
    await tester.pumpAndSettle();

    expect(find.text('Discard this entry?'), findsNothing,
        reason: 'nothing typed, nothing to lose — asking is just noise');
    expect(find.text('open editor'), findsOneWidget);
  });

  testWidgets('reopening a saved entry and leaving it alone pops straight through',
      (tester) async {
    await pushEditor(
      tester,
      existing: DiaryEntry(
        id: 'diary_1',
        title: 'Tuesday',
        body: 'Slept well, walked to the shops.',
        entryAt: DateTime(2026, 3, 10, 9),
        createdAt: DateTime(2026, 3, 10, 9),
      ),
    );
    expect(find.text('Edit entry'), findsOneWidget);

    await tester.tap(backArrow());
    await tester.pumpAndSettle();

    expect(find.text('Discard this entry?'), findsNothing,
        reason: 'dirtiness is measured against the entry as opened, not '
            'against empty');
    expect(find.text('open editor'), findsOneWidget);
  });

  /// The title has no `onChanged`, so before the controller listeners it was
  /// the one edit that never rebuilt the screen — `canPop` would have stayed
  /// true and a renamed entry would have popped silently.
  testWidgets('a title-only edit counts as unsaved work too', (tester) async {
    await pushEditor(
      tester,
      existing: DiaryEntry(
        id: 'diary_1',
        title: 'Tuesday',
        body: 'Slept well, walked to the shops.',
        entryAt: DateTime(2026, 3, 10, 9),
        createdAt: DateTime(2026, 3, 10, 9),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Wednesday');
    await tester.pumpAndSettle();

    await tester.tap(backArrow());
    await tester.pumpAndSettle();

    expect(find.text('Discard this entry?'), findsOneWidget);
  });

  testWidgets('the system back gesture is guarded too, not just the arrow',
      (tester) async {
    await pushEditor(tester);
    await tester.enterText(bodyField(), 'A long, careful paragraph.');
    await tester.pumpAndSettle();

    // What the platform back button/gesture does: a route-level maybePop.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard this entry?'), findsOneWidget);
  });
}
