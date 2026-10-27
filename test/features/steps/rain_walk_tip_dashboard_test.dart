/// The rain tip, on the Steps screen itself: there for someone behind when rain is
/// coming and a dry stretch is not, and not there — or asked for — otherwise.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/steps/widgets/rain_walk_tip_card.dart';
import 'package:tablet_remainder/features/water/services/hydration_weather_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;
  // 14:00: half the waking day. Behind means under 80% of half the goal.
  final now = DateTime(2026, 6, 30, 14, 0);
  final requests = <Uri>[];
  Future<Map<String, dynamic>?> Function(Uri)? previous;

  Map<String, dynamic> rainAtSix() => {
        'hourly': {
          'precipitation_probability': [
            for (var h = 0; h < 24; h++) (h >= 18 && h <= 20) ? 80 : 0
          ],
        },
      };

  /// The place is set either way: [enabled] is the opt-in, which is what the tip
  /// has to respect.
  Future<void> setUpWeather({bool enabled = true}) async {
    SharedPreferences.setMockInitialValues({
      if (enabled) 'hydration_weather_enabled': true,
      'hydration_weather_place': 'Chennai, Tamil Nadu, India',
      'hydration_weather_lat': 13.0827,
      'hydration_weather_lon': 80.2707,
    });
  }

  setUp(() async {
    requests.clear();
    previous = HydrationWeatherService.fetchForTesting;
    HydrationWeatherService.fetchForTesting = (uri) async {
      requests.add(uri);
      return rainAtSix();
    };
    await setUpWeather();
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
  });

  tearDown(() async {
    HydrationWeatherService.fetchForTesting = previous;
    await database.close();
  });

  Future<void> openSteps(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 3600);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // overflow is the responsive suite's job
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const StepsDashboardScreen()));
      // The screen's health probe gives up after six seconds of fake time.
      for (var f = 0; f < 90; f++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = prev;
    }
  }

  Future<void> walkedToday(int steps) async {
    await StepService.addManualStepsForDate(now, steps);
  }

  testWidgets('behind, with rain coming: the tip is there, with the place',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await walkedToday(500);
      await openSteps(tester);

      expect(find.byType(RainWalkTipCard), findsOneWidget);
      expect(find.textContaining('Rain from 6 pm'), findsOneWidget);
      expect(find.textContaining('looks dry for a walk'), findsOneWidget);
      expect(find.textContaining('Forecast for Chennai, Tamil Nadu, India'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('on pace: no tip', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await walkedToday(6000);
      await openSteps(tester);
      expect(find.textContaining('Rain from'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('a rest day: no tip, the goal is paused', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await walkedToday(500);
      await RestDayStore.markToday(RestKind.rest);
      await openSteps(tester);
      expect(find.textContaining('Rain from'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('the weather switched off: no tip, and nothing is fetched',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await setUpWeather(enabled: false);
      await walkedToday(500);
      await openSteps(tester);
      expect(find.textContaining('Rain from'), findsNothing);
      expect(requests, isEmpty,
          reason: 'the tip borrows the weather opt-in; it does not make its own');
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
