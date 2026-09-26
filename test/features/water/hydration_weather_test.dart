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

  test('the CC BY 4.0 attribution is present', () {
    // Open-Meteo's licence requires it, and it is rendered next to the toggle.
    expect(HydrationWeatherService.attribution.toLowerCase(),
        contains('open-meteo'));
    expect(HydrationWeatherService.attribution, contains('CC BY 4.0'));
  });
}
