/// A reading or a drink that was shared with Health Connect follows what is done to
/// it here.
///
/// Sharing was write-once: an edit left the old numbers in the store beside nothing,
/// and a delete (or an Undo of a drink) left the record there for every other app to
/// count. On Android the writes now carry a name (`clientRecordId`), so an edit
/// replaces its record and a delete removes it. Records written before the names
/// existed cannot be found again and are left alone — rewriting them would make a
/// second one — and on an iPhone the plugin ignores the name, so nothing changes.
///
/// What this cannot prove: that Health Connect honours the replace and the delete.
/// That is a device check in `docs/release-checklist.md`.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/health_record_ids.dart';
import 'package:tablet_remainder/core/health/health_sample_origin.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/services/vitals_health_import.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/services/hydration_health_sync.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late List<MethodCall> calls;
  var answer = true;
  final at = DateTime(2026, 9, 30, 8, 3);
  final t1 = DateTime(2026, 9, 30, 9, 0);
  final t2 = DateTime(2026, 9, 30, 9, 5);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    HydrationHealthSync.resetForTesting();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    HealthDataService.instance.configuredForTesting = true;
    calls = [];
    answer = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_health'), (call) async {
      calls.add(call);
      return answer;
    });
    await VitalsStorageService.setHealthConnectSyncEnabled(true);
    await HydrationHealthSync.setEnabled(true);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_health'), null);
    debugDefaultTargetPlatformOverride = null;
    HealthDataService.instance.configuredForTesting = false;
    await db.close();
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

  Map<String, dynamic> args(MethodCall c) =>
      Map<String, dynamic>.from(c.arguments as Map);

  List<MethodCall> writes() =>
      calls.where((c) => c.method == 'writeBloodPressure' || c.method == 'writeData').toList();
  List<MethodCall> deletes() =>
      calls.where((c) => c.method == 'deleteByClientRecordId').toList();

  Future<bool?> flag(String key) async =>
      (await SharedPreferences.getInstance()).getBool(key);

  BloodPressureReading bp(String id, {int sys = 120, DateTime? takenAt}) =>
      BloodPressureReading(
          id: id,
          systolic: sys,
          diastolic: 80,
          takenAt: takenAt ?? at,
          createdAt: at);
  GlucoseReading glucose(String id, {int v = 95}) =>
      GlucoseReading(id: id, valueMgdl: v, takenAt: at, createdAt: at);
  WeightReading weight(String id, {double kg = 70}) =>
      WeightReading(id: id, valueKg: kg, takenAt: at, createdAt: at);

  group('the names', () {
    test('are distinct per kind and per record', () {
      final ids = {
        HealthRecordIds.bloodPressure('1'),
        HealthRecordIds.glucose('1'),
        HealthRecordIds.weight('1'),
        HealthRecordIds.water('1'),
        HealthRecordIds.bloodPressure('2'),
      };
      expect(ids, hasLength(5));
    });

    test('only Android can replace and delete by name', () {
      expect(HealthRecordIds.supported(TargetPlatform.android), isTrue);
      expect(HealthRecordIds.supported(TargetPlatform.iOS), isFalse);
      expect(HealthRecordIds.supported(TargetPlatform.macOS), isFalse);
    });

    test('a later time is a higher version', () {
      expect(HealthRecordIds.version(t2), greaterThan(HealthRecordIds.version(t1)));
      expect(HealthRecordIds.version(t1), t1.millisecondsSinceEpoch.toDouble());
    });
  });

  group('the service', () {
    test('deletes by name on Android, with the type and the name', () async {
      expect(await HealthDataService.instance.deleteByClientId(HealthDataType.WEIGHT, 'n1'),
          isTrue);
      final d = args(deletes().single);
      expect((d['dataTypeKey'], d['clientRecordId']), ('WEIGHT', 'n1'));
    });

    test('and does nothing, calling nothing, anywhere else', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await HealthDataService.instance.deleteByClientId(HealthDataType.WEIGHT, 'n1'),
          isFalse);
      expect(deletes(), isEmpty);
    });

    test('a failing delete is a no, not a crash', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_health'),
              (call) async => throw PlatformException(code: 'x'));
      expect(await HealthDataService.instance.deleteByClientId(HealthDataType.WEIGHT, 'n1'),
          isFalse);
    });
  });

  group('blood pressure', () {
    test('is written under its name, with a version', () async {
      await withClock(Clock.fixed(t1), () async {
        await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
        await settle();
      });
      final w = args(writes().single);
      expect(w['clientRecordId'], HealthRecordIds.bloodPressure('b1'));
      expect(w['clientRecordVersion'], HealthRecordIds.version(t1));
      expect(await flag('health_connect_synced_b1'), isTrue);
      expect(await flag('health_connect_named_b1'), isTrue);
    });

    test('an edit replaces it: same name, higher version, new numbers', () async {
      await withClock(Clock.fixed(t1), () async {
        await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
        await settle();
      });
      await withClock(Clock.fixed(t2), () async {
        await VitalsStorageService.saveBp(bp('b1', sys: 135), stampActiveProfile: false);
        await settle();
      });
      final ws = writes();
      expect(ws, hasLength(2));
      expect(args(ws[1])['clientRecordId'], args(ws[0])['clientRecordId']);
      expect(args(ws[1])['clientRecordVersion'] as double,
          greaterThan(args(ws[0])['clientRecordVersion'] as double));
      expect(args(ws[1])['systolic'], 135);
    });

    test('a delete removes it from the store and clears both flags', () async {
      await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
      await settle();
      await VitalsStorageService.deleteBp('b1');
      await settle();

      final d = args(deletes().single);
      expect(d['clientRecordId'], HealthRecordIds.bloodPressure('b1'));
      expect(d['dataTypeKey'], 'BLOOD_PRESSURE_SYSTOLIC');
      expect(await flag('health_connect_synced_b1'), isNull);
      expect(await flag('health_connect_named_b1'), isNull);
    });

    test('Undo after a delete writes it afresh, once', () async {
      await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
      await settle();
      await VitalsStorageService.deleteBp('b1');
      await settle();
      await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
      await settle();

      expect(writes(), hasLength(2));
      expect(deletes(), hasLength(1));
      expect(await flag('health_connect_named_b1'), isTrue);
    });

    test('a delete the store refused leaves the flags, so Undo cannot duplicate',
        () async {
      await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
      await settle();
      answer = false;
      await VitalsStorageService.deleteBp('b1');
      await settle();
      answer = true;

      expect(deletes(), hasLength(1));
      expect(await flag('health_connect_synced_b1'), isTrue);
      expect(await flag('health_connect_named_b1'), isTrue);
      await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
      await settle();
      expect(writes(), hasLength(2),
          reason: 'the second is the edit-style rewrite of the same name — a replace, '
              'not a duplicate');
      expect(args(writes()[1])['clientRecordId'], args(writes()[0])['clientRecordId']);
    });

    test('a write the store refused sets nothing', () async {
      answer = false;
      await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
      await settle();
      expect(await flag('health_connect_synced_b1'), isNull);
      expect(await flag('health_connect_named_b1'), isNull);
    });

    test('a reading sent before the names existed is left alone', () async {
      SharedPreferences.setMockInitialValues({'health_connect_synced_old': true});
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      await VitalsStorageService.saveBp(bp('old', sys: 140), stampActiveProfile: false);
      await settle();
      expect(writes(), isEmpty, reason: 'its old record cannot be found; a rewrite is a duplicate');

      await VitalsStorageService.deleteBp('old');
      await settle();
      expect(deletes(), isEmpty);
      expect(await flag('health_connect_synced_old'), isTrue,
          reason: 'kept, which is what stops Undo duplicating it');
    });

    test('a reading that came from the store is never deleted from it', () async {
      final id = VitalsHealthImport.idFor('bp', at, 'com.omron.connect');
      expect(HealthSampleOrigin.cameFromTheStore(id), isTrue);
      await VitalsStorageService.saveBp(bp(id), stampActiveProfile: false, syncToHealthConnect: false);
      await VitalsStorageService.deleteBp(id);
      await settle();
      expect(deletes(), isEmpty);
    });

    test('with sharing off an edit is not sent, but a delete still withdraws',
        () async {
      await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
      await settle();
      await VitalsStorageService.setHealthConnectSyncEnabled(false);
      await VitalsStorageService.saveBp(bp('b1', sys: 150), stampActiveProfile: false);
      await settle();
      expect(writes(), hasLength(1));

      await VitalsStorageService.deleteBp('b1');
      await settle();
      expect(deletes(), hasLength(1),
          reason: 'what was shared is taken back with the reading');
    });

    test('on an iPhone nothing is named, edited or deleted', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await VitalsStorageService.saveBp(bp('b1'), stampActiveProfile: false);
      await settle();
      final w = args(writes().single);
      expect(w['clientRecordId'], isNull);
      expect(w['clientRecordVersion'], isNull);
      expect(await flag('health_connect_synced_b1'), isTrue);
      expect(await flag('health_connect_named_b1'), isNull);

      await VitalsStorageService.saveBp(bp('b1', sys: 140), stampActiveProfile: false);
      await VitalsStorageService.deleteBp('b1');
      await settle();
      expect(writes(), hasLength(1));
      expect(deletes(), isEmpty);
    });
  });

  group('blood sugar', () {
    test('written under its name, replaced by an edit, removed by a delete',
        () async {
      await withClock(Clock.fixed(t1), () async {
        await VitalsStorageService.saveGlucose(glucose('g1'), stampActiveProfile: false);
        await settle();
      });
      await withClock(Clock.fixed(t2), () async {
        await VitalsStorageService.saveGlucose(glucose('g1', v: 110), stampActiveProfile: false);
        await settle();
      });
      final ws = writes();
      expect(args(ws[0])['clientRecordId'], HealthRecordIds.glucose('g1'));
      expect(args(ws[1])['clientRecordId'], HealthRecordIds.glucose('g1'));
      expect(args(ws[1])['value'], 110.0);
      expect(args(ws[1])['clientRecordVersion'] as double,
          greaterThan(args(ws[0])['clientRecordVersion'] as double));

      await VitalsStorageService.deleteGlucose('g1');
      await settle();
      final d = args(deletes().single);
      expect(d['dataTypeKey'], 'BLOOD_GLUCOSE');
      expect(d['clientRecordId'], HealthRecordIds.glucose('g1'));
      expect(await flag('health_connect_synced_g1'), isNull);
    });

    test('an old one is left alone, and an iPhone is unchanged', () async {
      SharedPreferences.setMockInitialValues({'health_connect_synced_old': true});
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      await VitalsStorageService.saveGlucose(glucose('old', v: 120), stampActiveProfile: false);
      await VitalsStorageService.deleteGlucose('old');
      await settle();
      expect(writes(), isEmpty);
      expect(deletes(), isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await VitalsStorageService.saveGlucose(glucose('g2'), stampActiveProfile: false);
      await VitalsStorageService.deleteGlucose('g2');
      await settle();
      expect(args(writes().single)['clientRecordId'], isNull);
      expect(deletes(), isEmpty);
    });
  });

  group('weight', () {
    test('written under its name, replaced by an edit, removed by a delete',
        () async {
      await withClock(Clock.fixed(t1), () async {
        await VitalsStorageService.saveWeight(weight('w1'), stampActiveProfile: false);
        await settle();
      });
      await withClock(Clock.fixed(t2), () async {
        await VitalsStorageService.saveWeight(weight('w1', kg: 71.5), stampActiveProfile: false);
        await settle();
      });
      final ws = writes();
      expect(args(ws[0])['clientRecordId'], HealthRecordIds.weight('w1'));
      expect(args(ws[1])['value'], 71.5);
      expect(args(ws[1])['clientRecordVersion'] as double,
          greaterThan(args(ws[0])['clientRecordVersion'] as double));

      await VitalsStorageService.deleteWeight('w1');
      await settle();
      final d = args(deletes().single);
      expect(d['dataTypeKey'], 'WEIGHT');
      expect(d['clientRecordId'], HealthRecordIds.weight('w1'));
    });

    test('an old one is left alone, and an iPhone is unchanged', () async {
      SharedPreferences.setMockInitialValues({'health_connect_synced_old': true});
      await VitalsStorageService.setHealthConnectSyncEnabled(true);
      await VitalsStorageService.saveWeight(weight('old', kg: 80), stampActiveProfile: false);
      await VitalsStorageService.deleteWeight('old');
      await settle();
      expect(writes(), isEmpty);
      expect(deletes(), isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await VitalsStorageService.saveWeight(weight('w2'), stampActiveProfile: false);
      await VitalsStorageService.deleteWeight('w2');
      await settle();
      expect(args(writes().single)['clientRecordId'], isNull);
      expect(deletes(), isEmpty);
    });
  });

  group('drinks', () {
    EnhancedWaterLog log(String id, {int ml = 250, DateTime? time}) => EnhancedWaterLog(
          id: id,
          time: time ?? at,
          amountMl: ml,
          effectiveHydrationMl: ml,
          beverageId: 'water',
          beverageName: 'Water',
          beverageEmoji: '💧',
        );

    Future<List<String>> named() async =>
        (await SharedPreferences.getInstance()).getStringList('hydration_hc_named_syncs') ?? [];
    Future<List<String>> recent() async =>
        (await SharedPreferences.getInstance()).getStringList('hydration_hc_recent_syncs') ?? [];

    test('a drink is written under its name and remembered as named', () async {
      await withClock(Clock.fixed(t1), () async {
        await HydrationHealthSync.onLogAdded(log('d1'));
      });
      final w = args(writes().single);
      expect(w['clientRecordId'], HealthRecordIds.water('d1'));
      expect(w['clientRecordVersion'], HealthRecordIds.version(t1));
      expect(await named(), ['d1']);
      expect(await recent(), ['d1']);
    });

    test('an edit replaces it: same name, higher version, new volume', () async {
      await withClock(Clock.fixed(t1), () => HydrationHealthSync.onLogAdded(log('d1')));
      await withClock(Clock.fixed(t2),
          () => HydrationHealthSync.onLogUpdated(log('d1', ml: 400)));
      final ws = writes();
      expect(ws, hasLength(2));
      expect(args(ws[1])['clientRecordId'], HealthRecordIds.water('d1'));
      expect(args(ws[1])['value'], 0.4);
      expect(args(ws[1])['clientRecordVersion'] as double,
          greaterThan(args(ws[0])['clientRecordVersion'] as double));
    });

    test('a removal deletes it, then Undo (the same id again) writes it afresh',
        () async {
      await HydrationHealthSync.onLogAdded(log('d1'));
      await HydrationHealthSync.onLogRemoved('d1');
      final d = args(deletes().single);
      expect(d['dataTypeKey'], 'WATER');
      expect(d['clientRecordId'], HealthRecordIds.water('d1'));
      expect(await named(), isEmpty);
      expect(await recent(), isEmpty);

      await HydrationHealthSync.onLogAdded(log('d1'));
      expect(writes(), hasLength(2));
      expect(await named(), ['d1']);
    });

    test('a removal the store refused keeps the lists', () async {
      await HydrationHealthSync.onLogAdded(log('d1'));
      answer = false;
      await HydrationHealthSync.onLogRemoved('d1');
      answer = true;
      expect(await named(), ['d1']);
      expect(await recent(), ['d1']);
      await HydrationHealthSync.onLogAdded(log('d1'));
      expect(writes(), hasLength(1), reason: 'still "already sent"');
    });

    test('a drink sent before the names existed is left alone', () async {
      SharedPreferences.setMockInitialValues({
        'hydration_hc_recent_syncs': ['old'],
      });
      await HydrationHealthSync.setEnabled(true);
      await HydrationHealthSync.onLogUpdated(log('old', ml: 500));
      await HydrationHealthSync.onLogRemoved('old');
      expect(writes(), isEmpty);
      expect(deletes(), isEmpty);
      expect(await recent(), ['old']);
    });

    test('a drink that came from the store is never deleted from it', () async {
      await HydrationHealthSync.onLogRemoved('imported-1');
      expect(deletes(), isEmpty);
    });

    test('with sharing off an edit is not sent', () async {
      await HydrationHealthSync.onLogAdded(log('d1'));
      await HydrationHealthSync.setEnabled(false);
      await HydrationHealthSync.onLogUpdated(log('d1', ml: 500));
      expect(writes(), hasLength(1));
    });

    test('an edit to nothing is not sent', () async {
      await HydrationHealthSync.onLogAdded(log('d1'));
      await HydrationHealthSync.onLogUpdated(log('d1', ml: 0));
      expect(writes(), hasLength(1));
    });

    test('on an iPhone nothing is named, edited or deleted', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await HydrationHealthSync.onLogAdded(log('d1'));
      expect(args(writes().single)['clientRecordId'], isNull);
      expect(await named(), isEmpty);
      expect(await recent(), ['d1']);

      await HydrationHealthSync.onLogUpdated(log('d1', ml: 500));
      await HydrationHealthSync.onLogRemoved('d1');
      expect(writes(), hasLength(1));
      expect(deletes(), isEmpty);
    });

    group('through the water service', () {
      setUp(() async => WaterService.init());

      test('adding, editing and removing a drink reach the store', () async {
        final water = WaterService.getBeverage('water')!;
        final data = await WaterService.addWaterLog(amountMl: 250, beverage: water);
        await settle();
        final id = data.logs.single.id;
        expect(args(writes().single)['clientRecordId'], HealthRecordIds.water(id));

        await WaterService.updateWaterLogForDate(
            date: DateTime.now(), logId: id, amountMl: 400, beverage: water);
        await settle();
        expect(writes(), hasLength(2));
        expect(args(writes()[1])['value'], 0.4);
        expect(args(writes()[1])['clientRecordId'], HealthRecordIds.water(id));

        await WaterService.removeWaterLog(id);
        await settle();
        expect(args(deletes().single)['clientRecordId'], HealthRecordIds.water(id));
      });
    });
  });
}
