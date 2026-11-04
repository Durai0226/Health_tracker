/// The imports from the health store ask for, and are gated on, READ access — and
/// nothing else.
///
/// They were gated on the sharing switches' write check — WRITE on blood pressure,
/// glucose AND weight — and asked for that grant too. Health Connect grants read and
/// write per type, so someone who allowed the two the import reads but not weight
/// was told the store "did not share your readings" and the feature never started;
/// someone who allowed write and refused read passed the gate and then failed every
/// read; and a person who only wanted a cuff's readings brought in was shown a sheet
/// asking to write to the store, which the privacy policy says the app does only when
/// sharing is switched on.
///
/// Android discloses READ and is asked directly. iPhone never does, so there the
/// answer is whether the person got through the request sheet — remembered, like the
/// cycle and wearable reads.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_health_import.dart';
import 'package:tablet_remainder/features/medication/widgets/vitals_import_flow.dart';
import 'package:tablet_remainder/features/water/services/water_health_import.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:tablet_remainder/features/water/widgets/water_import_flow.dart';

import '../support/recording_notification_scheduler.dart';

/// What the platform is made to say, per kind of access. `null` is "will not say".
class _Platform {
  _Platform({
    this.read,
    this.write,
    this.throws = false,
    this.sheetAnswer = true,
    this.readable,
  });

  bool? read;
  bool? write;
  bool throws;

  /// Health Connect grants each type on its own. When set, READ is held for exactly
  /// these, and a question about several is "all of them" — as the plugin answers.
  final Set<HealthDataType>? readable;

  /// What the consent sheet's own answer is: on iPhone, "it closed without error".
  bool sheetAnswer;

  final asked = <(List<HealthDataType>, List<HealthDataAccess>)>[];
  final requested = <(List<HealthDataType>, List<HealthDataAccess>)>[];

  Future<bool?> check(List<HealthDataType> types, List<HealthDataAccess> access) async {
    asked.add((types, access));
    if (throws) throw StateError('the platform is gone');
    // The plugin asserts this: one access per type.
    if (types.length != access.length) {
      throw ArgumentError('${types.length} types but ${access.length} accesses');
    }
    if (!access.every((a) => a == HealthDataAccess.READ)) return write;
    final only = readable;
    return only == null ? read : types.every(only.contains);
  }

  Future<bool?> request(List<HealthDataType> types, List<HealthDataAccess> access) async {
    requested.add((types, access));
    if (throws) throw StateError('the platform is gone');
    return sheetAnswer;
  }

  bool askedAbout(HealthDataAccess a) => asked.any((q) => q.$2.every((x) => x == a));
}

/// Preferences that cannot be opened.
class _UnreadableStore extends InMemorySharedPreferencesStore {
  _UnreadableStore() : super.empty();

  @override
  Future<Map<String, Object>> getAll() => throw StateError('the preferences would not open');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = HealthDataService.instance;
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
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
    service.configuredForTesting = true;
  });

  tearDown(() async {
    service.permissionQueryForTesting = null;
    service.authorizationRequestForTesting = null;
    service.configuredForTesting = false;
    await db.close();
  });

  _Platform platform({
    bool? read,
    bool? write,
    bool throws = false,
    bool sheet = true,
    Set<HealthDataType>? readable,
  }) {
    final p = _Platform(
        read: read, write: write, throws: throws, sheetAnswer: sheet, readable: readable);
    service.permissionQueryForTesting = p.check;
    service.authorizationRequestForTesting = p.request;
    return p;
  }

  group('where the platform discloses READ (Android)', () {
    test('blood pressure and glucose are read-allowed whatever write says', () async {
      // Read on the two it reads; write refused — weight, say, or all of it.
      final p = platform(read: true, write: false);

      expect(await service.vitalsReadAccess(), isTrue);
      expect(await service.hasVitalsReadPermission(), isTrue);
      expect(p.askedAbout(HealthDataAccess.READ), isTrue);
    });

    test('and write without read is not enough', () async {
      platform(read: false, write: true);

      expect(await service.vitalsReadAccess(), isFalse);
      expect(await service.hasVitalsReadPermission(), isFalse);
    });

    test('it asks about exactly what the import reads — not weight', () async {
      final p = platform(read: true);

      await service.vitalsReadAccess();

      final (types, access) = p.asked.first;
      expect(types, HealthDataService.vitalsReadTypes);
      expect(types, isNot(contains(HealthDataType.WEIGHT)));
      expect(access, everyElement(HealthDataAccess.READ));
      expect(access, hasLength(types.length));
    });

    test('drinks the same: read decides, write does not', () async {
      platform(read: true, write: false);
      expect(await service.hydrationReadAccess(), isTrue);

      platform(read: false, write: true);
      expect(await service.hydrationReadAccess(), isFalse);
    });

    test('and it asks about water alone, for READ', () async {
      final p = platform(read: true);

      await service.hydrationReadAccess();

      final (types, access) = p.asked.first;
      expect(types, [HealthDataType.WATER]);
      expect(access, [HealthDataAccess.READ]);
    });
  });

  group('a grant of only some of them (Android grants each on its own)', () {
    const bp = {HealthDataType.BLOOD_PRESSURE_SYSTOLIC, HealthDataType.BLOOD_PRESSURE_DIASTOLIC};
    const glucose = {HealthDataType.BLOOD_GLUCOSE};

    test('blood pressure allowed and glucose refused is read-allowed', () async {
      platform(readable: bp);

      expect(await service.vitalsReadAccess(), isTrue);
      expect(await service.hasVitalsReadPermission(), isTrue);
    });

    test('glucose allowed and blood pressure refused is too', () async {
      platform(readable: glucose);

      expect(await service.vitalsReadAccess(), isTrue);
    });

    test('and one type of the three is a grant of something, whichever it is', () async {
      // Health Connect keeps systolic and diastolic in one record with one
      // permission, so this one cannot happen there; the question is asked per type,
      // and "the person allowed something" is what it answers.
      platform(readable: {HealthDataType.BLOOD_PRESSURE_SYSTOLIC});

      expect(await service.vitalsReadAccess(), isTrue);
    });

    test('none of them is a no', () async {
      platform(readable: const {});

      expect(await service.vitalsReadAccess(), isFalse);
      expect(await service.hasVitalsReadPermission(), isFalse);
    });

    test('all of them takes one question, not four', () async {
      final p = platform(readable: {...bp, ...glucose});

      expect(await service.vitalsReadAccess(), isTrue);

      expect(p.asked, hasLength(1));
    });

    test('a type the import does not read is no grant of anything it does', () async {
      platform(readable: {HealthDataType.WEIGHT, HealthDataType.STEPS});

      expect(await service.vitalsReadAccess(), isFalse);
    });

    test('drinks are one type, so there is no "some of them" to ask', () async {
      final p = platform(readable: const {});

      expect(await service.hydrationReadAccess(), isFalse);

      expect(p.asked, hasLength(1));
    });

    test('a look that fails part way is still a failed look, not a no', () async {
      final p = platform(readable: const {});
      var calls = 0;
      service.permissionQueryForTesting = (types, access) async {
        calls++;
        if (calls > 1) throw StateError('the store went away');
        return p.check(types, access);
      };

      expect(await service.vitalsReadAccess(), isNull);
    });

    test('asking: a sheet that allowed one of them is a yes', () async {
      platform(readable: bp, sheet: false);

      expect(await service.requestVitalsReadPermission(), isTrue);
    });

    test('and is remembered as asked, for the platform that will not say', () async {
      // iPhone: the sheet is all there is to go on, and the flag is written on it.
      platform(read: null, sheet: true);
      await service.requestVitalsReadPermission();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('vitals_health_import_read_asked'), isTrue);
    });

    test('and the import runs for the one that was allowed', () async {
      platform(readable: glucose);
      await VitalsHealthImport.setEnabled(true);

      final result = await VitalsHealthImport.runIfEnabled(
          force: true, now: now, bpSamples: const [], glucoseSamples: [
        HealthDataPoint(
          uuid: 'g1',
          value: NumericHealthValue(numericValue: 104),
          type: HealthDataType.BLOOD_GLUCOSE,
          unit: HealthDataUnit.MILLIGRAM_PER_DECILITER,
          dateFrom: ten,
          dateTo: ten,
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'unknown',
          sourceId: 'com.dexcom.g7',
          sourceName: 'Health Connect',
          recordingMethod: RecordingMethod.automatic,
        ),
      ]);

      expect(result?.glucose, hasLength(1));
    });
  });

  group('where it does not (iPhone)', () {
    // READ is never disclosed there, so the answer is whether the person got through
    // the sheet. WRITE is not consulted: the import never asked for it.
    test('before the sheet has been through, it is not allowed', () async {
      final p = platform(read: null, write: true);

      expect(await service.vitalsReadAccess(), isFalse);
      expect(await service.hydrationReadAccess(), isFalse);
      expect(p.askedAbout(HealthDataAccess.WRITE), isFalse,
          reason: 'a write grant the import never asked for says nothing about reading');
    });

    test('after it has, it is — and that is remembered', () async {
      platform(read: null, sheet: true);

      expect(await service.requestVitalsReadPermission(), isTrue);

      expect(await service.vitalsReadAccess(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('vitals_health_import_read_asked'), isTrue);
    });

    test('a sheet that did not complete is not', () async {
      platform(read: null, sheet: false);

      expect(await service.requestVitalsReadPermission(), isFalse);
      expect(await service.vitalsReadAccess(), isFalse);
    });

    test('an answer that cannot be read back is "could not tell", not "no"', () async {
      // Reading it is all iPhone has to go on. A caller that switches a person\'s
      // choice off on a "no" — the screens do, on `== false` — must not do it because
      // the preferences would not open.
      platform(read: null, sheet: true);
      await service.requestVitalsReadPermission();
      await service.requestHydrationReadPermission();
      SharedPreferencesStorePlatform.instance = _UnreadableStore();
      SharedPreferences.resetStatic();

      expect(await service.vitalsReadAccess(), isNull);
      expect(await service.hydrationReadAccess(), isNull);
      expect(await service.hasVitalsReadPermission(), isFalse, reason: 'and the gate stays shut');
    });

    test('whereas one that was never given is a plain no', () async {
      platform(read: null, sheet: true);

      expect(await service.vitalsReadAccess(), isFalse);
    });

    test('drinks the same, under their own flag', () async {
      platform(read: null, sheet: true);

      expect(await service.requestHydrationReadPermission(), isTrue);

      expect(await service.hydrationReadAccess(), isTrue);
      expect(await service.vitalsReadAccess(), isFalse, reason: 'a different grant');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('water_health_import_read_asked'), isTrue);
    });

    test('disconnecting forgets both, so the next switch-on asks again', () async {
      platform(read: null, sheet: true);
      await service.requestVitalsReadPermission();
      await service.requestHydrationReadPermission();

      await service.forgetConnection();

      expect(await service.vitalsReadAccess(), isFalse);
      expect(await service.hydrationReadAccess(), isFalse);
    });

    test('and "Delete all data" removes them with the rest of what the imports remember',
        () async {
      platform(read: null, sheet: true);
      await service.requestVitalsReadPermission();
      await service.requestHydrationReadPermission();

      await CleanStorageService.clearAllPersistentData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('vitals_health_import_read_asked'), isFalse);
      expect(prefs.containsKey('water_health_import_read_asked'), isFalse);
    });
  });

  group('asking', () {
    test('is for READ on what is read, and nothing else', () async {
      final p = platform(read: true);

      await service.requestVitalsReadPermission();

      expect(p.requested, hasLength(1));
      final (types, access) = p.requested.single;
      expect(types, HealthDataService.vitalsReadTypes);
      expect(types, isNot(contains(HealthDataType.WEIGHT)));
      expect(access, everyElement(HealthDataAccess.READ),
          reason: 'no sheet asking to write to the store');
    });

    test('drinks the same', () async {
      final p = platform(read: true);

      await service.requestHydrationReadPermission();

      final (types, access) = p.requested.single;
      expect(types, [HealthDataType.WATER]);
      expect(access, [HealthDataAccess.READ]);
    });

    test('the answer is checked afterwards where the platform will say, not taken from the request',
        () async {
      // Health Connect: the sheet reports "refused" because one of the requested
      // scopes was — yet read was allowed.
      platform(read: true, sheet: false);
      expect(await service.requestVitalsReadPermission(), isTrue);

      // And the sheet reports success while read is not held.
      platform(read: false, sheet: true);
      expect(await service.requestVitalsReadPermission(), isFalse);
    });

    test('a platform that throws is a no, not a crash', () async {
      platform(throws: true);

      expect(await service.requestVitalsReadPermission(), isFalse);
      expect(await service.requestHydrationReadPermission(), isFalse);
    });
  });

  group('a look that failed', () {
    test('is not a no: it is null, and the gate is simply closed', () async {
      platform(throws: true);

      expect(await service.vitalsReadAccess(), isNull);
      expect(await service.hydrationReadAccess(), isNull);
      expect(await service.hasVitalsReadPermission(), isFalse);
      expect(await service.hasHydrationReadPermission(), isFalse);
    });

    test('whereas a real no is false', () async {
      platform(read: false);

      expect(await service.vitalsReadAccess(), isFalse);
    });
  });

  test('the sharing switches still ask about WRITE, on everything they write', () async {
    final p = platform(read: false, write: true);

    expect(await service.hasVitalsWritePermission(), isTrue);
    expect(await service.hasHydrationWritePermission(), isTrue);

    expect(p.asked, hasLength(2));
    final (vitals, vitalsAccess) = p.asked[0];
    expect(vitals, HealthDataService.vitalsWriteTypes);
    expect(vitalsAccess, everyElement(HealthDataAccess.WRITE));
    expect(vitalsAccess, hasLength(vitals.length));
    final (water, waterAccess) = p.asked[1];
    expect(water, HealthDataService.hydrationWriteTypes);
    expect(waterAccess, [HealthDataAccess.WRITE]);
    expect(p.askedAbout(HealthDataAccess.READ), isFalse);
  });

  group('the automatic imports use it', () {
    HealthDataPoint point(HealthDataType type, num value, {String source = 'com.omron.connect'}) =>
        HealthDataPoint(
          uuid: '$type-$source',
          value: NumericHealthValue(numericValue: value),
          type: type,
          unit: type == HealthDataType.WATER ? HealthDataUnit.LITER : HealthDataUnit.NO_UNIT,
          dateFrom: ten.subtract(const Duration(minutes: 1)),
          dateTo: ten,
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'unknown',
          sourceId: source,
          sourceName: 'Health Connect',
          recordingMethod: RecordingMethod.automatic,
        );

    final cuff = [
      point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, 128),
      point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, 82),
    ];
    final drink = point(HealthDataType.WATER, 0.25, source: 'com.sec.android.app.shealth');

    test('blood pressure runs on a read grant with no write grant', () async {
      platform(read: true, write: false);
      await VitalsHealthImport.setEnabled(true);

      final result = await VitalsHealthImport.runIfEnabled(
          force: true, now: now, bpSamples: cuff, glucoseSamples: const []);

      expect(result?.bloodPressure, hasLength(1));
    });

    test('and stays out on a write grant with no read grant', () async {
      platform(read: false, write: true);
      await VitalsHealthImport.setEnabled(true);

      final result = await VitalsHealthImport.runIfEnabled(
          force: true, now: now, bpSamples: cuff, glucoseSamples: const []);

      expect(result, isNull);
    });

    test('drinks run on a read grant with no write grant', () async {
      platform(read: true, write: false);
      await WaterHealthImport.setEnabled(true);

      final result =
          await WaterHealthImport.runIfEnabled(force: true, now: now, samples: [drink]);

      expect(result?.count, 1);
    });

    test('and stay out on a write grant with no read grant', () async {
      platform(read: false, write: true);
      await WaterHealthImport.setEnabled(true);

      final result =
          await WaterHealthImport.runIfEnabled(force: true, now: now, samples: [drink]);

      expect(result, isNull);
    });

    test('a look that failed does not run it, and does not turn it off either', () async {
      platform(throws: true);
      await VitalsHealthImport.setEnabled(true);

      final result = await VitalsHealthImport.runIfEnabled(
          force: true, now: now, bpSamples: cuff, glucoseSamples: const []);

      expect(result, isNull);
      expect(await VitalsHealthImport.isEnabled(), isTrue,
          reason: 'the choice is the person\'s, and nothing said it was revoked');
    });
  });

  group('and so do the flows that switch them on', () {
    test('blood pressure: allowed() is the read answer, and null when the look failed', () async {
      platform(read: true, write: false);
      expect(await const HealthStoreVitalsSource().allowed(), isTrue);

      platform(read: false, write: true);
      expect(await const HealthStoreVitalsSource().allowed(), isFalse);

      platform(throws: true);
      expect(await const HealthStoreVitalsSource().allowed(), isNull);
    });

    test('blood pressure: asking is a READ-only request, and the read answer counts', () async {
      final yes = platform(read: true, sheet: false);
      expect(await const HealthStoreVitalsSource().ask(), isTrue);
      expect(yes.requested.single.$2, everyElement(HealthDataAccess.READ));

      platform(read: false, sheet: true);
      expect(await const HealthStoreVitalsSource().ask(), isFalse);
    });

    test('drinks: allowed() is the read answer, and null when the look failed', () async {
      platform(read: true, write: false);
      expect(await const HealthStoreWaterSource().allowed(), isTrue);

      platform(read: false, write: true);
      expect(await const HealthStoreWaterSource().allowed(), isFalse);

      platform(throws: true);
      expect(await const HealthStoreWaterSource().allowed(), isNull);
    });

    test('drinks: asking is a READ-only request, and the read answer counts', () async {
      final yes = platform(read: true, sheet: false);
      expect(await const HealthStoreWaterSource().ask(), isTrue);
      expect(yes.requested.single.$2, [HealthDataAccess.READ]);

      platform(read: false, sheet: true);
      expect(await const HealthStoreWaterSource().ask(), isFalse);
    });
  });
  group('what is read is what is asked about', () {
    // The permission question and the read name their types separately; if one is
    // changed for a platform and the other is not, the app asks about one thing and
    // reads another, and nothing says so. Run the readers and see which types they
    // actually ask the plugin for.
    late List<HealthDataType> read;

    setUp(() {
      read = [];
      service.pointReaderForTesting = (type, from, to) async {
        read.add(type);
        return const [];
      };
    });

    tearDown(() => service.pointReaderForTesting = null);

    test('blood pressure and blood sugar together are exactly vitalsReadTypes', () async {
      await service.readBloodPressureSamples(now, now);
      await service.readGlucoseSamples(now, now);

      expect(read.toSet(), HealthDataService.vitalsReadTypes.toSet());
      expect(read, hasLength(HealthDataService.vitalsReadTypes.length),
          reason: 'each once');
    });

    test('drinks are exactly hydrationReadTypes', () async {
      await service.readWaterSamples(now, now);

      expect(read.toSet(), HealthDataService.hydrationReadTypes.toSet());
    });

    test('and what an Android phone is asked about is what an Android phone reads', () {
      // The host is neither; the named per-platform lists are what the getters pick.
      for (final types in [
        HealthDataService.vitalsReadTypesAndroid,
        HealthDataService.vitalsReadTypesIOS,
      ]) {
        expect(types.toSet(), {
          HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
          HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
          HealthDataType.BLOOD_GLUCOSE,
        });
      }
      expect(HealthDataService.hydrationReadTypesAndroid, [HealthDataType.WATER]);
      expect(HealthDataService.hydrationReadTypesIOS, [HealthDataType.WATER]);
    });
  });

  group('"Delete all data" while an import is mid-read', () {
    // A read of the health store takes seconds. A run that finished after the wipe
    // saved what it had found into the emptied store and wrote down where it got to
    // — the person had deleted everything and found some of it back.
    HealthDataPoint sample(HealthDataType type, num value) => HealthDataPoint(
          uuid: 'wipe-$type',
          value: NumericHealthValue(numericValue: value),
          type: type,
          unit: type == HealthDataType.WATER ? HealthDataUnit.LITER : HealthDataUnit.NO_UNIT,
          dateFrom: ten.subtract(const Duration(minutes: 1)),
          dateTo: ten,
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'unknown',
          sourceId: 'com.sec.android.app.shealth',
          sourceName: 'Health Connect',
          recordingMethod: RecordingMethod.automatic,
        );

    test('drinks: nothing is kept, nothing remembered', () async {
      final reading = Completer<void>();
      final release = Completer<void>();
      WaterHealthImport.readerForTesting = (from, to) async {
        reading.complete();
        await release.future;
        return [sample(HealthDataType.WATER, 0.35)];
      };
      addTearDown(() => WaterHealthImport.readerForTesting = null);
      await WaterHealthImport.setEnabled(true);
      final run = WaterHealthImport.run(now: now);
      await reading.future;

      await CleanStorageService.clearAllPersistentData();
      release.complete();
      final result = await run;

      expect(result.isEmpty, isTrue);
      final day = await WaterService.loadDataForDate(DateTime(2026, 9, 30));
      expect(day?.logs ?? const [], isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('water_health_import_last_run_ms'), isFalse);
      expect(prefs.containsKey('water_health_import_seen_ids'), isFalse);
    });

    test('blood pressure and sugar: the same', () async {
      final reading = Completer<void>();
      final release = Completer<void>();
      VitalsHealthImport.readerForTesting = (kind, from, to) async {
        if (!reading.isCompleted) reading.complete();
        await release.future;
        return kind == 'bp'
            ? [
                sample(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, 128),
                sample(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, 82),
              ]
            : [sample(HealthDataType.BLOOD_GLUCOSE, 104)];
      };
      addTearDown(() => VitalsHealthImport.readerForTesting = null);
      await VitalsHealthImport.setEnabled(true);
      final run = VitalsHealthImport.run(now: now);
      await reading.future;

      await CleanStorageService.clearAllPersistentData();
      release.complete();
      final result = await run;

      expect(result.isEmpty, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('vitals_health_import_last_run_ms'), isFalse);
      expect(prefs.containsKey('vitals_health_import_seen_ids'), isFalse);
    });
  });
}
