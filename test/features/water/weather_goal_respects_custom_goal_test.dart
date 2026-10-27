import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/services/hydration_weather_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// "Adjust for the weather" raises the day's goal with the feels-like
/// temperature. It applied that to everybody — including users who had typed
/// their own daily target.
///
/// Someone told by a clinician to aim for 2000 ml, who also had the weather
/// toggle on, opened the app on a hot afternoon and found the day re-stamped at
/// ~3800 ml, their dial back near the start and their streak gone. Nothing said
/// why, and the profile screen still read 2000. A custom goal is an explicit
/// override; the weather does not get to overwrite it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  /// A fresh reading in the cache, so `HydrationWeatherService.current()`
  /// answers from disk and never touches the network.
  Future<void> seedWeather(double apparentC, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hydration_weather_enabled', true);
    await prefs.setString('hydration_weather_place', 'Chennai, India');
    await prefs.setDouble('hydration_weather_lat', 13.0827);
    await prefs.setDouble('hydration_weather_lon', 80.2707);
    await prefs.setDouble('hydration_weather_temp_c', apparentC);
    await prefs.setInt('hydration_weather_at', now.millisecondsSinceEpoch);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  final now = DateTime(2026, 8, 29, 15, 0);

  test('a custom goal survives a hot day', () async {
    final profile = HydrationProfile(
      id: 'profile',
      weightKg: 70,
      customGoalMl: 2000,
      useCustomGoal: true,
      createdAt: now,
    );
    // The test only means something if the weather WOULD have moved the goal.
    expect(profile.goalBreakdown(ambientC: 38).totalMl, isNot(2000));

    await withClock(Clock.fixed(now), () async {
      await seedWeather(38, now);
      await WaterService.saveProfile(profile);
      expect(WaterService.getDataForDate(now)!.dailyGoalMl, 2000);

      await WaterService.refreshWeatherGoal();

      expect(WaterService.getDataForDate(now)!.dailyGoalMl, 2000,
          reason: 'the number the user typed outranks the temperature');
      expect(WaterService.getDailyGoal(), 2000);
    });
  });

  test('without a custom goal the weather still applies', () async {
    final profile = HydrationProfile(
      id: 'profile',
      weightKg: 70,
      createdAt: now,
    );
    final hotGoal = profile.goalBreakdown(ambientC: 38).totalMl;

    await withClock(Clock.fixed(now), () async {
      await seedWeather(38, now);
      await WaterService.saveProfile(profile);
      // Saving the profile keeps the hot-day adjustment from the cached
      // reading. It used to stamp the bare profile goal here and wait for the
      // next refresh to put the weather back.
      expect(WaterService.getDataForDate(now)!.dailyGoalMl, hotGoal);

      await WaterService.refreshWeatherGoal();

      expect(WaterService.getDataForDate(now)!.dailyGoalMl, hotGoal,
          reason: 'the guard must not swallow the case the feature exists for');
      expect(hotGoal, isNot(profile.effectiveGoalMl));
    });
  });

  test('the goal is judged against today\'s forecast HIGH, not the morning '
      'reading', () async {
    final profile = HydrationProfile(
      id: 'profile',
      weightKg: 70,
      createdAt: now,
    );
    final coolGoal = profile.goalBreakdown(ambientC: 22).totalMl;
    final hotGoal = profile.goalBreakdown(ambientC: 38).totalMl;
    expect(hotGoal, greaterThan(coolGoal),
        reason: 'the test only means something if 38 asks for more than 22');

    final morning = DateTime(2026, 8, 29, 7, 30);
    await withClock(Clock.fixed(morning), () async {
      // It is 22 degrees at half past seven. The cache is empty, so the request
      // is made — and it says the day will reach 38.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hydration_weather_enabled', true);
      await prefs.setString('hydration_weather_place', 'Chennai, India');
      await prefs.setDouble('hydration_weather_lat', 13.0827);
      await prefs.setDouble('hydration_weather_lon', 80.2707);
      HydrationWeatherService.fetchForTesting = (_) async => {
            'current': {'apparent_temperature': 22.0},
            'daily': {'apparent_temperature_max': [38.0]},
          };
      addTearDown(() => HydrationWeatherService.fetchForTesting = null);

      await WaterService.saveProfile(profile);
      await WaterService.refreshWeatherGoal();

      expect(WaterService.getDataForDate(morning)!.dailyGoalMl, hotGoal,
          reason: 'the afternoon is coming: the morning goal already says so');
    });
  });

  test('and with no forecast it is the temperature right now, as before',
      () async {
    final profile = HydrationProfile(id: 'profile', weightKg: 70, createdAt: now);
    final coolGoal = profile.goalBreakdown(ambientC: 22).totalMl;
    final morning = DateTime(2026, 8, 29, 7, 30);
    await withClock(Clock.fixed(morning), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hydration_weather_enabled', true);
      await prefs.setString('hydration_weather_place', 'Chennai, India');
      await prefs.setDouble('hydration_weather_lat', 13.0827);
      await prefs.setDouble('hydration_weather_lon', 80.2707);
      HydrationWeatherService.fetchForTesting =
          (_) async => {'current': {'apparent_temperature': 22.0}};
      addTearDown(() => HydrationWeatherService.fetchForTesting = null);

      await WaterService.saveProfile(profile);
      await WaterService.refreshWeatherGoal();
      expect(WaterService.getDataForDate(morning)!.dailyGoalMl, coolGoal);
    });
  });

  test('a prescribed ceiling is never weather-adjusted', () async {
    final profile = HydrationProfile(
      id: 'profile',
      weightKg: 70,
      fluidCeilingMl: 1500,
      createdAt: now,
    );
    await withClock(Clock.fixed(now), () async {
      await seedWeather(38, now);
      await WaterService.saveProfile(profile);
      await WaterService.refreshWeatherGoal();
      expect(WaterService.getDataForDate(now)!.dailyGoalMl, 1500);
    });
  });
}
