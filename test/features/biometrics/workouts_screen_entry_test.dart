/// The Workouts screen with the way to add one: a run without the watch, a swim,
/// a class. Log it, open it, change it, delete it — and take any of that back.
///
/// The list used to be read-only, so a day with a workout the watch never saw
/// looked like a rest day, and a session you could see had nowhere to open.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/biometrics/screens/workouts_screen.dart';
import 'package:tablet_remainder/features/biometrics/services/biometrics_service.dart';

import '../../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;

  /// Noon on the 20th: "an hour ago" is still the 20th, so a workout logged
  /// from the form lands under "Today".
  final now = DateTime(2026, 6, 20, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    BiometricsService.clearInMemory();
    await BiometricsService.resetForTesting();
  });

  tearDown(() async => database.close());

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
    await tester.pumpWidget(
        MaterialApp(theme: fontFreeTheme(), home: const WorkoutsScreen()));
    await settle(tester);
    // The screen asks the health plugin what it can do and gives up after six
    // seconds; there is no plugin here, so let that run out on the fake clock.
    await tester.pump(const Duration(seconds: 7));
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
  }

  /// What the list shows for a workout: its row, found by title.
  Finder row(String title) => find.widgetWithText(AppListTile, title);
  Finder inRow(String title, String text) =>
      find.descendant(of: row(title), matching: find.text(text));

  Finder field(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
      matching: find.byType(TextField));

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(field(label), text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester, String label) async {
    await tapVisible(tester, find.text(label));
    await settle(tester);
  }

  /// A workout of yours already on the list, put there before the screen opens.
  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() => BiometricsService.saveEnteredWorkout(
        activityType: 'RUNNING',
        startedAt: DateTime(2026, 6, 19, 7, 30),
        durationMinutes: 40,
        kcal: 380,
        distanceKm: 5.5,
        note: 'park loop'));
  }

  Future<int> storedOn(WidgetTester tester, DateTime day) async =>
      (await tester.runAsync(() => database.biometricsDao.getWorkoutsForDateKey(key(day))))!
          .length;

  group('logging one', () {
    testWidgets('the button opens the form; a saved workout is on the list, with Undo',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await open(tester);
        expect(find.text('Log a workout'), findsNothing);

        await tester.tap(find.byType(AppFab));
        await settle(tester);
        expect(find.text('Log a workout'), findsOneWidget);

        await tester.tap(find.widgetWithText(AppChip, 'Running'));
        await tester.pump();
        await type(tester, 'Minutes', '40');
        await type(tester, 'Distance (optional)', '5.5');
        await save(tester, 'Save workout');

        expect(find.text('Log a workout'), findsNothing, reason: 'the sheet closed');
        expect(find.text('Workout logged'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(row('Running'), findsOneWidget);
        expect(inRow('Running', '40 min · 5.50 km'), findsOneWidget);
        expect(await storedOn(tester, now), 1);

        await tester.tap(find.text('Undo'));
        await settle(tester);
        expect(row('Running'), findsNothing, reason: 'Undo takes it back off the list');
        expect(await storedOn(tester, now), 0, reason: '… and out of the database');
      });
    });

    testWidgets('a refused entry keeps the form open and saves nothing', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await open(tester);
        await tester.tap(find.byType(AppFab));
        await settle(tester);

        await save(tester, 'Save workout');

        expect(find.text('How long did it last? At least a minute.'), findsOneWidget);
        expect(find.text('Log a workout'), findsOneWidget, reason: 'still there to fix');
        expect(find.text('Workout logged'), findsNothing);
        expect(find.byType(AppListTile), findsNothing);
        expect(await storedOn(tester, now), 0);
      });
    });

    testWidgets('closing the form without saving changes nothing', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await open(tester);
        await tester.tap(find.byType(AppFab));
        await settle(tester);
        await type(tester, 'Minutes', '40');

        await tester.tapAt(const Offset(215, 40));
        await settle(tester);

        expect(find.text('Log a workout'), findsNothing,
            reason: 'the premise: the tap outside really did close it');
        expect(find.text('Workout logged'), findsNothing);
        expect(await storedOn(tester, now), 0);
      });
    });
  });

  group('opening one', () {
    testWidgets('shows it whole, as yours, with the ways to change it', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed(tester);
        await open(tester);

        await tester.tap(row('Running'));
        await settle(tester);

        expect(find.text('Added by you'), findsOneWidget);
        expect(find.text('380 kcal'), findsOneWidget);
        expect(find.text('5.50 km'), findsOneWidget);
        expect(find.text('park loop'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });
    });

    testWidgets('a session a watch wrote opens read-only', (tester) async {
      await withClock(Clock.fixed(now), () async {
        final day = DateTime(2026, 6, 19);
        final morning = DateTime(2026, 6, 19, 7);
        HealthDataPoint point(String id, HealthDataType type, HealthValue value,
                HealthDataUnit unit, DateTime from, DateTime to) =>
            HealthDataPoint(
              uuid: id,
              value: value,
              type: type,
              unit: unit,
              dateFrom: from,
              dateTo: to,
              sourcePlatform: HealthPlatformType.googleHealthConnect,
              sourceDeviceId: 'unknown',
              sourceId: 'com.watch',
              sourceName: 'Watch',
              recordingMethod: RecordingMethod.automatic,
            );
        HealthDataPoint bpm(DateTime at, int v) => point('hr-$v-${at.hour}', HealthDataType.HEART_RATE,
            NumericHealthValue(numericValue: v), HealthDataUnit.BEATS_PER_MINUTE, at, at);
        await tester.runAsync(() => BiometricsService.syncFromHealth(
              days: 3,
              now: now,
              samples: {
                key(day): [
                  point(
                      'w1',
                      HealthDataType.WORKOUT,
                      WorkoutHealthValue(
                        workoutActivityType: HealthWorkoutActivityType.SWIMMING,
                        totalEnergyBurned: 300,
                        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
                      ),
                      HealthDataUnit.NO_UNIT,
                      morning,
                      morning.add(const Duration(minutes: 30))),
                  bpm(morning.add(const Duration(minutes: 10)), 140),
                  bpm(morning.add(const Duration(minutes: 20)), 150),
                  bpm(DateTime(2026, 6, 19, 3), 55),
                ],
              },
            ));
        await open(tester);
        expect(row('Swimming'), findsOneWidget, reason: 'the premise: it is on the list');

        await tester.tap(row('Swimming'));
        await settle(tester);

        // Which health app it names follows the platform the test runs on.
        expect(
            find.byWidgetPredicate((w) =>
                w is Text &&
                (w.data == 'From Health Connect' || w.data == 'From Apple Health')),
            findsOneWidget);
        expect(find.text('Edit'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.textContaining('came from your health app'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await settle(tester);
        expect(find.textContaining('came from your health app'), findsNothing);
        expect(row('Swimming'), findsOneWidget, reason: 'and nothing happened to it');
      });
    });
  });

  group('changing one', () {
    testWidgets('Edit opens the form on it; saving updates the row; Undo restores it',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed(tester);
        await open(tester);
        expect(inRow('Running', '40 min · 5.50 km · 380 kcal'), findsOneWidget);

        await tester.tap(row('Running'));
        await settle(tester);
        await tester.tap(find.text('Edit'));
        await settle(tester);

        expect(find.text('Edit workout'), findsOneWidget);
        expect(find.text('Save changes'), findsOneWidget);
        await type(tester, 'Minutes', '55');
        await save(tester, 'Save changes');

        expect(find.text('Workout updated'), findsOneWidget);
        expect(inRow('Running', '55 min · 5.50 km · 380 kcal'), findsOneWidget);
        expect(find.byType(AppListTile), findsOneWidget, reason: 'an edit, not a copy');

        await tester.tap(find.text('Undo'));
        await settle(tester);
        expect(inRow('Running', '40 min · 5.50 km · 380 kcal'), findsOneWidget,
            reason: 'back as it was');
        expect(find.byType(AppListTile), findsOneWidget);
      });
    });

    testWidgets('a different kind replaces it, and Undo puts the old one back',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed(tester);
        await open(tester);
        await tester.tap(row('Running'));
        await settle(tester);
        await tester.tap(find.text('Edit'));
        await settle(tester);

        // A different kind changes its identity just as a different start does:
        // the old session has to go, or the list would show both.
        await tester.tap(find.widgetWithText(AppChip, 'Biking'));
        await tester.pump();
        await save(tester, 'Save changes');

        expect(row('Biking'), findsOneWidget);
        expect(row('Running'), findsNothing, reason: 'the old one did not stay behind');
        expect(await storedOn(tester, DateTime(2026, 6, 19)), 1);

        await tester.tap(find.text('Undo'));
        await settle(tester);
        expect(row('Running'), findsOneWidget);
        expect(row('Biking'), findsNothing);
        expect(await storedOn(tester, DateTime(2026, 6, 19)), 1);
      });
    });
  });

  group('deleting one', () {
    testWidgets('removes it, says so, and Undo brings it back with everything',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed(tester);
        await open(tester);

        await tester.tap(row('Running'));
        await settle(tester);
        await tester.tap(find.text('Delete'));
        await settle(tester);

        expect(find.text('Workout deleted'), findsOneWidget);
        expect(row('Running'), findsNothing);
        expect(await storedOn(tester, DateTime(2026, 6, 19)), 0);

        await tester.tap(find.text('Undo'));
        await settle(tester);

        expect(inRow('Running', '40 min · 5.50 km · 380 kcal'), findsOneWidget,
            reason: 'the calories and distance too, not just the row');
        expect(await storedOn(tester, DateTime(2026, 6, 19)), 1);
      });
    });
  });
}
