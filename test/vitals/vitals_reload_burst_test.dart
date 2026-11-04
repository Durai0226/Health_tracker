/// A burst of readings is one reload, not one each.
///
/// The blood-pressure and blood-sugar screens follow the store's `revision`, and
/// every save bumps it. An import of a few hundred readings saves them one at a
/// time, so the screen on which it was started began a few hundred overlapping
/// reloads — each reading the whole table and rebuilding the whole list — while the
/// import was still writing. Two things stop that: a bulk save tells listeners once
/// when it is done, and a screen runs one load at a time with whatever arrived
/// meanwhile as ONE more.
library;

import 'dart:async';

import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/services/vitals_health_import.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// Counts the selects made on each table, and can hold them back.
class _Selects extends QueryInterceptor {
  final statements = <String>[];

  /// While set, a select on [heldTable] waits for it.
  Completer<void>? gate;
  String? heldTable;

  int on(String table) => statements.where((s) => s.contains(table)).length;

  @override
  Future<List<Map<String, Object?>>> runSelect(
      QueryExecutor executor, String statement, List<Object?> args) async {
    statements.add(statement);
    final g = gate;
    if (g != null && heldTable != null && statement.contains(heldTable!)) {
      await g.future;
    }
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late _Selects selects;
  final day = DateTime(2026, 9, 30, 8);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    selects = _Selects();
    db = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(selects));
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async {
    selects.gate = null;
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  BloodPressureReading bp(int i) => BloodPressureReading(
        id: 'bp$i',
        systolic: 100 + i,
        diastolic: 60 + (i % 30),
        takenAt: day.add(Duration(minutes: i)),
        createdAt: day,
      );

  GlucoseReading sugar(int i) => GlucoseReading(
        id: 'g$i',
        valueMgdl: 80 + i,
        takenAt: day.add(Duration(minutes: i)),
        createdAt: day,
      );

  HealthDataPoint point(HealthDataType type, DateTime at, num value,
          {String source = 'com.omron.connect'}) =>
      HealthDataPoint(
        uuid: '$type-${at.millisecondsSinceEpoch}-$source',
        value: NumericHealthValue(numericValue: value),
        type: type,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: at,
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: source,
        sourceName: 'Omron connect',
        recordingMethod: RecordingMethod.automatic,
      );

  /// How many times listeners are told, while [body] runs.
  Future<int> bumpsDuring(Future<void> Function() body) async {
    var n = 0;
    void count() => n++;
    VitalsStorageService.revision.addListener(count);
    try {
      await body();
    } finally {
      VitalsStorageService.revision.removeListener(count);
    }
    return n;
  }

  group('a bulk save tells listeners once', () {
    test('outside a batch every save is its own notice, as ever', () async {
      final bumps = await bumpsDuring(() async {
        for (var i = 0; i < 5; i++) {
          await VitalsStorageService.saveBp(bp(i), stampActiveProfile: false);
        }
      });

      expect(bumps, 5);
    });

    test('inside one, many saves are a single notice, after the last', () async {
      var seenWhenTold = -1;
      void check() async => seenWhenTold =
          (await VitalsStorageService.getAllBp(scopeToActiveProfile: false)).length;

      final bumps = await bumpsDuring(() async {
        VitalsStorageService.revision.addListener(check);
        await VitalsStorageService.batch(() async {
          for (var i = 0; i < 40; i++) {
            await VitalsStorageService.saveBp(bp(i), stampActiveProfile: false);
          }
        });
        VitalsStorageService.revision.removeListener(check);
      });
      await Future<void>.delayed(Duration.zero);

      expect(bumps, 1);
      expect(seenWhenTold, 40, reason: 'told when all of it is there, not before');
    });

    test('nothing saved, nothing said', () async {
      expect(await bumpsDuring(() => VitalsStorageService.batch(() async {})), 0);
    });

    test('a batch inside a batch speaks once, when the outer one ends', () async {
      final bumps = await bumpsDuring(() => VitalsStorageService.batch(() async {
            await VitalsStorageService.saveBp(bp(1), stampActiveProfile: false);
            await VitalsStorageService.batch(() async {
              await VitalsStorageService.saveBp(bp(2), stampActiveProfile: false);
            });
            await VitalsStorageService.saveBp(bp(3), stampActiveProfile: false);
          }));

      expect(bumps, 1);
    });

    test('two at once speak once, when both are done', () async {
      final bumps = await bumpsDuring(() => Future.wait([
            VitalsStorageService.batch(() async {
              await VitalsStorageService.saveBp(bp(1), stampActiveProfile: false);
            }),
            VitalsStorageService.batch(() async {
              await VitalsStorageService.saveGlucose(sugar(1), stampActiveProfile: false);
            }),
          ]));

      expect(bumps, 1);
    });

    test('one that throws rolls ALL of it back, rethrows, and is not left "open"', () async {
      Object? error;
      final bumps = await bumpsDuring(() async {
        try {
          await VitalsStorageService.batch(() async {
            await VitalsStorageService.saveBp(bp(1), stampActiveProfile: false);
            await VitalsStorageService.saveBp(bp(2), stampActiveProfile: false);
            throw StateError('half way');
          });
        } catch (e) {
          error = e;
        }
      });

      expect(error, isA<StateError>());
      expect(await VitalsStorageService.getAllBp(scopeToActiveProfile: false), isEmpty,
          reason: 'nothing half done');
      expect(bumps, lessThanOrEqualTo(1),
          reason: 'listeners may be told; a reload that finds nothing changed is cheap');
      // And it is not left "inside a batch": the next save speaks for itself.
      expect(
          await bumpsDuring(() =>
              VitalsStorageService.saveBp(bp(3), stampActiveProfile: false)),
          1);
    });

    test('a batch is one transaction: a reader outside it sees all or none', () async {
      final sawCounts = <int>[];
      final reading = VitalsStorageService.batch(() async {
        for (var i = 0; i < 20; i++) {
          await VitalsStorageService.saveBp(bp(i), stampActiveProfile: false);
        }
      });
      // Meanwhile something else reads, as the screen would.
      final read = VitalsStorageService.getAllBp(scopeToActiveProfile: false)
          .then((rows) => sawCounts.add(rows.length));
      await Future.wait([reading, read]);

      expect(sawCounts.single, anyOf(0, 20), reason: 'never part of it');
    });

    test('and hands back what the body returns', () async {
      expect(await VitalsStorageService.batch(() async => 42), 42);
    });
  });

  group('the bulk paths use it', () {
    test('the import from the health store: 60 readings, one notice', () async {
      final cuff = [
        for (var i = 0; i < 40; i++) ...[
          point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, day.add(Duration(minutes: i * 10)), 110 + i),
          point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, day.add(Duration(minutes: i * 10)), 70 + i % 20),
        ]
      ];
      final meter = [
        for (var i = 0; i < 20; i++)
          point(HealthDataType.BLOOD_GLUCOSE, day.add(Duration(minutes: i * 10)), 90 + i,
              source: 'com.glucose.meter'),
      ];
      late VitalsImportResult result;

      final bumps = await bumpsDuring(() async {
        result = await VitalsHealthImport.run(
            now: DateTime(2026, 9, 30, 20), bpSamples: cuff, glucoseSamples: meter);
      });

      expect(result.bloodPressure, hasLength(40), reason: 'the premise');
      expect(result.glucose, hasLength(20), reason: 'the premise');
      expect(bumps, 1);
    });

    test('an import that finds nothing new says nothing', () async {
      final bumps = await bumpsDuring(() async {
        await VitalsHealthImport.run(
            now: DateTime(2026, 9, 30, 20),
            bpSamples: const [],
            glucoseSamples: const []);
      });

      expect(bumps, 0);
    });

    test('the weight import', () async {
      final scale = [
        for (var i = 0; i < 25; i++)
          point(HealthDataType.WEIGHT, day.add(Duration(days: i)), 70 + i / 10,
              source: 'com.withings.wiscale2'),
      ];
      var imported = 0;

      final bumps = await bumpsDuring(() async {
        imported = await VitalsStorageService.importFromHealthConnect(samples: scale);
      });

      expect(imported, 25, reason: 'the premise');
      expect(bumps, 1);
    });

    test('a restore from a backup', () async {
      final backup = {
        'bloodPressure': [for (var i = 0; i < 20; i++) bp(i).toJson()],
        'glucose': [for (var i = 0; i < 10; i++) sugar(i).toJson()],
        'weight': [
          for (var i = 0; i < 5; i++)
            WeightReading(id: 'w$i', valueKg: 70.0 + i, takenAt: day, createdAt: day).toJson()
        ],
        'mood': [
          for (var i = 0; i < 5; i++)
            MoodEntry(id: 'm$i', moodIndex: 2, takenAt: day.add(Duration(hours: i)), createdAt: day)
                .toJson()
        ],
      };

      final bumps = await bumpsDuring(() => VitalsStorageService.importJson(backup));

      expect(bumps, 1);
      expect(await VitalsStorageService.getAllBp(scopeToActiveProfile: false), hasLength(20));
      expect(await VitalsStorageService.getAllGlucose(scopeToActiveProfile: false), hasLength(10));
    });
  });

  group('a screen open while readings arrive', () {
    Future<void> settle(WidgetTester tester, [int ms = 600]) async {
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        for (var t = 0; t < ms; t += 100) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
    }

    Future<void> show(WidgetTester tester, Widget home) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 3000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
        await settle(tester, 800);
      } finally {
        FlutterError.onError = prev;
      }
    }

    testWidgets('blood pressure: 60 saves while a load is under way are ONE more load',
        (tester) async {
      await show(tester, const BloodPressureScreen());
      final before = selects.on('blood_pressure_readings');
      expect(before, greaterThan(0), reason: 'the premise: the first load happened');

      // Loads are held up, as a slow phone holds them, while the saves go in.
      selects
        ..heldTable = 'blood_pressure_readings'
        ..gate = Completer<void>();
      for (var i = 0; i < 60; i++) {
        await VitalsStorageService.saveBp(bp(i), stampActiveProfile: false);
      }
      selects.gate!.complete();
      await settle(tester);

      final loads = selects.on('blood_pressure_readings') - before;
      expect(loads, lessThanOrEqualTo(3),
          reason: 'one under way and one behind it — not one per save (was 60)');
      expect(loads, greaterThanOrEqualTo(1));
      // And nothing was missed: the screen ends on everything that was saved.
      expect(find.textContaining('159/'), findsWidgets);
    });

    testWidgets('blood sugar: the same', (tester) async {
      await show(tester, const BloodSugarScreen());
      final before = selects.on('glucose_readings');
      expect(before, greaterThan(0), reason: 'the premise: the first load happened');

      selects
        ..heldTable = 'glucose_readings'
        ..gate = Completer<void>();
      for (var i = 0; i < 60; i++) {
        await VitalsStorageService.saveGlucose(sugar(i), stampActiveProfile: false);
      }
      selects.gate!.complete();
      await settle(tester);

      final loads = selects.on('glucose_readings') - before;
      expect(loads, lessThanOrEqualTo(3));
      expect(loads, greaterThanOrEqualTo(1));
      expect(find.textContaining('139'), findsWidgets);
    });

    testWidgets('an import started with the screen open reloads it once', (tester) async {
      await show(tester, const BloodPressureScreen());
      final before = selects.on('blood_pressure_readings');
      final cuff = [
        for (var i = 0; i < 50; i++) ...[
          point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, day.add(Duration(minutes: i * 10)), 110 + i),
          point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, day.add(Duration(minutes: i * 10)), 70 + i % 20),
        ]
      ];

      await VitalsHealthImport.run(
          now: DateTime(2026, 9, 30, 20), bpSamples: cuff, glucoseSamples: const []);
      await settle(tester);

      // The import itself reads the table once to spot duplicates; the screen
      // reloads once for the whole import.
      expect(selects.on('blood_pressure_readings') - before, lessThanOrEqualTo(2));
      expect(find.textContaining('159/'), findsWidgets);
    });
  });
}
