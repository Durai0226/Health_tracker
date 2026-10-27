/// Today's hour-by-hour chance of rain, for the Steps screen's "looks dry" tip.
///
/// It rides on the weather opt-in and the place the person already gave for the
/// water goal: nothing new is asked for, and nothing is fetched without them.
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/features/water/services/hydration_weather_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 8, 21, 12);

  /// A day of [p]% everywhere, with [over] (hour → percent) overriding it.
  List<num?> day({num? p = 0, Map<int, num?> over = const {}}) =>
      [for (var h = 0; h < 24; h++) over.containsKey(h) ? over[h] : p];

  Map<String, dynamic> response(List<num?> hourly) => {
        'hourly': {
          'time': [for (var h = 0; h < hourly.length; h++) '2026-08-21T${h.toString().padLeft(2, '0')}:00'],
          'precipitation_probability': hourly,
        },
      };

  final requests = <Uri>[];
  Future<Map<String, dynamic>?> Function(Uri)? previous;

  setUp(() {
    requests.clear();
    previous = HydrationWeatherService.fetchForTesting;
    SharedPreferences.setMockInitialValues({
      'hydration_weather_enabled': true,
      'hydration_weather_place': 'Chennai, Tamil Nadu, India',
      'hydration_weather_lat': 13.0827,
      'hydration_weather_lon': 80.2707,
    });
  });

  tearDown(() => HydrationWeatherService.fetchForTesting = previous);

  void answer(Map<String, dynamic>? body) {
    HydrationWeatherService.fetchForTesting = (uri) async {
      requests.add(uri);
      return body;
    };
  }

  Future<RainForecast?> today({bool force = false, DateTime? at}) => withClock(
      Clock.fixed(at ?? now), () => HydrationWeatherService.rainForecastToday(force: force));

  test('asks for the hourly chance of rain, for one day, where they are', () async {
    answer(response(day()));
    await today();

    final q = requests.single;
    expect(q.host, 'api.open-meteo.com');
    expect(q.queryParameters['hourly'], 'precipitation_probability');
    expect(q.queryParameters['forecast_days'], '1');
    expect(q.queryParameters['timezone'], 'auto',
        reason: 'hour 14 must be 14:00 where they are, not in Greenwich');
    expect(q.queryParameters['latitude'], '13.0827');
    expect(q.queryParameters['longitude'], '80.2707');
  });

  test('twenty-four hours of percentages, and the place', () async {
    answer(response(day(over: {18: 70, 19: 85, 7: 10})));
    final f = (await today())!;
    expect(f.hourly, hasLength(24));
    expect(f.hourly[18], 70);
    expect(f.hourly[19], 85);
    expect(f.hourly[7], 10);
    expect(f.hourly[0], 0);
    expect(f.placeName, 'Chennai, Tamil Nadu, India');
  });

  test('an hour with no forecast is unknown, not zero', () async {
    answer(response(day(over: {15: null})));
    expect((await today())!.hourly[15], isNull,
        reason: 'unknown is neither dry nor wet: "looks dry" must not be said of it');
  });

  test('a percentage out of range is kept inside it', () async {
    answer(response(day(over: {10: 140, 11: -5})));
    final f = (await today())!;
    expect(f.hourly[10], 100);
    expect(f.hourly[11], 0);
  });

  test('doubles from JSON are whole percentages', () async {
    answer(response(day(over: {9: 42.6})));
    expect((await today())!.hourly[9], 43);
  });

  group('whether to ask at all', () {
    test('off by default: no request, no forecast — even with a place saved',
        () async {
      SharedPreferences.setMockInitialValues({
        'hydration_weather_place': 'Chennai, Tamil Nadu, India',
        'hydration_weather_lat': 13.0827,
        'hydration_weather_lon': 80.2707,
      });
      answer(response(day()));
      expect(await today(), isNull);
      expect(requests, isEmpty,
          reason: 'the opt-in is what makes a request acceptable');
    });

    test('switched off after being on: nothing, whatever is cached', () async {
      answer(response(day(over: {18: 80})));
      await today();
      await HydrationWeatherService.setEnabled(false);
      requests.clear();
      expect(await today(), isNull);
      expect(requests, isEmpty);
    });

    test('on but no place: nothing to ask about', () async {
      SharedPreferences.setMockInitialValues({'hydration_weather_enabled': true});
      answer(response(day()));
      expect(await today(), isNull);
      expect(requests, isEmpty);
    });
  });

  group('failing soft', () {
    test('no answer', () async {
      answer(null);
      expect(await today(), isNull);
    });

    test('an answer with no hourly part', () async {
      answer({'current': {'apparent_temperature': 30}});
      expect(await today(), isNull);
    });

    test('fewer than a day of hours', () async {
      answer(response(day().sublist(0, 12)));
      expect(await today(), isNull,
          reason: 'half a day would put the wrong hour on every percentage');
    });

    test('garbage values', () async {
      answer({
        'hourly': {'precipitation_probability': 'sunny'}
      });
      expect(await today(), isNull);
    });

    test('a request that throws is null, never an exception', () async {
      HydrationWeatherService.fetchForTesting = (_) async => throw Exception('offline');
      expect(await today(), isNull);
    });
  });

  group('the cache', () {
    test('a fresh forecast is served without another request', () async {
      answer(response(day(over: {18: 80})));
      await today();
      expect(requests, hasLength(1));

      final again = await today(at: now.add(const Duration(minutes: 90)));
      expect(requests, hasLength(1), reason: 'inside the TTL');
      expect(again!.hourly[18], 80);
    });

    test('a stale one is fetched again', () async {
      answer(response(day(over: {18: 80})));
      await today();
      answer(response(day(over: {18: 5})));

      final again = await today(at: now.add(HydrationWeatherService.rainCacheTtl +
          const Duration(minutes: 1)));
      expect(requests, hasLength(2));
      expect(again!.hourly[18], 5, reason: 'the forecast changed, and so does the tip');
    });

    test('yesterday\'s is never today\'s, however fresh', () async {
      answer(response(day(over: {18: 80})));
      await today(at: DateTime(2026, 8, 21, 23, 50));
      answer(response(day(over: {18: 5})));

      final next = await today(at: DateTime(2026, 8, 22, 0, 10));
      expect(requests, hasLength(2),
          reason: '20 minutes old, but of another day: hour 18 is a different 18:00');
      expect(next!.hourly[18], 5);
    });

    test('force goes to the network anyway', () async {
      answer(response(day()));
      await today();
      await today(force: true);
      expect(requests, hasLength(2));
    });

    test('a failed fetch falls back to nothing, not to the stale copy', () async {
      answer(response(day(over: {18: 80})));
      await today();
      answer(null);
      final later = await today(
          at: now.add(HydrationWeatherService.rainCacheTtl + const Duration(minutes: 5)));
      expect(later, isNull,
          reason: 'rain that was forecast hours ago is not a reason to say anything now');
    });

    test('the cache is stored as one day of numbers', () async {
      answer(response(day(over: {18: 80})));
      await today();
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('hydration_weather_rain_json');
      expect(raw, isNotNull);
      expect(jsonDecode(raw!) as List, hasLength(24));
    });
  });
}
