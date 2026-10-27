/// The Steps screen's "Rain from 6 pm — 4–6 pm looks dry for a walk." tip.
///
/// Said only to someone clearly behind on today's goal, when the forecast has
/// rain in the hours left and a dry stretch to point at — never on a dry day, on
/// pace, on a rest day, or with no weather set up.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/steps/widgets/rain_walk_tip_card.dart';
import 'package:tablet_remainder/features/water/services/hydration_weather_service.dart';

import '../../support/font_free_theme.dart';

void main() {
  /// A day of 0% with [over] (hour → percent) overriding it.
  List<int?> day({Map<int, int?> over = const {}}) =>
      [for (var h = 0; h < 24; h++) over.containsKey(h) ? over[h] : 0];

  RainForecast forecast(List<int?> hourly, {String place = 'Chennai'}) =>
      RainForecast(hourly: hourly, placeName: place);

  Future<void> pump(
    WidgetTester tester, {
    required int steps,
    int goal = 8000,
    bool restDay = false,
    required DateTime at,
    RainForecast? f,
    double width = 400,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1200);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await withClock(Clock.fixed(at), () async {
      await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RainWalkTipCard(
              steps: steps,
              goal: goal,
              restDay: restDay,
              load: () async => f,
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    });
  }

  // 14:00, 2,500 of 8,000: behind (an even day has half the goal by now).
  final afternoon = DateTime(2026, 8, 21, 14);
  final rainAt6 = forecast(day(over: {18: 70, 19: 85, 20: 60}));

  testWidgets('behind, rain coming, a dry stretch first: says so', (tester) async {
    await pump(tester, steps: 2500, at: afternoon, f: rainAt6);
    expect(find.text('Rain from 6 pm — 2–4 pm looks dry for a walk.'), findsOneWidget);
    expect(find.text('Forecast for Chennai — a guess, not a promise.'), findsOneWidget);
  });

  testWidgets('and rain now: until it eases', (tester) async {
    final raining = forecast(day(over: {14: 80, 15: 75}));
    await pump(tester, steps: 2500, at: afternoon, f: raining);
    expect(find.text('Rain until 4 pm — 4–6 pm looks dry for a walk.'), findsOneWidget);
  });

  testWidgets('a dry day says nothing', (tester) async {
    await pump(tester, steps: 2500, at: afternoon, f: forecast(day()));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('on pace says nothing, rain or not', (tester) async {
    await pump(tester, steps: 5000, at: afternoon, f: rainAt6);
    expect(find.byType(Text), findsNothing,
        reason: 'the tip is for someone behind');
  });

  testWidgets('the goal met says nothing', (tester) async {
    await pump(tester, steps: 8200, at: afternoon, f: rainAt6);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a rest day says nothing: the goal is paused', (tester) async {
    await pump(tester, steps: 2500, at: afternoon, f: rainAt6, restDay: true);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('no weather set up says nothing', (tester) async {
    await pump(tester, steps: 2500, at: afternoon, f: null);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('nothing before the day has begun', (tester) async {
    await pump(tester, steps: 0, at: DateTime(2026, 8, 21, 6), f: rainAt6);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('rain that has all gone says nothing', (tester) async {
    final morning = forecast(day(over: {9: 90, 10: 90}));
    await pump(tester, steps: 2500, at: afternoon, f: morning);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('the place is named, so it is clear whose weather this is',
      (tester) async {
    await pump(tester, steps: 2500, at: afternoon, f: forecast(day(over: {18: 90}), place: 'Pune, India'));
    expect(find.textContaining('Pune, India'), findsOneWidget);
  });

  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
    testWidgets('fits $width wide at ${scale}x text', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final prev = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await pump(tester,
            steps: 2500, at: afternoon, f: rainAt6, width: width, scale: scale);
      } finally {
        FlutterError.onError = prev;
      }
      expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);
      expect(find.textContaining('Rain from'), findsOneWidget);
    });
  }
}
