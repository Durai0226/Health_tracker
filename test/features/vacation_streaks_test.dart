import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/vacation_mode.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// Vacation mode freezes the water and steps streaks: nine days away do not
/// cost a ten-day streak, and without the vacation the same gap does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  // Ten completed days (1-10 March), then away 11-19 March, back on the 20th.
  final today = DateTime(2026, 3, 20, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => db.close());

  Future<void> awayEleventhToNineteenth() => VacationMode.start(
      until: DateTime(2026, 3, 19), now: DateTime(2026, 3, 11));

  group('steps', () {
    Future<void> tenGoodDays() async {
      for (var d = 1; d <= 10; d++) {
        // 30,000 clears any goal the app would set (it is capped at 15,000).
        await StepService.addManualStepsForDate(DateTime(2026, 3, d), 30000,
            maxDaysBack: 60);
      }
    }

    test('without a vacation the gap breaks the streak', () async {
      await withClock(Clock.fixed(today), () async {
        await tenGoodDays();
        expect(StepService.getStreakResult().current, lessThan(10));
      });
    });

    test('with the vacation the streak survives intact', () async {
      await withClock(Clock.fixed(today), () async {
        await tenGoodDays();
        await awayEleventhToNineteenth();
        expect(StepService.getStreakResult().current, 10);
      });
    });
  });

  group('water', () {
    final water = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');

    Future<void> tenGoodDays() async {
      for (var d = 1; d <= 10; d++) {
        final at = DateTime(2026, 3, d, 9);
        // Spread out so the "too fast" rule has nothing to say.
        for (var h = 0; h < 4; h++) {
          await WaterService.addWaterLogForDate(
              date: at,
              time: at.add(Duration(hours: h * 3)),
              amountMl: 1500,
              beverage: water);
        }
      }
    }

    test('without a vacation the gap breaks the streak', () async {
      await withClock(Clock.fixed(today), () async {
        await tenGoodDays();
        expect(WaterService.getStreakResult().current, lessThan(10));
      });
    });

    test('with the vacation the streak survives intact', () async {
      await withClock(Clock.fixed(today), () async {
        await tenGoodDays();
        await awayEleventhToNineteenth();
        expect(WaterService.getStreakResult().current, 10);
      });
    });
  });
}
