/// Two counters that counted the wrong things.
///
///  * **"Plants" in Today's Progress** read `todayPlants`, which filtered the
///    garden by date only. `abandonSession` appends a withered
///    `FocusPlant(isAlive: false)` for every session given up on, so starting
///    a 25-minute session and tapping "Give up" read `Minutes 0 · Plants 1 ·
///    Streak 0` — a plant credited for the session you abandoned, beside two
///    counters correctly saying nothing happened.
///
///  * **`getLast7Days`** asked for `dayOffset(now, -7) .. now` against an
///    inclusive range, so it returned EIGHT calendar days — and D-7 is the
///    same weekday as today. The Week bar chart folds rows by `date.weekday`,
///    so that extra day was summed into today's bar.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/detailed_stats.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  // A Saturday afternoon.
  final now = DateTime(2026, 3, 14, 13, 0);

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

  group("Today's Progress counts plants that grew", () {
    /// One stored plant. `abandonSession` writes `isAlive: false`; a completed
    /// session writes `isAlive: true`.
    Map<String, dynamic> plant(String id, DateTime at, {required bool alive}) =>
        FocusPlant(
          id: id,
          type: PlantType.values.first,
          plantedAt: at,
          durationMinutes: alive ? 25 : 5,
          isAlive: alive,
          growthProgress: alive ? 1.0 : 0.2,
        ).toJson();

    /// Cold-start the service against a persisted garden.
    Future<void> bootGarden(List<Map<String, dynamic>> plants) async {
      await CleanStorageService.setAppPreference('focusGarden', plants);
      await FocusService().init();
    }

    test('a withered plant does not count', () async {
      await withClock(Clock.fixed(now), () async {
        await bootGarden([
          plant('dead', DateTime(2026, 3, 14, 9, 0), alive: false),
        ]);
        final f = FocusService();
        expect(f.garden, hasLength(1),
            reason: 'premise: the plant IS in the garden — without this the '
                'assertion below passes on an empty store and proves nothing');
        expect(f.todayGrownPlants, isEmpty,
            reason: 'a plant credited for a session the user gave up on, '
                'beside a Minutes counter correctly reading 0');
      });
    });

    test('a grown plant does count', () async {
      await withClock(Clock.fixed(now), () async {
        await bootGarden([
          plant('alive', DateTime(2026, 3, 14, 9, 0), alive: true),
        ]);
        expect(FocusService().todayGrownPlants, hasLength(1),
            reason: 'the counter must still count the thing it is for');
      });
    });

    test('a mixed day counts only the living', () async {
      await withClock(Clock.fixed(now), () async {
        await bootGarden([
          plant('a', DateTime(2026, 3, 14, 9, 0), alive: true),
          plant('b', DateTime(2026, 3, 14, 11, 0), alive: false),
          plant('c', DateTime(2026, 3, 14, 15, 0), alive: true),
        ]);
        expect(FocusService().garden, hasLength(3));
        expect(FocusService().todayGrownPlants, hasLength(2));
      });
    });

    test('yesterday does not count toward today', () async {
      await withClock(Clock.fixed(now), () async {
        await bootGarden([
          plant('y', DateTime(2026, 3, 13, 9, 0), alive: true),
        ]);
        expect(FocusService().garden, hasLength(1));
        expect(FocusService().todayGrownPlants, isEmpty);
      });
    });
  });

  group('the rolling windows are the length they claim', () {
    /// One completed session per day, [days] days back from today.
    List<FocusSession> daily(int days) => [
          for (var back = 0; back < days; back++)
            FocusSession(
              id: 's$back',
              startedAt: DateTime(2026, 3, 14 - back, 9, 0),
              completedAt: DateTime(2026, 3, 14 - back, 9, 30),
              targetMinutes: 30,
              actualMinutes: 30,
              wasCompleted: true,
              activityType: FocusActivityType.work,
              plantType: PlantType.values.first,
            ),
        ];

    test('getLast7Days spans seven calendar days, not eight', () async {
      await withClock(Clock.fixed(now), () async {
        // Sessions on each of the last EIGHT days. A correct 7-day window sees
        // seven of them; the old one saw all eight, and the eighth shares
        // today's weekday.
        StatsService().buildFromSessions(daily(8));

        final days = StatsService().getLast7Days();
        expect(days, hasLength(7),
            reason: 'an inclusive range from dayOffset(now, -7) is eight days, '
                'and its first day is the same weekday as today — so the Week '
                'chart summed two rows into one bar');

        // ...and no weekday appears twice, which is the property the chart
        // actually depends on.
        final weekdays = days.map((d) => d.date.weekday).toList();
        expect(weekdays.toSet(), hasLength(weekdays.length),
            reason: 'a repeated weekday is a double-counted bar: $weekdays');
      });
    });

    test('getLast30Days spans thirty', () async {
      await withClock(Clock.fixed(now), () async {
        StatsService().buildFromSessions(daily(31));
        expect(StatsService().getLast30Days(), hasLength(30));
      });
    });
  });

  group('Productivity Patterns needs a pattern', () {
    FocusSession s(String id, DateTime at, {required bool completed}) =>
        FocusSession(
          id: id,
          startedAt: at,
          completedAt: at.add(const Duration(minutes: 25)),
          targetMinutes: 25,
          actualMinutes: completed ? 25 : 4,
          wasCompleted: completed,
          wasAbandoned: !completed,
          activityType: FocusActivityType.work,
          plantType: PlantType.values.first,
        );

    test('no sessions at all means no pattern', () {
      StatsService().updateProductivityPattern(const []);
      expect(StatsService().productivityPattern, isNull,
          reason: 'analyze() returns a non-null object for an empty list, with '
              'mostProductiveHour = 0 and mostProductiveDay = 1 left at their '
              'initialisers — so a fresh install was told "Peak Hour 12 AM, '
              'Best Day Mon"');
    });

    test('only abandoned sessions means no pattern either', () {
      StatsService().updateProductivityPattern([
        s('a', DateTime(2026, 3, 14, 9), completed: false),
        s('b', DateTime(2026, 3, 13, 9), completed: false),
      ]);
      expect(StatsService().productivityPattern, isNull,
          reason: 'analyze() walks sessions.where(wasCompleted), so these '
              'contribute nothing and the card would still be inventing one');
    });

    test('a completed session does produce one, with the real hour', () {
      StatsService().updateProductivityPattern([
        s('c', DateTime(2026, 3, 14, 15), completed: true),
      ]);
      final p = StatsService().productivityPattern;
      expect(p, isNotNull, reason: 'the card must still appear when earned');
      expect(p!.mostProductiveHour, 15,
          reason: 'and report the hour that was actually focused in, not 0');
    });
  });

  /// The Overview hero and the Activity Breakdown beneath it have to mean the
  /// same days.
  ///
  /// The hero calls `getTotalMinutes(period)` — `getWeekStats()` for weekly,
  /// the current Mon–Sun week. The breakdown called `getLast7Days()`, a
  /// rolling window. On a Wednesday the hero covered Mon–Wed while the
  /// breakdown covered the previous Thursday onward, so the breakdown could
  /// total MORE minutes than the hero said existed, under one control labelled
  /// "Week".
  group('the Overview and the Activity Breakdown agree', () {
    /// `now` is a Wednesday, so the calendar week (Mon–Wed) and any rolling
    /// 7-day window differ by four days.
    final wednesday = DateTime(2026, 3, 11, 13, 0);

    FocusSession at(String id, DateTime start, int minutes) => FocusSession(
          id: id,
          startedAt: start,
          completedAt: start.add(Duration(minutes: minutes)),
          targetMinutes: minutes,
          actualMinutes: minutes,
          wasCompleted: true,
          activityType: FocusActivityType.work,
          plantType: PlantType.values.first,
        );

    test('weekly: the breakdown never exceeds the hero', () async {
      await withClock(Clock.fixed(wednesday), () async {
        expect(wednesday.weekday, DateTime.wednesday, reason: 'premise');

        StatsService().buildFromSessions([
          // Inside this calendar week (Mon 9th, Wed 11th).
          at('mon', DateTime(2026, 3, 9, 9), 30),
          at('wed', DateTime(2026, 3, 11, 9), 20),
          // LAST week, but inside a rolling 7-day window from the 11th.
          at('fri', DateTime(2026, 3, 6, 9), 90),
          at('sat', DateTime(2026, 3, 7, 9), 45),
        ]);

        final hero = StatsService().getTotalMinutes(StatsPeriod.weekly);
        final breakdown = StatsService()
            .getActivityBreakdown(StatsPeriod.weekly)
            .values
            .fold<int>(0, (a, b) => a + b);

        expect(hero, 50, reason: 'Mon 30 + Wed 20 is this calendar week');
        expect(breakdown, hero,
            reason: 'the rolling window pulled in the 90 and 45 from last '
                'week, so the breakdown totalled 185 under a hero saying 50');
      });
    });

    test('monthly: the breakdown never exceeds the hero', () async {
      await withClock(Clock.fixed(wednesday), () async {
        StatsService().buildFromSessions([
          at('thismonth', DateTime(2026, 3, 2, 9), 60),
          // February — inside a rolling 30 days, outside the calendar month.
          at('lastmonth', DateTime(2026, 2, 20, 9), 120),
        ]);

        final hero = StatsService().getTotalMinutes(StatsPeriod.monthly);
        final breakdown = StatsService()
            .getActivityBreakdown(StatsPeriod.monthly)
            .values
            .fold<int>(0, (a, b) => a + b);

        expect(hero, 60, reason: 'March only');
        expect(breakdown, hero,
            reason: "the rolling window counted February's 120 minutes under "
                'a hero reporting the calendar month');
      });
    });
  });
}
