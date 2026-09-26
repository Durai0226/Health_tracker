import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/hydration_goal.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// The over-hydration guardrail measures the last hour's intake against the
/// renal ceiling (~800–1000 ml/h), which is how exercise-associated
/// hyponatremia is avoided.
///
/// It only ever read TODAY's logs. So for the first hour after midnight the
/// window it needs to measure lies mostly in yesterday's row and the guard saw
/// nothing: a litre downed at 23:55 raised no warning at 00:05 — the one moment
/// it was most needed — and someone who kept drinking got told they were fine.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  BeverageType water() =>
      BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');

  Future<void> log(DateTime at, int ml) => WaterService.addWaterLogForDate(
        date: at,
        amountMl: ml,
        beverage: water(),
        time: at,
      );

  test('a window straddling midnight counts yesterday half', () async {
    // 23:40 and 23:55 last night, then a check at 00:15.
    await log(DateTime(2026, 8, 28, 23, 40), 600);
    await log(DateTime(2026, 8, 28, 23, 55), 500);
    final now = DateTime(2026, 8, 29, 0, 15);

    expect(WaterService.intakeInLastHourMl(now: now), 1100);
    expect(WaterService.isDrinkingTooFast(now: now), isTrue,
        reason: '1.1 L in 35 minutes is past the renal ceiling of '
            '${HydrationGoalCalculator.safeHourlyCeilingMl} ml/h, and midnight '
            'landing in the middle of it changes nothing physiologically');
  });

  test('both halves are summed, not just the older one', () async {
    await log(DateTime(2026, 8, 28, 23, 50), 500);
    await log(DateTime(2026, 8, 29, 0, 10), 500);
    expect(
        WaterService.intakeInLastHourMl(now: DateTime(2026, 8, 29, 0, 20)),
        1000);
  });

  test('yesterday drinks OUTSIDE the window are still ignored', () async {
    // 22:00 is 2h15 before the check — the guard must not start reporting a
    // whole extra day of intake as "the last hour".
    await log(DateTime(2026, 8, 28, 22, 0), 900);
    final now = DateTime(2026, 8, 29, 0, 15);

    expect(WaterService.intakeInLastHourMl(now: now), 0);
    expect(WaterService.isDrinkingTooFast(now: now), isFalse,
        reason: 'a guard that over-fires on last night\'s water is a guard '
            'people turn off');
  });

  test('a window inside one day is unchanged', () async {
    await withClock(Clock.fixed(DateTime(2026, 8, 29, 14, 0)), () async {
      await log(DateTime(2026, 8, 29, 13, 30), 300);
      await log(DateTime(2026, 8, 29, 11, 0), 900);
      expect(WaterService.intakeInLastHourMl(), 300);
      expect(WaterService.isDrinkingTooFast(), isFalse);
    });
  });
}
