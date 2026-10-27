import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/features/water/services/hydration_weather_service.dart';

/// Hydro Coach shipped weather-driven goals as its flagship 2026 feature, and it
/// is the input our losses-based model wants most — the ACSM sweat coefficient
/// is a function of ambient temperature.
///
/// The notable design choice is what is NOT here: no `geolocator`, no coarse
/// location permission, nothing to declare under Location in the Play
/// data-safety form. The user names their city once.
///
/// `TestWidgetsFlutterBinding` installs an `HttpOverrides` that answers every
/// request with **400**, deliberately, so tests cannot reach the network. The
/// "Open-Meteo returned 400" lines in this suite's output are that mock, not a
/// broken query — the live endpoints were verified separately and answer these
/// exact parameters:
///
///   GET geocoding-api.open-meteo.com/v1/search?name=Chennai&count=1&language=en&format=json
///     -> results[0] = {name: Chennai, latitude: 13.08784, longitude: 80.27847,
///                      admin1: Tamil Nadu, country: India}
///   GET api.open-meteo.com/v1/forecast?latitude=13.0827&longitude=80.2707
///       &current=apparent_temperature&timezone=auto
///     -> current = {time: ..., apparent_temperature: 33.1}
///
/// So what these tests pin is the half that has to be right when the network is
/// not there: the opt-in gate, the cache and its TTL, and failing soft rather
/// than throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('off by default', () async {
    expect(await HydrationWeatherService.isEnabled(), isFalse);
  });

  test('disabled means no reading even with a cached value', () async {
    SharedPreferences.setMockInitialValues({
      'hydration_weather_temp_c': 31.0,
      'hydration_weather_place': 'Chennai',
    });
    expect(await HydrationWeatherService.cachedApparentC(), isNull,
        reason: 'the opt-in gate must come before the cache');
    expect(await HydrationWeatherService.current(), isNull);
  });

  test('enabled with no place set yields nothing', () async {
    await HydrationWeatherService.setEnabled(true);
    expect(await HydrationWeatherService.current(), isNull,
        reason: 'no coordinates means nothing to ask about');
  });

  test('a fresh cached reading is served without a network call', () async {
    final now = DateTime(2026, 8, 21, 12);
    SharedPreferences.setMockInitialValues({
      'hydration_weather_enabled': true,
      'hydration_weather_place': 'Chennai, Tamil Nadu, India',
      'hydration_weather_lat': 13.0827,
      'hydration_weather_lon': 80.2707,
      'hydration_weather_temp_c': 34.5,
      'hydration_weather_at':
          now.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch,
    });

    final w = await withClock(
        Clock.fixed(now), () => HydrationWeatherService.current());

    expect(w, isNotNull, reason: 'no network is needed inside the TTL');
    expect(w!.apparentC, 34.5);
    expect(w.placeName, 'Chennai, Tamil Nadu, India');
  });

  test('a stale reading is not served from cache', () async {
    final now = DateTime(2026, 8, 21, 12);
    SharedPreferences.setMockInitialValues({
      'hydration_weather_enabled': true,
      'hydration_weather_place': 'Chennai',
      'hydration_weather_lat': 13.0827,
      'hydration_weather_lon': 80.2707,
      'hydration_weather_temp_c': 34.5,
      'hydration_weather_at':
          now.subtract(const Duration(hours: 9)).millisecondsSinceEpoch,
    });

    // Past the TTL it tries the network, which is unavailable here — and must
    // return null rather than throwing.
    final w = await withClock(
        Clock.fixed(now), () => HydrationWeatherService.current());
    expect(w, isNull);
  });

  test('cachedApparentC ignores the TTL on purpose', () async {
    final now = DateTime(2026, 8, 21, 12);
    SharedPreferences.setMockInitialValues({
      'hydration_weather_enabled': true,
      'hydration_weather_temp_c': 29.0,
      'hydration_weather_at':
          now.subtract(const Duration(hours: 20)).millisecondsSinceEpoch,
    });
    // A stale temperature is still a far better input to the sweat model than
    // falling back to a dropdown the user last touched in March.
    expect(await HydrationWeatherService.cachedApparentC(), 29.0);
  });

  test('an empty place query is rejected without a network call', () async {
    expect(await HydrationWeatherService.setPlace('   '), isNull);
  });

  test('a lookup failure is null, never an exception', () async {
    // No network in the suite; this must fail soft.
    expect(await HydrationWeatherService.setPlace('Chennai'), isNull);
  });

  forecastTests();

  test('the CC BY 4.0 attribution is present', () {
    // Open-Meteo's licence requires it, and it is rendered next to the toggle.
    expect(HydrationWeatherService.attribution.toLowerCase(),
        contains('open-meteo'));
    expect(HydrationWeatherService.attribution, contains('CC BY 4.0'));
  });
}

/// The hot-day goal reads today's FORECAST HIGH, not only the temperature at the
/// moment of the request: a goal set at 7 am was cool for a day that reached 36
/// degrees by three.
///
/// The network is answered by `fetchForTesting`, so what is pinned here is what
/// is asked for, how the answer is read, and what the goal is judged against.
void forecastTests() {
  group('the forecast high', () {
    final now = DateTime(2026, 8, 21, 7, 30);

    Map<String, Object> prefs({
      double? cachedTemp,
      double? cachedForecast,
      String? forecastDay,
      Duration age = const Duration(minutes: 30),
    }) =>
        {
          'hydration_weather_enabled': true,
          'hydration_weather_place': 'Chennai',
          'hydration_weather_lat': 13.0827,
          'hydration_weather_lon': 80.2707,
          if (cachedTemp != null) 'hydration_weather_temp_c': cachedTemp,
          if (cachedTemp != null)
            'hydration_weather_at': now.subtract(age).millisecondsSinceEpoch,
          if (cachedForecast != null)
            'hydration_weather_forecast_max_c': cachedForecast,
          if (forecastDay != null) 'hydration_weather_forecast_day': forecastDay,
        };

    Map<String, dynamic> answer({double? current = 24.0, Object? max = 36.5}) => {
          if (current != null) 'current': {'apparent_temperature': current},
          if (max != null) 'daily': {'apparent_temperature_max': [max]},
        };

    tearDown(() => HydrationWeatherService.fetchForTesting = null);

    test('asks for today\'s high as well as the current temperature', () async {
      SharedPreferences.setMockInitialValues(prefs());
      Uri? asked;
      HydrationWeatherService.fetchForTesting = (uri) async {
        asked = uri;
        return answer();
      };
      await withClock(Clock.fixed(now), () => HydrationWeatherService.current());

      expect(asked!.queryParameters['current'], 'apparent_temperature');
      expect(asked!.queryParameters['daily'], 'apparent_temperature_max');
      expect(asked!.queryParameters['forecast_days'], '1');
    });

    test('reads both, and judges the goal by the hotter', () async {
      SharedPreferences.setMockInitialValues(prefs());
      HydrationWeatherService.fetchForTesting = (_) async => answer();
      final w = (await withClock(
          Clock.fixed(now), () => HydrationWeatherService.current()))!;
      expect(w.apparentC, 24.0);
      expect(w.forecastMaxC, 36.5);
      expect(w.goalC, 36.5);
    });

    test('a forecast cooler than now is not used: it is already hotter than '
        'that', () async {
      SharedPreferences.setMockInitialValues(prefs());
      HydrationWeatherService.fetchForTesting =
          (_) async => answer(current: 33.0, max: 30.0);
      final w = (await withClock(
          Clock.fixed(now), () => HydrationWeatherService.current()))!;
      expect(w.goalC, 33.0);
    });

    test('no forecast in the answer: the current temperature, as before',
        () async {
      SharedPreferences.setMockInitialValues(prefs());
      HydrationWeatherService.fetchForTesting = (_) async => answer(max: null);
      final w = (await withClock(
          Clock.fixed(now), () => HydrationWeatherService.current()))!;
      expect(w.forecastMaxC, isNull);
      expect(w.goalC, 24.0);
    });

    test('an unbelievable forecast is ignored', () async {
      SharedPreferences.setMockInitialValues(prefs());
      HydrationWeatherService.fetchForTesting = (_) async => answer(max: 400);
      final w = (await withClock(
          Clock.fixed(now), () => HydrationWeatherService.current()))!;
      expect(w.forecastMaxC, isNull);
    });

    test('a fresh cache carries the forecast with it, from today', () async {
      SharedPreferences.setMockInitialValues(prefs(
          cachedTemp: 25.0, cachedForecast: 35.0, forecastDay: '2026-08-21'));
      HydrationWeatherService.fetchForTesting =
          (_) async => fail('inside the TTL: no request');
      final w = (await withClock(
          Clock.fixed(now), () => HydrationWeatherService.current()))!;
      expect(w.forecastMaxC, 35.0);
      expect(w.goalC, 35.0);
    });

    test('and never yesterday\'s high', () async {
      SharedPreferences.setMockInitialValues(prefs(
          cachedTemp: 25.0, cachedForecast: 41.0, forecastDay: '2026-08-20'));
      final w = (await withClock(
          Clock.fixed(now), () => HydrationWeatherService.current()))!;
      expect(w.forecastMaxC, isNull);
      expect(w.goalC, 25.0);
    });

    test('the synchronous read gets it too, only when it is today\'s', () async {
      SharedPreferences.setMockInitialValues(prefs(
          cachedTemp: 25.0, cachedForecast: 35.0, forecastDay: '2026-08-21'));
      expect(
          await withClock(
              Clock.fixed(now), () => HydrationWeatherService.cachedApparentC()),
          35.0);

      SharedPreferences.setMockInitialValues(prefs(
          cachedTemp: 25.0, cachedForecast: 35.0, forecastDay: '2026-08-20'));
      expect(
          await withClock(
              Clock.fixed(now), () => HydrationWeatherService.cachedApparentC()),
          25.0);
    });

    test('a request that returns no forecast clears a stale one', () async {
      SharedPreferences.setMockInitialValues(prefs(
          cachedTemp: 25.0,
          cachedForecast: 35.0,
          forecastDay: '2026-08-21',
          age: const Duration(hours: 5)));
      HydrationWeatherService.fetchForTesting = (_) async => answer(max: null);
      await withClock(Clock.fixed(now), () => HydrationWeatherService.current());
      expect(await withClock(
              Clock.fixed(now), () => HydrationWeatherService.cachedApparentC()),
          24.0);
    });
  });
}
