/// The breathing exercises that were finished can be looked back on.
///
/// The only trace was a counter behind an achievement, so what had been practised,
/// when, and how often could not be seen.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/breathing_exercise.dart';
import 'package:tablet_remainder/features/focus/models/breathing_record.dart';
import 'package:tablet_remainder/features/focus/screens/breathing_history_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/breathing_history.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  final focus = FocusService();
  // A Wednesday, so "this week" has Monday and Tuesday behind it.
  final now = DateTime(2026, 9, 30, 11, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
  });

  tearDown(() async {
    focus.resetForTesting();
    await db.close();
  });

  BreathingRecord rec(BreathingPattern p, int cycles, DateTime at) =>
      BreathingRecord(pattern: p, cycles: cycles, completedAt: at);

  group('a record', () {
    test('knows how long it took from the pattern\'s own timing', () {
      // 4-7-8 is 19 seconds a cycle.
      expect(rec(BreathingPattern.relaxing, 4, now).seconds, 76);
      // Box breathing is 16.
      expect(rec(BreathingPattern.balancing, 5, now).seconds, 80);
    });

    test('round-trips through JSON', () {
      final r = rec(BreathingPattern.calming, 6, DateTime(2026, 9, 29, 7, 30));
      final back = BreathingRecord.fromJson(r.toJson())!;
      expect(back.pattern, BreathingPattern.calming);
      expect(back.cycles, 6);
      expect(back.completedAt, DateTime(2026, 9, 29, 7, 30));
    });

    test('an entry that cannot be read is null, not an exception', () {
      for (final bad in <Object?>[
        null,
        'x',
        {'pattern': 99, 'cycles': 4, 'at': '2026-09-29T07:30:00'},
        {'pattern': 0, 'cycles': 0, 'at': '2026-09-29T07:30:00'},
        {'pattern': 0, 'cycles': 'four', 'at': '2026-09-29T07:30:00'},
        {'pattern': 0, 'cycles': 4, 'at': 'yesterday'},
        {'pattern': 0, 'cycles': 4},
      ]) {
        expect(BreathingRecord.fromJson(bad), isNull, reason: '$bad');
      }
    });
  });

  group('the saved history', () {
    test('starts empty', () {
      expect(BreathingHistory.all(), isEmpty);
    });

    test('is newest first, whatever order it was written in', () async {
      await BreathingHistory.record(BreathingPattern.relaxing, 4, at: DateTime(2026, 9, 20, 8));
      await BreathingHistory.record(BreathingPattern.calming, 6, at: DateTime(2026, 9, 29, 8));
      await BreathingHistory.record(BreathingPattern.balancing, 4, at: DateTime(2026, 9, 25, 8));

      expect(BreathingHistory.all().map((r) => r.pattern), [
        BreathingPattern.calming,
        BreathingPattern.balancing,
        BreathingPattern.relaxing,
      ]);
    });

    test('stamps the moment it is recorded when none is given', () async {
      await withClock(Clock.fixed(now), () async {
        await BreathingHistory.record(BreathingPattern.relaxing, 4);
      });
      expect(BreathingHistory.all().single.completedAt, now);
    });

    test('keeps the newest three hundred', () async {
      for (var i = 0; i < BreathingHistory.cap + 25; i++) {
        await BreathingHistory.record(BreathingPattern.relaxing, 4,
            at: DateTime(2026, 1, 1).add(Duration(hours: i)));
      }
      final all = BreathingHistory.all();
      expect(all, hasLength(BreathingHistory.cap));
      expect(all.first.completedAt,
          DateTime(2026, 1, 1).add(Duration(hours: BreathingHistory.cap + 24)));
      expect(all.last.completedAt, DateTime(2026, 1, 1).add(const Duration(hours: 25)),
          reason: 'the oldest twenty-five went');
    });

    test('a record with no cycles is not recorded', () async {
      await BreathingHistory.record(BreathingPattern.relaxing, 0);
      expect(BreathingHistory.all(), isEmpty);
      expect(CleanStorageService.getAppPreferences()['focusBreathingLog'], isNull,
          reason: 'not even stored: an unreadable entry would still take a slot of '
              'the three hundred');
    });

    test('survives a bad entry beside good ones', () async {
      await CleanStorageService.setAppPreference('focusBreathingLog', [
        rec(BreathingPattern.relaxing, 4, now).toJson(),
        {'pattern': 99, 'cycles': 4, 'at': now.toIso8601String()},
        'not a record',
      ]);
      expect(BreathingHistory.all(), hasLength(1));
    });
  });

  group('the totals', () {
    test('nothing recorded is empty, not a division by zero', () {
      final s = BreathingHistory.summarize(const [], now: now);
      expect((s.sessions, s.minutes, s.thisWeek, s.mostUsed), (0, 0, 0, null));
    });

    test('count sessions and minutes breathed', () {
      final s = BreathingHistory.summarize([
        rec(BreathingPattern.relaxing, 4, now), // 76 s
        rec(BreathingPattern.balancing, 5, now), // 80 s
        rec(BreathingPattern.energizing, 8, now), // 64 s
      ], now: now);
      expect(s.sessions, 3);
      expect(s.minutes, 4, reason: '220 seconds is three and two-thirds minutes');
    });

    test('this week starts on Monday', () {
      final s = BreathingHistory.summarize([
        rec(BreathingPattern.relaxing, 4, DateTime(2026, 9, 30, 8)), // Wed
        rec(BreathingPattern.relaxing, 4, DateTime(2026, 9, 28)), // Mon, to the second
        rec(BreathingPattern.relaxing, 4, DateTime(2026, 9, 28, 0, 5)), // Mon, just in
        rec(BreathingPattern.relaxing, 4, DateTime(2026, 9, 27, 23, 55)), // Sun: last week
        rec(BreathingPattern.relaxing, 4, DateTime(2026, 9, 1, 8)),
      ], now: now);
      expect(s.thisWeek, 3);
      expect(s.sessions, 5);
    });

    test('the most-used pattern wins, and a tie goes to the more recent', () {
      final plain = BreathingHistory.summarize([
        rec(BreathingPattern.calming, 6, DateTime(2026, 9, 1)),
        rec(BreathingPattern.calming, 6, DateTime(2026, 9, 2)),
        rec(BreathingPattern.relaxing, 4, DateTime(2026, 9, 29)),
      ], now: now);
      expect(plain.mostUsed, BreathingPattern.calming);

      final tie = BreathingHistory.summarize([
        rec(BreathingPattern.calming, 6, DateTime(2026, 9, 1)),
        rec(BreathingPattern.relaxing, 4, DateTime(2026, 9, 29)),
      ], now: now);
      expect(tie.mostUsed, BreathingPattern.relaxing);
    });
  });

  group('finishing an exercise', () {
    test('writes the pattern and its cycles, and still counts it', () async {
      await withClock(Clock.fixed(now), () async {
        focus.incrementBreathingCount(
            pattern: BreathingPattern.sleepBreathing, cycles: 3);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      final r = BreathingHistory.all().single;
      expect(r.pattern, BreathingPattern.sleepBreathing);
      expect(r.cycles, 3);
      expect(r.completedAt, now);
      expect(CleanStorageService.getAppPreferences()['focusBreathingCount'], 1,
          reason: 'the achievement\'s counter still moves');
    });

    test('with no pattern given, only the counter moves (an older caller)', () async {
      focus.incrementBreathingCount();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(BreathingHistory.all(), isEmpty);
      expect(CleanStorageService.getAppPreferences()['focusBreathingCount'], 1);
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester, List<BreathingRecord>? records,
        {double width = 411, double scale = 1}) async {
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 3000);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: BreathingHistoryScreen(records: records)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    final sample = [
      rec(BreathingPattern.relaxing, 4, DateTime(2026, 9, 30, 9, 15)),
      rec(BreathingPattern.calming, 6, DateTime(2026, 9, 30, 7, 40)),
      rec(BreathingPattern.relaxing, 4, DateTime(2026, 9, 29, 21, 5)),
      rec(BreathingPattern.balancing, 5, DateTime(2026, 9, 26, 12)),
    ];

    testWidgets('shows the totals, the favourite and each day', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await open(tester, sample);

        expect(find.text('4'), findsWidgets, reason: 'four sessions');
        expect(find.text('Sessions'), findsOneWidget);
        expect(find.text('Minutes'), findsOneWidget);
        expect(find.text('This week'), findsOneWidget);
        expect(find.text('Most often: Relaxing (4-7-8)'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Yesterday'), findsOneWidget);
        expect(find.text('Sep 26'), findsOneWidget);
      });
    });

    testWidgets('each row says what, how long and when', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await open(tester, sample);

        expect(find.text('Calming (4-8)'), findsOneWidget);
        expect(find.text('6 cycles · 1 min'), findsOneWidget);
        expect(find.text('9:15 AM'), findsOneWidget);
        expect(find.text('7:40 AM'), findsOneWidget);
      });
    });

    testWidgets('a day groups its sessions under one heading, newest first', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await open(tester, sample);
        expect(find.text('Today'), findsOneWidget);
        expect(tester.getTopLeft(find.text('9:15 AM')).dy,
            lessThan(tester.getTopLeft(find.text('7:40 AM')).dy));
      });
    });

    testWidgets('nothing yet is said, with a way back', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await open(tester, const []);
        expect(find.text('No breathing yet'), findsOneWidget);
        expect(find.text('Back to Focus'), findsOneWidget);
        expect(find.text('Sessions'), findsNothing);
      });
    });

    testWidgets('reads the saved history when given none', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await BreathingHistory.record(BreathingPattern.deepBreathing, 5,
            at: DateTime(2026, 9, 30, 6, 30));
        await open(tester, null);
        expect(find.text('Deep Breathing (5-5)'), findsOneWidget);
      });
    });

    test('the headings and detail are plain words', () {
      expect(BreathingHistoryScreen.dayHeading(DateTime(2026, 9, 30), now), 'Today');
      expect(BreathingHistoryScreen.dayHeading(DateTime(2026, 9, 29), now), 'Yesterday');
      expect(BreathingHistoryScreen.dayHeading(DateTime(2026, 9, 20), now), 'Sep 20');
      expect(BreathingHistoryScreen.detail(rec(BreathingPattern.sleepBreathing, 1, now)),
          '1 cycle');
      expect(BreathingHistoryScreen.detail(rec(BreathingPattern.energizing, 8, now)),
          '8 cycles · 1 min');
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('fits $width wide at ${scale}x text', (tester) async {
        await withClock(Clock.fixed(now), () async {
          final errors = <FlutterErrorDetails>[];
          final prev = FlutterError.onError;
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = Size(width, 4000);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.reset);
          FlutterError.onError = errors.add;
          try {
            await tester.pumpWidget(MaterialApp(home: BreathingHistoryScreen(records: sample)));
            await tester.pump(const Duration(milliseconds: 100));
          } finally {
            FlutterError.onError = prev;
          }
          expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);
        });
      });
    }
  });

  group('from the Focus screen', () {
    testWidgets('a finished exercise is in the history, and the sheet leads to it',
        (tester) async {
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(411, 6000);
      addTearDown(tester.view.reset);

      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        // Breathing card -> sheet -> a pattern.
        await tester.ensureVisible(find.text('Breathing').first);
        await tester.pump();
        await tester.tap(find.text('Breathing').first);
        // The sheet slides up from the bottom of a tall view: give it time.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Relaxing (4-7-8)'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Start'), findsOneWidget, reason: 'the exercise is on screen');
        await tester.tap(find.text('Start'));

        // The exercise runs its own cycles, one second at a time.
        for (var i = 0; i < 140 && BreathingHistory.all().isEmpty; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        final all = BreathingHistory.all();
        expect(all, hasLength(1), reason: 'the exercise ran to its end');
        expect(all.single.pattern, BreathingPattern.relaxing);
        expect(all.single.cycles, BreathingPattern.relaxing.recommendedCycles);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('the breathing sheet has a way into the history', (tester) async {
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(411, 6000);
      addTearDown(tester.view.reset);

      await withClock(Clock.fixed(now), () async {
        await BreathingHistory.record(BreathingPattern.calming, 6,
            at: DateTime(2026, 9, 30, 8));
        await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.ensureVisible(find.text('Breathing').first);
        await tester.pump();
        await tester.tap(find.text('Breathing').first);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text('Your breathing history'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(BreathingHistoryScreen), findsOneWidget);
        expect(find.text('Calming (4-8)'), findsOneWidget,
            reason: 'and it shows what was recorded');
        await tester.pump(const Duration(seconds: 8));
      });
    });
  });
}
