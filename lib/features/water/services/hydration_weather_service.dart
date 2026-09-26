import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A cached "feels like" temperature, used to scale the day's hydration target.
class HydrationWeather {
  /// Apparent (feels-like) temperature in Celsius.
  final double apparentC;

  /// The place this was fetched for, as the user will recognise it.
  final String placeName;

  final DateTime fetchedAt;

  const HydrationWeather({
    required this.apparentC,
    required this.placeName,
    required this.fetchedAt,
  });
}

/// Opt-in weather input for the hydration goal.
///
/// Hydro Coach shipped "Auto-Weather" as its flagship 2026 feature — the daily
/// goal rising with the temperature — and it is the one input our
/// losses-based model wants most, because the ACSM sweat coefficient is a
/// function of ambient temperature.
///
/// ## Why there is no location permission
///
/// The obvious build is `geolocator` + a coarse-location permission. This does
/// not do that. The user names their city once, it is geocoded once, and the
/// coordinates are stored locally. That means:
///
///   * no location permission is requested, so nothing to disclose in the Play
///     data-safety form under Location, and nothing to explain to a reviewer;
///   * no background position access, ever;
///   * the only thing that leaves the device is a place name the user typed and
///     a pair of coordinates — no identifier, no account, no health data.
///
/// A hydration app asking for your location is a worse trade than typing
/// "Chennai" once.
///
/// Open-Meteo needs no API key for non-commercial use, is CC BY 4.0 (attribution
/// is rendered next to the toggle), and its free tier allows 10,000 calls a day
/// against our one call every few hours.
///
/// Everything here fails soft: no network, a rejected response, a garbage
/// payload, all end up as null, and the goal calculator falls back to the
/// manually chosen climate band.
class HydrationWeatherService {
  HydrationWeatherService._();

  static const _enabledKey = 'hydration_weather_enabled';
  static const _latKey = 'hydration_weather_lat';
  static const _lonKey = 'hydration_weather_lon';
  static const _placeKey = 'hydration_weather_place';
  static const _cachedTempKey = 'hydration_weather_temp_c';
  static const _cachedAtKey = 'hydration_weather_at';

  /// How long a reading stays good. Ambient temperature does not move fast
  /// enough to justify hammering a free API — and the goal is a daily number.
  static const Duration cacheTtl = Duration(hours: 3);

  static const _geocodeHost = 'geocoding-api.open-meteo.com';
  static const _forecastHost = 'api.open-meteo.com';

  /// Attribution required by Open-Meteo's CC BY 4.0 licence.
  static const String attribution = 'Weather data by Open-Meteo.com (CC BY 4.0)';

  static Future<bool> isEnabled() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_enabledKey, v);
  }

  static Future<String?> savedPlaceName() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_placeKey);
    } catch (_) {
      return null;
    }
  }

  /// Resolve a typed place name to coordinates and remember them.
  ///
  /// Returns the resolved display name, or null when nothing matched — the
  /// caller shows that as "we couldn't find that place", never as an error.
  static Future<String?> setPlace(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    try {
      final body = await _getJson(Uri.https(_geocodeHost, '/v1/search', {
        'name': q,
        'count': '1',
        'language': 'en',
        'format': 'json',
      }));
      final results = body?['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final lat = (first['latitude'] as num?)?.toDouble();
      final lon = (first['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final name = [
        first['name'],
        first['admin1'],
        first['country'],
      ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

      final p = await SharedPreferences.getInstance();
      await p.setDouble(_latKey, lat);
      await p.setDouble(_lonKey, lon);
      await p.setString(_placeKey, name);
      // A new place invalidates the cached reading.
      await p.remove(_cachedTempKey);
      await p.remove(_cachedAtKey);
      return name;
    } catch (e) {
      debugPrint('HydrationWeatherService.setPlace failed: $e');
      return null;
    }
  }

  /// Current feels-like temperature, from cache when it is still fresh.
  ///
  /// Null whenever the feature is off, no place is set, or anything at all goes
  /// wrong — the goal then uses the manual climate band, exactly as before.
  static Future<HydrationWeather?> current({bool force = false}) async {
    try {
      if (!await isEnabled()) return null;
      final p = await SharedPreferences.getInstance();
      final place = p.getString(_placeKey);
      final lat = p.getDouble(_latKey);
      final lon = p.getDouble(_lonKey);
      if (place == null || lat == null || lon == null) return null;

      final cachedAt = p.getInt(_cachedAtKey);
      final cachedTemp = p.getDouble(_cachedTempKey);
      if (!force && cachedAt != null && cachedTemp != null) {
        final at = DateTime.fromMillisecondsSinceEpoch(cachedAt);
        if (clock.now().difference(at) < cacheTtl) {
          return HydrationWeather(
              apparentC: cachedTemp, placeName: place, fetchedAt: at);
        }
      }

      final body = await _getJson(Uri.https(_forecastHost, '/v1/forecast', {
        'latitude': lat.toStringAsFixed(4),
        'longitude': lon.toStringAsFixed(4),
        // Feels-like, not raw air temperature: humidity and wind change the
        // evaporative load, which is what actually drives sweat.
        'current': 'apparent_temperature',
        'timezone': 'auto',
      }));
      final temp =
          (body?['current']?['apparent_temperature'] as num?)?.toDouble();
      if (temp == null || temp < -90 || temp > 70) return null;

      final now = clock.now();
      await p.setDouble(_cachedTempKey, temp);
      await p.setInt(_cachedAtKey, now.millisecondsSinceEpoch);
      return HydrationWeather(
          apparentC: temp, placeName: place, fetchedAt: now);
    } catch (e) {
      debugPrint('HydrationWeatherService.current failed: $e');
      return null;
    }
  }

  /// Whatever reading is already cached, without touching the network.
  ///
  /// Lets a synchronous goal read still benefit from weather. Ignores the TTL
  /// on purpose: a three-hour-old temperature is a far better input than
  /// falling back to a dropdown the user set once in March.
  static Future<double?> cachedApparentC() async {
    try {
      if (!await isEnabled()) return null;
      final p = await SharedPreferences.getInstance();
      return p.getDouble(_cachedTempKey);
    } catch (_) {
      return null;
    }
  }

  /// One small GET, decoded. `dart:io` rather than `package:http` because http
  /// is only a transitive dependency here and this needs nothing http adds.
  static Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        debugPrint('Open-Meteo returned ${res.statusCode} for ${uri.host}');
        return null;
      }
      final text = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } finally {
      client.close(force: true);
    }
  }
}
