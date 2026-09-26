import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// Water reminders were generated once in the settings screen and then frozen:
/// every slot fired every day whether the person had drunk nothing or three
/// litres. Fixed-interval nagging is the behaviour the whole category gets
/// criticised for, and notification fatigue is the top reason people turn
/// hydration reminders off entirely.
///
/// The pruning itself is private to ReminderRescheduleService (it needs
/// NotificationService, which has no headless implementation), so these tests
/// pin the input it depends on: the typical-drink estimate that decides how
/// many nudges are still needed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final noon = DateTime(2026, 8, 21, 12);

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await withClock(Clock.fixed(noon), () => WaterService.init());
  });

  tearDown(() async => database.close());

  test('defaults to the category-standard 250 ml with no history', () {
    expect(WaterService.typicalDrinkMl(), 250);
  });

  test('learns the user real drink size', () async {
    await withClock(Clock.fixed(noon), () async {
      final water = WaterService.getBeverage('water')!;
      for (var i = 0; i < 5; i++) {
        await WaterService.addWaterLogForDate(
          date: noon,
          amountMl: 500,
          beverage: water,
          time: noon.subtract(Duration(hours: i + 1)),
        );
      }
      expect(WaterService.typicalDrinkMl(), 500);
    });
  });

  test('uses the median, so one big bottle does not skew it', () async {
    await withClock(Clock.fixed(noon), () async {
      final water = WaterService.getBeverage('water')!;
      for (final ml in [200, 250, 250, 250, 2000]) {
        await WaterService.addWaterLogForDate(
          date: noon,
          amountMl: ml,
          beverage: water,
          time: noon.subtract(Duration(minutes: ml)),
        );
      }
      expect(WaterService.typicalDrinkMl(), 250,
          reason: 'a mean would report 590 and under-schedule every reminder');
    });
  });

  test('the remaining-need arithmetic shrinks as the day fills', () async {
    await withClock(Clock.fixed(noon), () async {
      final water = WaterService.getBeverage('water')!;
      final goal = WaterService.getDailyGoal();

      int nudgesNeeded() {
        final d = WaterService.getTodayData();
        final remaining = d.dailyGoalMl - d.effectiveHydrationMl;
        if (remaining <= 0) return 0;
        return (remaining / WaterService.typicalDrinkMl()).ceil();
      }

      final atStart = nudgesNeeded();
      expect(atStart, greaterThan(1));

      // Drink most of the goal.
      await WaterService.addWaterLogForDate(
        date: noon,
        amountMl: goal - 200,
        beverage: water,
        time: noon.subtract(const Duration(hours: 1)),
      );

      expect(nudgesNeeded(), 1,
          reason: '200 ml short needs one more nudge, not the full schedule');

      await WaterService.addWaterLogForDate(
        date: noon,
        amountMl: 400,
        beverage: water,
        time: noon,
      );
      expect(nudgesNeeded(), 0, reason: 'goal met — stop nagging entirely');
    });
  });
}
