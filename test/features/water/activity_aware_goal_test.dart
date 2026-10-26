import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// On an active day the goal rises and says why ("+350 ml for 420 active kcal").
///
/// The rules that matter: only MEASURED activity counts, it can only raise the
/// goal (never below the profile's own activity level, never lower than an
/// earlier top-up the same day), and a custom goal or a fluid limit is never
/// touched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;
  final now = DateTime(2026, 8, 29, 15, 0);

  HydrationProfile profile({
    ActivityLevel level = ActivityLevel.sedentary,
    bool custom = false,
    int? ceiling,
  }) =>
      HydrationProfile(
        id: 'profile',
        weightKg: 70,
        activityLevel: level,
        customGoalMl: 2000,
        useCustomGoal: custom,
        fluidCeilingMl: ceiling,
        createdAt: now,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
    WaterService.activeKcalReaderForTesting = null;
  });

  tearDown(() async {
    WaterService.activeKcalReaderForTesting = null;
    await database.close();
  });

  group('HydrationProfile.activityDeltaMl', () {
    test('real activity above the usual adds exactly the difference', () {
      final p = profile();
      final delta = p.activityDeltaMl(activeKcal: 700);
      expect(delta, greaterThan(0));
      expect(delta,
          p.goalBreakdown(activeKcal: 700).totalMl - p.goalBreakdown().totalMl);
    });

    test('little activity adds nothing — and is never negative', () {
      expect(profile().activityDeltaMl(activeKcal: 50), 0);
    });

    test('measured activity below what the level assumes cannot lower the goal',
        () {
      // "Very active" assumes a lot; 300 measured kcal is less than that.
      final p = profile(level: ActivityLevel.veryActive);
      expect(p.activityDeltaMl(activeKcal: 300), 0);
      expect(p.goalBreakdown(activeKcal: 300).totalMl,
          lessThan(p.goalBreakdown().totalMl),
          reason: 'premise: plugging the measured figure straight in WOULD '
              'lower the goal, which is what the delta must not pass on');
    });

    test('more activity never adds less', () {
      final p = profile();
      expect(p.activityDeltaMl(activeKcal: 900),
          greaterThanOrEqualTo(p.activityDeltaMl(activeKcal: 500)));
    });
  });

  group('saving the profile keeps what today has already earned', () {
    test('an activity top-up survives a profile edit', () async {
      final p = profile();
      final delta = p.activityDeltaMl(activeKcal: 700);
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(p);
        final base = WaterService.getDataForDate(now)!.dailyGoalMl;
        WaterService.activeKcalReaderForTesting = () async => 700;
        await WaterService.refreshDailyGoal();
        expect(WaterService.getDataForDate(now)!.dailyGoalMl, base + delta);

        // The person fixes a typo in their name or age: the target they are
        // mid-way through must not drop by the top-up.
        await WaterService.saveProfile(p);
        expect(WaterService.getDataForDate(now)!.dailyGoalMl, base + delta,
            reason: 'saving the profile stamped the bare profile goal on today '
                'and dropped the activity top-up until the next app open');
      });
    });

    test('a hot-day adjustment survives a profile edit', () async {
      final p = profile();
      SharedPreferences.setMockInitialValues({
        'hydration_weather_enabled': true,
        'hydration_weather_temp_c': 36.0,
      });
      final hot = p.goalBreakdown(ambientC: 36).totalMl;
      expect(hot, greaterThan(p.goalBreakdown().totalMl),
          reason: 'premise: 36 degrees must raise the goal');
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(p);
        expect(WaterService.getDataForDate(now)!.dailyGoalMl, hot);
      });
    });

    test('a custom goal is still exactly what was typed', () async {
      SharedPreferences.setMockInitialValues({
        'hydration_weather_enabled': true,
        'hydration_weather_temp_c': 36.0,
      });
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(profile(custom: true));
        expect(WaterService.getDataForDate(now)!.dailyGoalMl, 2000);
      });
    });

    test('a prescribed ceiling is still exactly the ceiling', () async {
      SharedPreferences.setMockInitialValues({
        'hydration_weather_enabled': true,
        'hydration_weather_temp_c': 36.0,
      });
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(profile(ceiling: 1500));
        expect(WaterService.getDataForDate(now)!.dailyGoalMl, 1500);
      });
    });

    test('with no weather and no top-up it is the profile goal, as before',
        () async {
      final p = profile();
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(p);
        expect(WaterService.getDataForDate(now)!.dailyGoalMl,
            p.effectiveGoalMl);
      });
    });
  });

  group('WaterService.refreshDailyGoal', () {
    test('measured activity raises today\'s goal and records why', () async {
      final p = profile();
      final delta = p.activityDeltaMl(activeKcal: 700);
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(p);
        final before = WaterService.getDataForDate(now)!.dailyGoalMl;
        WaterService.activeKcalReaderForTesting = () async => 700;

        await WaterService.refreshDailyGoal();

        expect(WaterService.getDataForDate(now)!.dailyGoalMl, before + delta);
        final note = WaterService.todayActivityGoalNote!;
        expect(note.deltaMl, delta);
        expect(note.activeKcal, 700);
      });
    });

    test('a quiet day changes nothing and shows no note', () async {
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(profile());
        final before = WaterService.getDataForDate(now)!.dailyGoalMl;
        WaterService.activeKcalReaderForTesting = () async => 80;

        await WaterService.refreshDailyGoal();

        expect(WaterService.getDataForDate(now)!.dailyGoalMl, before);
        expect(WaterService.todayActivityGoalNote, isNull);
      });
    });

    test('no health data at all changes nothing', () async {
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(profile());
        final before = WaterService.getDataForDate(now)!.dailyGoalMl;
        WaterService.activeKcalReaderForTesting = () async => null;

        await WaterService.refreshDailyGoal();

        expect(WaterService.getDataForDate(now)!.dailyGoalMl, before);
        expect(WaterService.todayActivityGoalNote, isNull);
      });
    });

    test('the goal only ever rises: a later, lower reading keeps the top-up',
        () async {
      final p = profile();
      final high = p.activityDeltaMl(activeKcal: 900);
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(p);
        final before = WaterService.getDataForDate(now)!.dailyGoalMl;

        WaterService.activeKcalReaderForTesting = () async => 900;
        await WaterService.refreshDailyGoal();
        expect(WaterService.getDataForDate(now)!.dailyGoalMl, before + high);

        // A glitchy or source-switched read that says less activity.
        WaterService.activeKcalReaderForTesting = () async => 400;
        await WaterService.refreshDailyGoal();

        expect(WaterService.getDataForDate(now)!.dailyGoalMl, before + high,
            reason: 'a target that shrinks mid-day reads as being told to '
                'drink less');
        expect(WaterService.todayActivityGoalNote!.activeKcal, 900,
            reason: 'and the explanation still matches the number shown');
      });
    });

    test('a custom goal is never raised by activity', () async {
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(profile(custom: true));
        WaterService.activeKcalReaderForTesting = () async => 900;

        await WaterService.refreshDailyGoal();

        expect(WaterService.getDataForDate(now)!.dailyGoalMl, 2000);
        expect(WaterService.todayActivityGoalNote, isNull);
      });
    });

    test('a prescribed fluid ceiling is never raised by activity', () async {
      await withClock(Clock.fixed(now), () async {
        await WaterService.saveProfile(profile(ceiling: 1500));
        WaterService.activeKcalReaderForTesting = () async => 900;

        await WaterService.refreshDailyGoal();

        expect(WaterService.getDataForDate(now)!.dailyGoalMl, 1500);
        expect(WaterService.todayActivityGoalNote, isNull);
      });
    });

    test('yesterday\'s note never explains today\'s goal', () async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.setAppPreference(
            'water_activity_goal_note', '2026-08-28|350|420');
        expect(WaterService.todayActivityGoalNote, isNull);

        await CleanStorageService.setAppPreference(
            'water_activity_goal_note', '2026-08-29|350|420');
        expect(WaterService.todayActivityGoalNote,
            (deltaMl: 350, activeKcal: 420));
      });
    });

    test('a note that is garbled reads as no note', () async {
      await withClock(Clock.fixed(now), () async {
        for (final bad in ['', 'x', '2026-08-29|abc|420', '2026-08-29|0|420']) {
          await CleanStorageService.setAppPreference(
              'water_activity_goal_note', bad);
          expect(WaterService.todayActivityGoalNote, isNull, reason: bad);
        }
      });
    });
  });

  group('the dashboard line', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1600);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // layout is the responsive suite's job
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const AquaWaterDashboard()));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 400));
      } finally {
        FlutterError.onError = prev;
      }
    }

    String todayKey() {
      final n = DateTime.now();
      return '${n.year.toString().padLeft(4, '0')}-'
          '${n.month.toString().padLeft(2, '0')}-'
          '${n.day.toString().padLeft(2, '0')}';
    }

    testWidgets('says why the goal is higher today', (tester) async {
      await CleanStorageService.setAppPreference(
          'water_activity_goal_note', '${todayKey()}|350|420');
      await pump(tester);
      expect(find.text('Goal +350 ml today for 420 active kcal'),
          findsOneWidget);
    });

    testWidgets('shows nothing when the goal was not raised', (tester) async {
      await pump(tester);
      expect(find.textContaining('active kcal'), findsNothing);
    });
  });
}
