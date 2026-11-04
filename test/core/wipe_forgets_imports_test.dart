/// "Delete all data" forgets what the imports from the health store remember.
///
/// Their switches, the point where the last read ended and every sample id they
/// had seen live in SharedPreferences, not in the table the wipe clears — so they
/// outlived it. The ids did the damage: a sample the import has seen is skipped,
/// and after a wipe that meant everything the health store still held was skipped
/// too. A person who deleted their data and switched the import back on got none
/// of it. The switches are consent, and a wipe is the moment to ask again.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/daily_check_in.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_health_import.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/water/services/hydration_health_sync.dart';
import 'package:tablet_remainder/features/water/services/water_health_import.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 9, 30, 12);
  final ten = DateTime(2026, 9, 30, 10, 15);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    HydrationHealthSync.resetForTesting();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => db.close());

  HealthDataPoint point(HealthDataType type, DateTime at, num value, {String source = 'com.omron.connect'}) =>
      HealthDataPoint(
        uuid: '$type-${at.millisecondsSinceEpoch}-$source',
        value: NumericHealthValue(numericValue: value),
        type: type,
        unit: type == HealthDataType.WATER ? HealthDataUnit.LITER : HealthDataUnit.NO_UNIT,
        dateFrom: at.subtract(const Duration(minutes: 1)),
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: source,
        sourceName: 'Health Connect',
        recordingMethod: RecordingMethod.automatic,
      );

  test('their keys are gone, and nothing else in SharedPreferences is', () async {
    SharedPreferences.setMockInitialValues({
      'water_health_import_enabled': true,
      'water_health_import_last_run_ms': 123,
      'water_health_import_seen_ids': ['hc_water_a'],
      'vitals_health_import_enabled': true,
      'vitals_health_import_last_run_ms': 456,
      'vitals_health_import_seen_ids': ['hc_bp_1'],
      'some_other_key': 'stays',
    });

    await CleanStorageService.clearAllPersistentData();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'some_other_key'});
  });

  test('so the switches are off, and a second sign-up is a fresh one', () async {
    await WaterHealthImport.setEnabled(true);
    await VitalsHealthImport.setEnabled(true);

    await CleanStorageService.clearAllPersistentData();

    expect(await WaterHealthImport.isEnabled(), isFalse);
    expect(await VitalsHealthImport.isEnabled(), isFalse);
  });

  test('and what the health store still holds comes back when it is switched on again',
      () async {
    final drink = point(HealthDataType.WATER, ten, 0.25, source: 'com.sec.android.app.shealth');
    await WaterHealthImport.run(now: now, samples: [drink]);
    expect(
        (await WaterService.loadDataForDate(DateTime(2026, 9, 30)))?.logs.length, 1,
        reason: 'the premise: it came in once');

    await CleanStorageService.clearAllPersistentData();
    final again = await WaterHealthImport.run(now: now, samples: [drink]);

    expect(again.count, 1,
        reason: 'the id it had seen was forgotten with the data it described');
  });

  test('the vitals import the same', () async {
    final cuff = [
      point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, ten, 128),
      point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, ten, 82),
    ];
    final first = await VitalsHealthImport.run(
        now: now, bpSamples: cuff, glucoseSamples: const []);
    expect(first.bloodPressure, hasLength(1), reason: 'the premise');

    await CleanStorageService.clearAllPersistentData();
    final again = await VitalsHealthImport.run(
        now: now, bpSamples: cuff, glucoseSamples: const []);

    expect(again.bloodPressure, hasLength(1));
    expect(await VitalsStorageService.getAllBp(scopeToActiveProfile: false), hasLength(1));
  });

  test('the daily check-in is not left switched on for the next start', () async {
    await CleanStorageService.setAppPreference(DailyCheckIn.enabledKey, true);

    await CleanStorageService.clearAllPersistentData();

    expect(CleanStorageService.getAppPreference(DailyCheckIn.enabledKey), isNot(true));
  });
}
