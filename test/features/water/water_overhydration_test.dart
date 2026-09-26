import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// The app had no concept of "too much".
///
/// Every surface — the gauge, the streak, the achievements, the coach copy —
/// assumed more water is always better, and the overachiever badge explicitly
/// rewarded exceeding the goal by 20%. But maximal renal free-water clearance
/// is only ~800-1000 mL/h, and drinking past it is the mechanism behind
/// exercise-associated hyponatremia. WaterMinder is the only app in the
/// category that warns; nobody else does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final noon = DateTime(2026, 8, 21, 12);

  Future<void> log(int ml, DateTime at) async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLogForDate(
        date: at, amountMl: ml, beverage: water, time: at);
  }

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await withClock(Clock.fixed(noon), () => WaterService.init());
  });

  tearDown(() async => database.close());

  test('a normal pace does not trigger the warning', () async {
    await withClock(Clock.fixed(noon), () async {
      await log(250, noon.subtract(const Duration(minutes: 50)));
      await log(250, noon.subtract(const Duration(minutes: 20)));
      expect(WaterService.intakeInLastHourMl(), 500);
      expect(WaterService.isDrinkingTooFast(), isFalse);
    });
  });

  test('past the renal ceiling in one hour does trigger it', () async {
    await withClock(Clock.fixed(noon), () async {
      await log(600, noon.subtract(const Duration(minutes: 40)));
      await log(600, noon.subtract(const Duration(minutes: 10)));
      expect(WaterService.intakeInLastHourMl(), 1200);
      expect(WaterService.isDrinkingTooFast(), isTrue);
    });
  });

  test('only the last hour counts — the window really slides', () async {
    await withClock(Clock.fixed(noon), () async {
      // Well over the ceiling across the day, but spread out.
      await log(900, noon.subtract(const Duration(hours: 5)));
      await log(900, noon.subtract(const Duration(hours: 3)));
      await log(250, noon.subtract(const Duration(minutes: 5)));

      expect(WaterService.intakeInLastHourMl(), 250,
          reason: 'a big drink three hours ago is not a current hazard');
      expect(WaterService.isDrinkingTooFast(), isFalse);
    });
  });

  test('the volume swallowed is what counts, not the adjusted figure', () async {
    await withClock(Clock.fixed(noon), () async {
      // Spirits carry a negative hydration coefficient, but the kidney still
      // has to clear the fluid that went down.
      final spirits = WaterService.getBeverage('spirits')!;
      await WaterService.addWaterLogForDate(
        date: noon,
        amountMl: 1100,
        beverage: spirits,
        time: noon.subtract(const Duration(minutes: 5)),
      );
      expect(WaterService.intakeInLastHourMl(), 1100);
      expect(WaterService.isDrinkingTooFast(), isTrue,
          reason: 'effective hydration is negative here, but the load is real');
    });
  });

  test('an empty day is not "too fast"', () async {
    await withClock(Clock.fixed(noon), () {
      expect(WaterService.intakeInLastHourMl(), 0);
      expect(WaterService.isDrinkingTooFast(), isFalse);
    });
  });
}
