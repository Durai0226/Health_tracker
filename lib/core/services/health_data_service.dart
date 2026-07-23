import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Availability of device health data, so callers can fall back to manual entry.
enum HealthAvailability { available, unavailable, notDetermined, denied }

/// Thin, all-static-ish, never-throws wrapper over Apple HealthKit /
/// Android Health Connect (`package:health`) + the live step sensor
/// (`package:pedometer`).
///
/// Every read returns data-or-empty; failures are swallowed (logged) so the
/// Steps/Sleep features degrade gracefully to manual entry — which is also the
/// only path available on the iOS Simulator (no pedometer, no real HealthKit).
class HealthDataService {
  HealthDataService._();
  static final HealthDataService instance = HealthDataService._();

  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> readTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_SESSION,
  ];

  static const List<HealthDataType> sleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_SESSION,
  ];

  List<HealthDataAccess> get _readAccess =>
      readTypes.map((_) => HealthDataAccess.READ).toList();

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
    } catch (e) {
      debugPrint('HealthDataService.configure failed: $e');
    }
  }

  /// Whether health data can be read (Android Health Connect present + perms).
  Future<HealthAvailability> availability() async {
    try {
      await _ensureConfigured();
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          return HealthAvailability.unavailable;
        }
      } else if (!Platform.isIOS) {
        return HealthAvailability.unavailable;
      }
      // Once the user has explicitly connected, treat health as available.
      // iOS HealthKit NEVER discloses READ-authorization status — hasPermissions()
      // returns null for read scopes by design — so gating solely on it would
      // leave the "Connect" card up forever and block every sync even after the
      // user granted access. The persisted connect flag (set in
      // requestPermissions) is our reliable cross-platform "connected" signal.
      if (await _isConnected()) return HealthAvailability.available;
      final has = await _health.hasPermissions(readTypes, permissions: _readAccess);
      if (has == true) return HealthAvailability.available;
      return HealthAvailability.notDetermined;
    } catch (e) {
      debugPrint('HealthDataService.availability failed: $e');
      return HealthAvailability.unavailable;
    }
  }

  /// Request read permissions (+ Android activity-recognition for the pedometer).
  /// On success, persists a "connected" flag so [availability] can report
  /// available even where the platform won't disclose read-permission status.
  Future<bool> requestPermissions() async {
    try {
      await _ensureConfigured();
      if (Platform.isAndroid) {
        await Permission.activityRecognition.request();
      }
      final has = await _health.hasPermissions(readTypes, permissions: _readAccess);
      if (has == true) {
        await _setConnected(true);
        return true;
      }
      final granted =
          await _health.requestAuthorization(readTypes, permissions: _readAccess);
      if (granted) await _setConnected(true);
      return granted;
    } catch (e) {
      debugPrint('HealthDataService.requestPermissions failed: $e');
      return false;
    }
  }

  // --- Persisted "user has connected health" flag ------------------------------
  // HealthKit read-status is undisclosable on iOS, so we remember that the user
  // completed the connect flow and thereafter attempt syncs / clear the card.
  static const String _connectedPrefKey = 'health_connected';
  bool? _connectedCache;

  Future<bool> _isConnected() async {
    if (_connectedCache != null) return _connectedCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _connectedCache = prefs.getBool(_connectedPrefKey) ?? false;
    } catch (_) {
      _connectedCache = false;
    }
    return _connectedCache!;
  }

  Future<void> _setConnected(bool value) async {
    _connectedCache = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_connectedPrefKey, value);
    } catch (_) {
      // Non-fatal: the in-memory cache still reflects this session.
    }
  }

  /// Forget the connect flag (used by "disconnect" / full data wipe).
  Future<void> resetConnected() => _setConnected(false);

  Future<int?> readTodaySteps() async {
    final now = DateTime.now();
    return readStepsForDay(now, end: now);
  }

  /// Total steps for [day] (midnight → [end] or next midnight).
  Future<int?> readStepsForDay(DateTime day, {DateTime? end}) async {
    try {
      await _ensureConfigured();
      final start = DateTime(day.year, day.month, day.day);
      final to = end ?? start.add(const Duration(days: 1));
      return await _health.getTotalStepsInInterval(start, to);
    } catch (e) {
      debugPrint('HealthDataService.readStepsForDay failed: $e');
      return null;
    }
  }

  /// 24 hourly step buckets for [day].
  Future<List<int>> readHourlySteps(DateTime day) async {
    final out = List<int>.filled(24, 0);
    try {
      await _ensureConfigured();
      final base = DateTime(day.year, day.month, day.day);
      for (var h = 0; h < 24; h++) {
        final s = base.add(Duration(hours: h));
        out[h] = (await _health.getTotalStepsInInterval(
                s, s.add(const Duration(hours: 1)))) ??
            0;
      }
    } catch (e) {
      debugPrint('HealthDataService.readHourlySteps failed: $e');
    }
    return out;
  }

  Future<double?> readActiveEnergy(DateTime from, DateTime to) =>
      _sumNumeric(const [HealthDataType.ACTIVE_ENERGY_BURNED], from, to);

  Future<double?> readDistanceMeters(DateTime from, DateTime to) =>
      _sumNumeric(const [HealthDataType.DISTANCE_WALKING_RUNNING], from, to);

  Future<double?> _sumNumeric(
      List<HealthDataType> types, DateTime from, DateTime to) async {
    try {
      await _ensureConfigured();
      final pts = await _health.getHealthDataFromTypes(
          startTime: from, endTime: to, types: types);
      if (pts.isEmpty) return null;
      double sum = 0;
      for (final p in pts) {
        final v = p.value;
        if (v is NumericHealthValue) sum += v.numericValue.toDouble();
      }
      return sum;
    } catch (e) {
      debugPrint('HealthDataService._sumNumeric failed: $e');
      return null;
    }
  }

  /// Raw sleep segments in [from]..[to]; the SleepService aggregates these into
  /// one session per night.
  Future<List<HealthDataPoint>> readSleepSegments(
      DateTime from, DateTime to) async {
    try {
      await _ensureConfigured();
      return await _health.getHealthDataFromTypes(
          startTime: from, endTime: to, types: sleepTypes);
    } catch (e) {
      debugPrint('HealthDataService.readSleepSegments failed: $e');
      return [];
    }
  }

  /// Live cumulative step stream (since device boot) while the app is open.
  Stream<StepCount> get stepCountStream => Pedometer.stepCountStream;
  Stream<PedestrianStatus> get pedestrianStatusStream =>
      Pedometer.pedestrianStatusStream;
}
