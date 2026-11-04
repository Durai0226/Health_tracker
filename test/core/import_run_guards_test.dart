/// Two things the imports from the health store must not get wrong, whichever of
/// them is running: overlapping, and failing.
///
/// **Overlapping.** The app starts an import on its first frame and another on the
/// resume that follows it, and the 15-minute gate is only written at the END of a
/// run. The second began while the first was still reading: same ledger, same
/// samples, and — neither having written yet — no matching log to find. One
/// drink could be added twice. A caller that arrives mid-run is given that run's
/// answer.
///
/// **Failing.** A read that could not be made used to come back as an empty list,
/// and the run recorded a success and moved its window forward. Readings from the
/// stretch it never saw were then outside every later window: lost without a
/// message. "Could not look" and "nothing there" are different answers, and only
/// the second may move anything.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_health_import.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/water/services/hydration_health_sync.dart';
import 'package:tablet_remainder/features/water/services/water_health_import.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final now = DateTime(2026, 9, 30, 12);
  final ten = DateTime(2026, 9, 30, 10, 15);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    HydrationHealthSync.resetForTesting();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async {
    WaterHealthImport.readerForTesting = null;
    VitalsHealthImport.readerForTesting = null;
    await database.close();
  });

  HealthDataPoint point(
    HealthDataType type,
    DateTime at,
    num value, {
    String source = 'com.sec.android.app.shealth',
  }) =>
      HealthDataPoint(
        uuid: '$type-${at.millisecondsSinceEpoch}-$source',
        value: NumericHealthValue(numericValue: value),
        type: type,
        unit: type == HealthDataType.WATER
            ? HealthDataUnit.LITER
            : HealthDataUnit.NO_UNIT,
        dateFrom: at.subtract(const Duration(minutes: 1)),
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: source,
        sourceName: 'Samsung Health',
        recordingMethod: RecordingMethod.automatic,
      );

  HealthDataPoint drink(DateTime end, double litres) =>
      point(HealthDataType.WATER, end, litres);

  List<HealthDataPoint> cuff(DateTime at, int sys, int dia) => [
        point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, at, sys, source: 'com.omron.connect'),
        point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, at, dia, source: 'com.omron.connect'),
      ];

  Future<int> drinksOn(DateTime d) async =>
      (await WaterService.loadDataForDate(DateTime(d.year, d.month, d.day)))?.logs.length ?? 0;

  Future<Map<String, Object?>> stored() async {
    final prefs = await SharedPreferences.getInstance();
    return {for (final k in prefs.getKeys()) k: prefs.get(k)};
  }

  group('the water import', () {
    test('two runs that overlap are one: the second gets the first\'s answer', () async {
      final samples = [drink(ten, 0.25)];

      final a = WaterHealthImport.run(now: now, samples: samples);
      final b = WaterHealthImport.run(now: now, samples: samples);
      final results = await Future.wait([a, b]);

      expect(identical(results[0], results[1]), isTrue,
          reason: 'one run, so one result');
      expect(results[0].count, 1);
      expect(await drinksOn(ten), 1, reason: 'and the drink is in once');
    });

    test('and an overlap through the automatic path is the same', () async {
      await WaterHealthImport.setEnabled(true);
      final samples = [drink(ten, 0.25)];

      final results = await Future.wait([
        WaterHealthImport.runIfEnabled(
            now: now, force: true, hasPermission: () async => true, samples: samples),
        WaterHealthImport.runIfEnabled(
            now: now, force: true, hasPermission: () async => true, samples: samples),
      ]);

      expect(await drinksOn(ten), 1);
      expect(results.whereType<WaterImportResult>(), isNotEmpty);
    });

    test('once it has finished, the next run is a run of its own', () async {
      await WaterHealthImport.run(now: now, samples: [drink(ten, 0.25)]);

      final next = await WaterHealthImport.run(
          now: now.add(const Duration(hours: 1)),
          samples: [drink(ten.add(const Duration(minutes: 90)), 0.5)]);

      expect(next.count, 1);
      expect(await drinksOn(ten), 2);
    });

    test('a store that could not be read: the run throws and nothing moves', () async {
      WaterHealthImport.readerForTesting =
          (_, _) async => throw const HealthReadException('not answering');
      final before = await stored();

      await expectLater(WaterHealthImport.run(now: now),
          throwsA(isA<HealthReadException>()));

      expect(await stored(), before, reason: 'no window moved, no id remembered');
    });

    test('and the next run reads the same stretch again', () async {
      WaterHealthImport.readerForTesting =
          (_, _) async => throw const HealthReadException('not answering');
      await expectLater(WaterHealthImport.run(now: now), throwsA(isA<HealthReadException>()));

      DateTime? asked;
      WaterHealthImport.readerForTesting = (from, to) async {
        asked = from;
        return [drink(ten, 0.25)];
      };
      final result = await WaterHealthImport.run(now: now);

      expect(asked, now.subtract(WaterHealthImport.firstLookback),
          reason: 'still the first window: the failed run recorded nothing');
      expect(result.count, 1);
    });

    test('the guard is released after a failure', () async {
      WaterHealthImport.readerForTesting =
          (_, _) async => throw const HealthReadException('not answering');
      await expectLater(WaterHealthImport.run(now: now), throwsA(anything));

      WaterHealthImport.readerForTesting = (_, _) async => [drink(ten, 0.25)];

      expect((await WaterHealthImport.run(now: now)).count, 1);
    });

    test('automatically, a failure is quiet — and moves nothing', () async {
      await WaterHealthImport.setEnabled(true);
      WaterHealthImport.readerForTesting =
          (_, _) async => throw const HealthReadException('not answering');
      final before = await stored();

      final r = await WaterHealthImport.runIfEnabled(
          now: now, hasPermission: () async => true);

      expect(r, isNull);
      expect(await stored(), before);
    });

    test('nothing there is a real answer, and does move the window', () async {
      WaterHealthImport.readerForTesting = (_, _) async => const [];

      final result = await WaterHealthImport.run(now: now);

      expect(result.isEmpty, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('water_health_import_last_run_ms'),
          now.millisecondsSinceEpoch);
    });
  });

  group('the vitals import', () {
    test('two runs that overlap are one', () async {
      final samples = cuff(ten, 128, 82);

      final a = VitalsHealthImport.run(now: now, bpSamples: samples, glucoseSamples: const []);
      final b = VitalsHealthImport.run(now: now, bpSamples: samples, glucoseSamples: const []);
      final results = await Future.wait([a, b]);

      expect(identical(results[0], results[1]), isTrue);
      expect(results[0].bloodPressure, hasLength(1));
      expect(await VitalsStorageService.getAllBp(scopeToActiveProfile: false), hasLength(1));
    });

    test('once it has finished, the next run is a run of its own', () async {
      await VitalsHealthImport.run(now: now, bpSamples: cuff(ten, 128, 82), glucoseSamples: const []);

      final next = await VitalsHealthImport.run(
          now: now.add(const Duration(hours: 1)),
          bpSamples: cuff(ten.add(const Duration(minutes: 90)), 130, 84),
          glucoseSamples: const []);

      expect(next.bloodPressure, hasLength(1));
    });

    test('a store that could not be read: the run throws and nothing moves', () async {
      VitalsHealthImport.readerForTesting =
          (_, _, _) async => throw const HealthReadException('not answering');
      final before = await stored();

      await expectLater(VitalsHealthImport.run(now: now), throwsA(isA<HealthReadException>()));

      expect(await stored(), before);
    });

    test('and one reading kind failing is a failure of the run — half is not a result',
        () async {
      VitalsHealthImport.readerForTesting = (kind, from, to) async {
        if (kind == 'glucose') throw const HealthReadException('not answering');
        return cuff(ten, 128, 82);
      };
      final before = await stored();

      await expectLater(VitalsHealthImport.run(now: now), throwsA(isA<HealthReadException>()));

      expect(await stored(), before, reason: 'the blood pressure was not recorded as seen');
      expect(await VitalsStorageService.getAllBp(scopeToActiveProfile: false), isEmpty,
          reason: 'and was not half-imported');
    });

    test('the guard is released after a failure', () async {
      VitalsHealthImport.readerForTesting =
          (_, _, _) async => throw const HealthReadException('not answering');
      await expectLater(VitalsHealthImport.run(now: now), throwsA(anything));

      VitalsHealthImport.readerForTesting =
          (kind, _, _) async => kind == 'bp' ? cuff(ten, 128, 82) : const [];

      expect((await VitalsHealthImport.run(now: now)).bloodPressure, hasLength(1));
    });

    test('automatically, a failure is quiet — and moves nothing', () async {
      await VitalsHealthImport.setEnabled(true);
      VitalsHealthImport.readerForTesting =
          (_, _, _) async => throw const HealthReadException('not answering');
      final before = await stored();

      final r = await VitalsHealthImport.runIfEnabled(
          now: now, hasPermission: () async => true);

      expect(r, isNull);
      expect(await stored(), before);
    });

    test('nothing there is a real answer, and does move the window', () async {
      VitalsHealthImport.readerForTesting = (_, _, _) async => const [];

      await VitalsHealthImport.run(now: now);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('vitals_health_import_last_run_ms'),
          now.millisecondsSinceEpoch);
    });
  });

  group('the reads themselves', () {
    // On this host there is no health plugin, so the store "cannot be set up":
    // exactly the case that used to come back as an empty list.
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 9, 30);

    test('hydration says it could not be read', () {
      expect(HealthDataService.instance.readWaterSamples(from, to),
          throwsA(isA<HealthReadException>()));
    });

    test('so does blood pressure', () {
      expect(HealthDataService.instance.readBloodPressureSamples(from, to),
          throwsA(isA<HealthReadException>()));
    });

    test('and blood sugar', () {
      expect(HealthDataService.instance.readGlucoseSamples(from, to),
          throwsA(isA<HealthReadException>()));
    });

    group('with the store reachable', () {
      setUp(() => HealthDataService.instance.configuredForTesting = true);
      tearDown(() {
        HealthDataService.instance.configuredForTesting = false;
        HealthDataService.instance.pointReaderForTesting = null;
      });

      test('a read that finds nothing is an empty list — a real answer', () async {
        HealthDataService.instance.pointReaderForTesting = (_, _, _) async => const [];

        expect(await HealthDataService.instance.readWaterSamples(from, to), isEmpty);
        expect(await HealthDataService.instance.readBloodPressureSamples(from, to), isEmpty);
      });

      test('a read that finds something returns it', () async {
        final d = drink(DateTime(2026, 9, 20, 10), 0.25);
        HealthDataService.instance.pointReaderForTesting = (_, _, _) async => [d];

        expect(await HealthDataService.instance.readWaterSamples(from, to), [d]);
      });

      test('a read that throws is a failure, not an empty list', () async {
        HealthDataService.instance.pointReaderForTesting =
            (_, _, _) async => throw StateError('Health Connect is busy');

        await expectLater(HealthDataService.instance.readWaterSamples(from, to),
            throwsA(isA<HealthReadException>()));
        await expectLater(HealthDataService.instance.readGlucoseSamples(from, to),
            throwsA(isA<HealthReadException>()));
      });

      test('half a blood pressure reading failing fails the read: half is no reading', () async {
        HealthDataService.instance.pointReaderForTesting = (type, _, _) async {
          if (type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC) {
            throw StateError('diastolic would not read');
          }
          return [point(type, DateTime(2026, 9, 20, 8), 128)];
        };

        await expectLater(HealthDataService.instance.readBloodPressureSamples(from, to),
            throwsA(isA<HealthReadException>()));
      });

      test('the message says how many of the reads failed', () async {
        HealthDataService.instance.pointReaderForTesting =
            (_, _, _) async => throw StateError('x');

        await expectLater(
            HealthDataService.instance.readBloodPressureSamples(from, to),
            throwsA(predicate((e) => '$e'.contains('2 of 2'))));
      });

      test('a read nothing waits on stays soft even when it fails', () async {
        HealthDataService.instance.pointReaderForTesting =
            (_, _, _) async => throw StateError('x');

        expect(await HealthDataService.instance.readWeightSamples(from, to), isEmpty);
      });
    });

    test('a read nothing waits on is still soft: weight comes back empty', () async {
      expect(await HealthDataService.instance.readWeightSamples(from, to), isEmpty);
    });

    test('the exception says what happened', () {
      expect(const HealthReadException('x').toString(), 'HealthReadException: x');
    });
  });
}
