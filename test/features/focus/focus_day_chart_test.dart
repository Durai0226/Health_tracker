import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// The segment labelled **Day** has to mean today.
///
/// It plotted `productivityPattern.minutesByHour`, and
/// `ProductivityPattern.analyze` walks `sessions.where((s) => s.wasCompleted)`
/// with no date filter at all — it is a LIFETIME aggregate, built for the
/// "your most productive hour" card further down the same screen. So the Day
/// chart showed every session ever recorded, bucketed by hour: a user who had
/// not focused at all today still saw a full set of bars under a heading that
/// said Day, and the number under it (the overview card, which is correctly
/// scoped to today) said zero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  // A Saturday afternoon, so "today" has hours both behind and ahead of it.
  final now = DateTime(2026, 3, 14, 13, 0);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    StatsService().resetForTesting();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    StatsService().resetForTesting();
    await db.close();
  });

  Map<String, dynamic> completed(String id, DateTime startedAt, int minutes) => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'completedAt':
            startedAt.add(Duration(minutes: minutes)).toIso8601String(),
        'targetMinutes': minutes,
        'actualMinutes': minutes,
        'wasCompleted': true,
        'wasAbandoned': false,
        'activityType': FocusActivityType.work.index,
        'plantType': 0,
      };

  /// Cold-start the service against a persisted history.
  Future<void> bootWith(List<Map<String, dynamic>> sessions) async {
    await CleanStorageService.setAppPreference('focusSessions', sessions);
    await FocusService().init();
  }

  /// Open Statistics and switch to the Day segment.
  Future<void> pumpDayChart(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: DetailedStatsScreen()));
    // Never pumpAndSettle a Focus screen: several run looping animations.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Day'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// The chart falls back to this whenever every bar is zero, so its presence
  /// is a readable proxy for "the Day chart has nothing to draw".
  final emptyChart = find.text('Your trend starts with one session');

  testWidgets('a day with no sessions draws no bars, however long the history is',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      // Five days ago, and nothing since.
      await bootWith([
        completed('older', DateTime(2026, 3, 9, 16, 0), 45),
      ]);
      expect(FocusService().sessions, hasLength(1),
          reason: 'sanity: the history really did load');

      await pumpDayChart(tester);
    });

    expect(emptyChart, findsOneWidget,
        reason: 'BEFORE THE FIX the Day chart plotted the LIFETIME '
            'hour-of-day aggregate, so a 45-minute session from five days ago '
            'drew a bar under a heading that says Day — while the overview '
            'card directly above it correctly reported 0m for today');
  });

  testWidgets('a day with a session does draw its bars', (tester) async {
    // The other half, and the reason the assertion above is not simply "the
    // Day chart is always empty": scoping it to today must not empty it out.
    await withClock(Clock.fixed(now), () async {
      await bootWith([
        completed('older', DateTime(2026, 3, 9, 16, 0), 45),
        completed('today', DateTime(2026, 3, 14, 10, 0), 25),
      ]);

      await pumpDayChart(tester);
    });

    expect(emptyChart, findsNothing,
        reason: 'twenty-five minutes were focused today, at 10:00');
  });

  group('minutesByHourForDay', () {
    FocusSession session({
      required DateTime startedAt,
      required int minutes,
      bool wasCompleted = true,
    }) =>
        FocusSession(
          id: '${startedAt.toIso8601String()}-$minutes',
          startedAt: startedAt,
          completedAt: wasCompleted ? startedAt : null,
          targetMinutes: minutes,
          actualMinutes: minutes,
          wasCompleted: wasCompleted,
          wasAbandoned: !wasCompleted,
          activityType: FocusActivityType.work,
          plantType: PlantType.tree,
        );

    test('buckets one day by start hour and ignores every other day', () {
      final stats = StatsService();
      final byHour = stats.minutesByHourForDay(now, [
        session(startedAt: DateTime(2026, 3, 14, 10, 5), minutes: 25),
        session(startedAt: DateTime(2026, 3, 14, 10, 40), minutes: 15),
        session(startedAt: DateTime(2026, 3, 14, 9, 0), minutes: 30),
        session(startedAt: DateTime(2026, 3, 9, 10, 0), minutes: 45),
      ]);

      expect(byHour, {10: 40, 9: 30});
    });

    test('counts completed minutes only, like every other total on the screen',
        () {
      final stats = StatsService();
      final byHour = stats.minutesByHourForDay(now, [
        session(startedAt: DateTime(2026, 3, 14, 10, 0), minutes: 25),
        session(
            startedAt: DateTime(2026, 3, 14, 10, 30),
            minutes: 5,
            wasCompleted: false),
      ]);

      expect(byHour, {10: 25},
          reason: 'abandoned time is not focus time — DailyFocusStats '
              '.totalMinutes draws the same line');
    });
  });
}
