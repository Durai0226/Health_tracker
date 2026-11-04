/// Drinks logged in another app count toward today — once the person has asked
/// for that — without doubling what they typed in, or sending it back out.
///
/// The platform read cannot run headless, so the samples are handed in. What is
/// worth proving is everything around it: which samples are drinks, that the
/// app's own never come back, that nothing is added twice, and that a drink the
/// person removed stays removed.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/health_import_control.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/services/hydration_health_sync.dart';
import 'package:tablet_remainder/features/water/services/water_health_import.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

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

/// Runs [then] once, inside the first select from a table whose name is in the
/// statement — once [armed] — so that something happens while a read is awaited.
class _AfterFirstSelect extends QueryInterceptor {
  _AfterFirstSelect(this.table, this.then);

  final String table;
  final void Function() then;
  bool armed = false;
  var _fired = false;

  @override
  Future<List<Map<String, Object?>>> runSelect(
      QueryExecutor executor, String statement, List<Object?> args) async {
    final rows = await super.runSelect(executor, statement, args);
    if (armed && !_fired && statement.contains(table)) {
      _fired = true;
      then();
    }
    return rows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final now = DateTime(2026, 9, 30, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    HydrationHealthSync.resetForTesting();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  /// A drink as the plugin hands it over. On iPhone `sourceId` is the bundle id and
  /// `sourceName` what the person sees; on Android `sourceId` is EMPTY and
  /// `sourceName` is the package ([android]).
  HealthDataPoint drink(
    DateTime end,
    double litres, {
    String source = 'com.sec.android.app.shealth',
    String? uuid,
    HealthDataType type = HealthDataType.WATER,
    HealthValue? raw,
    bool android = false,
  }) =>
      HealthDataPoint(
        uuid: uuid ?? 'w-${end.millisecondsSinceEpoch}-$source',
        value: raw ?? NumericHealthValue(numericValue: litres),
        type: type,
        unit: HealthDataUnit.LITER,
        dateFrom: end.subtract(const Duration(minutes: 1)),
        dateTo: end,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: android ? '' : source,
        sourceName: android ? source : 'Samsung Health',
        recordingMethod: RecordingMethod.automatic,
      );

  final ten = DateTime(2026, 9, 30, 10, 15);
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<List<String>> logIds(DateTime d) async =>
      [for (final l in (await WaterService.loadDataForDate(day(d)))?.logs ?? []) l.id];

  group('drinks in a read', () {
    test('litres become millilitres, at the time the drink ended', () {
      final got = WaterHealthImport.drinks([drink(ten, 0.35)]);
      expect(got.single.amountMl, 350);
      expect(got.single.at, ten);
    });

    test('the same sample always gets the same id', () {
      final a = WaterHealthImport.drinks([drink(ten, 0.25, uuid: 'abc-123')]).single.id;
      final b = WaterHealthImport.drinks([drink(ten, 0.25, uuid: 'abc-123')]).single.id;
      expect(a, b);
      expect(a, 'hc_water_abc-123');
      expect(WaterHealthImport.isImported(a), isTrue);
      expect(WaterHealthImport.isImported('3f2a-uuid-of-a-typed-drink'), isFalse);
    });

    test('a sample with no id still gets a stable one, apart from another app\'s',
        () {
      final a = WaterHealthImport.drinks([drink(ten, 0.25, uuid: '')]).single.id;
      final b = WaterHealthImport.drinks([drink(ten, 0.25, uuid: '')]).single.id;
      final c = WaterHealthImport.drinks(
          [drink(ten, 0.25, uuid: '', source: 'com.fitbit.FitbitMobile')]).single.id;
      expect(a, b);
      expect(a, isNot(c));
      expect(a, startsWith('hc_water_'));
    });

    test('what this app wrote itself is not read back', () {
      expect(WaterHealthImport.drinks([drink(ten, 0.25, source: 'com.dlyminder.app')]),
          isEmpty);
    });

    test('nor on Android, where the package is in the name and the id is empty', () {
      expect(
          WaterHealthImport.drinks(
              [drink(ten, 0.25, source: 'com.dlyminder.app', android: true)]),
          isEmpty);
      expect(
          WaterHealthImport.drinks(
              [drink(ten, 0.25, source: 'com.sec.android.app.shealth', android: true)]),
          hasLength(1));
    });

    test('a sample with no id from two Android apps gets two ids', () {
      final a = WaterHealthImport.drinks(
          [drink(ten, 0.25, uuid: '', source: 'com.a', android: true)]).single.id;
      final b = WaterHealthImport.drinks(
          [drink(ten, 0.25, uuid: '', source: 'com.b', android: true)]).single.id;

      expect(a, isNot(b));
    });

    test('a sliver and a day\'s total in one record are not drinks', () {
      expect(
          WaterHealthImport.drinks([
            drink(ten, 0.005), // 5 ml
            drink(ten.add(const Duration(minutes: 5)), 5.5), // 5.5 L
          ]),
          isEmpty);
    });

    test('the limits are the ones named', () {
      expect(WaterHealthImport.drinks([drink(ten, 0.010)]), hasLength(1)); // 10 ml
      expect(WaterHealthImport.drinks([drink(ten, 5.0)]), hasLength(1)); // 5000 ml
    });

    test('other kinds of sample, and samples that are not numbers, are ignored', () {
      expect(
          WaterHealthImport.drinks([
            drink(ten, 0.25, type: HealthDataType.STEPS),
            drink(ten, 0.25,
                raw: WorkoutHealthValue(
                    workoutActivityType: HealthWorkoutActivityType.WALKING)),
          ]),
          isEmpty);
    });

    test('oldest first', () {
      final got = WaterHealthImport.drinks([
        drink(ten.add(const Duration(hours: 2)), 0.2),
        drink(ten, 0.3),
      ]);
      expect([for (final d in got) d.amountMl], [300, 200]);
    });
  });

  group('what the import says', () {
    test('counts the drinks and the millilitres', () {
      final r = WaterImportResult([
        (date: day(ten), id: 'a', amountMl: 350),
        (date: day(ten), id: 'b', amountMl: 300),
      ]);
      expect(r.describe(), '2 drinks (650 ml)');
      expect(WaterImportResult([(date: day(ten), id: 'a', amountMl: 250)]).describe(),
          '1 drink (250 ml)');
      expect(const WaterImportResult().isEmpty, isTrue);
    });
  });

  group('keeping the drinks', () {
    test('a drink lands as plain water, on its own day, under its own id, and counts',
        () async {
      final r = await WaterHealthImport.run(
          now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);

      expect(r.count, 1);
      final data = (await WaterService.loadDataForDate(day(ten)))!;
      final log = data.logs.single;
      expect(log.id, 'hc_water_abc');
      expect(log.amountMl, 350);
      expect(log.beverageId, 'water');
      expect(log.effectiveHydrationMl, 350);
      expect(log.time, ten);
      expect(data.totalIntakeMl, 350, reason: 'it counts toward the day');
    });

    test('drinks either side of midnight stay on their own days', () async {
      await WaterHealthImport.run(now: now, samples: [
        drink(DateTime(2026, 9, 29, 23, 50), 0.2, uuid: 'late'),
        drink(DateTime(2026, 9, 30, 0, 10), 0.3, uuid: 'early'),
      ]);

      expect(await logIds(DateTime(2026, 9, 29)), ['hc_water_late']);
      expect(await logIds(DateTime(2026, 9, 30)), ['hc_water_early']);
    });

    test('a drink already typed in — same amount, same minute — is not added again',
        () async {
      await WaterService.addWaterLogForDate(
          date: day(ten),
          amountMl: 350,
          beverage: BeverageType.defaultBeverages.first,
          time: ten.add(const Duration(seconds: 90)));

      final r = await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35)]);

      expect(r.isEmpty, isTrue);
      expect((await logIds(ten)), hasLength(1));
    });

    test('but another amount, or another time, is another drink', () async {
      await WaterService.addWaterLogForDate(
          date: day(ten),
          amountMl: 350,
          beverage: BeverageType.defaultBeverages.first,
          time: ten);

      final r = await WaterHealthImport.run(now: now, samples: [
        drink(ten, 0.30, uuid: 'other-amount'),
        drink(ten.add(const Duration(minutes: 10)), 0.35, uuid: 'other-time'),
      ]);

      expect(r.count, 2);
    });

    group('two drinks that look alike', () {
      // A smart bottle that saves two 250 ml drinks a minute and a half apart has
      // saved two. Checked against everything already on the day, the second was
      // taken for a copy of the first — which the same run had just added — and,
      // its id being remembered, 250 ml was never counted.
      test('from the health store are two drinks, in one read', () async {
        final r = await WaterHealthImport.run(now: now, samples: [
          drink(ten, 0.25, uuid: 'first'),
          drink(ten.add(const Duration(seconds: 90)), 0.25, uuid: 'second'),
        ]);

        expect(r.count, 2);
        expect(await logIds(ten), containsAll(['hc_water_first', 'hc_water_second']));
      });

      test('and in two reads, the second arriving later', () async {
        await WaterHealthImport.run(now: now, samples: [drink(ten, 0.25, uuid: 'first')]);

        final later = await WaterHealthImport.run(
            now: now.add(const Duration(hours: 1)),
            samples: [drink(ten.add(const Duration(seconds: 90)), 0.25, uuid: 'second')]);

        expect(later.count, 1);
        expect(await logIds(ten), containsAll(['hc_water_first', 'hc_water_second']));
      });

      test('neither is lost for good: the second is not remembered as seen unless it was kept',
          () async {
        await WaterHealthImport.run(now: now, samples: [
          drink(ten, 0.25, uuid: 'first'),
          drink(ten.add(const Duration(seconds: 90)), 0.25, uuid: 'second'),
        ]);

        final again = await WaterHealthImport.run(now: now, samples: [
          drink(ten, 0.25, uuid: 'first'),
          drink(ten.add(const Duration(seconds: 90)), 0.25, uuid: 'second'),
        ]);

        expect(again.isEmpty, isTrue, reason: 'and running it again still adds nothing');
        expect(await logIds(ten), hasLength(2));
      });

      test('but a drink the person typed in is still taken for the same one', () async {
        await WaterService.addWaterLogForDate(
            date: day(ten),
            amountMl: 250,
            beverage: BeverageType.defaultBeverages.first,
            time: ten);

        final r = await WaterHealthImport.run(now: now, samples: [
          drink(ten.add(const Duration(seconds: 30)), 0.25, uuid: 'same-glass'),
        ]);

        expect(r.isEmpty, isTrue);
      });
    });

    test('a drink that is already there under its id is not added a second time', () async {
      // The ledger is written at the end of a run. A run that was killed after saving
      // a drink and before that, or a phone restored from a backup — the ledger is
      // not in one — meets the same sample again with nothing remembered about it.
      await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('water_health_import_seen_ids');

      final again =
          await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);

      expect(again.isEmpty, isTrue);
      expect(await logIds(ten), ['hc_water_abc'], reason: 'one drink, not two');
      final day = await WaterService.loadDataForDate(DateTime(ten.year, ten.month, ten.day));
      expect(day!.logs.fold<int>(0, (sum, l) => sum + l.amountMl), 350,
          reason: 'and the day\'s total is one drink\'s');
      expect(prefs.getStringList('water_health_import_seen_ids'), ['hc_water_abc'],
          reason: 'remembered now');
    });

    test('running again over the same samples adds nothing', () async {
      await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);
      final again =
          await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);

      expect(again.isEmpty, isTrue);
      expect(await logIds(ten), ['hc_water_abc']);
    });

    test('a drink the person deleted does not come back', () async {
      await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);
      await WaterService.removeWaterLogForDate(day(ten), 'hc_water_abc');
      expect(await logIds(ten), isEmpty);

      final again =
          await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);

      expect(again.isEmpty, isTrue);
      expect(await logIds(ten), isEmpty);
    });

    test('the app\'s own drinks are never kept', () async {
      final r = await WaterHealthImport.run(
          now: now, samples: [drink(ten, 0.35, source: 'com.dlyminder.app')]);

      expect(r.isEmpty, isTrue);
      expect(await logIds(ten), isEmpty);
    });

    test('Undo takes back what the import kept, and only that', () async {
      await WaterService.addWaterLogForDate(
          date: day(ten),
          amountMl: 200,
          beverage: BeverageType.defaultBeverages.first,
          time: DateTime(2026, 9, 30, 8),
          id: 'mine');
      final r = await WaterHealthImport.run(now: now, samples: [
        drink(ten, 0.35, uuid: 'abc'),
        drink(DateTime(2026, 9, 29, 20), 0.25, uuid: 'yesterday'),
      ]);
      expect(r.count, 2);

      await WaterHealthImport.undo(r);

      expect(await logIds(ten), ['mine']);
      expect(await logIds(DateTime(2026, 9, 29)), isEmpty);
    });

    test('and an Undone drink is not fetched again', () async {
      final r = await WaterHealthImport.run(
          now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);
      await WaterHealthImport.undo(r);

      final again =
          await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);

      expect(again.isEmpty, isTrue);
    });

    test('it is not written back to the health store', () async {
      // Sharing is on and the plugin answers "yes" to everything: a drink that
      // came in and went straight back out would show as a write call, under this
      // app's own name, doubling it for every other app that reads the store.
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
      await HydrationHealthSync.setEnabled(true);

      await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35, uuid: 'abc')]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(calls.where((c) => c.toLowerCase().contains('write')), isEmpty);
    });

    test('but a drink typed in here is still written out, as before', () async {
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
      await HydrationHealthSync.setEnabled(true);

      await WaterService.addWaterLogForDate(
          date: day(ten),
          amountMl: 250,
          beverage: BeverageType.defaultBeverages.first,
          time: ten);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(calls, isNotEmpty,
          reason: 'the write-through is untouched for a drink logged here');
    });
  });

  group('when it runs', () {
    Future<bool> allowed() async => true;
    Future<bool> refused() async => false;

    test('off until the person turns it on', () async {
      expect(await WaterHealthImport.isEnabled(), isFalse);
      final r = await WaterHealthImport.runIfEnabled(
          now: now, hasPermission: allowed, samples: [drink(ten, 0.35)]);
      expect(r, isNull);
      expect(await logIds(ten), isEmpty);
    });

    test('on but the permission is gone: does not run', () async {
      await WaterHealthImport.setEnabled(true);
      final r = await WaterHealthImport.runIfEnabled(
          now: now, hasPermission: refused, samples: [drink(ten, 0.35)]);
      expect(r, isNull);
      expect(await logIds(ten), isEmpty);
    });

    test('on and allowed: brings the drinks in', () async {
      await WaterHealthImport.setEnabled(true);
      final r = await WaterHealthImport.runIfEnabled(
          now: now, hasPermission: allowed, samples: [drink(ten, 0.35)]);
      expect(r!.count, 1);
    });

    test('not twice within a quarter of an hour, unless forced', () async {
      await WaterHealthImport.setEnabled(true);
      await WaterHealthImport.runIfEnabled(
          now: now, hasPermission: allowed, samples: [drink(ten, 0.35)]);

      final soon = now.add(const Duration(minutes: 14));
      final tooSoon = await WaterHealthImport.runIfEnabled(
          now: soon,
          hasPermission: allowed,
          samples: [drink(soon.subtract(const Duration(minutes: 2)), 0.2, uuid: 'x')]);
      expect(tooSoon, isNull);

      final forced = await WaterHealthImport.runIfEnabled(
          force: true,
          now: soon,
          hasPermission: allowed,
          samples: [drink(soon.subtract(const Duration(minutes: 2)), 0.2, uuid: 'x')]);
      expect(forced!.count, 1);

      final later = soon.add(const Duration(minutes: 16));
      final afterGap = await WaterHealthImport.runIfEnabled(
          now: later,
          hasPermission: allowed,
          samples: [drink(later.subtract(const Duration(minutes: 2)), 0.3, uuid: 'y')]);
      expect(afterGap!.count, 1);
    });

    test('a health store that throws does not stop the app: null', () async {
      await WaterHealthImport.setEnabled(true);
      final r = await WaterHealthImport.runIfEnabled(
          now: now, hasPermission: () async => throw StateError('no provider'));
      expect(r, isNull);
    });

    test('switching it off forgets when it last ran', () async {
      await WaterHealthImport.setEnabled(true);
      await WaterHealthImport.runIfEnabled(
          now: now, hasPermission: allowed, samples: const []);
      await WaterHealthImport.setEnabled(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('water_health_import_last_run_ms'), isNull);
    });
  });

  group('turned off while it runs', () {
    Future<bool> allowed() async => true;

    final nine = DateTime(2026, 9, 30, 9, 5);
    final eleven = DateTime(2026, 9, 30, 11, 5);

    /// A read of the health store that does not come back until it is let go.
    ({Completer<void> reading, Completer<void> release}) holdTheRead(
        List<HealthDataPoint> returns) {
      final reading = Completer<void>();
      final release = Completer<void>();
      WaterHealthImport.readerForTesting = (from, to) async {
        if (!reading.isCompleted) reading.complete();
        await release.future;
        return returns;
      };
      addTearDown(() => WaterHealthImport.readerForTesting = null);
      return (reading: reading, release: release);
    }

    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

    test('off while the store is being read: nothing is kept, nothing remembered, no run recorded',
        () async {
      final read = holdTheRead([drink(ten, 0.35)]);
      await WaterHealthImport.setEnabled(true);
      final run = WaterHealthImport.runIfEnabled(now: now, hasPermission: allowed);
      await read.reading.future;

      await WaterHealthImport.setEnabled(false);
      read.release.complete();
      final result = await run;

      expect(result!.isEmpty, isTrue);
      expect(await logIds(ten), isEmpty);
      final p = await prefs();
      expect(p.getInt('water_health_import_last_run_ms'), isNull,
          reason: 'a run the person said no to must not leave a "last run" behind');
      expect(p.getStringList('water_health_import_seen_ids'), isNull);
      expect(await WaterHealthImport.isEnabled(), isFalse);
    });

    test('and turning it on again brings that drink in: nothing was used up', () async {
      final read = holdTheRead([drink(ten, 0.35)]);
      await WaterHealthImport.setEnabled(true);
      final run = WaterHealthImport.runIfEnabled(now: now, hasPermission: allowed);
      await read.reading.future;
      await WaterHealthImport.setEnabled(false);
      read.release.complete();
      await run;

      await WaterHealthImport.setEnabled(true);
      final again = await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35)]);

      expect(again.count, 1);
    });

    test('a turn-on that comes while the stopped run is still reading is not given its answer',
        () async {
      // Off, then on at once — and the screen's "on" does a read of its own. Handed
      // the stopped run's empty answer it would say "nothing found", and the drinks
      // would wait for the next start.
      final read = holdTheRead([drink(ten, 0.35)]);
      await WaterHealthImport.setEnabled(true);
      final stopping = WaterHealthImport.runIfEnabled(now: now, hasPermission: allowed);
      await read.reading.future;
      await WaterHealthImport.setEnabled(false);
      await WaterHealthImport.setEnabled(true);

      final fresh = WaterHealthImport.run(now: now);
      read.release.complete();

      expect((await stopping)!.isEmpty, isTrue);
      expect((await fresh).count, 1, reason: 'a run of its own, over the same store');
    });

    test('off between two drinks: what was kept stays, and is remembered; the rest waits',
        () async {
      final hooked = db.AppDatabase.forTesting(NativeDatabase.memory().interceptWith(
          _AfterFirstInsert('enhanced_water_logs', () {
        // Not awaited: the loop is the thing in the middle.
        unawaited(WaterHealthImport.setEnabled(false));
      })));
      db.AppDatabase.setInstanceForTesting(hooked);
      addTearDown(hooked.close);
      WaterService.clearInMemory();
      await WaterService.resetForTesting();
      await WaterService.init();
      await WaterHealthImport.setEnabled(true);

      final r = await WaterHealthImport.run(now: now, samples: [
        drink(nine, 0.2, uuid: 'a'),
        drink(ten, 0.3, uuid: 'b'),
        drink(eleven, 0.4, uuid: 'c'),
      ]);

      expect(r.logs.map((l) => l.amountMl), [200], reason: 'the first, saved before "off"');
      expect(await logIds(ten), ['hc_water_a']);
      final p = await prefs();
      expect(p.getStringList('water_health_import_seen_ids'), ['hc_water_a'],
          reason: 'only what was dealt with: the others are for next time');
      expect(p.getInt('water_health_import_last_run_ms'), isNull);
    });

    test('"Delete all data" in the middle: nothing is written back, not even what was dealt with',
        () async {
      // A switch turned off keeps the ids it had dealt with. A wipe has just deleted
      // them: the list this run holds is the one that is gone, and writing it back
      // would make the next "on" skip everything the store still has.
      final hooked = db.AppDatabase.forTesting(NativeDatabase.memory().interceptWith(
          _AfterFirstInsert('enhanced_water_logs', HealthImportControl.wipeBegan)));
      db.AppDatabase.setInstanceForTesting(hooked);
      addTearDown(hooked.close);
      addTearDown(HealthImportControl.wipeEnded);
      WaterService.clearInMemory();
      await WaterService.resetForTesting();
      await WaterService.init();
      await WaterHealthImport.setEnabled(true);
      final p = await prefs();
      await p.setStringList('water_health_import_seen_ids', ['hc_water_old']);

      final r = await WaterHealthImport.run(now: now, samples: [
        drink(nine, 0.2, uuid: 'a'),
        drink(ten, 0.3, uuid: 'b'),
      ]);

      expect(r.logs, hasLength(1), reason: 'the first was saved before the wipe began');
      expect(p.getStringList('water_health_import_seen_ids'), ['hc_water_old']);
      expect(p.getInt('water_health_import_last_run_ms'), isNull);
    });

    test('off while the day is being looked at: that drink is not kept either', () async {
      // The look at the day is an await of its own, between the check that the person
      // still wants this and the write — and the switch can go off inside it.
      final hook = _AfterFirstSelect('daily_water_data', () {
        unawaited(WaterHealthImport.setEnabled(false));
      });
      final hooked = db.AppDatabase.forTesting(NativeDatabase.memory().interceptWith(hook));
      db.AppDatabase.setInstanceForTesting(hooked);
      addTearDown(hooked.close);
      WaterService.clearInMemory();
      await WaterService.resetForTesting();
      await WaterService.init();
      await WaterHealthImport.setEnabled(true);
      hook.armed = true;

      final r = await WaterHealthImport.run(now: now, samples: [drink(ten, 0.3, uuid: 'b')]);

      expect(r.isEmpty, isTrue);
      expect(await logIds(ten), isEmpty);
      final p = await prefs();
      expect(p.getStringList('water_health_import_seen_ids'), anyOf(isNull, isEmpty),
          reason: 'it was not dealt with, so it is not remembered as seen');
      expect(p.getInt('water_health_import_last_run_ms'), isNull);
    });

    test('and the drinks it left are brought in by the next run, the first not again', () async {
      final hooked = db.AppDatabase.forTesting(NativeDatabase.memory().interceptWith(
          _AfterFirstInsert('enhanced_water_logs', () {
        unawaited(WaterHealthImport.setEnabled(false));
      })));
      db.AppDatabase.setInstanceForTesting(hooked);
      addTearDown(hooked.close);
      WaterService.clearInMemory();
      await WaterService.resetForTesting();
      await WaterService.init();
      await WaterHealthImport.setEnabled(true);
      final samples = [
        drink(nine, 0.2, uuid: 'a'),
        drink(ten, 0.3, uuid: 'b'),
        drink(eleven, 0.4, uuid: 'c'),
      ];
      await WaterHealthImport.run(now: now, samples: samples);

      await WaterHealthImport.setEnabled(true);
      final next = await WaterHealthImport.run(now: now, samples: samples);

      expect(next.logs.map((l) => l.amountMl), [300, 400]);
      expect(await logIds(ten), ['hc_water_a', 'hc_water_b', 'hc_water_c']);
    });

    test('a run nobody switched off is recorded as before', () async {
      await WaterHealthImport.setEnabled(true);

      await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35)]);

      final p = await prefs();
      expect(p.getInt('water_health_import_last_run_ms'), now.millisecondsSinceEpoch);
      expect(p.getStringList('water_health_import_seen_ids'), hasLength(1));
    });
  });

  group('where a read starts', () {
    test('the first run reaches back three days', () {
      expect(WaterHealthImport.windowStart(lastRunMs: null, now: now),
          now.subtract(const Duration(days: 3)));
    });

    test('later runs start two days before the last', () {
      final last = DateTime(2026, 9, 29, 9);
      expect(
          WaterHealthImport.windowStart(
              lastRunMs: last.millisecondsSinceEpoch, now: now),
          last.subtract(const Duration(days: 2)));
    });
  });

  test('clock is what decides "now" when none is given', () async {
    await withClock(Clock.fixed(now), () async {
      await WaterHealthImport.run(samples: const []);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('water_health_import_last_run_ms'),
          now.millisecondsSinceEpoch);
    });
  });
}
