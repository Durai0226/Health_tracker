/// The steps streak was capped at about 35 days.
///
/// It counts consecutive days on which the goal was reached, and the days it
/// looked at were the in-memory window: the last ~35 loaded from the database.
/// Someone on a 90-day run saw "35". The streak now reads the dates of every
/// goal-reached day, and lets the days in memory — fresher — overrule them.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/utils/calendar_day.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  // Midday, so "today" is unambiguous.
  final now = DateTime(2026, 6, 15, 12, 0);
  DateTime day(int offset) => dayOffset(DateTime(2026, 6, 15), offset);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await StepService.resetForTesting();
  });

  tearDown(() async {
    await StepService.resetForTesting();
    await database.close();
  });

  /// One stored day. [reached] is the stored flag the streak reads.
  Future<void> seed(DateTime date, {required bool reached}) =>
      database.stepsDao.saveDay(db.StepDailyDataCompanion.insert(
        id: '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        date: date,
        createdAt: date,
        updatedAt: date,
        sensorSteps: Value(reached ? 9000 : 100),
        goalReached: Value(reached),
      ));

  /// Goal reached on every day from [from] to [to] inclusive (offsets from today).
  Future<void> run(int from, int to) async {
    for (var o = from; o <= to; o++) {
      await seed(day(o), reached: true);
    }
  }

  test('a run longer than the in-memory window counts in full', () async {
    await withClock(Clock.fixed(now), () async {
      // Ninety unbroken days up to and including today.
      await run(-89, 0);
      await StepService.reloadFromDb();

      final streak = StepService.getStreakResult();
      expect(streak.current, 90,
          reason: 'it read only the last ~35 loaded days, so it said 35');
      expect(streak.longest, 90);
    });
  });

  test('the all-time best survives a break, and the current run restarts',
      () async {
    await withClock(Clock.fixed(now), () async {
      // 60 days a long while ago, a week-long gap, then 5 days up to today.
      await run(-80, -21);
      await run(-4, 0);
      await StepService.reloadFromDb();

      final streak = StepService.getStreakResult();
      expect(streak.longest, 60,
          reason: 'the old run is outside the loaded window but still counts');
      expect(streak.current, lessThan(10));
    });
  });

  test('a day edited in memory overrules the stored flag', () async {
    await withClock(Clock.fixed(now), () async {
      await run(-59, 0);
      await StepService.reloadFromDb();
      expect(StepService.getStreakResult().current, 60);

      // Yesterday is corrected down to a handful of steps: not a goal day now.
      StepService.storeHealthDayForTesting(day(-1), 100, isToday: false);

      expect(StepService.getStreakResult().current, isNot(60),
          reason: 'the stored history said yesterday was a goal day; the day '
              'as it stands in memory says otherwise, and is fresher');
    });
  });

  test('a short history is unchanged', () async {
    await withClock(Clock.fixed(now), () async {
      await run(-6, 0);
      await StepService.reloadFromDb();
      expect(StepService.getStreakResult().current, 7);
    });
  });

  test('a data wipe forgets the history', () async {
    await withClock(Clock.fixed(now), () async {
      await run(-59, 0);
      await StepService.reloadFromDb();
      expect(StepService.getStreakResult().current, 60);

      StepService.clearInMemory();
      expect(StepService.getStreakResult().current, 0);
    });
  });
}
