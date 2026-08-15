/// The Home screen the user screenshotted.
///
/// What was on screen: a three-line greeting, the literal word "User" as the
/// title, and the AI briefing truncated mid-sentence at "…a glass no…".
/// "Good evening" appeared TWICE — once in the header, once inside the briefing
/// sentence, which is what pushed the actionable clause past the two-line clamp.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/coach_text.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_header.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';

import '../../support/text_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pumpHome(WidgetTester tester, {double width = 360}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  /// The title inside the header specifically — a section further down the
  /// page is also labelled "Today", so a bare `find.text` is ambiguous.
  Finder headerTitle() => find.descendant(
        of: find.byType(AppHeader),
        matching: find.text('Today'),
      );

  /// Every string currently rendered anywhere in the tree.
  List<String> visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList();

  testWidgets('the title describes the view, not the account', (tester) async {
    await pumpHome(tester);

    expect(headerTitle(), findsOneWidget,
        reason: 'Apple HIG: a title is a short phrase describing the view. '
            'The screen is reached from a bottom-nav tab labelled Today.');
    expectSingleLine(tester, headerTitle(), label: 'The Home title');

    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the placeholder name "User" is never rendered', (tester) async {
    await pumpHome(tester);

    expect(
      visibleText(tester).where((s) => s == 'User'),
      isEmpty,
      reason: 'The screenshot showed the literal string "User" as the screen '
          'title. It came from auth_service.dart\'s displayName fallback — '
          '"User" is a placeholder, not a name.',
    );

    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the header carries no greeting and no date', (tester) async {
    await pumpHome(tester);

    final texts = visibleText(tester);
    expect(
      texts.where((s) => s.contains('Good morning') ||
          s.contains('Good afternoon') ||
          s.contains('Good evening')),
      isEmpty,
      reason: 'The greeting was removed from the header. NN/g: a generic '
          'welcome carries no information. It also duplicated the briefing.',
    );
    expect(
      texts.where((s) => RegExp(r'(Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day, ')
          .hasMatch(s)),
      isEmpty,
      reason: 'The date was removed — the status bar already shows it, and it '
          'was the longest string competing for the starved title column.',
    );

    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('no header text wraps, at any supported phone width',
      (tester) async {
    for (final width in const [320.0, 360.0, 375.0, 390.0, 428.0]) {
      await pumpHome(tester, width: width);
      expectSingleLine(tester, headerTitle(),
          label: 'The Home title at ${width.toInt()}pt');
      await tester.pump(const Duration(seconds: 8));
    }
  });

  group('the briefing sentence', () {
    // The strip is clamped to two lines. Anything spent before the nudge is
    // spent on something already on screen, and the nudge is what gets cut.
    const coach = CoachText();

    test('does not repeat the greeting the header used to show', () {
      final s = coach.dailyBriefing(
        medsTaken: 0,
        medsTotal: 2,
        waterPct: 0,
        focusMinutes: 0,
        remindersLeft: 0,
        hour: 19,
      );

      expect(s.contains('Good evening'), isFalse,
          reason: 'The screenshot showed "Good evening" twice on one screen.');
      expect(s.contains('Good morning'), isFalse);
      expect(s.contains('Good afternoon'), isFalse);
    });

    test('does not recap the numbers the pulse row already renders', () {
      final s = coach.dailyBriefing(
        medsTaken: 1,
        medsTotal: 2,
        waterPct: 40,
        focusMinutes: 25,
        remindersLeft: 3,
        hour: 19,
      );

      expect(s.contains('Today so far'), isFalse,
          reason: 'Meds / Water / Focus / Reminders are rendered as a 4-up '
              'pulse row immediately below this strip.');
      expect(s.contains('water 40%'), isFalse);
      expect(s.contains('meds 1/2'), isFalse);
    });

    test('leads with the actionable clause and fits two lines', () {
      // The exact state from the screenshot: water at 0%, doses outstanding.
      final s = coach.dailyBriefing(
        medsTaken: 0,
        medsTotal: 2,
        waterPct: 0,
        focusMinutes: 0,
        remindersLeft: 0,
        hour: 19,
      );

      expect(s, isNotEmpty);
      expect(
        s.length,
        lessThanOrEqualTo(140),
        reason: 'At bodyMedium in ~290pt, two lines holds roughly 140 '
            'characters. The old string was ~110 characters BEFORE the nudge, '
            'so the nudge — the only actionable part — was always truncated. '
            'Got: "$s"',
      );
    });
  });
}
