import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// Phase 5's gate: sharing vitals with Health Connect/HealthKit is opt-in,
/// best-effort, and must NEVER block or fail the local save — the plugin has
/// no platform channel registered in headless `flutter test`, which is
/// exactly the failure this contract has to survive gracefully (see
/// HealthDataService's per-write try/catch).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  BloodPressureReading bp(String id) => BloodPressureReading(
        id: id,
        systolic: 120,
        diastolic: 80,
        takenAt: DateTime(2026, 1, 1, 8),
        createdAt: DateTime(2026, 1, 1, 8),
      );

  GlucoseReading glucose(String id) => GlucoseReading(
        id: id,
        valueMgdl: 95,
        takenAt: DateTime(2026, 1, 1, 8),
        createdAt: DateTime(2026, 1, 1, 8),
      );

  WeightReading weight(String id) => WeightReading(
        id: id,
        valueKg: 70,
        takenAt: DateTime(2026, 1, 1, 8),
        createdAt: DateTime(2026, 1, 1, 8),
      );

  // Synthetic stand-in for a sample `getHealthDataFromTypes` would return —
  // the real plugin has no platform channel in `flutter test`, so
  // `importFromHealthConnect`'s `samples` param is the injection seam that
  // lets these tests exercise the persist+dedupe half without it.
  HealthDataPoint weightPoint(DateTime at, double kg) => HealthDataPoint(
        uuid: 'hc-uuid-${at.millisecondsSinceEpoch}',
        value: NumericHealthValue(numericValue: kg),
        type: HealthDataType.WEIGHT,
        unit: HealthDataUnit.KILOGRAM,
        dateFrom: at,
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'test-device',
        sourceId: 'test-source',
        sourceName: 'Test Smart Scale',
      );

  group('sync preference', () {
    test('defaults to off', () async {
      expect(await VitalsStorageService.isHealthConnectSyncEnabled(), false);
    });

    test('round-trips through SharedPreferences', () async {
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      expect(await VitalsStorageService.isHealthConnectSyncEnabled(), true);
      await VitalsStorageService.setHealthConnectSyncEnabled(false);
      expect(await VitalsStorageService.isHealthConnectSyncEnabled(), false);
    });
  });

  group('saveBp / saveGlucose never block or fail the local save', () {
    test('sync disabled (default): reading still saves locally', () async {
      await VitalsStorageService.saveBp(bp('bp1'), stampActiveProfile: false);
      final all = await VitalsStorageService.getAllBp(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), contains('bp1'));
    });

    test('sync enabled, plugin unavailable headless: local save still succeeds',
        () async {
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      await VitalsStorageService.saveBp(bp('bp2'), stampActiveProfile: false);
      final all = await VitalsStorageService.getAllBp(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), contains('bp2'));
    });

    test('glucose: sync enabled, plugin unavailable headless: local save still succeeds',
        () async {
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      await VitalsStorageService.saveGlucose(glucose('gl1'),
          stampActiveProfile: false);
      final all =
          await VitalsStorageService.getAllGlucose(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), contains('gl1'));
    });

    test('weight: sync enabled, plugin unavailable headless: local save still succeeds',
        () async {
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      await VitalsStorageService.saveWeight(weight('wt1'),
          stampActiveProfile: false);
      final all =
          await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), contains('wt1'));
    });

    test('syncToHealthConnect: false (import path) still saves locally even with sync on',
        () async {
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      await VitalsStorageService.saveBp(bp('bp3'),
          stampActiveProfile: false, syncToHealthConnect: false);
      final all = await VitalsStorageService.getAllBp(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), contains('bp3'));
    });
  });

  group('deleteBp / deleteGlucose preserve the synced flag (regression)', () {
    // A prior fix cleared the per-id synced flag on delete (to stop it
    // accumulating forever). That reopened a worse bug: the delete-
    // confirmation SnackBar's Undo action re-saves the SAME id, which -- with
    // the flag cleared -- passed the "already synced" check on the very next
    // save and pushed a brand-new, duplicate write to Health Connect/HealthKit
    // for data that was already there (the plugin can't update/delete a prior
    // write, so the original was never actually removed by a local delete
    // either way). The flag must survive delete so Undo doesn't re-sync.
    test('deleteBp does not clear an existing synced flag', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('health_connect_synced_bp-synced', true);
      await VitalsStorageService.saveBp(bp('bp-synced'),
          stampActiveProfile: false, syncToHealthConnect: false);

      await VitalsStorageService.deleteBp('bp-synced');

      expect(prefs.getBool('health_connect_synced_bp-synced'), true);
    });

    test('deleteGlucose does not clear an existing synced flag', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('health_connect_synced_gl-synced', true);
      await VitalsStorageService.saveGlucose(glucose('gl-synced'),
          stampActiveProfile: false, syncToHealthConnect: false);

      await VitalsStorageService.deleteGlucose('gl-synced');

      expect(prefs.getBool('health_connect_synced_gl-synced'), true);
    });

    test('deleteWeight does not clear an existing synced flag', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('health_connect_synced_wt-synced', true);
      await VitalsStorageService.saveWeight(weight('wt-synced'),
          stampActiveProfile: false, syncToHealthConnect: false);

      await VitalsStorageService.deleteWeight('wt-synced');

      expect(prefs.getBool('health_connect_synced_wt-synced'), true);
    });
  });

  group('importJson restores vitals without attempting a sync storm', () {
    test('restoring a backup with sync enabled does not throw', () async {
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      await VitalsStorageService.importJson({
        'bloodPressure': [bp('restored-bp').toJson()],
        'glucose': [glucose('restored-gl').toJson()],
        'weight': [weight('restored-wt').toJson()],
      });
      final bps = await VitalsStorageService.getAllBp(scopeToActiveProfile: false);
      final gls =
          await VitalsStorageService.getAllGlucose(scopeToActiveProfile: false);
      final wts =
          await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(bps.map((r) => r.id), contains('restored-bp'));
      expect(gls.map((r) => r.id), contains('restored-gl'));
      expect(wts.map((r) => r.id), contains('restored-wt'));
    });
  });

  group('VitalsStorageService.importFromHealthConnect (weight, read-direction)', () {
    test('importing synthetic samples creates the right number of new readings '
        'with correct values', () async {
      final t1 = DateTime(2026, 3, 1, 7);
      final t2 = DateTime(2026, 3, 2, 7);
      final count = await VitalsStorageService.importFromHealthConnect(
        samples: [weightPoint(t1, 71.5), weightPoint(t2, 72.0)],
      );

      expect(count, 2);
      final all = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(all, hasLength(2));
      expect(all.map((r) => r.valueKg), containsAll([71.5, 72.0]));
      expect(all.map((r) => r.takenAt), containsAll([t1, t2]));
      // Deterministic id derived from the sample's own timestamp.
      expect(
          all.map((r) => r.id),
          containsAll([
            'hc_import_${t1.millisecondsSinceEpoch}',
            'hc_import_${t2.millisecondsSinceEpoch}',
          ]));
    });

    test('importing the SAME samples twice does not create duplicates '
        '(idempotency)', () async {
      final t1 = DateTime(2026, 3, 1, 7);
      final samples = [weightPoint(t1, 71.5)];

      final first = await VitalsStorageService.importFromHealthConnect(samples: samples);
      final second = await VitalsStorageService.importFromHealthConnect(samples: samples);

      expect(first, 1);
      expect(second, 0); // already imported: nothing new
      final all = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(all, hasLength(1));
      expect(all.first.valueKg, 71.5);
    });

    test('a partial re-import only counts genuinely new samples', () async {
      final t1 = DateTime(2026, 3, 1, 7);
      final t2 = DateTime(2026, 3, 2, 7);
      await VitalsStorageService.importFromHealthConnect(samples: [weightPoint(t1, 71.5)]);

      final second = await VitalsStorageService.importFromHealthConnect(
        samples: [weightPoint(t1, 71.5), weightPoint(t2, 72.0)],
      );

      expect(second, 1); // only t2 is new
      final all = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(all, hasLength(2));
    });

    test('imported readings never sync back to Health Connect, even with '
        'write-sync enabled', () async {
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      final t1 = DateTime(2026, 3, 1, 7);

      // Must not throw despite the plugin having no platform channel here,
      // and must not mark the imported id as "synced" (that flag belongs to
      // the write direction only).
      await VitalsStorageService.importFromHealthConnect(
          samples: [weightPoint(t1, 71.5)]);

      final id = 'hc_import_${t1.millisecondsSinceEpoch}';
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('health_connect_synced_$id'), isNull);
      final all = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), contains(id));
    });

    test('an empty sample list imports nothing and returns 0', () async {
      final count = await VitalsStorageService.importFromHealthConnect(samples: const []);
      expect(count, 0);
      final all = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(all, isEmpty);
    });
  });
}
