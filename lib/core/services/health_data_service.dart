import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/medication/models/blood_pressure_reading.dart';
import '../../features/medication/models/glucose_reading.dart';
import '../../features/medication/models/weight_reading.dart';

/// Availability of device health data, so callers can fall back to manual entry.
///
/// * [available]        — reads are permitted right now.
/// * [notDetermined]    — we can ask; the user hasn't decided yet.
/// * [denied]           — we asked and were refused (or access was revoked).
/// * [unavailable]      — no provider on this device (Simulator, no Health
///                        Connect, unsupported platform).
/// * [needsProviderUpdate] — Android only: Health Connect is present but must be
///                        installed/updated from the Play Store first.
enum HealthAvailability {
  available,
  unavailable,
  notDetermined,
  denied,
  needsProviderUpdate,
}

/// Thin, all-static-ish, never-throws wrapper over Apple HealthKit /
/// Android Health Connect (`package:health`) + the live step sensor
/// (`package:pedometer`).
///
/// Every read returns data-or-empty; failures are swallowed (logged) so the
/// Steps/Sleep features degrade gracefully to manual entry — which is also the
/// only path available on the iOS Simulator.
///
/// ## Why the type lists are per-platform
///
/// `package:health` exposes one `HealthDataType` enum but each platform only
/// implements a subset (`dataTypeKeysIOS` / `dataTypeKeysAndroid`), and the
/// plugin fails **hard and silently** on a type the running platform doesn't
/// know:
///
/// * Android: `hasPermissions` / `requestAuthorization` bail out with
///   `success(false)` on the FIRST unmapped type — the Health Connect consent
///   sheet is never even shown. `DISTANCE_WALKING_RUNNING` (Android wants
///   `DISTANCE_DELTA`) and `SLEEP_IN_BED` (iOS-only) both do this, which is why
///   granting access used to leave the "Enable" card up forever.
/// * iOS: `SLEEP_SESSION` is Android-only; the Swift side silently falls back to
///   *body mass*, so we'd be asking for the wrong scope.
/// * Reads: `getHealthDataFromTypes` throws `HealthException` for a type that
///   isn't available on the platform, and it throws from inside the loop — so a
///   single bad type discards every segment already collected (all sleep data).
///
/// So: build the request per platform, and read one type at a time so a future
/// plugin gap degrades to "that metric is missing" instead of "nothing works".
class HealthDataService {
  HealthDataService._();
  static final HealthDataService instance = HealthDataService._();

  final Health _health = Health();
  bool _configured = false;

  // ---- platform-correct data types ----------------------------------------
  //
  // The per-platform lists are named statics (not just branches inside the
  // getters) so a test can assert BOTH against `package:health`'s own
  // `dataTypeKeysAndroid` / `dataTypeKeysIOS` — see
  // test/features/health_data_types_test.dart. Checking only the running
  // platform is what let the Android list rot unnoticed.

  /// Cumulative distance. Health Connect models it as a delta record; HealthKit
  /// as walking+running distance.
  static const HealthDataType distanceTypeAndroid =
      HealthDataType.DISTANCE_DELTA;
  static const HealthDataType distanceTypeIOS =
      HealthDataType.DISTANCE_WALKING_RUNNING;

  static HealthDataType get distanceType =>
      Platform.isAndroid ? distanceTypeAndroid : distanceTypeIOS;

  /// Sleep stage types.
  ///
  /// On Android every entry maps to the same `SleepSessionRecord` (a single
  /// `READ_SLEEP` permission); `SLEEP_SESSION` returns the whole night, which the
  /// SleepService uses only as a fallback when no stages exist. `SLEEP_IN_BED` is
  /// HealthKit-only and `SLEEP_SESSION` Health-Connect-only — swapping either
  /// across platforms is what silently broke sleep import.
  static const List<HealthDataType> sleepTypesAndroid = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_SESSION,
  ];

  static const List<HealthDataType> sleepTypesIOS = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_IN_BED,
  ];

  static List<HealthDataType> get sleepTypes =>
      Platform.isAndroid ? sleepTypesAndroid : sleepTypesIOS;

  /// The types the features genuinely need. Without these there is nothing to
  /// sync, so a grant that misses them counts as "not connected".
  static List<HealthDataType> essentialTypesFor(bool android) => [
        HealthDataType.STEPS,
        ...(android ? sleepTypesAndroid : sleepTypesIOS),
      ];

  /// Nice-to-have metrics: we derive both from the profile when absent, so a
  /// user who refuses them still gets working steps + sleep.
  static List<HealthDataType> optionalTypesFor(bool android) => [
        android ? distanceTypeAndroid : distanceTypeIOS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];

  /// Everything we ask for, in one consent sheet.
  static List<HealthDataType> readTypesFor(bool android) => [
        ...essentialTypesFor(android),
        ...optionalTypesFor(android),
      ];

  static List<HealthDataType> get essentialTypes =>
      essentialTypesFor(Platform.isAndroid);
  static List<HealthDataType> get optionalTypes =>
      optionalTypesFor(Platform.isAndroid);
  static List<HealthDataType> get readTypes => readTypesFor(Platform.isAndroid);

  static List<HealthDataAccess> _readAccessFor(List<HealthDataType> types) =>
      types.map((_) => HealthDataAccess.READ).toList();

  // ---- wearable biometrics (READ-ONLY) --------------------------------------
  //
  // A THIRD tier, deliberately NOT folded into [readTypesFor].
  //
  // Health Connect is all-or-nothing per request and throttles re-prompting, so
  // adding eight scopes to the first-run steps+sleep sheet would make the whole
  // grant likelier to be refused — breaking the two features that already work
  // — and would burn the user's limited re-prompt budget. It also collides with
  // `requestPermissions`' fallback, which retries with `essentialTypes` only.
  // Play's minimum-permission rule points the same way: ask when the user opens
  // the feature, not at first launch.
  //
  // This app never WRITES any of these.

  /// HealthKit exposes HRV as SDNN; Health Connect exposes RMSSD. Neither
  /// platform has the other's type, and they are different statistics over
  /// different ranges — see [HrvMetric]. Getting this backwards is the
  /// `DISTANCE_WALKING_RUNNING` bug again.
  static const HealthDataType hrvTypeAndroid =
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD;
  static const HealthDataType hrvTypeIOS =
      HealthDataType.HEART_RATE_VARIABILITY_SDNN;

  static HealthDataType get hrvType =>
      Platform.isAndroid ? hrvTypeAndroid : hrvTypeIOS;

  /// Android reports a DELTA from the wearer's baseline; Apple's sleeping wrist
  /// temperature is ABSOLUTE °C. Same non-comparability problem as HRV.
  ///
  /// Both types arrived in `health` 13.x — neither existed in 11.1.1.
  static const HealthDataType skinTempTypeAndroid =
      HealthDataType.SKIN_TEMPERATURE;
  static const HealthDataType skinTempTypeIOS =
      HealthDataType.SLEEP_WRIST_TEMPERATURE;

  static HealthDataType get skinTempType =>
      Platform.isAndroid ? skinTempTypeAndroid : skinTempTypeIOS;

  /// Everything the biometrics feature reads, in one separate consent sheet.
  ///
  /// VO2 max is deliberately absent: `package:health` 13.3.2 declares no
  /// VO2MAX type on either platform, even though HealthKit and Health Connect
  /// both store one. `health_data_types_test.dart` fails when that changes.
  static List<HealthDataType> biometricTypesFor(bool android) => [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        android ? hrvTypeAndroid : hrvTypeIOS,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.RESPIRATORY_RATE,
        HealthDataType.BODY_TEMPERATURE,
        android ? skinTempTypeAndroid : skinTempTypeIOS,
        HealthDataType.WORKOUT,
      ];

  static List<HealthDataType> get biometricTypes =>
      biometricTypesFor(Platform.isAndroid);

  /// Every type the app can ever read — for the conformance tests, which assert
  /// both platform lists against the plugin's own `dataTypeKeys*`.
  static List<HealthDataType> allReadTypesFor(bool android) => [
        ...readTypesFor(android),
        ...biometricTypesFor(android),
      ];

  static const String _biometricsPrefKey = 'health_biometrics_connected';
  bool? _biometricsCache;

  /// Whether the biometric read scope is granted.
  ///
  /// Android answers truthfully. iOS never discloses READ authorization, so
  /// [hasPermissions] returns null there and we fall back to the persisted
  /// flag — the same split [availability] already makes for the base grant.
  Future<bool> hasBiometricPermission() async {
    try {
      await _ensureConfigured();
      final types = biometricTypes;
      final has = await _health.hasPermissions(types,
          permissions: _readAccessFor(types));
      if (has != null) return has;
      _biometricsCache ??= await _readFlag(_biometricsPrefKey);
      return _biometricsCache ?? false;
    } catch (e) {
      debugPrint('HealthDataService.hasBiometricPermission failed: $e');
      return false;
    }
  }

  /// Ask for the biometric read scope. Call this from the biometrics screens,
  /// never at first launch — see the tier note above.
  ///
  /// Skin temperature is dropped from the request when the installed Health
  /// Connect is too old to know the type: an unsupported type makes Android
  /// bail with `success(false)` before the sheet is even shown, which would
  /// take the other seven scopes down with it.
  Future<bool> requestBiometricPermission() async {
    try {
      await _ensureConfigured();
      final types = List<HealthDataType>.from(biometricTypes);
      if (!await isSkinTemperatureSupported()) {
        types.remove(skinTempType);
      }
      final granted = await _health.requestAuthorization(types,
          permissions: _readAccessFor(types));
      // iOS returns true whenever the sheet closed without error, so re-check
      // where the platform will actually tell us.
      final ok = granted == true;
      await _setBiometricsFlag(ok);
      return ok;
    } catch (e) {
      debugPrint('HealthDataService.requestBiometricPermission failed: $e');
      return false;
    }
  }

  /// Health Connect feature-gates `SkinTemperatureRecord`; older installs do
  /// not have it. Always false on iOS-with-no-support and on any throw.
  Future<bool> isSkinTemperatureSupported() async {
    try {
      await _ensureConfigured();
      return await _health.isSkinTemperatureAvailable();
    } catch (e) {
      debugPrint('HealthDataService.isSkinTemperatureSupported failed: $e');
      return false;
    }
  }

  Future<void> _setBiometricsFlag(bool value) async {
    _biometricsCache = value;
    await _writeFlag(_biometricsPrefKey, value);
  }

  /// Raw samples of ONE biometric type. One type per call by design — see
  /// [_readPoints].
  Future<List<HealthDataPoint>> readBiometricSamples(
      HealthDataType type, DateTime from, DateTime to) async {
    try {
      await _ensureConfigured();
      return await _readPoints([type], from, to);
    } catch (e) {
      debugPrint('HealthDataService.readBiometricSamples(${type.name}) '
          'failed: $e');
      return [];
    }
  }

  /// Exercise sessions in [from]..[to]. Each point's value is a
  /// [WorkoutHealthValue]; heart rate is NOT included and must be intersected
  /// from the same day's HR samples.
  Future<List<HealthDataPoint>> readWorkouts(DateTime from, DateTime to) async {
    try {
      await _ensureConfigured();
      return await _readPoints([HealthDataType.WORKOUT], from, to);
    } catch (e) {
      debugPrint('HealthDataService.readWorkouts failed: $e');
      return [];
    }
  }

  // ---- vitals write (BP / glucose / weight) ---------------------------------
  //
  // Opt-in and, for BP/glucose, one-directional: this app never reads BP or
  // glucose back from Health Connect/HealthKit, it only offers to publish
  // what the user already logged locally. `writeBloodPressure`/
  // `BLOOD_GLUCOSE`/`WEIGHT` are identical types on both platforms (unlike
  // sleep/distance above), so no per-platform split is needed here. Mood has
  // no native record type on either platform, so it is never written.
  //
  // Weight is the one exception to "one-directional": [readWeightSamples]
  // below is a separate, explicit, user-triggered pull (see
  // VitalsStorageService.importFromHealthConnect) that lets a reading logged
  // by a smart scale or another app — never touching this app's write path —
  // flow into the local Weight tracker. It reuses this same READ_WRITE grant
  // rather than requesting a standalone read scope.
  //
  // Duplicate-write avoidance is handled at the Dart level by the caller (see
  // VitalsStorageService's per-id synced flag), NOT by the platform.
  //
  // Since v13 the plugin does expose `clientRecordId`/`clientRecordVersion` on
  // the write path plus `deleteByUUID`, `deleteByClientRecordId` and `delete()`
  // — the older "the plugin cannot upsert or delete" claim is no longer true.
  // The Dart flag is kept anyway, deliberately, for two reasons:
  //   1. clientRecordId is a Health Connect concept. The iOS/darwin side of the
  //      plugin ignores the argument entirely, so it cannot be the sole
  //      dedup mechanism for a cross-platform app.
  //   2. Records this app already wrote carry no clientRecordId, and ownership
  //      cannot be claimed retroactively — so a migration would have to treat
  //      every pre-existing write as unowned regardless.
  // Revisiting this is a named follow-up, not a limitation.
  static const List<HealthDataType> vitalsWriteTypes = [
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.WEIGHT,
  ];

  static List<HealthDataAccess> _readWriteAccessFor(
          List<HealthDataType> types) =>
      types.map((_) => HealthDataAccess.READ_WRITE).toList();

  /// Whether the vitals write scope is currently granted.
  ///
  /// Checked with [HealthDataAccess.WRITE], NOT `READ_WRITE` — on iOS,
  /// HealthKit only discloses status for a plain READ or WRITE query;
  /// `READ_WRITE` falls into the same undisclosed branch as READ and always
  /// returns null (i.e. "not granted"), even right after a real grant.
  Future<bool> hasVitalsWritePermission() async {
    try {
      await _ensureConfigured();
      final has = await _health.hasPermissions(vitalsWriteTypes,
          permissions:
              vitalsWriteTypes.map((_) => HealthDataAccess.WRITE).toList());
      return has == true;
    } catch (e) {
      debugPrint('HealthDataService.hasVitalsWritePermission failed: $e');
      return false;
    }
  }

  /// Ask for the vitals write scope. `package:health` has no write-only
  /// request — requesting WRITE always requests READ alongside it.
  Future<bool> requestVitalsWritePermission() async {
    try {
      await _ensureConfigured();
      final granted = await _health.requestAuthorization(vitalsWriteTypes,
          permissions: _readWriteAccessFor(vitalsWriteTypes));
      return granted == true;
    } catch (e) {
      debugPrint('HealthDataService.requestVitalsWritePermission failed: $e');
      return false;
    }
  }

  /// Writes systolic+diastolic as ONE combined record — Health Connect models
  /// blood pressure that way, and the plugin refuses to write either number
  /// alone. Only the numbers and the time are written: the plugin exposes no
  /// parameter for [BloodPressureReading.arm]/[position].
  Future<bool> writeBloodPressure(BloodPressureReading reading) async {
    try {
      await _ensureConfigured();
      return await _health.writeBloodPressure(
        systolic: reading.systolic,
        diastolic: reading.diastolic,
        startTime: reading.takenAt,
        recordingMethod: RecordingMethod.manual,
      );
    } catch (e) {
      debugPrint('HealthDataService.writeBloodPressure failed: $e');
      return false;
    }
  }

  /// Writes the glucose value + time. The plugin exposes no parameter for
  /// [GlucoseReading.context] (fasting/pre/post-meal) — there is no dedicated
  /// glucose writer, only the generic [Health.writeHealthData] call.
  Future<bool> writeGlucose(GlucoseReading reading) async {
    try {
      await _ensureConfigured();
      return await _health.writeHealthData(
        value: reading.valueMgdl.toDouble(),
        type: HealthDataType.BLOOD_GLUCOSE,
        unit: HealthDataUnit.MILLIGRAM_PER_DECILITER,
        startTime: reading.takenAt,
        recordingMethod: RecordingMethod.manual,
      );
    } catch (e) {
      debugPrint('HealthDataService.writeGlucose failed: $e');
      return false;
    }
  }

  /// Writes body weight in kilograms — [WeightReading.valueKg] is already the
  /// canonical unit, so no conversion is needed here.
  Future<bool> writeWeight(WeightReading reading) async {
    try {
      await _ensureConfigured();
      return await _health.writeHealthData(
        value: reading.valueKg,
        type: HealthDataType.WEIGHT,
        unit: HealthDataUnit.KILOGRAM,
        startTime: reading.takenAt,
        recordingMethod: RecordingMethod.manual,
      );
    } catch (e) {
      debugPrint('HealthDataService.writeWeight failed: $e');
      return false;
    }
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
    } catch (e) {
      debugPrint('HealthDataService.configure failed: $e');
    }
  }

  /// Whether health data can be read right now.
  ///
  /// Android (Health Connect) *does* disclose read-permission status, so it is
  /// the source of truth there — that way a user who revokes access in the
  /// Health Connect app is detected instead of being stuck "connected". iOS
  /// HealthKit never discloses READ authorization (`hasPermissions` returns null
  /// by design), so there we fall back to the persisted "user completed the
  /// connect flow" flag.
  Future<HealthAvailability> availability() async {
    try {
      await _ensureConfigured();

      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        // Health Connect ships with Android 14+ and is a Play Store app below
        // that. minSdk is 26 and Health Connect supports 26+, so "not available"
        // here almost always means "not installed / too old" — which the user can
        // fix. Report it as actionable rather than as a dead end (the manual
        // logging path stays available either way).
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          debugPrint('HealthDataService: Health Connect status $status');
          return HealthAvailability.needsProviderUpdate;
        }
        // Health Connect reports real grant state — trust it over any flag.
        if (await _hasEssentialPermissions()) {
          await _setConnected(true);
          return HealthAvailability.available;
        }
        await _setConnected(false);
        return await _wasAsked()
            ? HealthAvailability.denied
            : HealthAvailability.notDetermined;
      }

      if (!Platform.isIOS) return HealthAvailability.unavailable;

      // iOS: read status is undisclosable, so the connect flag is our signal.
      if (await _isConnected()) return HealthAvailability.available;
      if (await _hasEssentialPermissions()) return HealthAvailability.available;
      return await _wasAsked()
          ? HealthAvailability.denied
          : HealthAvailability.notDetermined;
    } catch (e) {
      debugPrint('HealthDataService.availability failed: $e');
      return HealthAvailability.unavailable;
    }
  }

  /// True when the types we actually need are granted. Never throws; a null
  /// answer (iOS read scopes) is treated as "unknown", i.e. not a grant.
  Future<bool> _hasEssentialPermissions() async {
    try {
      final types = essentialTypes;
      final has =
          await _health.hasPermissions(types, permissions: _readAccessFor(types));
      return has == true;
    } catch (e) {
      debugPrint('HealthDataService.hasPermissions failed: $e');
      return false;
    }
  }

  /// Request read permissions (+ Android activity-recognition for the pedometer).
  ///
  /// Asks for everything in one sheet, then falls back to the essential types
  /// alone if the full set wasn't granted — Health Connect is all-or-nothing per
  /// request, so a user who allowed steps + sleep but not calories/distance would
  /// otherwise be told "not granted" and left with the Enable card up.
  Future<bool> requestPermissions() async {
    try {
      await _ensureConfigured();
      await _setAsked(true);

      if (Platform.isAndroid) {
        // Live pedometer needs the runtime activity-recognition permission; it is
        // independent of Health Connect and must not gate the health grant.
        await Permission.activityRecognition.request();

        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          debugPrint('HealthDataService: Health Connect status $status');
          return false;
        }
      }

      if (await _hasEssentialPermissions()) {
        await _setConnected(true);
        return true;
      }

      final all = readTypes;
      var granted = await _health.requestAuthorization(all,
          permissions: _readAccessFor(all));

      // `requestAuthorization` reports false when *any* requested scope was
      // refused, so on Android ask Health Connect what actually stuck before
      // concluding anything — steps + sleep may well have been allowed while
      // calories/distance weren't. Doing this BEFORE any retry matters: Health
      // Connect throttles an app that re-prompts, so a redundant second sheet
      // can burn the user's remaining attempts.
      if (!granted && Platform.isAndroid) {
        granted = await _hasEssentialPermissions();
      }

      if (!granted) {
        // Still nothing: ask once more for the essentials alone, which is a
        // smaller, easier-to-accept request than the full set.
        final core = essentialTypes;
        granted = await _health.requestAuthorization(core,
            permissions: _readAccessFor(core));
        if (!granted && Platform.isAndroid) {
          granted = await _hasEssentialPermissions();
        }
      }

      await _setConnected(granted);
      return granted;
    } catch (e) {
      debugPrint('HealthDataService.requestPermissions failed: $e');
      return false;
    }
  }

  /// Send the user to the Play Store to install / update Health Connect.
  Future<void> installHealthConnect() async {
    if (!Platform.isAndroid) return;
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('HealthDataService.installHealthConnect failed: $e');
    }
  }

  // --- Persisted connect / asked flags -----------------------------------------
  // HealthKit read-status is undisclosable on iOS, so we remember that the user
  // completed the connect flow. `asked` lets us tell "never asked" (offer
  // Enable) from "asked and refused" (offer Try again / Settings).
  static const String _connectedPrefKey = 'health_connected';
  static const String _askedPrefKey = 'health_permission_asked';
  bool? _connectedCache;
  bool? _askedCache;

  Future<bool> _isConnected() async {
    if (_connectedCache != null) return _connectedCache!;
    _connectedCache = await _readFlag(_connectedPrefKey);
    return _connectedCache!;
  }

  Future<void> _setConnected(bool value) async {
    if (_connectedCache == value) return;
    _connectedCache = value;
    await _writeFlag(_connectedPrefKey, value);
  }

  Future<bool> _wasAsked() async {
    if (_askedCache != null) return _askedCache!;
    _askedCache = await _readFlag(_askedPrefKey);
    return _askedCache!;
  }

  Future<void> _setAsked(bool value) async {
    if (_askedCache == value) return;
    _askedCache = value;
    await _writeFlag(_askedPrefKey, value);
  }

  Future<bool> _readFlag(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeFlag(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Non-fatal: the in-memory cache still reflects this session.
    }
  }

  /// Forget the connect flag (used by "disconnect" / full data wipe).
  Future<void> resetConnected() async {
    await _setConnected(false);
    await _setAsked(false);
  }

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
      _sumNumeric([HealthDataType.ACTIVE_ENERGY_BURNED], from, to);

  Future<double?> readDistanceMeters(DateTime from, DateTime to) =>
      _sumNumeric([distanceType], from, to);

  Future<double?> _sumNumeric(
      List<HealthDataType> types, DateTime from, DateTime to) async {
    try {
      await _ensureConfigured();
      final pts = await _readPoints(types, from, to);
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
      return await _readPoints(sleepTypes, from, to);
    } catch (e) {
      debugPrint('HealthDataService.readSleepSegments failed: $e');
      return [];
    }
  }

  /// Raw weight samples in [from]..[to] — the read-direction counterpart to
  /// [writeWeight], for pulling in readings a user already logged via a smart
  /// scale or another app (see VitalsStorageService.importFromHealthConnect).
  /// Each point's value is a [NumericHealthValue] in kilograms (`WEIGHT`'s
  /// fixed unit on both platforms), matching [WeightReading.valueKg]'s
  /// canonical unit exactly — no conversion needed.
  Future<List<HealthDataPoint>> readWeightSamples(
      DateTime from, DateTime to) async {
    try {
      await _ensureConfigured();
      return await _readPoints([HealthDataType.WEIGHT], from, to);
    } catch (e) {
      debugPrint('HealthDataService.readWeightSamples failed: $e');
      return [];
    }
  }

  /// Read [types] one at a time so an unsupported / unavailable type degrades to
  /// a missing metric instead of throwing away every point already collected
  /// (`getHealthDataFromTypes` throws from inside its own loop).
  Future<List<HealthDataPoint>> _readPoints(
      List<HealthDataType> types, DateTime from, DateTime to) async {
    final out = <HealthDataPoint>[];
    for (final type in types) {
      try {
        out.addAll(await _health.getHealthDataFromTypes(
            startTime: from, endTime: to, types: [type]));
      } catch (e) {
        debugPrint('HealthDataService: read ${type.name} failed: $e');
      }
    }
    return out;
  }

  /// Live cumulative step stream (since device boot) while the app is open.
  Stream<StepCount> get stepCountStream => Pedometer.stepCountStream;
  Stream<PedestrianStatus> get pedestrianStatusStream =>
      Pedometer.pedestrianStatusStream;
}
