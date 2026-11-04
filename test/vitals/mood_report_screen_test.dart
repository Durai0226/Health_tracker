/// The Mood report screen: a window of days, what they add up to, and a PDF.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  final now = DateTime(2026, 9, 30, 21, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  var n = 0;
  Future<void> mood(int day, int index, {int month = 9, String? note}) =>
      VitalsStorageService.saveMood(MoodEntry(
          id: 'm${n++}',
          moodIndex: index,
          takenAt: DateTime(2026, month, day, 12),
          note: note,
          createdAt: DateTime(2026, month, day, 12)));

  Future<void> open(WidgetTester tester,
      {Future<void> Function(Uint8List, String)? onShare,
      double width = 390,
      double scale = 1.0}) async {
    tester.view.physicalSize = Size(width, 3000);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: MoodReportScreen(onShare: onShare)));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = prev;
    }
  }

  void pinned(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) => withClock(Clock.fixed(now), () => body(tester)));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  pinned('nothing logged: says so, and has nothing to share', (tester) async {
    var shared = 0;
    await open(tester, onShare: (_, _) async => shared++);

    expect(find.text('Nothing logged in this period'), findsOneWidget);
    expect(find.text('Average'), findsNothing);

    await tester.tap(find.byTooltip('Share report as PDF'));
    await settle(tester);
    expect(find.text('Nothing logged in this period to share.'), findsOneWidget);
    expect(shared, 0);
    await tester.pump(const Duration(seconds: 8));
  });

  pinned('shows the average, the days logged and the entries', (tester) async {
    await mood(28, 0); // Great
    await mood(29, 1); // Good
    await mood(30, 3); // Bad
    await open(tester);

    expect(find.text('Average'), findsOneWidget);
    expect(find.text('Good'), findsWidgets); // (4 + 3 + 1) / 3 = 2.67 -> Good
    expect(find.text('3/30'), findsOneWidget);
    expect(find.text('Days logged'), findsOneWidget);
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('How the entries felt'), findsOneWidget);
    expect(find.textContaining('each day counts once'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  pinned('the window follows the toggle', (tester) async {
    await mood(30, 1);
    await mood(15, 1); // 15 days ago: in 30d, out of 7d
    await open(tester);
    expect(find.text('2/30'), findsOneWidget);

    await tester.tap(find.text('7d'));
    await settle(tester);
    expect(find.text('1/7'), findsOneWidget);
    expect(find.text('Week by week'), findsNothing,
        reason: 'a week is just the average');

    await tester.tap(find.text('90d'));
    await settle(tester);
    expect(find.text('2/90'), findsOneWidget);
    expect(find.text('Week by week'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  pinned('harder days are counted, and only shown when there are some',
      (tester) async {
    await mood(28, 4);
    await mood(29, 0);
    await mood(30, 1);
    await open(tester);
    expect(find.text('Harder days'), findsOneWidget);
    expect(find.text('1 of 3 days logged were rated Bad or Terrible.'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  pinned('the harder days are out of the days logged, not the entries', (tester) async {
    await mood(28, 4);
    await mood(28, 4); // the same day, logged twice
    await mood(29, 0);
    await open(tester);
    expect(find.text('1 of 2 days logged were rated Bad or Terrible.'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  pinned('no harder days: no card', (tester) async {
    await mood(28, 0);
    await mood(29, 1);
    await open(tester);
    expect(find.text('Harder days'), findsNothing);
    await tester.pump(const Duration(seconds: 8));
  });

  group('sharing', () {
    pinned('hands a PDF to the share sheet, named for what it is', (tester) async {
      await mood(28, 1);
      await mood(29, 3, note: 'a private note');
      Uint8List? bytes;
      String? name;
      await open(tester, onShare: (b, f) async {
        bytes = b;
        name = f;
      });

      await tester.ensureVisible(find.text('Share as PDF'));
      await tester.pump();
      await tester.tap(find.text('Share as PDF'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(tester);

      expect(name, 'mood-report.pdf');
      expect(String.fromCharCodes(bytes!.take(5)), '%PDF-');
      await tester.pump(const Duration(seconds: 8));
    });

    pinned('the header\'s share does the same', (tester) async {
      await mood(28, 1);
      var shared = 0;
      await open(tester, onShare: (_, _) async => shared++);

      await tester.tap(find.byTooltip('Share report as PDF'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(tester);

      expect(shared, 1);
      await tester.pump(const Duration(seconds: 8));
    });

    pinned('two taps in the same frame share once', (tester) async {
      await mood(28, 1);
      final gate = Completer<void>();
      var shared = 0;
      await open(tester, onShare: (_, _) async {
        shared++;
        await gate.future;
      });

      await tester.ensureVisible(find.text('Share as PDF'));
      await tester.pump();
      await tester.tap(find.text('Share as PDF'));
      await tester.tap(find.text('Share as PDF'), warnIfMissed: false);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump();

      expect(shared, 1, reason: 'the second tap lands before the first has finished');
      gate.complete();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await settle(tester);
      await tester.pump(const Duration(seconds: 8));
    });

    pinned('a failure says so and nothing is shared', (tester) async {
      await mood(28, 1);
      await open(tester, onShare: (_, _) async => throw StateError('no share sheet'));

      await tester.ensureVisible(find.text('Share as PDF'));
      await tester.pump();
      await tester.tap(find.text('Share as PDF'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(tester);

      expect(find.text('Could not create the report. Try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    pinned('says what the PDF leaves out', (tester) async {
      await mood(28, 1);
      await open(tester);
      expect(find.text('The PDF has the levels, dates and tags, and leaves your '
          'notes out.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('fits', () {
    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      pinned('$width wide at ${scale}x text', (tester) async {
        for (var d = 1; d <= 20; d++) {
          await mood(d, d % 5, month: 9);
        }
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        tester.view.physicalSize = Size(width, 4000);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.reset);
        FlutterError.onError = errors.add;
        try {
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.lightTheme, home: const MoodReportScreen()));
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        } finally {
          FlutterError.onError = prev;
        }
        expect(
            errors.where((e) =>
                '${e.exception}'.contains('overflowed') &&
                // The test font is wider than the real one; only a genuine
                // layout overflow counts, not Ahem's glyph widths.
                !'${e.exception}'.contains('Ahem')),
            isEmpty);
        await tester.pump(const Duration(seconds: 8));
      });
    }
  });

  group('the way in', () {
    pinned('the Mood screen has a Mood report button', (tester) async {
      await mood(28, 1);
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const MoodScreen()));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.byTooltip('Mood report'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.byType(MoodReportScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
