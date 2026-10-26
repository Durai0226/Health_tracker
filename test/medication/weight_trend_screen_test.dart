import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/weight_trend.dart';
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_goal_sheet.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_screen.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/weight_goal.dart';
import 'package:tablet_remainder/features/medication/services/weight_trend_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  group('weightRateLabel', () {
    test('no rate yet is nothing to say', () {
      expect(weightRateLabel(null, lb: false), isNull);
    });
    test('uses a real minus and the shown precision', () {
      expect(weightRateLabel(-0.42, lb: false), '−0.4 kg a week');
      expect(weightRateLabel(0.31, lb: false), '+0.3 kg a week');
    });
    test('converts to pounds', () {
      expect(weightRateLabel(-0.5, lb: true), '−1.1 lb a week');
    });
    test('anything that rounds to nothing is steady, never "−0.0"', () {
      expect(weightRateLabel(-0.04, lb: false), 'steady');
      expect(weightRateLabel(0.0, lb: false), 'steady');
    });
  });

  group('weightGoalLine', () {
    test('each status reads as a plain sentence', () {
      String line(GoalStatus s, {DateTime? date}) =>
          weightGoalLine(GoalForecast(s, date: date), 72, lb: false);
      expect(line(GoalStatus.reached), "You're at your goal of 72.0 kg.");
      expect(line(GoalStatus.onTrack, date: DateTime(2026, 12, 14)),
          contains('72.0 kg around '));
      expect(line(GoalStatus.flat), contains('flat'));
      expect(line(GoalStatus.wrongWay), contains('moving away'));
      expect(line(GoalStatus.tooFar), contains('two years'));
      expect(line(GoalStatus.notEnoughData), contains('two weeks'));
    });
    test('shows the goal in pounds when asked', () {
      expect(weightGoalLine(const GoalForecast(GoalStatus.reached), 72, lb: true),
          "You're at your goal of 158.7 lb.");
    });
  });

  group('WeightGoal', () {
    test('parse accepts kg, lb and a decimal comma', () {
      expect(WeightGoal.parse('72', lb: false), 72);
      expect(WeightGoal.parse('72,5', lb: false), 72.5);
      expect(WeightGoal.parse('158.7', lb: true)!, closeTo(71.98, 0.01));
    });
    test('parse refuses junk and out-of-range values', () {
      for (final bad in ['', 'abc', '7', '700', '-70']) {
        expect(WeightGoal.parse(bad, lb: false), isNull, reason: bad);
      }
    });
    test('a saved goal survives a restart', () async {
      await WeightGoal.set(72.5);
      // A restart: a fresh cache read from the same stored preferences.
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      expect(WeightGoal.get(), 72.5,
          reason: 'prefs have no double path; the goal is stored as a string');
    });
    test('clear removes it', () async {
      await WeightGoal.set(72);
      await WeightGoal.clear();
      expect(WeightGoal.get(), isNull);
    });
  });

  group('WeightGoalForm', () {
    Future<List<bool>> pump(WidgetTester tester, {bool lb = false}) async {
      final done = <bool>[];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (c) => WeightGoalForm(
                  accent: AppColorsExt.of(c).brand, lb: lb, onDone: done.add),
            ),
          ),
        ),
      ));
      return done;
    }

    testWidgets('saving stores the goal in kilograms, from pounds',
        (tester) async {
      final done = await pump(tester, lb: true);
      await tester.enterText(find.byType(TextField), '158.7');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      expect(done, [true]);
      expect(WeightGoal.get()!, closeTo(71.98, 0.01));
    });

    testWidgets('an implausible number explains itself and does not save',
        (tester) async {
      final done = await pump(tester);
      await tester.enterText(find.byType(TextField), '7');
      await tester.pump();
      expect(find.text('Enter a weight between 20 and 400 kg.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(done, isEmpty);
      expect(WeightGoal.get(), isNull);
    });
  });

  group('on the Weight screen', () {
    final now = DateTime(2026, 3, 1, 9);

    Future<void> seedFalling(int days) async {
      for (var i = 0; i < days; i++) {
        final at = DateTime(2026, 3, 1 - (days - 1 - i), 7);
        await VitalsStorageService.saveWeight(
          WeightReading(
            id: 'w$i',
            valueKg: 80 - 0.1 * i,
            takenAt: at,
            createdAt: at,
          ),
          syncToHealthConnect: false,
        );
      }
    }

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WeightScreen(),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> two(double latestKg, double prevKg) async {
      for (final (i, kg) in [(0, prevKg), (1, latestKg)]) {
        final at = DateTime(2026, 2, 27 + i, 7);
        await VitalsStorageService.saveWeight(
          WeightReading(id: 'd$i', valueKg: kg, takenAt: at, createdAt: at),
          syncToHealthConnect: false,
        );
      }
    }

    testWidgets('"vs last" in kilograms is the plain difference', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await two(69.0, 70.0);
        await open(tester);
        expect(find.text('-1.0 kg vs last'), findsOneWidget);
      });
    });

    testWidgets('"vs last" in pounds is converted once, not twice',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.setAppPreference('weight_unit', 'lb');
        // 70.0 kg = 154.3 lb, 69.0 kg = 152.1 lb: a 2.2 lb change. Converting
        // the already-converted difference again gave 4.9.
        await two(69.0, 70.0);
        await open(tester);
        expect(find.text('-2.2 lb vs last'), findsOneWidget);
        expect(find.textContaining('4.9'), findsNothing);
      });
    });

    testWidgets('an unchanged weight shows no "vs last"', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await two(70.0, 70.0);
        await open(tester);
        expect(find.textContaining('vs last'), findsNothing);
      });
    });

    testWidgets('no trend card before there is anything to smooth',
        (tester) async {
      await open(tester);
      expect(find.textContaining('Trend '), findsNothing);
    });

    testWidgets('a trend with a rate, and the prompt to set a goal',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seedFalling(28);
        await open(tester);
        expect(find.textContaining('Trend 7'), findsOneWidget);
        expect(find.textContaining('kg a week'), findsOneWidget);
        expect(find.text('Set a goal weight'), findsOneWidget);
      });
    });

    testWidgets('a short history gets a trend but no rate', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seedFalling(3);
        await open(tester);
        expect(find.textContaining('Trend '), findsOneWidget);
        expect(find.textContaining('a week'), findsNothing);
      });
    });

    testWidgets('setting a goal puts a date on the card', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seedFalling(28);
        await open(tester);
        await tester.tap(find.text('Set a goal weight'));
        await tester.pumpAndSettle();
        expect(find.text('Goal weight'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '70');
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.textContaining('70.0 kg around '), findsOneWidget);
        expect(find.text('Set a goal weight'), findsNothing);
      });
    });
  });
}
