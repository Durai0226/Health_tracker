/// Readings from a cuff or a meter app appear by themselves — once the person has
/// asked for that — without doubling anything they typed in or this app sent out.
///
/// The platform read cannot run headless, so the samples are handed in. What is
/// worth proving is everything around it: which samples count, that the app's own
/// records never come back, that nothing is added twice, and that a reading the
/// person removed stays removed.
library;

import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/health_import_control.dart';
import 'package:tablet_remainder/core/health/health_sample_origin.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/services/vitals_health_import.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// Runs [then] once, right after the first insert into a table whose name is in the
/// statement: a way to do something in the middle of a loop that is saving.
class _AfterFirstInsert extends QueryInterceptor {
  _AfterFirstInsert(this.table, this.then);

  final String table;
  final void Function() then;
  var _fired = false;

  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) async {
    final id = await super.runInsert(executor, statement, args);
    if (!_fired && statement.contains(table)) {
      _fired = true;
      then();
    }
    return id;
  }
}

/// Counts the selects made on the vitals tables.
class _CountSelects extends QueryInterceptor {
  int onVitals = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
      QueryExecutor executor, String statement, List<Object?> args) {
    if (statement.contains('blood_pressure_readings') ||
        statement.contains('glucose_readings')) {
      onVitals++;
    }
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 9, 30, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    // A kind a test does not hand in reads as "nothing there". Without a plugin
    // the real read cannot be made at all, and that is now an error — not an
    // empty list, which is what these tests were quietly relying on.
    VitalsHealthImport.readerForTesting = (_, _, _) async => const [];
  });

  tearDown(() async {
    VitalsHealthImport.readerForTesting = null;
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  /// A sample as the plugin hands it over. The two platforms fill the source fields
  /// differently: on iPhone `sourceId` is the bundle id and `sourceName` what the
  /// person sees; on Android `sourceId` is EMPTY and `sourceName` is the package.
  /// [android] makes it the Android shape — the default is the iPhone's, which is
  /// the one every test here was first written in.
  HealthDataPoint point(
    HealthDataType type,
    DateTime at,
    num value, {
    String source = 'com.omron.connect',
    String name = 'Omron connect',
    HealthValue? raw,
    bool android = false,
  }) =>
      HealthDataPoint(
        uuid: '$type-${at.millisecondsSinceEpoch}-$source',
        value: raw ?? NumericHealthValue(numericValue: value),
        type: type,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: at,
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: android ? '' : source,
        sourceName: android ? source : name,
        recordingMethod: RecordingMethod.automatic,
      );

  /// Both halves of one cuff reading.
  List<HealthDataPoint> cuff(DateTime at, int sys, int dia,
          {String source = 'com.omron.connect', bool android = false}) =>
      [
        point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, at, sys,
            source: source, android: android),
        point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, at, dia,
            source: source, android: android),
      ];

  HealthDataPoint sugar(DateTime at, num mgdl,
          {String source = 'com.glucose.meter', bool android = false}) =>
      point(HealthDataType.BLOOD_GLUCOSE, at, mgdl, source: source, android: android);

  final eight = DateTime(2026, 9, 30, 8, 3);

  group('whose record it is', () {
    test('the ids it treats as its own are the ones the build files declare', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final applicationId =
          RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)!.group(1)!;
      expect(HealthSampleOrigin.ownSourceIds, contains(applicationId),
          reason: 'Health Connect stamps this app\'s writes with it');

      // The project holds the app target and its extensions (RunnerTests, the
      // water widget), whose ids are the app's with a suffix. Only the app
      // itself writes to HealthKit: it is the one that is a prefix of the rest.
      final project =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      final bundleIds = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .allMatches(project)
          .map((m) => m.group(1)!)
          .toSet();
      final app = bundleIds.reduce((a, b) => a.length <= b.length ? a : b);
      expect(bundleIds.every((id) => id.startsWith(app)), isTrue,
          reason: 'the app target\'s id is the base of every other target\'s');
      expect(HealthSampleOrigin.ownSourceIds, contains(app),
          reason: 'HealthKit stamps this app\'s writes with the bundle id');
    });

    test('a sample from the app\'s own id is its own; another app\'s is not', () {
      expect(HealthSampleOrigin.isOwn(sugar(eight, 100, source: 'com.dlyminder.app')),
          isTrue);
      expect(HealthSampleOrigin.isOwn(sugar(eight, 100)), isFalse);
    });

    test('on Android the id is empty and the package is in the name: still its own', () {
      // health 13.3.2 `createBaseRecord`: "source_id" to "", "source_name" to the
      // package. Checked on the id alone, nothing Android wrote was ever its own.
      expect(
          HealthSampleOrigin.isOwn(
              sugar(eight, 100, source: 'com.dlyminder.app', android: true)),
          isTrue);
      expect(HealthSampleOrigin.isOwn(sugar(eight, 100, android: true)), isFalse);
    });

    test('on iPhone the name is only what the person sees, and the id decides', () {
      final own = point(HealthDataType.BLOOD_GLUCOSE, eight, 100,
          source: 'com.implementation.tabletremainder.tabletRemainder', name: 'DlyMinder');
      final other = point(HealthDataType.BLOOD_GLUCOSE, eight, 100,
          source: 'com.glucose.meter', name: 'DlyMinder');

      expect(HealthSampleOrigin.isOwn(own), isTrue);
      expect(HealthSampleOrigin.isOwn(other), isFalse,
          reason: 'another app that happens to be named like this one is not it');
    });

    test('which app wrote it: the id where there is one, the name where there is not', () {
      expect(HealthSampleOrigin.appOf(sugar(eight, 100, source: 'com.a')), 'com.a');
      expect(HealthSampleOrigin.appOf(sugar(eight, 100, source: 'com.a', android: true)),
          'com.a');
    });
  });

  group('on Android, where the plugin leaves the id empty', () {
    test('a reading is a systolic and a diastolic from the same app, told by its package', () {
      final got = VitalsHealthImport.bloodPressure(
          cuff(eight, 128, 82, source: 'com.omron.connect', android: true));

      expect(got.single.systolic, 128);
      expect(got.single.diastolic, 82);
    });

    test('two apps that saved a reading at the same time are two readings, not one', () {
      // Told apart by the empty id alone, both halves of both apps were filed under
      // one key, and the second app's numbers replaced the first's.
      final got = VitalsHealthImport.bloodPressure([
        ...cuff(eight, 120, 80, source: 'com.omron.connect', android: true),
        ...cuff(eight, 130, 85, source: 'com.withings.wiscale2', android: true),
      ]);

      expect(got.map((r) => (r.systolic, r.diastolic)).toSet(), {(120, 80), (130, 85)});
      expect(got.map((r) => r.id).toSet(), hasLength(2));
    });

    test('halves from different apps are not paired', () {
      final got = VitalsHealthImport.bloodPressure([
        point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, eight, 120,
            source: 'com.omron.connect', android: true),
        point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, eight, 80,
            source: 'com.withings.wiscale2', android: true),
      ]);

      expect(got, isEmpty);
    });

    test('and the ids of two apps\' blood sugars at the same second differ', () {
      final a = VitalsHealthImport.glucose([sugar(eight, 100, source: 'com.a', android: true)]);
      final b = VitalsHealthImport.glucose([sugar(eight, 100, source: 'com.b', android: true)]);

      expect(a.single.id, isNot(b.single.id));
    });

    test('what this app wrote itself is not read back, whichever kind it is', () {
      expect(
          VitalsHealthImport.bloodPressure(
              cuff(eight, 128, 82, source: 'com.dlyminder.app', android: true)),
          isEmpty);
      expect(
          VitalsHealthImport.glucose(
              [sugar(eight, 100, source: 'com.dlyminder.app', android: true)]),
          isEmpty);
    });

    test('so a blood pressure it shared does not come back through a full import', () async {
      final r = await VitalsHealthImport.run(
        now: now,
        bpSamples: [
          ...cuff(eight, 128, 82, source: 'com.dlyminder.app', android: true),
          ...cuff(eight.add(const Duration(hours: 1)), 131, 84,
              source: 'com.omron.connect', android: true),
        ],
        glucoseSamples: [sugar(eight, 99, source: 'com.dlyminder.app', android: true)],
      );

      expect(r.bloodPressure, hasLength(1));
      expect(r.glucose, isEmpty);
      final stored = await VitalsStorageService.getAllBp(scopeToActiveProfile: false);
      expect(stored.single.systolic, 131);
    });
  });

  group('blood pressure from a read', () {
    test('a systolic and a diastolic from the same app at the same time are one reading',
        () {
      final got = VitalsHealthImport.bloodPressure(cuff(eight, 128, 82));
      expect(got, hasLength(1));
      expect(got.single.systolic, 128);
      expect(got.single.diastolic, 82);
      expect(got.single.takenAt, eight);
    });

    test('numbers are rounded to whole mm Hg', () {
      final got = VitalsHealthImport.bloodPressure([
        point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, eight, 127.6),
        point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, eight, 81.4),
      ]);
      expect([got.single.systolic, got.single.diastolic], [128, 81]);
    });

    test('half a reading is not one', () {
      expect(
          VitalsHealthImport.bloodPressure(
              [point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, eight, 128)]),
          isEmpty);
    });

    test('halves from different apps are not paired', () {
      expect(
          VitalsHealthImport.bloodPressure([
            point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, eight, 128,
                source: 'com.omron.connect'),
            point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, eight, 82,
                source: 'com.withings.wiscale2'),
          ]),
          isEmpty);
    });

    test('two apps that saved a reading at the same second keep both, under different ids',
        () {
      final got = VitalsHealthImport.bloodPressure([
        ...cuff(eight, 128, 82, source: 'com.omron.connect'),
        ...cuff(eight, 128, 82, source: 'com.withings.wiscale2'),
      ]);
      expect(got, hasLength(2));
      expect(got[0].id, isNot(got[1].id));
    });

    test('what this app wrote itself is not read back', () {
      expect(
          VitalsHealthImport.bloodPressure(
              cuff(eight, 128, 82, source: 'com.dlyminder.app')),
          isEmpty);
    });

    test('an implausible pair is dropped', () {
      for (final (s, d) in [(80, 120), (120, 120), (320, 90), (40, 30), (130, 20)]) {
        expect(VitalsHealthImport.bloodPressure(cuff(eight, s, d)), isEmpty,
            reason: '$s/$d');
      }
    });

    test('a sample that is not a number is ignored', () {
      expect(
          VitalsHealthImport.bloodPressure([
            point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, eight, 0,
                raw: WorkoutHealthValue(
                    workoutActivityType: HealthWorkoutActivityType.WALKING)),
            point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, eight, 82),
          ]),
          isEmpty);
    });

    test('the same sample always gets the same id, and a different time a different one',
        () {
      final a = VitalsHealthImport.bloodPressure(cuff(eight, 128, 82)).single.id;
      final b = VitalsHealthImport.bloodPressure(cuff(eight, 128, 82)).single.id;
      final c = VitalsHealthImport.bloodPressure(
              cuff(eight.add(const Duration(minutes: 1)), 128, 82))
          .single
          .id;
      expect(a, b);
      expect(a, isNot(c));
      expect(a, startsWith('hc_bp_'));
    });

    test('oldest first', () {
      final got = VitalsHealthImport.bloodPressure([
        ...cuff(eight.add(const Duration(hours: 9)), 130, 85),
        ...cuff(eight, 128, 82),
      ]);
      expect([for (final r in got) r.systolic], [128, 130]);
    });
  });

  group('blood sugar from a read', () {
    test('a number in mg/dL, rounded, with its time', () {
      final got = VitalsHealthImport.glucose([sugar(eight, 104.6)]);
      expect(got.single.valueMgdl, 105);
      expect(got.single.takenAt, eight);
      expect(got.single.id, startsWith('hc_gl_'));
    });

    test('what this app wrote itself is not read back', () {
      expect(
          VitalsHealthImport.glucose([sugar(eight, 100, source: 'com.dlyminder.app')]),
          isEmpty);
    });

    test('an impossible value is dropped', () {
      expect(VitalsHealthImport.glucose([sugar(eight, 5), sugar(eight, 1200)]),
          isEmpty);
    });

    test('other kinds of sample are ignored', () {
      expect(
          VitalsHealthImport.glucose(
              [point(HealthDataType.WEIGHT, eight, 70, source: 'com.scale')]),
          isEmpty);
    });
  });

  group('what the import says', () {
    test('names what was brought in, with the right plurals', () {
      expect(const VitalsImportResult(bloodPressure: ['a']).describe(),
          '1 blood pressure reading');
      expect(const VitalsImportResult(bloodPressure: ['a', 'b']).describe(),
          '2 blood pressure readings');
      expect(const VitalsImportResult(glucose: ['a']).describe(),
          '1 blood sugar reading');
      expect(
          const VitalsImportResult(bloodPressure: ['a', 'b'], glucose: ['c']).describe(),
          '2 blood pressure readings and 1 blood sugar reading');
    });
  });

  group('keeping the readings', () {
    Future<List<BloodPressureReading>> storedBp() =>
        VitalsStorageService.getAllBp(scopeToActiveProfile: false);
    Future<List<GlucoseReading>> storedGlucose() =>
        VitalsStorageService.getAllGlucose(scopeToActiveProfile: false);

    test('both kinds are saved, and counted', () async {
      final r = await VitalsHealthImport.run(
        now: now,
        bpSamples: cuff(eight, 128, 82),
        glucoseSamples: [sugar(eight, 104)],
      );

      expect(r.bloodPressure, hasLength(1));
      expect(r.glucose, hasLength(1));
      expect(r.count, 2);
      expect((await storedBp()).single.systolic, 128);
      expect((await storedGlucose()).single.valueMgdl, 104);
    });

    test('they belong to the person whose health store it is, not the profile that is open',
        () async {
      await ActiveProfileService().setActiveDependent('child-1');

      await VitalsHealthImport.run(
        now: now,
        bpSamples: cuff(eight, 128, 82),
        glucoseSamples: [sugar(eight, 104)],
      );

      expect((await storedBp()).single.dependentId, isNull);
      expect((await storedGlucose()).single.dependentId, isNull);
    });

    test('a reading already typed in at the same time with the same numbers is not added again',
        () async {
      await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'typed',
            systolic: 128,
            diastolic: 82,
            takenAt: eight.add(const Duration(seconds: 90)),
            createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );

      final r = await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 82));

      expect(r.isEmpty, isTrue);
      expect(await storedBp(), hasLength(1));
    });

    test('but different numbers, or a different time, are different readings',
        () async {
      await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'typed',
            systolic: 128,
            diastolic: 82,
            takenAt: eight,
            createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );

      final r = await VitalsHealthImport.run(now: now, bpSamples: [
        ...cuff(eight, 130, 82), // another number
        ...cuff(eight.add(const Duration(minutes: 5)), 128, 82), // another time
      ]);

      expect(r.bloodPressure, hasLength(2));
    });

    test('two apps that each left the same reading in the store are one reading', () async {
      // A cuff app and an aggregator that mirrors it: different packages, so
      // different ids, the same numbers and time. Compared only with what was already
      // kept, both passed — a typed-in reading would have caught the second.
      final r = await VitalsHealthImport.run(now: now, bpSamples: [
        ...cuff(eight, 128, 82, source: 'com.omron.connect', android: true),
        ...cuff(eight.add(const Duration(seconds: 40)), 128, 82,
            source: 'com.sec.android.app.shealth', android: true),
      ]);

      expect(r.bloodPressure, hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('vitals_health_import_seen_ids'), hasLength(2),
          reason: 'both are dealt with, so neither is looked at again');
    });

    test('and the same for blood sugar', () async {
      final r = await VitalsHealthImport.run(now: now, glucoseSamples: [
        sugar(eight, 104, source: 'com.dexcom.g7', android: true),
        sugar(eight.add(const Duration(seconds: 70)), 104,
            source: 'com.sec.android.app.shealth', android: true),
      ]);

      expect(r.glucose, hasLength(1));
    });

    test('but another value in the same two minutes is another reading', () async {
      final r = await VitalsHealthImport.run(now: now, glucoseSamples: [
        sugar(eight, 104, source: 'com.dexcom.g7', android: true),
        sugar(eight.add(const Duration(seconds: 70)), 109, source: 'com.dexcom.g7', android: true),
      ]);

      expect(r.glucose, hasLength(2));
    });

    test('the same top number with another bottom number is another reading', () async {
      await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'typed', systolic: 128, diastolic: 82, takenAt: eight, createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );

      final r = await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 90));

      expect(r.bloodPressure, hasLength(1));
    });

    test('a blood sugar already typed in is not added again either', () async {
      await VitalsStorageService.saveGlucose(
        GlucoseReading(id: 'typed', valueMgdl: 104, takenAt: eight, createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );

      final r = await VitalsHealthImport.run(now: now, glucoseSamples: [sugar(eight, 104)]);

      expect(r.isEmpty, isTrue);
    });

    test('nor when the meter app saved it a minute and a half from the time it was typed',
        () async {
      await VitalsStorageService.saveGlucose(
        GlucoseReading(
            id: 'typed',
            valueMgdl: 104,
            takenAt: eight.add(const Duration(seconds: 90)),
            createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );

      final r = await VitalsHealthImport.run(now: now, glucoseSamples: [sugar(eight, 104)]);

      expect(r.isEmpty, isTrue);
    });

    test('but ten minutes apart, or another value, it is another blood sugar', () async {
      await VitalsStorageService.saveGlucose(
        GlucoseReading(id: 'typed', valueMgdl: 104, takenAt: eight, createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );

      final r = await VitalsHealthImport.run(now: now, glucoseSamples: [
        sugar(eight.add(const Duration(minutes: 10)), 104),
        sugar(eight, 118),
      ]);

      expect(r.glucose, hasLength(2));
    });

    test('what is kept is read only when there is something new to compare it with', () async {
      // This runs at every start and resume, and almost always finds nothing new:
      // it must not load, and index, every reading ever kept to find that out.
      final counter = _CountSelects();
      final counted = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(counter));
      AppDatabase.setInstanceForTesting(counted);
      addTearDown(counted.close);
      final samples = cuff(eight, 128, 82);
      await VitalsHealthImport.run(
          now: now, bpSamples: samples, glucoseSamples: [sugar(eight, 104)]);
      counter.onVitals = 0;

      final again = await VitalsHealthImport.run(
          now: now, bpSamples: samples, glucoseSamples: [sugar(eight, 104)]);

      expect(again.isEmpty, isTrue);
      expect(counter.onVitals, 0, reason: 'every sample was already seen');
    });

    test('and then only the kinds that have something new', () async {
      final counter = _CountSelects();
      final counted = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(counter));
      AppDatabase.setInstanceForTesting(counted);
      addTearDown(counted.close);
      await VitalsHealthImport.run(
          now: now, bpSamples: cuff(eight, 128, 82), glucoseSamples: [sugar(eight, 104)]);
      counter.onVitals = 0;

      await VitalsHealthImport.run(
          now: now,
          bpSamples: cuff(eight, 128, 82),
          glucoseSamples: [sugar(eight.add(const Duration(hours: 1)), 111)]);

      expect(counter.onVitals, 1, reason: 'the blood sugar, only: blood pressure had nothing new');
    });

    test('a reading typed in exactly the window before the first new one is still a copy',
        () async {
      // The kept readings are read between the first and the last new one, widened by
      // the window: the edge of it is inclusive on both sides.
      await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'early',
            systolic: 128,
            diastolic: 82,
            takenAt: eight.subtract(VitalsHealthImport.duplicateWindow),
            createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );
      await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'late',
            systolic: 131,
            diastolic: 84,
            takenAt: eight.add(const Duration(hours: 1)).add(VitalsHealthImport.duplicateWindow),
            createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );

      final r = await VitalsHealthImport.run(now: now, bpSamples: [
        ...cuff(eight, 128, 82),
        ...cuff(eight.add(const Duration(hours: 1)), 131, 84),
      ]);

      expect(r.isEmpty, isTrue, reason: 'both are copies of what was typed');
    });

    test('running again over the same samples adds nothing', () async {
      await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 82));
      final again =
          await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 82));

      expect(again.isEmpty, isTrue);
      expect(await storedBp(), hasLength(1));
    });

    test('a reading the person deleted does not come back', () async {
      final first =
          await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 82));
      await VitalsStorageService.deleteBp(first.bloodPressure.single);
      expect(await storedBp(), isEmpty);

      final again =
          await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 82));

      expect(again.isEmpty, isTrue);
      expect(await storedBp(), isEmpty);
    });

    test('a reading skipped as a duplicate is remembered too, so deleting the typed one does not bring it in',
        () async {
      await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'typed',
            systolic: 128,
            diastolic: 82,
            takenAt: eight,
            createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );
      await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 82));
      await VitalsStorageService.deleteBp('typed');

      final again =
          await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 82));

      expect(again.isEmpty, isTrue);
    });

    test('the app\'s own records are never kept', () async {
      final r = await VitalsHealthImport.run(
        now: now,
        bpSamples: cuff(eight, 128, 82, source: 'com.dlyminder.app'),
        glucoseSamples: [sugar(eight, 104, source: 'com.dlyminder.app')],
      );

      expect(r.isEmpty, isTrue);
      expect(await storedBp(), isEmpty);
      expect(await storedGlucose(), isEmpty);
    });

    test('Undo takes back what the import kept, and only that', () async {
      await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'mine',
            systolic: 118,
            diastolic: 76,
            takenAt: eight.subtract(const Duration(days: 1)),
            createdAt: eight),
        stampActiveProfile: false,
        syncToHealthConnect: false,
      );
      final r = await VitalsHealthImport.run(
        now: now,
        bpSamples: cuff(eight, 128, 82),
        glucoseSamples: [sugar(eight, 104)],
      );

      await VitalsHealthImport.undo(r);

      expect([for (final x in await storedBp()) x.id], ['mine']);
      expect(await storedGlucose(), isEmpty);
    });

    test('and an Undone reading is not fetched again', () async {
      final r = await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 82));
      await VitalsHealthImport.undo(r);

      final again =
          await VitalsHealthImport.run(now: now, bpSamples: cuff(eight, 128, 82));

      expect(again.isEmpty, isTrue);
    });

    test('imports are not written back to the health store', () async {
      // The write-back switch is on, and the health plugin answers "yes" to
      // everything: an imported reading that was sent out again would show up as
      // a write call, under this app's own name.
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/device_info'),
          (call) async => <String, dynamic>{});
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_health'),
          (call) async {
        calls.add(call.method);
        return true;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/device_info'), null);
        messenger.setMockMethodCallHandler(const MethodChannel('flutter_health'), null);
      });
      await VitalsStorageService.setHealthConnectSyncEnabled(true);

      await VitalsHealthImport.run(
          now: now,
          bpSamples: cuff(eight, 128, 82),
          glucoseSamples: [sugar(eight, 104)]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(calls.where((c) => c.toLowerCase().contains('write')), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getKeys().where((k) => k.startsWith('health_connect_synced_')),
          isEmpty);
    });

    test('it remembers at most the newest 1500 ids', () async {
      final points = <HealthDataPoint>[];
      for (var i = 0; i < VitalsHealthImport.seenCap + 20; i++) {
        points.addAll(cuff(DateTime(2025, 1, 1).add(Duration(minutes: 10 * i)), 120, 80));
      }
      await VitalsHealthImport.run(now: now, bpSamples: points);

      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList('vitals_health_import_seen_ids')!;
      expect(seen, hasLength(VitalsHealthImport.seenCap));
      // The newest are the ones kept: the oldest 20 fell off the front.
      final oldest = VitalsHealthImport.idFor('bp', DateTime(2025, 1, 1), 'com.omron.connect');
      expect(seen, isNot(contains(oldest)));
    });
  });

  group('an app that writes a reading every few minutes', () {
    // A continuous glucose monitor's app writes about 288 readings a day. A week of
    // those is far more than the cap of ids the ledger keeps — and a reading
    // dropped from the ledger while it can still be read is a deleted reading that
    // comes back at the next run.
    const perDay = 288;

    /// [days] of readings, five minutes apart, ending an hour before [now].
    List<HealthDataPoint> monitor(int days) => [
          for (var i = 0; i < days * perDay; i++)
            sugar(now.subtract(const Duration(hours: 1)).subtract(Duration(minutes: 5 * i)),
                80 + (i % 60)),
        ];

    test('everything inside the week the next run will read is remembered, past the cap',
        () async {
      await VitalsHealthImport.run(now: now, glucoseSamples: monitor(9));

      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList('vitals_health_import_seen_ids')!;
      expect(seen.length, greaterThan(VitalsHealthImport.seenCap),
          reason: 'the cap is for what is no longer wanted');
      // The next run's window starts a week before this one: every reading in it.
      final weekAgo = now.subtract(VitalsHealthImport.overlap);
      final inWindow = monitor(9)
          .where((p) => !p.dateFrom.isBefore(weekAgo))
          .map((p) => VitalsHealthImport.idFor('gl', p.dateFrom, p.sourceId))
          .toList();
      expect(seen, containsAll(inWindow));
      // And what is older than that window is not: nothing else is held on to.
      final dayEarlier = now.subtract(VitalsHealthImport.overlap + const Duration(days: 1));
      final wanted = monitor(9).where((p) => !p.dateFrom.isBefore(dayEarlier)).length;
      expect(seen, hasLength(wanted));
    });

    test('blood pressure too: a week of readings is remembered past the cap', () async {
      final first = now.subtract(const Duration(hours: 1));
      final cuffs = <HealthDataPoint>[
        for (var i = 0; i < VitalsHealthImport.seenCap + 100; i++)
          ...cuff(first.subtract(Duration(minutes: 5 * i)), 120 + i % 30, 80),
      ];

      await VitalsHealthImport.run(now: now, bpSamples: cuffs);

      final seen = (await SharedPreferences.getInstance())
          .getStringList('vitals_health_import_seen_ids')!;
      expect(seen.length, VitalsHealthImport.seenCap + 100,
          reason: 'all of it is inside the week the next run reads again');
      final oldest = first.subtract(const Duration(minutes: 5 * (VitalsHealthImport.seenCap + 99)));
      expect(seen, contains(VitalsHealthImport.idFor('bp', oldest, 'com.omron.connect')));
    });

    test('a reading deleted from the last week does not come back at the next run', () async {
      final samples = monitor(9);
      await VitalsHealthImport.run(now: now, glucoseSamples: samples);
      // Six days old: past the 1500 newest ids, but inside the week.
      final sixDaysAgo = samples.firstWhere(
          (p) => p.dateFrom.isBefore(now.subtract(const Duration(days: 6))));
      final id = VitalsHealthImport.idFor('gl', sixDaysAgo.dateFrom, sixDaysAgo.sourceId);
      expect(await VitalsStorageService.getAllGlucose(scopeToActiveProfile: false),
          anyElement((GlucoseReading r) => r.id == id),
          reason: 'the premise: it was brought in');
      await VitalsStorageService.deleteGlucose(id);

      final later = now.add(const Duration(hours: 2));
      final again = await VitalsHealthImport.run(now: later, glucoseSamples: samples);

      expect(again.glucose, isNot(contains(id)));
      expect(await VitalsStorageService.getAllGlucose(scopeToActiveProfile: false),
          isNot(anyElement((GlucoseReading r) => r.id == id)));
    });

    test('and what has left the week is let go, so the ledger does not grow for ever',
        () async {
      await VitalsHealthImport.run(now: now, glucoseSamples: monitor(9));
      final a = (await SharedPreferences.getInstance())
          .getStringList('vitals_health_import_seen_ids')!
          .length;

      // A month on, with the same kind of week of readings.
      final month = now.add(const Duration(days: 30));
      final week = [
        for (var i = 0; i < 8 * perDay; i++)
          sugar(month.subtract(const Duration(hours: 1)).subtract(Duration(minutes: 5 * i)),
              80 + (i % 60))
      ];
      await VitalsHealthImport.run(now: month, glucoseSamples: week);
      final b = (await SharedPreferences.getInstance())
          .getStringList('vitals_health_import_seen_ids')!
          .length;

      final wanted = week
          .where((p) => !p.dateFrom
              .isBefore(month.subtract(VitalsHealthImport.overlap + const Duration(days: 1))))
          .length;
      expect(b, wanted, reason: 'only the readings in the new week; the old week is let go');
      expect(b, lessThan(a + wanted));
    });

    test('and there is a ceiling, whatever an app writes', () async {
      // A reading a minute is five times that: the ids live in preferences that are
      // read whole at every start.
      final dense = [
        for (var i = 0; i < 4 * 1440; i++)
          sugar(now.subtract(const Duration(hours: 1)).subtract(Duration(minutes: i)),
              80 + (i % 60))
      ];

      await VitalsHealthImport.run(now: now, glucoseSamples: dense);

      final seen = (await SharedPreferences.getInstance())
          .getStringList('vitals_health_import_seen_ids')!;
      expect(seen.length, lessThanOrEqualTo(5000));
    });
  });

  group('when it runs', () {
    Future<bool> allowed() async => true;
    Future<bool> refused() async => false;

    test('off until the person turns it on', () async {
      expect(await VitalsHealthImport.isEnabled(), isFalse);
      final r = await VitalsHealthImport.runIfEnabled(
          now: now, hasPermission: allowed, bpSamples: cuff(eight, 128, 82));
      expect(r, isNull);
      expect(await VitalsStorageService.getAllBp(scopeToActiveProfile: false), isEmpty);
    });

    test('on but the health app\'s permission is gone: does not run', () async {
      await VitalsHealthImport.setEnabled(true);
      final r = await VitalsHealthImport.runIfEnabled(
          now: now, hasPermission: refused, bpSamples: cuff(eight, 128, 82));
      expect(r, isNull);
      expect(await VitalsStorageService.getAllBp(scopeToActiveProfile: false), isEmpty);
    });

    test('on and allowed: brings the readings in', () async {
      await VitalsHealthImport.setEnabled(true);
      final r = await VitalsHealthImport.runIfEnabled(
          now: now, hasPermission: allowed, bpSamples: cuff(eight, 128, 82));
      expect(r!.bloodPressure, hasLength(1));
    });

    test('not twice within a quarter of an hour, unless forced', () async {
      await VitalsHealthImport.setEnabled(true);
      await VitalsHealthImport.runIfEnabled(
          now: now, hasPermission: allowed, bpSamples: cuff(eight, 128, 82));

      final soon = now.add(const Duration(minutes: 14));
      final tooSoon = await VitalsHealthImport.runIfEnabled(
          now: soon,
          hasPermission: allowed,
          bpSamples: cuff(soon.subtract(const Duration(minutes: 1)), 131, 84));
      expect(tooSoon, isNull);

      final forced = await VitalsHealthImport.runIfEnabled(
          force: true,
          now: soon,
          hasPermission: allowed,
          bpSamples: cuff(soon.subtract(const Duration(minutes: 1)), 131, 84));
      expect(forced!.bloodPressure, hasLength(1));

      final later = soon.add(const Duration(minutes: 16));
      final afterGap = await VitalsHealthImport.runIfEnabled(
          now: later,
          hasPermission: allowed,
          bpSamples: cuff(later, 133, 86));
      expect(afterGap!.bloodPressure, hasLength(1));
    });

    test('a health store that throws does not stop the app: null, nothing kept',
        () async {
      await VitalsHealthImport.setEnabled(true);
      final r = await VitalsHealthImport.runIfEnabled(
          now: now, hasPermission: () async => throw StateError('no provider'));
      expect(r, isNull);
    });

    test('switching it off forgets when it last ran, so turning it on reads the whole first window',
        () async {
      await VitalsHealthImport.setEnabled(true);
      await VitalsHealthImport.runIfEnabled(
          now: now, hasPermission: allowed, bpSamples: const []);
      await VitalsHealthImport.setEnabled(false);
      await VitalsHealthImport.setEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('vitals_health_import_last_run_ms'), isNull);
    });
  });

  group('turned off while it runs', () {
    Future<bool> allowed() async => true;

    final t1 = DateTime(2026, 9, 30, 8, 3);
    final t2 = DateTime(2026, 9, 30, 9, 3);
    final t3 = DateTime(2026, 9, 30, 10, 3);

    /// A read of the health store that does not come back until it is let go.
    ({Completer<void> reading, Completer<void> release}) holdTheRead() {
      final reading = Completer<void>();
      final release = Completer<void>();
      VitalsHealthImport.readerForTesting = (kind, from, to) async {
        if (!reading.isCompleted) reading.complete();
        await release.future;
        return kind == 'bp' ? cuff(eight, 128, 82) : [sugar(eight, 104)];
      };
      return (reading: reading, release: release);
    }

    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

    test('off while the store is being read: nothing is kept, nothing remembered, no run recorded',
        () async {
      final read = holdTheRead();
      await VitalsHealthImport.setEnabled(true);
      final run = VitalsHealthImport.runIfEnabled(now: now, hasPermission: allowed);
      await read.reading.future;

      await VitalsHealthImport.setEnabled(false);
      read.release.complete();
      final result = await run;

      expect(result!.isEmpty, isTrue);
      expect(await VitalsStorageService.getAllBp(scopeToActiveProfile: false), isEmpty);
      expect(await VitalsStorageService.getAllGlucose(scopeToActiveProfile: false), isEmpty);
      final p = await prefs();
      expect(p.getInt('vitals_health_import_last_run_ms'), isNull,
          reason: 'a run the person said no to must not leave a "last run" behind');
      expect(p.getStringList('vitals_health_import_seen_ids'), isNull);
      expect(await VitalsHealthImport.isEnabled(), isFalse);
    });

    test('and turning it on again reads what that run would have: nothing was used up', () async {
      final read = holdTheRead();
      await VitalsHealthImport.setEnabled(true);
      final run = VitalsHealthImport.runIfEnabled(now: now, hasPermission: allowed);
      await read.reading.future;
      await VitalsHealthImport.setEnabled(false);
      read.release.complete();
      await run;

      await VitalsHealthImport.setEnabled(true);
      final again = await VitalsHealthImport.run(
        now: now,
        bpSamples: cuff(eight, 128, 82),
        glucoseSamples: [sugar(eight, 104)],
      );

      expect(again.count, 2);
    });

    test('a turn-on that comes while the stopped run is still reading is not given its answer',
        () async {
      // Off, then on at once — and the screen's "on" does a read of its own. Handed
      // the stopped run's empty answer it would say "nothing found", and the
      // readings would wait for the next start.
      final read = holdTheRead();
      await VitalsHealthImport.setEnabled(true);
      final stopping = VitalsHealthImport.runIfEnabled(now: now, hasPermission: allowed);
      await read.reading.future;
      await VitalsHealthImport.setEnabled(false);
      await VitalsHealthImport.setEnabled(true);

      final fresh = VitalsHealthImport.run(now: now);
      read.release.complete();

      expect((await stopping)!.isEmpty, isTrue);
      expect((await fresh).count, 2, reason: 'a run of its own, over the same store');
    });

    test('off between two readings: what was kept stays, and is remembered; the rest waits',
        () async {
      late AppDatabase hooked;
      hooked = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(
          _AfterFirstInsert('blood_pressure_readings', () {
        // Not awaited: the loop is the thing in the middle.
        unawaited(VitalsHealthImport.setEnabled(false));
      })));
      AppDatabase.setInstanceForTesting(hooked);
      addTearDown(hooked.close);
      await VitalsHealthImport.setEnabled(true);

      final r = await VitalsHealthImport.run(
        now: now,
        bpSamples: [...cuff(t1, 120, 80), ...cuff(t2, 125, 82), ...cuff(t3, 130, 85)],
        glucoseSamples: [sugar(t1, 99)],
      );

      expect(r.bloodPressure, hasLength(1), reason: 'the first was saved before "off"');
      expect(r.glucose, isEmpty, reason: 'and nothing after it');
      final stored = await VitalsStorageService.getAllBp(scopeToActiveProfile: false);
      expect(stored.map((b) => b.systolic), [120]);
      final p = await prefs();
      expect(p.getStringList('vitals_health_import_seen_ids'), [r.bloodPressure.single],
          reason: 'only what was dealt with: the others are for next time');
      expect(p.getInt('vitals_health_import_last_run_ms'), isNull);
    });

    test('"Delete all data" in the middle: nothing is written back, not even what was dealt with',
        () async {
      // A switch turned off keeps the ids it had dealt with. A wipe has just deleted
      // them: the list this run holds is the one that is gone, and writing it back
      // would make the next "on" skip everything the store still has.
      final hooked = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(
          _AfterFirstInsert('blood_pressure_readings', HealthImportControl.wipeBegan)));
      AppDatabase.setInstanceForTesting(hooked);
      addTearDown(hooked.close);
      addTearDown(HealthImportControl.wipeEnded);
      await VitalsHealthImport.setEnabled(true);
      final p = await prefs();
      await p.setStringList('vitals_health_import_seen_ids', ['hc_bp_old']);

      final r = await VitalsHealthImport.run(
        now: now,
        bpSamples: [...cuff(t1, 120, 80), ...cuff(t2, 125, 82)],
        glucoseSamples: const [],
      );

      expect(r.bloodPressure, hasLength(1));
      expect(p.getStringList('vitals_health_import_seen_ids'), ['hc_bp_old']);
      expect(p.getInt('vitals_health_import_last_run_ms'), isNull);
    });

    test('and the readings it left are brought in by the next run', () async {
      final hooked = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(
          _AfterFirstInsert('blood_pressure_readings', () {
        unawaited(VitalsHealthImport.setEnabled(false));
      })));
      AppDatabase.setInstanceForTesting(hooked);
      addTearDown(hooked.close);
      await VitalsHealthImport.setEnabled(true);
      final samples = [...cuff(t1, 120, 80), ...cuff(t2, 125, 82), ...cuff(t3, 130, 85)];
      await VitalsHealthImport.run(now: now, bpSamples: samples, glucoseSamples: const []);

      await VitalsHealthImport.setEnabled(true);
      final next = await VitalsHealthImport.run(
          now: now, bpSamples: samples, glucoseSamples: const []);

      expect(next.bloodPressure, hasLength(2), reason: 'the two it had not got to, not the first again');
      final stored = await VitalsStorageService.getAllBp(scopeToActiveProfile: false);
      expect(stored.map((b) => b.systolic).toSet(), {120, 125, 130});
    });

    test('a run nobody switched off is recorded as before', () async {
      await VitalsHealthImport.setEnabled(true);

      await VitalsHealthImport.run(
          now: now, bpSamples: cuff(eight, 128, 82), glucoseSamples: const []);

      final p = await prefs();
      expect(p.getInt('vitals_health_import_last_run_ms'), now.millisecondsSinceEpoch);
      expect(p.getStringList('vitals_health_import_seen_ids'), hasLength(1));
    });
  });

  group('where a read starts', () {
    test('the first run reaches back ninety days', () {
      expect(VitalsHealthImport.windowStart(lastRunMs: null, now: now),
          now.subtract(const Duration(days: 90)));
    });

    test('later runs start a week before the last, so a late reading is still found',
        () {
      final last = DateTime(2026, 9, 29, 9);
      expect(
          VitalsHealthImport.windowStart(
              lastRunMs: last.millisecondsSinceEpoch, now: now),
          last.subtract(const Duration(days: 7)));
    });
  });

  group('the weight import skips the app\'s own records too', () {
    HealthDataPoint weight(DateTime at, double kg, String source) => point(
        HealthDataType.WEIGHT, at, kg, source: source, name: 'Scale');

    test('only the other app\'s reading comes in', () async {
      final imported = await VitalsStorageService.importFromHealthConnect(samples: [
        weight(eight, 70, 'com.dlyminder.app'),
        weight(eight.add(const Duration(hours: 1)), 70.4, 'com.xiaomi.scale'),
      ]);

      expect(imported, 1);
      final stored = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(stored.single.valueKg, 70.4);
    });

    test('on Android too, where the package is in the name and the id is empty', () async {
      // Weight has no "same number, same minute" check behind it: this is the only
      // thing between a weight shared from here and the same weight imported again.
      final imported = await VitalsStorageService.importFromHealthConnect(samples: [
        point(HealthDataType.WEIGHT, eight, 70, source: 'com.dlyminder.app', android: true),
        point(HealthDataType.WEIGHT, eight.add(const Duration(hours: 1)), 70.4,
            source: 'com.xiaomi.scale', android: true),
      ]);

      expect(imported, 1);
      final stored = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(stored.single.valueKg, 70.4);
    });
  });

  test('clock is what decides "now" when none is given', () async {
    await withClock(Clock.fixed(now), () async {
      await VitalsHealthImport.run(bpSamples: cuff(eight, 128, 82));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('vitals_health_import_last_run_ms'),
          now.millisecondsSinceEpoch);
    });
  });
}
