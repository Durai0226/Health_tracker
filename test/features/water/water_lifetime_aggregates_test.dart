import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// Achievements and streaks used to be folded out of `WaterService`'s 90-day
/// in-memory warm cache. That made lifetime numbers *shrink*: a day older than
/// the window stopped counting toward "total ml" and "days goal met", and
/// because `_evaluateAchievements` persists what it computes, the shrunken
/// totals were written over the good ones. A user's longest streak also silently
/// capped at the cache width.
///
/// These tests pin the fix — the aggregates come from Drift — and pin the one
/// piece of SQL date arithmetic it introduced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  /// Well outside [WaterService.warmCacheWindow] (90 days).
  DateTime dayAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - n);
  }

  String keyFor(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  /// Seeds one stored day. [hours] are the local hours-of-day its logs sit at.
  Future<void> seedDay(
    DateTime date, {
    required int intakeMl,
    required bool goalReached,
    int goalMl = 2500,
    int caffeineMg = 0,
    int alcoholCount = 0,
    List<int> hours = const [9],
  }) async {
    final key = keyFor(date);
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(key),
      date: Value(date),
      dailyGoalMl: Value(goalMl),
      totalIntakeMl: Value(intakeMl),
      effectiveHydrationMl: Value(intakeMl),
      totalCaffeineMg: Value(caffeineMg),
      alcoholicDrinksCount: Value(alcoholCount),
      goalReached: Value(goalReached),
    ));
    for (var i = 0; i < hours.length; i++) {
      await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
        id: Value('$key-log-$i'),
        dailyDataId: Value(key),
        time: Value(DateTime(date.year, date.month, date.day, hours[i])),
        amountMl: Value((intakeMl / hours.length).round()),
        effectiveHydrationMl: Value((intakeMl / hours.length).round()),
        beverageId: Value(i == 0 ? 'water' : 'tea'),
        beverageName: Value(i == 0 ? 'Water' : 'Tea'),
        hydrationPercent: const Value(100),
        caffeineAmount: Value(i == 0 ? 0 : caffeineMg),
        isAlcoholic: Value(alcoholCount > 0 && i == 0),
      ));
    }
  }

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async => database.close());

  group('lifetime aggregates read the table, not the warm cache', () {
    test('a day older than the warm cache still counts toward totals', () async {
      // 200 days ago: on disk, never in the in-memory window.
      await seedDay(dayAgo(200), intakeMl: 3000, goalReached: true);
      await seedDay(dayAgo(1), intakeMl: 2600, goalReached: true);
      await WaterService.init();

      // Premise guard: if warmCacheWindow ever grows past 200 days this test
      // would pass for the wrong reason.
      expect(WaterService.getDataForDate(dayAgo(200)), isNull,
          reason: 'the old day must be outside the warm cache');

      final ach = WaterService.getAchievements();
      expect(ach.totalMl, 5600,
          reason: 'the pre-cache day must still be in the lifetime total');
      expect(ach.daysGoalMet, 2);
      expect(ach.totalDrinks, 2);
    });

    test('longest streak is not capped by the cache width', () async {
      // A 100-day run ending 150 days ago — entirely outside the 90-day cache.
      for (var i = 150; i < 250; i++) {
        await seedDay(dayAgo(i), intakeMl: 2600, goalReached: true);
      }
      await WaterService.init();

      expect(WaterService.getAchievements().longestStreak, 100,
          reason: 'a 100-day run predating the cache must survive');
    });

    test('a failed aggregate read leaves stored achievements alone', () async {
      await seedDay(dayAgo(1), intakeMl: 2600, goalReached: true);
      await WaterService.init();
      final before = WaterService.getAchievements().totalMl;
      expect(before, 2600);

      // Close the database under the service: the next evaluate must fail its
      // read and return empty rather than persisting zeros over good data.
      await database.close();
      final newly = await WaterService.evaluateAchievementsForTesting();

      expect(newly, isEmpty);
      expect(WaterService.getAchievements().totalMl, before,
          reason: 'a read failure must not zero the stored totals');
    });
  });

  group('the SQL early-drink hour matches Dart', () {
    test('pre-07:00 local logs are counted, 07:00+ are not', () async {
      // Dart's DateTime.hour and SQLite's
      // strftime('%H', time, 'unixepoch', 'localtime') must agree, because the
      // "early bird" achievement is defined in local time and drift stores
      // DateTime as unix *seconds*.
      await seedDay(dayAgo(120), intakeMl: 500, goalReached: false, hours: [5]);
      await seedDay(dayAgo(121), intakeMl: 500, goalReached: false, hours: [6]);
      await seedDay(dayAgo(122), intakeMl: 500, goalReached: false, hours: [7]);
      await seedDay(dayAgo(123), intakeMl: 500, goalReached: false, hours: [23]);

      final rows = await database.waterDao.lifetimeDayAggregates();

      for (final r in rows) {
        final logs = await database.waterDao.getLogsForDay(keyFor(r.date));
        final dartEarly = logs.where((l) => l.time.hour < 7).length;
        expect(r.earlyLogCount, dartEarly,
            reason: 'SQL and Dart disagree on the local hour for ${r.date}');
      }

      await WaterService.init();
      expect(WaterService.getAchievements().earlyMorningDrinks, 2,
          reason: 'only the 05:00 and 06:00 days are early');
    });
  });

  group('goalReachedAt', () {
    test('is stamped on the edited day, not wall-clock now', () async {
      final past = dayAgo(120);
      await WaterService.init();

      final water = WaterService.getBeverage('water')!;
      // One log big enough to clear the goal on a day months ago. Derived from
      // the real goal, not a magic 3000 — the goal now comes from the IOM
      // adequate-intake table and is not a fixed number.
      await WaterService.addWaterLogForDate(
        date: past,
        amountMl: WaterService.getDailyGoal() + 100,
        beverage: water,
        time: DateTime(past.year, past.month, past.day, 10),
      );

      final day = WaterService.getDataForDate(past)!;
      expect(day.goalReached, isTrue);
      expect(day.goalReachedAt, isNotNull);
      expect(day.goalReachedAt!.year, past.year);
      expect(day.goalReachedAt!.month, past.month);
      expect(day.goalReachedAt!.day, past.day,
          reason: 'back-filling a past day must not stamp it with today');
    });

    test('is cleared when an edit drops the day back under its goal', () async {
      final past = dayAgo(121);
      await WaterService.init();
      final water = WaterService.getBeverage('water')!;

      final day = await WaterService.addWaterLogForDate(
        date: past,
        amountMl: WaterService.getDailyGoal() + 100,
        beverage: water,
        time: DateTime(past.year, past.month, past.day, 10),
      );
      expect(day.goalReachedAt, isNotNull);

      await WaterService.removeWaterLogForDate(past, day.logs.last.id);

      final after = WaterService.getDataForDate(past);
      expect(after?.goalReached ?? false, isFalse);
      expect(after?.goalReachedAt, isNull,
          reason: 'an unmet day must not keep a "reached at" timestamp');
    });
  });
}
