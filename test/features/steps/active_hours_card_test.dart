/// "6 of 9 active hours" on the Steps screen: only when the hourly record covers
/// the day, and never on a day the goal is paused.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/active_hours.dart';
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/steps/widgets/active_hours_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late db.AppDatabase database;

  // A Thursday evening.
  final now = DateTime(2026, 3, 12, 19, 0);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
  });

  tearDown(() async => database.close());

  List<int> hours(Iterable<int> active, int steps) =>
      [for (var h = 0; h < 24; h++) active.contains(h) ? steps : 0];

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 4200);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // overflow is the responsive suite's job
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const StepsDashboardScreen()));
      for (var f = 0; f < 8; f++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // The screen shows a spinner until the health-app probe answers or times
      // out (6 s); nothing answers in a test, so wait that out.
      await tester.pump(const Duration(seconds: 7));
    } finally {
      FlutterError.onError = prev;
    }
  }

  group('on the Steps screen', () {
    testWidgets('says how many hours had walking in them', (tester) async {
      await withClock(Clock.fixed(now), () async {
        final h = hours([7, 8, 12, 13, 17, 18], 400); // 2,400 steps
        StepService.storeHealthDayForTesting(now, 2400, isToday: true, hourly: h);
        await open(tester);

        expect(find.text('6 of 9 active hours'), findsOneWidget);
        expect(find.textContaining('at least 250 steps'), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('marks exactly the active hours', (tester) async {
      await withClock(Clock.fixed(now), () async {
        final h = hours([7, 8], 400);
        StepService.storeHealthDayForTesting(now, 800, isToday: true, hourly: h);
        await open(tester);

        Color? colorOf(int hour) => ((tester
                    .widget<Container>(find.byKey(ValueKey('active-hour-$hour')))
                    .decoration) as BoxDecoration)
            .color;
        // Active hours are drawn in the accent, solid; the rest are a faint grey.
        expect(colorOf(7)!.a, 1.0, reason: 'an active hour is solid');
        expect(colorOf(6)!.a, lessThan(0.5), reason: 'a quiet hour is faint');
        expect(colorOf(7), isNot(colorOf(6)));
        expect(colorOf(8), colorOf(7), reason: 'both active');
        expect(colorOf(9), colorOf(6), reason: 'both quiet');
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('at the target it says so, in words that are not a score',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        final h = hours(List.generate(9, (i) => 8 + i), 300);
        StepService.storeHealthDayForTesting(now, 2700, isToday: true, hourly: h);
        await open(tester);

        expect(find.text('9 of 9 active hours'), findsOneWidget);
        expect(find.textContaining('moved through enough of the day'),
            findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('no hourly record: no card, rather than "0 of 9"', (tester) async {
      await withClock(Clock.fixed(now), () async {
        StepService.storeHealthDayForTesting(now, 4000, isToday: true);
        await open(tester);

        expect(find.textContaining('active hours'), findsNothing);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('a record that stops short of the day: no card', (tester) async {
      await withClock(Clock.fixed(now), () async {
        // Synced mid-morning: 1,200 steps in the buckets, 5,000 in the day.
        final h = hours([8, 9, 10], 400);
        StepService.storeHealthDayForTesting(now, 5000, isToday: true, hourly: h);
        await open(tester);

        expect(find.textContaining('active hours'), findsNothing);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('not on a rest day: the goal is paused', (tester) async {
      await withClock(Clock.fixed(now), () async {
        final h = hours([7, 8, 12], 400);
        StepService.storeHealthDayForTesting(now, 1200, isToday: true, hourly: h);
        await RestDayStore.markToday(RestKind.rest);
        await open(tester);

        expect(find.textContaining('active hours'), findsNothing);
        await tester.pump(const Duration(seconds: 8));
      });
    });
  });

  group('the card', () {
    Widget host(ActiveHours? r) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: ActiveHoursCard(result: r)));

    testWidgets('takes no room with nothing to say', (tester) async {
      await tester.pumpWidget(host(null));

      expect(tester.getSize(find.byType(ActiveHoursCard)), Size.zero);
    });

    testWidgets('reads as one sentence to a screen reader', (tester) async {
      await tester.pumpWidget(host(ActiveHours(hours([8, 9, 10], 400).map((s) => s >= 250).toList())));

      expect(find.bySemanticsLabel('3 of 9 active hours so far today'),
          findsOneWidget);
    });
  });
}
