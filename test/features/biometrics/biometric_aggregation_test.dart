import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:tablet_remainder/features/biometrics/models/biometric_metric.dart';
import 'package:tablet_remainder/features/biometrics/services/biometrics_service.dart';
import 'package:tablet_remainder/features/biometrics/services/health_source_registry.dart';

/// `BiometricsService.aggregateDay` is pure — it derives both aggregation
/// windows from the date key, so it reads no clock and no database and can be
/// driven entirely by hand-built points. That is the same injection seam
/// `VitalsStorageService.importFromHealthConnect({samples})` uses, and it is
/// the only way to test any of this: there is no mocking framework here and the
/// plugin has no platform channel under `flutter test`.
void main() {
  const dateKey = '2026-03-10';
  final now = DateTime(2026, 3, 10, 12);

  HealthDataPoint point(
    HealthDataType type,
    num value,
    DateTime from, {
    String sourceId = 'com.watch',
    String sourceName = 'Galaxy Watch5',
    Duration span = const Duration(minutes: 1),
  }) =>
      HealthDataPoint(
        uuid: '$type-${from.millisecondsSinceEpoch}-$sourceId',
        value: NumericHealthValue(numericValue: value),
        type: type,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: from,
        dateTo: from.add(span),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: sourceId,
        sourceName: sourceName,
        recordingMethod: RecordingMethod.automatic,
      );

  /// 10:00 on the target day — squarely inside the calendar window and
  /// squarely OUTSIDE the night window, which is what several tests turn on.
  DateTime midday(int minute) => DateTime(2026, 3, 10, 10, minute);

  /// 02:00 on the target day — inside BOTH the calendar day and the night
  /// window `[9 Mar 18:00, 10 Mar 18:00)`.
  DateTime night(int minute) => DateTime(2026, 3, 10, 2, minute);

  group('heart rate', () {
    test('min/avg/max and sample count come from the day window', () {
      final pts = [
        point(HealthDataType.HEART_RATE, 60, midday(0)),
        point(HealthDataType.HEART_RATE, 80, midday(1)),
        point(HealthDataType.HEART_RATE, 100, midday(2)),
      ];

      final r = BiometricsService.aggregateDay(dateKey, pts, now: now, android: true)!;
      expect(r.day.hrMin, 60);
      expect(r.day.hrMax, 100);
      expect(r.day.hrAvg, 80);
      expect(r.day.hrSampleCount, 3);
    });

    test('hourly buckets are null for hours with no sample, never zero', () {
      final r = BiometricsService.aggregateDay(
          dateKey,
          [
            point(HealthDataType.HEART_RATE, 70, midday(0)),
            point(HealthDataType.HEART_RATE, 90, midday(30)),
          ],
          now: now, android: true)!;

      expect(r.day.hourlyHr, hasLength(24));
      expect(r.day.hourlyHr[10], 80, reason: 'mean of the two 10:00 samples');
      // A zero here would draw a measured 0 bpm the device never recorded.
      expect(r.day.hourlyHr[11], isNull);
      expect(r.day.hourlyHr.where((v) => v == 0), isEmpty);
    });

    test('a day with nothing usable produces no row at all', () {
      expect(BiometricsService.aggregateDay(dateKey, const [], now: now, android: true),
          isNull);
    });
  });

  group('resting heart rate', () {
    test('a measured record is used as-is and not marked derived', () {
      final r = BiometricsService.aggregateDay(
          dateKey,
          [point(HealthDataType.RESTING_HEART_RATE, 54, midday(0))],
          now: now, android: true)!;
      expect(r.day.restingHr, 54);
      expect(r.day.restingHrDerived, isFalse);
    });

    test('with no record it is derived from the night, and flagged', () {
      // 40 night samples, 50..89 bpm. The 5th percentile lands on the 2nd.
      final pts = [
        for (var i = 0; i < 40; i++)
          point(HealthDataType.HEART_RATE, 50 + i, night(i)),
      ];

      final r = BiometricsService.aggregateDay(dateKey, pts, now: now, android: true)!;
      expect(r.day.restingHrDerived, isTrue,
          reason: 'the UI must be able to label this "estimated"');
      expect(r.day.restingHr, 52);
    });

    test('too few night samples means no resting HR rather than a guess', () {
      final pts = [
        for (var i = 0; i < 5; i++)
          point(HealthDataType.HEART_RATE, 50 + i, night(i)),
      ];
      final r = BiometricsService.aggregateDay(dateKey, pts, now: now, android: true)!;
      expect(r.day.restingHr, isNull,
          reason: 'one stray low reading is not a resting rate');
    });

    test('daytime heart rate alone never derives a resting rate', () {
      final pts = [
        for (var i = 0; i < 40; i++)
          point(HealthDataType.HEART_RATE, 100 + i, midday(i)),
      ];
      final r = BiometricsService.aggregateDay(dateKey, pts, now: now, android: true)!;
      expect(r.day.restingHr, isNull);
    });
  });

  group('window separation', () {
    test('an evening reading belongs to TOMORROW night, not this one', () {
      // The night window for 2026-03-10 is [9 Mar 18:00, 10 Mar 18:00). A
      // reading at 19:00 on the 10th falls after it closes, so it belongs to
      // the night that wakes up on the 11th. Same 18:00 rule SleepService
      // buckets by — if these two ever disagree, "last night" means two
      // different things in two features.
      final r = BiometricsService.aggregateDay(
          dateKey,
          [
            point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, 55,
                DateTime(2026, 3, 10, 19)),
          ],
          now: now,
          android: true);
      expect(r, isNull);

      // ...and it IS picked up by the next day's aggregation.
      final tomorrow = BiometricsService.aggregateDay(
          '2026-03-11',
          [
            point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, 55,
                DateTime(2026, 3, 10, 19)),
          ],
          now: now,
          android: true)!;
      expect(tomorrow.day.hrvNightlyMs, 55);
    });

    test('HRV inside the night window is aggregated', () {
      final r = BiometricsService.aggregateDay(
          dateKey,
          [
            point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, 40, night(0)),
            point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, 60, night(5)),
          ],
          now: now, android: true)!;
      expect(r.day.hrvNightlyMs, 50);
      expect(r.day.hrvSampleCount, 2);
      // Recorded so a chart can never mix RMSSD with iOS's SDNN.
      expect(r.day.hrvMetric, HrvMetric.rmssd);
    });

    test('the previous evening counts toward this night', () {
      final r = BiometricsService.aggregateDay(
          dateKey,
          [
            point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, 45,
                DateTime(2026, 3, 9, 23)),
          ],
          now: now, android: true)!;
      expect(r.day.hrvNightlyMs, 45);
    });
  });

  group('blood oxygen unit normalisation', () {
    test('a HealthKit-style fraction becomes a percentage', () {
      // HealthKit reports 0..1 while Health Connect reports 0..100, despite
      // both declaring PERCENT. Unnormalised, this renders as "0.97%".
      final r = BiometricsService.aggregateDay(
          dateKey,
          [point(HealthDataType.BLOOD_OXYGEN, 0.97, midday(0))],
          now: now, android: true)!;
      expect(r.day.spo2Avg, closeTo(97, 0.001));
    });

    test('an already-percentage reading is left alone', () {
      final r = BiometricsService.aggregateDay(
          dateKey,
          [point(HealthDataType.BLOOD_OXYGEN, 96, midday(0))],
          now: now, android: true)!;
      expect(r.day.spo2Avg, closeTo(96, 0.001));
      expect(r.day.spo2Min, closeTo(96, 0.001));
    });
  });

  group('source precedence', () {
    SourceCandidate cand(String id, {int priority = 0, int samples = 1}) =>
        SourceCandidate(
          id: id,
          sourceId: id,
          sourceName: id,
          platformIndex: 0,
          sampleCount: samples,
          lastSeenAt: DateTime(2026, 3, 10),
          priority: priority,
        );

    test('a user pin beats a higher sample count', () {
      final winner = HealthSourceRegistry.pickWinner([
        cand('ring', samples: 500),
        cand('watch', priority: 1, samples: 3),
      ])!;
      expect(winner.id, 'watch');
    });

    test('otherwise the source with more samples wins', () {
      final winner = HealthSourceRegistry.pickWinner(
          [cand('ring', samples: 10), cand('watch', samples: 400)])!;
      expect(winner.id, 'watch');
    });

    test('the order is total, so the winner never flip-flops', () {
      // Two sources identical on every ranked signal. Without the final
      // lexicographic tiebreak they could alternate between syncs and the
      // trend line would jump between two calibrations — variation that is
      // really just a coin flip.
      final a = cand('aaa', samples: 5);
      final b = cand('bbb', samples: 5);
      for (var i = 0; i < 50; i++) {
        expect(HealthSourceRegistry.pickWinner([a, b])!.id, 'aaa');
        expect(HealthSourceRegistry.pickWinner([b, a])!.id, 'aaa');
      }
    });

    test('two devices on one day never blend into one range', () {
      // The ring's 40 and 200 must not become this day's min and max: that
      // would be a range no device ever measured.
      final pts = [
        for (var i = 0; i < 10; i++)
          point(HealthDataType.HEART_RATE, 70 + i, midday(i),
              sourceId: 'com.watch', sourceName: 'Watch'),
        point(HealthDataType.HEART_RATE, 40, midday(20),
            sourceId: 'com.ring', sourceName: 'Ring'),
        point(HealthDataType.HEART_RATE, 200, midday(21),
            sourceId: 'com.ring', sourceName: 'Ring'),
      ];

      final r = BiometricsService.aggregateDay(dateKey, pts, now: now, android: true)!;
      expect(r.day.hrMin, 70);
      expect(r.day.hrMax, 79);
      expect(r.day.hrSampleCount, 10, reason: 'winner-only, not the union');
    });

    test('the winning source is recorded per metric', () {
      final pts = [
        point(HealthDataType.HEART_RATE, 70, midday(0),
            sourceId: 'com.watch', sourceName: 'Watch'),
      ];
      final r = BiometricsService.aggregateDay(dateKey, pts, now: now, android: true)!;
      final expected = HealthSourceRegistry.keyForParts(
          HealthPlatformType.googleHealthConnect.name, 'com.watch', 'Watch');
      expect(r.day.sourceByMetric[BiometricMetricKey.hr], expected);
      expect(r.day.primarySourceId, expected);
    });
  });

  group('source identity', () {
    test('the key is stable and hides the user-supplied name', () {
      final key = HealthSourceRegistry.keyForParts(
          'appleHealth', 'com.apple.health', "Durai's Apple Watch");
      expect(key, startsWith('src_'));
      expect(key, hasLength(20));
      // The name becomes a Firestore document id if it leaks into the key.
      expect(key.toLowerCase(), isNot(contains('durai')));
      expect(
          key,
          HealthSourceRegistry.keyForParts(
              'appleHealth', 'com.apple.health', "Durai's Apple Watch"));
    });

    test('different devices get different keys', () {
      final a = HealthSourceRegistry.keyForParts('p', 'com.a', 'A');
      final b = HealthSourceRegistry.keyForParts('p', 'com.b', 'B');
      expect(a, isNot(b));
    });
  });

  group('workouts', () {
    test('id is deterministic so a re-import is a no-op', () {
      final start = DateTime(2026, 3, 10, 7);
      final w = HealthDataPoint(
        uuid: 'w1',
        value: WorkoutHealthValue(
          workoutActivityType: HealthWorkoutActivityType.RUNNING,
          totalEnergyBurned: 320,
          totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
          totalDistance: 5000,
          totalDistanceUnit: HealthDataUnit.METER,
        ),
        type: HealthDataType.WORKOUT,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: start,
        dateTo: start.add(const Duration(minutes: 32)),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: 'com.watch',
        sourceName: 'Watch',
        recordingMethod: RecordingMethod.automatic,
      );

      final first = BiometricsService.aggregateWorkouts(dateKey, [w], now: now);
      final again = BiometricsService.aggregateWorkouts(dateKey, [w], now: now);
      expect(first.single.id, again.single.id);
      expect(first.single.id,
          'hw_${start.millisecondsSinceEpoch}_RUNNING');
      expect(first.single.durationMinutes, 32);
      expect(first.single.energyKcal, 320);
      // A raw string, never the enum index: that enum's ordinals shift between
      // plugin releases and would silently reinterpret stored history.
      expect(first.single.activityType, 'RUNNING');
      expect(first.single.activityLabel, 'Running');
    });

    test('heart rate is intersected from the session window only', () {
      final start = DateTime(2026, 3, 10, 7);
      final w = HealthDataPoint(
        uuid: 'w1',
        value: WorkoutHealthValue(
            workoutActivityType: HealthWorkoutActivityType.WALKING),
        type: HealthDataType.WORKOUT,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: start,
        dateTo: start.add(const Duration(minutes: 30)),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: 'com.watch',
        sourceName: 'Watch',
        recordingMethod: RecordingMethod.automatic,
      );

      final out = BiometricsService.aggregateWorkouts(
        dateKey,
        [
          w,
          point(HealthDataType.HEART_RATE, 120, start.add(const Duration(minutes: 5))),
          point(HealthDataType.HEART_RATE, 140, start.add(const Duration(minutes: 10))),
          // Two hours later — must not count toward this session.
          point(HealthDataType.HEART_RATE, 200, start.add(const Duration(hours: 2))),
        ],
        now: now,
      );

      expect(out.single.avgHr, 130);
      expect(out.single.maxHr, 140);
    });

    test('a zero-length session is dropped', () {
      final start = DateTime(2026, 3, 10, 7);
      final w = HealthDataPoint(
        uuid: 'w0',
        value: WorkoutHealthValue(
            workoutActivityType: HealthWorkoutActivityType.OTHER),
        type: HealthDataType.WORKOUT,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: start,
        dateTo: start,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: 'com.watch',
        sourceName: 'Watch',
        recordingMethod: RecordingMethod.automatic,
      );
      expect(BiometricsService.aggregateWorkouts(dateKey, [w], now: now),
          isEmpty);
    });
  });
}
