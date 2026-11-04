/// A reading that came from the health store is never sent back to it.
///
/// The import saves with the share-out off, but an EDIT of an imported reading — a
/// tag, a corrected pulse — is a save like any other and used the default, which is
/// on. The reading had never been marked as sent, so it went out again under this
/// app's own name, and every other app that reads the store counted it twice. The
/// import's origin filter and `HealthSampleOrigin` exist to prevent exactly that.
library;

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/health_sample_origin.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/services/vitals_health_import.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late List<String> calls;
  final at = DateTime(2026, 9, 30, 8, 3);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    HealthDataService.instance.configuredForTesting = true;
    calls = [];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_health'), (call) async {
      calls.add(call.method);
      return true;
    });
    await VitalsStorageService.setHealthConnectSyncEnabled(true);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_health'), null);
    HealthDataService.instance.configuredForTesting = false;
    await db.close();
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 100));

  List<String> writes() => calls.where((c) => c.toLowerCase().contains('write')).toList();

  group('what came from the store', () {
    test('a blood pressure reading, edited, is not written back', () async {
      final id = VitalsHealthImport.idFor('bp', at, 'com.omron.connect');
      await VitalsStorageService.saveBp(
          BloodPressureReading(id: id, systolic: 128, diastolic: 82, takenAt: at, createdAt: at),
          stampActiveProfile: false);
      await settle();

      expect(writes(), isEmpty);
      expect((await SharedPreferences.getInstance()).getBool('health_connect_synced_$id'), isNull);
    });

    test('nor a blood sugar', () async {
      final id = VitalsHealthImport.idFor('gl', at, 'com.glucose.meter');
      await VitalsStorageService.saveGlucose(
          GlucoseReading(id: id, valueMgdl: 104, takenAt: at, createdAt: at),
          stampActiveProfile: false);
      await settle();

      expect(writes(), isEmpty);
    });

    test('nor a weight', () async {
      await VitalsStorageService.saveWeight(
          WeightReading(id: '${HealthSampleOrigin.weightIdPrefix}1', valueKg: 70, takenAt: at, createdAt: at),
          stampActiveProfile: false);
      await settle();

      expect(writes(), isEmpty);
    });
  });

  group('what was typed in here', () {
    // The premise of the above: with the plugin answering "yes" to everything and
    // the share-out on, a reading typed in IS sent. Without this the tests above
    // would pass on a plugin that could not be written to at all.
    test('a blood pressure reading is still sent out', () async {
      await VitalsStorageService.saveBp(
          BloodPressureReading(id: 'typed-1', systolic: 118, diastolic: 76, takenAt: at, createdAt: at),
          stampActiveProfile: false);
      await settle();

      expect(writes(), isNotEmpty);
    });

    test('so is a blood sugar, and a weight', () async {
      await VitalsStorageService.saveGlucose(
          GlucoseReading(id: 'typed-2', valueMgdl: 95, takenAt: at, createdAt: at),
          stampActiveProfile: false);
      await VitalsStorageService.saveWeight(
          WeightReading(id: 'typed-3', valueKg: 71.2, takenAt: at, createdAt: at),
          stampActiveProfile: false);
      await settle();

      expect(writes().length, 2);
    });
  });

  group('which ids say "from the store"', () {
    test('the ones the imports really build', () {
      expect(HealthSampleOrigin.cameFromTheStore(VitalsHealthImport.idFor('bp', at, 'a')), isTrue);
      expect(HealthSampleOrigin.cameFromTheStore(VitalsHealthImport.idFor('gl', at, 'a')), isTrue);
    });

    test('and the weight import\'s, which VitalsStorageService builds', () async {
      final reading = HealthDataPoint(
        uuid: 'w',
        value: NumericHealthValue(numericValue: 70.5),
        type: HealthDataType.WEIGHT,
        unit: HealthDataUnit.KILOGRAM,
        dateFrom: at,
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: 'com.withings.wiscale2',
        sourceName: 'Withings',
        recordingMethod: RecordingMethod.automatic,
      );
      await VitalsStorageService.importFromHealthConnect(samples: [reading]);

      final saved = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);

      expect(saved, hasLength(1));
      expect(HealthSampleOrigin.cameFromTheStore(saved.single.id), isTrue);
    });

    test('and the importer\'s own test for it agrees', () {
      expect(VitalsHealthImport.isImported(VitalsHealthImport.idFor('bp', at, 'a')), isTrue);
      expect(VitalsHealthImport.isImported(VitalsHealthImport.idFor('gl', at, 'a')), isTrue);
      expect(VitalsHealthImport.isImported('typed-1'), isFalse);
    });

    test('a typed-in reading\'s id is not mistaken for one', () {
      for (final id in ['typed-1', 'bp1', '3f2a-uuid', 'hc', 'hc_', 'xhc_bp_1']) {
        expect(HealthSampleOrigin.cameFromTheStore(id), isFalse, reason: id);
      }
    });
  });
}
