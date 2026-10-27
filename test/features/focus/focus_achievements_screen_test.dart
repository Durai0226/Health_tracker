/// Every focus achievement has somewhere to be seen.
///
/// They were reachable only inside Statistics, and there only as the six most
/// recent and the three nearest — so most of the twenty-four were never shown, and
/// "what is there to earn?" had no answer.
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
import 'package:tablet_remainder/features/focus/models/focus_achievement.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_achievements_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
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
  final now = DateTime(2026, 9, 30, 11, 0);
  final total = AchievementType.values.length;

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

  FocusAchievement earnedOn(AchievementType t, DateTime on) => FocusAchievement(
      type: t,
      unlockedAt: on,
      isUnlocked: true,
      currentProgress: t.requiredValue);

  Future<void> seed(List<FocusAchievement> given) async {
    await CleanStorageService.setAppPreference('focusAchievements', {
      for (final a in given) a.type.index.toString(): a.toJson(),
    });
    await focus.init();
  }

  void quietOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  Future<void> open(WidgetTester tester, {double width = 411, double scale = 1}) async {
    quietOverflow();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 6000);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: FocusAchievementsScreen()));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('the order', () {
    test('earned ones come newest first', () {
      final list = FocusAchievementsScreen.earned([
        earnedOn(AchievementType.firstSession, DateTime(2026, 9, 1)),
        earnedOn(AchievementType.tenMinutes, DateTime(2026, 9, 20)),
        earnedOn(AchievementType.thirtyMinutes, DateTime(2026, 9, 10)),
        const FocusAchievement(type: AchievementType.oneHour),
      ]);
      expect(list.map((a) => a.type), [
        AchievementType.tenMinutes,
        AchievementType.thirtyMinutes,
        AchievementType.firstSession,
      ]);
    });

    test('the rest are nearest first, and a tie keeps the order they are declared in',
        () {
      final list = FocusAchievementsScreen.inProgress([
        const FocusAchievement(type: AchievementType.oneHour, currentProgress: 15),
        const FocusAchievement(type: AchievementType.threeHours, currentProgress: 90),
        const FocusAchievement(type: AchievementType.fiveHours),
        const FocusAchievement(type: AchievementType.tenHours),
        earnedOn(AchievementType.firstSession, DateTime(2026, 9, 1)),
      ]);
      // oneHour 15/60 = 25%, threeHours 90/180 = 50%, the rest 0%.
      expect(list.map((a) => a.type), [
        AchievementType.threeHours,
        AchievementType.oneHour,
        AchievementType.fiveHours,
        AchievementType.tenHours,
      ]);
    });
  });

  group('the screen', () {
    testWidgets('says how many are earned and lists every one, not nine', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed([
          earnedOn(AchievementType.firstSession, DateTime(2026, 9, 29, 10)),
          earnedOn(AchievementType.tenMinutes, DateTime(2026, 9, 20)),
          earnedOn(AchievementType.firstPlant, DateTime(2026, 9, 25)),
          const FocusAchievement(type: AchievementType.thirtyMinutes, currentProgress: 15),
        ]);
        await open(tester);

        expect(find.text('3 of $total earned'), findsOneWidget);
        expect(find.text('Earned'), findsOneWidget);
        expect(find.text('Still to earn'), findsOneWidget);
        // All of them, which Statistics never showed: three earned, the other
        // twenty-one still to earn.
        for (final t in AchievementType.values) {
          expect(find.text(t.name), findsOneWidget, reason: t.name);
        }
      });
    });

    testWidgets('earned ones carry the day they were earned and their reward',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed([earnedOn(AchievementType.oneHour, DateTime(2026, 9, 29, 10))]);
        await open(tester);

        expect(find.text('Earned Sep 29 · Silver · 25 coins'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsNothing,
            reason: 'a Material Symbol, not the framework icon');
      });
    });

    testWidgets('and the rest show how far along they are', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed([
          const FocusAchievement(type: AchievementType.oneHour, currentProgress: 30),
        ]);
        await open(tester);

        expect(find.text('50%'), findsOneWidget);
        expect(find.text('Silver · 25 coins'), findsWidgets);
      });
    });

    testWidgets('nothing earned yet: no Earned section, and the count says so',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed(const []);
        await open(tester);

        expect(find.text('0 of $total earned'), findsOneWidget);
        expect(find.text('Earned'), findsNothing);
        expect(find.text('Still to earn'), findsOneWidget);
      });
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('fits $width wide at ${scale}x text', (tester) async {
        await withClock(Clock.fixed(now), () async {
          await seed([earnedOn(AchievementType.hundredHours, DateTime(2026, 9, 1))]);
          final errors = <FlutterErrorDetails>[];
          final prev = FlutterError.onError;
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = Size(width, 8000);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.reset);
          FlutterError.onError = errors.add;
          try {
            await tester.pumpWidget(const MaterialApp(home: FocusAchievementsScreen()));
            await tester.pump(const Duration(milliseconds: 100));
          } finally {
            FlutterError.onError = prev;
          }
          expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);
        });
      });
    }
  });

  group('the way in', () {
    testWidgets('Statistics offers "See all" beside its short list', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed([earnedOn(AchievementType.firstSession, DateTime(2026, 9, 29))]);
        quietOverflow();
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(411, 6000);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MaterialApp(home: DetailedStatsScreen()));
        await tester.pump(const Duration(milliseconds: 400));

        final seeAll = find.text('See all');
        expect(seeAll, findsWidgets);
        await tester.ensureVisible(seeAll.first);
        await tester.pump();
        // The header the link belongs to is the Achievements one.
        final header = find.ancestor(
            of: find.text('Achievements'), matching: find.byType(Row)).first;
        await tester.tap(find.descendant(of: header, matching: find.text('See all')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(FocusAchievementsScreen), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('the Focus screen has a row of its own for it', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed([
          earnedOn(AchievementType.firstSession, DateTime(2026, 9, 29)),
          earnedOn(AchievementType.tenMinutes, DateTime(2026, 9, 29)),
        ]);
        quietOverflow();
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(411, 6000);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 400));

        final row = find.text('2 of $total earned');
        expect(row, findsOneWidget);
        await tester.ensureVisible(row);
        await tester.pump();
        await tester.tap(row);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(FocusAchievementsScreen), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });
  });
}
