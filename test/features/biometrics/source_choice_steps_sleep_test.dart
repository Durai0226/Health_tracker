/// Connected devices' two choices — "use this source" and "prefer this device" —
/// used to reach heart data only, while the screen said a preference "applies to
/// every measurement this source writes". Sleep and steps now honour both.
///
/// Steps are the awkward one: the health stores total them across sources, so a
/// choice can only be kept by reading one source's records. The tests pin that
/// the platform total still stands whenever no choice touches the day (a user
/// who never opens Connected devices must see no change), and that a choice
/// never blends two sources.
library;

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/features/biometrics/models/health_source.dart';
import 'package:tablet_remainder/features/biometrics/services/health_source_choices.dart';
import 'package:tablet_remainder/features/biometrics/services/health_source_registry.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_session.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/steps/services/step_source_choice.dart';

HealthDataPoint _point(
  HealthDataType type,
  DateTime from,
  int amount, {
  required String source,
  Duration? span,
}) =>
    HealthDataPoint(
      uuid: '$source-$type-${from.millisecondsSinceEpoch}',
      value: NumericHealthValue(numericValue: amount),
      type: type,
      unit: HealthDataUnit.NO_UNIT,
      dateFrom: from,
      dateTo: from.add(span ?? Duration(minutes: amount)),
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'unknown',
      sourceId: source,
      sourceName: source,
      recordingMethod: RecordingMethod.automatic,
    );

/// The registered row for [source], keyed exactly as the registry keys a point.
HealthSource _known(String source, {bool enabled = true, int priority = 0}) {
  final t = DateTime(2026, 6, 1);
  return HealthSource(
    id: HealthSourceRegistry.keyForParts(
        HealthPlatformType.googleHealthConnect.name, source, source),
    sourceId: source,
    sourceName: source,
    platformIndex: HealthPlatformType.googleHealthConnect.index,
    firstSeenAt: t,
    lastSeenAt: t,
    createdAt: t,
    updatedAt: t,
    enabled: enabled,
    priority: priority,
  );
}

Map<String, HealthSource> _byId(List<HealthSource> rows) =>
    {for (final r in rows) r.id: r};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('registry helpers', () {
    final at = DateTime(2026, 6, 19, 8);
    final watch = _point(HealthDataType.STEPS, at, 100, source: 'com.watch');
    final phone = _point(HealthDataType.STEPS, at, 100, source: 'com.phone');

    test('usable drops a switched-off source and keeps one nobody registered',
        () {
      final known = _byId([_known('com.phone', enabled: false)]);

      expect(HealthSourceRegistry.usable([watch, phone], known), [watch],
          reason: 'the phone is off; the watch was never registered, and '
              'unknown must not mean off');
      expect(HealthSourceRegistry.usable([watch, phone], const {}),
          [watch, phone]);
    });

    test('pinnedKeyIn names the pin only when it wrote one of the points', () {
      final known = _byId([_known('com.phone', priority: 1)]);

      expect(HealthSourceRegistry.pinnedKeyIn([watch, phone], known),
          known.keys.single);
      expect(HealthSourceRegistry.pinnedKeyIn([watch], known), isNull,
          reason: 'a pin is a preference: a day the pinned device missed is '
              'filled from whoever recorded it');
      expect(HealthSourceRegistry.pinnedKeyIn([watch, phone], const {}),
          isNull);
    });

    test('should two ever be pinned, the higher priority wins', () {
      // The screen is a radio, so this cannot be reached from it — but a row
      // synced from another device could carry any priority.
      final known = _byId([
        _known('com.phone', priority: 2),
        _known('com.watch', priority: 1),
      ]);

      expect(HealthSourceRegistry.pinnedKeyIn([watch, phone], known),
          _known('com.phone').id);
      expect(HealthSourceRegistry.pinnedKeyIn([phone, watch], known),
          _known('com.phone').id,
          reason: 'not whichever came last');
    });
  });

  group('sleep', () {
    final bed = DateTime(2026, 6, 19, 23);

    /// [minutes] of light sleep from [source], from bedtime.
    List<HealthDataPoint> night(String source, int minutes) => [
          _point(HealthDataType.SLEEP_LIGHT, bed, minutes,
              source: source, span: Duration(minutes: minutes)),
        ];

    SleepSession? aggregate(List<HealthDataPoint> points,
            [Map<String, HealthSource> known = const {}]) =>
        SleepService.aggregateForTesting(
            '2026-06-20', points, SleepSource.healthConnect,
            known: known);

    final both = [...night('com.watch', 300), ...night('com.phone', 420)];

    test('with no choice the device that recorded most still wins', () {
      expect(aggregate(both)!.asleepMinutes, 420);
      expect(aggregate(both, _byId([_known('com.watch')]))!.asleepMinutes, 420,
          reason: 'a registered but un-pinned source changes nothing');
    });

    test('the pinned device wins even though the other recorded more', () {
      final s = aggregate(both, _byId([_known('com.watch', priority: 1)]))!;

      expect(s.asleepMinutes, 300);
    });

    test('a pinned device that missed the night is not waited for', () {
      final s = aggregate(night('com.phone', 420),
          _byId([_known('com.watch', priority: 1)]))!;

      expect(s.asleepMinutes, 420);
    });

    test('a switched-off source is not a candidate', () {
      final s =
          aggregate(both, _byId([_known('com.phone', enabled: false)]))!;

      expect(s.asleepMinutes, 300,
          reason: 'the phone recorded more but the user turned it off');
    });

    test('a night only a switched-off source recorded is skipped, not zeroed',
        () {
      expect(
          aggregate(night('com.phone', 420),
              _byId([_known('com.phone', enabled: false)])),
          isNull);
    });
  });

  group('the saved choices', () {
    late db.AppDatabase database;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      db.AppDatabase.setInstanceForTesting(database);
      await SleepService.resetForTesting();
    });

    tearDown(() async => database.close());

    test('load reads every registered source, keyed by id', () async {
      final pinned = _known('com.watch', priority: 1);
      await database.biometricsDao.upsertSource(pinned.toCompanion());
      await database.biometricsDao
          .upsertSource(_known('com.phone', enabled: false).toCompanion());

      final loaded = await HealthSourceChoices.load();

      expect(loaded.keys, unorderedEquals([pinned.id, _known('com.phone').id]));
      expect(loaded[pinned.id]!.priority, 1);
      expect(loaded[_known('com.phone').id]!.enabled, isFalse);
    });

    test('load answers empty, not an error, when the table cannot be read',
        () async {
      HealthSourceChoices.readerForTesting = () async => throw 'locked';
      addTearDown(() => HealthSourceChoices.readerForTesting = null);

      expect(await HealthSourceChoices.load(), isEmpty,
          reason: 'an import must never stop because a preference is '
              'unavailable');
    });

    test('the sleep import stores the pinned device\'s night', () async {
      final bed = DateTime(2026, 6, 19, 23);
      HealthDataPoint light(String source, int minutes) => _point(
          HealthDataType.SLEEP_LIGHT, bed, minutes,
          source: source, span: Duration(minutes: minutes));
      final buckets = {
        '2026-06-20': [light('com.watch', 300), light('com.phone', 420)],
      };

      await SleepService.importBucketsForTesting(
          buckets, SleepSource.healthConnect,
          known: _byId([_known('com.watch', priority: 1)]));

      final row = await database.sleepDao.getForDateKey('2026-06-20');
      expect(row!.asleepMinutes, 300,
          reason: 'the import, not just the aggregate, must carry the choice');
    });
  });

  group('steps: resolve', () {
    final day = DateTime(2026, 6, 19);
    final at = DateTime(2026, 6, 19, 9);

    HealthDataPoint steps(String source, int n,
            {DateTime? from, Duration? span}) =>
        _point(HealthDataType.STEPS, from ?? at, n,
            source: source, span: span ?? const Duration(minutes: 10));

    test('no choice that touches the day leaves the platform total standing',
        () {
      final points = [steps('com.watch', 4000), steps('com.phone', 3000)];

      expect(StepSourceChoice.resolve(points, const {}, day), isNull);
      expect(
          StepSourceChoice.resolve(
              points, _byId([_known('com.watch'), _known('com.phone')]), day),
          isNull);
      expect(
          StepSourceChoice.resolve(
              points, _byId([_known('com.garmin', priority: 1)]), day),
          isNull,
          reason: 'the pinned device wrote no steps today, so nothing changes');
      expect(
          StepSourceChoice.resolve(
              points, _byId([_known('com.oura', enabled: false)]), day),
          isNull,
          reason: 'a switched-off device that wrote no steps changes nothing');
    });

    test('the pinned device\'s steps are the day, never summed with another',
        () {
      final points = [
        steps('com.watch', 4000),
        steps('com.watch', 500, from: at.add(const Duration(hours: 2))),
        steps('com.phone', 9000),
      ];

      final choice = StepSourceChoice.resolve(
          points, _byId([_known('com.watch', priority: 1)]), day)!;

      expect(choice.steps, 4500);
      expect(choice.hourly.reduce((a, b) => a + b), 4500);
    });

    test('a switched-off source leaves the busiest of the others, not a blend',
        () {
      final points = [
        steps('com.phone', 9000),
        steps('com.band', 2500),
        steps('com.watch', 4000),
        steps('com.watch', 100, from: at.add(const Duration(hours: 1))),
      ];

      final choice = StepSourceChoice.resolve(
          points, _byId([_known('com.phone', enabled: false)]), day)!;

      expect(choice.steps, 4100,
          reason: 'the watch (two records) beats the band; the phone is off');
    });

    test('every step source switched off: the day is left alone', () {
      final choice = StepSourceChoice.resolve(
          [steps('com.phone', 9000)],
          _byId([_known('com.phone', enabled: false)]),
          day)!;

      expect(choice.steps, isNull);
      expect(choice.hourly, isEmpty);
    });

    test('a record is shared across the hours it spans, in proportion', () {
      // 10:30–11:30: half in hour 10, half in hour 11.
      final points = [
        steps('com.watch', 100,
            from: DateTime(2026, 6, 19, 10, 30),
            span: const Duration(hours: 1)),
        // An instant lands whole in its own hour.
        steps('com.watch', 7,
            from: DateTime(2026, 6, 19, 3), span: Duration.zero),
      ];

      final h = StepSourceChoice.resolve(
          points, _byId([_known('com.watch', priority: 1)]), day)!.hourly;

      expect(h[10], 50);
      expect(h[11], 50);
      expect(h[3], 7);
      expect(h, hasLength(24));
    });

    test('mayApply is false for registered sources the user never touched', () {
      expect(StepSourceChoice.mayApply(const {}), isFalse);
      expect(StepSourceChoice.mayApply(_byId([_known('com.watch')])), isFalse);
      expect(
          StepSourceChoice.mayApply(
              _byId([_known('com.watch', priority: 1)])),
          isTrue);
      expect(
          StepSourceChoice.mayApply(
              _byId([_known('com.watch', enabled: false)])),
          isTrue);
    });
  });

  group('steps: the day read', () {
    const channel = MethodChannel('flutter_health');
    final svc = HealthDataService.instance;
    final day = DateTime(2026, 6, 19);
    final now = DateTime(2026, 6, 20, 12);
    final at = DateTime(2026, 6, 19, 9);
    var rawReads = 0;

    setUp(() {
      rawReads = 0;
      svc.configuredForTesting = true;
      svc.pointReaderForTesting = (type, from, to) async {
        rawReads++;
        return [
          _point(HealthDataType.STEPS, at, 4000,
              source: 'com.watch', span: const Duration(minutes: 10)),
          _point(HealthDataType.STEPS, at, 3000,
              source: 'com.phone', span: const Duration(minutes: 10)),
        ];
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        // The platform's own de-duplicated total.
        return call.method == 'getTotalStepsInInterval' ? 5555 : null;
      });
    });

    tearDown(() {
      svc.pointReaderForTesting = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('no choices: the platform total, and no raw read at all', () async {
      final read = await StepService.readDayForTesting(svc, day, now, const {});

      expect(read!.steps, 5555);
      expect(rawReads, 0,
          reason: 'a user who never opened Connected devices pays nothing');
    });

    test('a pinned device: its steps replace the platform total', () async {
      final read = await StepService.readDayForTesting(
          svc, day, now, _byId([_known('com.watch', priority: 1)]));

      expect(read!.steps, 4000);
    });

    test('a pin on a device with no steps falls back to the platform total',
        () async {
      final read = await StepService.readDayForTesting(
          svc, day, now, _byId([_known('com.garmin', priority: 1)]));

      expect(read!.steps, 5555);
      expect(rawReads, 1);
    });

    test('a failed raw read falls back to the platform total', () async {
      svc.pointReaderForTesting = (type, from, to) async => throw 'denied';

      final read = await StepService.readDayForTesting(
          svc, day, now, _byId([_known('com.watch', priority: 1)]));

      expect(read!.steps, 5555);
    });

    test('today keeps its hourly buckets, from whichever path answered',
        () async {
      final today = DateTime(2026, 6, 19);
      final noon = DateTime(2026, 6, 19, 12);

      final platform =
          await StepService.readDayForTesting(svc, today, noon, const {});
      expect(platform!.hourly, hasLength(24));
      expect(platform.hourly.every((h) => h == 5555), isTrue,
          reason: 'one aggregate query per hour, as before');

      final chosen = await StepService.readDayForTesting(
          svc, today, noon, _byId([_known('com.watch', priority: 1)]));
      expect(chosen!.hourly, hasLength(24));
      expect(chosen.hourly[9], 4000,
          reason: 'the watch\'s 09:00 record, not the platform buckets');

      final past = await StepService.readDayForTesting(svc, day, now, const {});
      expect(past!.hourly, isEmpty,
          reason: 'only today has an hourly chart');
    });

    test('every step source switched off: the day is skipped', () async {
      final read = await StepService.readDayForTesting(
          svc,
          day,
          now,
          _byId([
            _known('com.watch', enabled: false),
            _known('com.phone', enabled: false),
          ]));

      expect(read, isNull);
    });
  });
}
