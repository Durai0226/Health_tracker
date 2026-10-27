/// A workout typed in by hand: saved, changed, deleted, undone — and never lost
/// to a sync.
///
/// The Workouts list was read-only, so a run without the watch, a swim or a class
/// left a day that looked like a rest day. A sync that replaced a day's sessions
/// would have dropped an entered one from the screen too.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/workout_entry.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/biometrics/models/biometric_metric.dart';
import 'package:tablet_remainder/features/biometrics/services/biometrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    BiometricsService.clearInMemory();
    await BiometricsService.resetForTesting();
  });

  tearDown(() async => database.close());

  final start = DateTime(2026, 6, 19, 7, 30);
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<String> idsOn(DateTime day) =>
      BiometricsService.workoutsForDate(day).map((w) => w.id).toList();

  group('saving', () {
    test('a workout typed in is stored, and shown, as yours', () async {
      final w = await BiometricsService.saveEnteredWorkout(
        activityType: 'RUNNING',
        startedAt: start,
        durationMinutes: 40,
        kcal: 380,
        distanceKm: 5.5,
        note: 'park loop',
      );
      expect(WorkoutEntry.isEntered(w.id), isTrue);
      expect(w.source, BiometricSource.manual);
      expect(w.endedAt, start.add(const Duration(minutes: 40)));
      expect(w.distanceMeters, 5500);
      expect(w.energyKcal, 380);
      expect(w.note, 'park loop');
      expect(idsOn(start), [w.id]);

      final rows = await database.biometricsDao.getWorkoutsForDateKey(key(start));
      expect(rows.single.id, w.id);
    });

    test('calories, distance and a note are optional, and blank is none', () async {
      final w = await BiometricsService.saveEnteredWorkout(
          activityType: 'YOGA', startedAt: start, durationMinutes: 30, note: '   ');
      expect(w.energyKcal, isNull);
      expect(w.distanceMeters, isNull, reason: 'a workout with no distance shows none, not 0 km');
      expect(w.note, isNull);
    });

    test('sessions on one day are in the order they happened', () async {
      await BiometricsService.saveEnteredWorkout(
          activityType: 'YOGA', startedAt: DateTime(2026, 6, 19, 18), durationMinutes: 30);
      await BiometricsService.saveEnteredWorkout(
          activityType: 'RUNNING', startedAt: DateTime(2026, 6, 19, 7), durationMinutes: 30);
      final kinds = BiometricsService.workoutsForDate(start).map((w) => w.activityType);
      expect(kinds, ['RUNNING', 'YOGA']);
    });

    test('the same start and kind is an edit, not a copy', () async {
      await BiometricsService.saveEnteredWorkout(
          activityType: 'RUNNING', startedAt: start, durationMinutes: 40);
      await BiometricsService.saveEnteredWorkout(
          activityType: 'RUNNING', startedAt: start, durationMinutes: 45);
      expect(BiometricsService.workoutsForDate(start), hasLength(1));
      expect(BiometricsService.workoutsForDate(start).single.durationMinutes, 45);
    });
  });

  group('changing one', () {
    test('keeps its row and creation when only the length changes', () async {
      final before = await BiometricsService.saveEnteredWorkout(
          activityType: 'RUNNING',
          startedAt: start,
          durationMinutes: 40,
          now: DateTime(2026, 6, 19, 9));
      final after = await BiometricsService.saveEnteredWorkout(
          activityType: 'RUNNING',
          startedAt: start,
          durationMinutes: 50,
          replacing: before,
          now: DateTime(2026, 6, 20, 9));
      expect(after.id, before.id);
      expect(after.createdAt, before.createdAt);
      expect(after.updatedAt.isAfter(before.updatedAt), isTrue);
    });

    test('a different start moves it: the old one is gone, nothing is left behind',
        () async {
      final before = await BiometricsService.saveEnteredWorkout(
          activityType: 'RUNNING', startedAt: start, durationMinutes: 40);
      final newStart = DateTime(2026, 6, 18, 18);
      final after = await BiometricsService.saveEnteredWorkout(
          activityType: 'RUNNING', startedAt: newStart, durationMinutes: 40, replacing: before);

      expect(after.id, isNot(before.id));
      expect(BiometricsService.workoutsForDate(start), isEmpty);
      expect(idsOn(newStart), [after.id]);
      final old = await database.biometricsDao.getWorkoutsForDateKey(key(start));
      expect(old, isEmpty, reason: 'deleted, so a read of that day finds nothing');
    });

    test('a different kind is a different identity too', () async {
      final before = await BiometricsService.saveEnteredWorkout(
          activityType: 'WALKING', startedAt: start, durationMinutes: 40);
      final after = await BiometricsService.saveEnteredWorkout(
          activityType: 'RUNNING', startedAt: start, durationMinutes: 40, replacing: before);
      expect(BiometricsService.workoutsForDate(start).map((w) => w.id), [after.id]);
    });
  });

  group('deleting and undoing', () {
    test('delete removes it from the screen and the database', () async {
      final w = await BiometricsService.saveEnteredWorkout(
          activityType: 'SWIMMING', startedAt: start, durationMinutes: 30);
      await BiometricsService.deleteEnteredWorkout(w.id);
      expect(BiometricsService.workoutsForDate(start), isEmpty);
      expect(await database.biometricsDao.getWorkoutsForDateKey(key(start)), isEmpty);
    });

    test('and leaves the day\'s other sessions alone', () async {
      final a = await BiometricsService.saveEnteredWorkout(
          activityType: 'SWIMMING', startedAt: DateTime(2026, 6, 19, 7), durationMinutes: 30);
      final b = await BiometricsService.saveEnteredWorkout(
          activityType: 'YOGA', startedAt: DateTime(2026, 6, 19, 18), durationMinutes: 30);
      await BiometricsService.deleteEnteredWorkout(a.id);
      expect(idsOn(start), [b.id]);
    });

    test('Undo brings it back as it was', () async {
      final w = await BiometricsService.saveEnteredWorkout(
          activityType: 'SWIMMING',
          startedAt: start,
          durationMinutes: 30,
          kcal: 250,
          note: 'lane 3');
      await BiometricsService.deleteEnteredWorkout(w.id);
      await BiometricsService.restoreEnteredWorkout(w);

      final back = BiometricsService.workoutsForDate(start).single;
      expect(back.id, w.id);
      expect(back.energyKcal, 250);
      expect(back.note, 'lane 3');
      final rows = await database.biometricsDao.getWorkoutsForDateKey(key(start));
      expect(rows, hasLength(1), reason: 'the tombstone is cleared, not a second row');
      expect(rows.single.deletedAt, isNull);
    });
  });

  group('a sync does not drop them', () {
    HealthDataPoint watchRun(DateTime from) => HealthDataPoint(
          uuid: 'w-${from.millisecondsSinceEpoch}',
          value: WorkoutHealthValue(
            workoutActivityType: HealthWorkoutActivityType.RUNNING,
            totalEnergyBurned: 300,
            totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
            totalDistance: 5000,
            totalDistanceUnit: HealthDataUnit.METER,
          ),
          type: HealthDataType.WORKOUT,
          unit: HealthDataUnit.NO_UNIT,
          dateFrom: from,
          dateTo: from.add(const Duration(minutes: 30)),
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'unknown',
          sourceId: 'com.watch',
          sourceName: 'Watch',
          recordingMethod: RecordingMethod.automatic,
        );

    /// A day the aggregator will keep needs some heart rate in it; a workout
    /// alone is not a day.
    HealthDataPoint heartRate(DateTime at, int bpm) => HealthDataPoint(
          uuid: 'hr-${at.millisecondsSinceEpoch}',
          value: NumericHealthValue(numericValue: bpm),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: at,
          dateTo: at,
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'unknown',
          sourceId: 'com.watch',
          sourceName: 'Watch',
          recordingMethod: RecordingMethod.automatic,
        );

    Map<String, List<HealthDataPoint>> watchDay() => {
          key(start): [
            watchRun(DateTime(2026, 6, 19, 7)),
            heartRate(DateTime(2026, 6, 19, 7, 10), 140),
            heartRate(DateTime(2026, 6, 19, 7, 20), 150),
            heartRate(DateTime(2026, 6, 19, 3), 55),
          ],
        };

    test('the watch\'s session and yours sit side by side', () async {
      final mine = await BiometricsService.saveEnteredWorkout(
          activityType: 'YOGA', startedAt: DateTime(2026, 6, 19, 18), durationMinutes: 30);

      await BiometricsService.syncFromHealth(
        days: 3,
        now: DateTime(2026, 6, 20, 12),
        samples: watchDay(),
      );

      final day = BiometricsService.workoutsForDate(start);
      expect(day.map((w) => w.activityType), ['RUNNING', 'YOGA'],
          reason: 'in the order they happened');
      expect(day.map((w) => w.id), contains(mine.id),
          reason: 'replacing the day\'s list outright used to drop it from the screen');
    });

    test('and it is still there after the screen reloads from the database', () async {
      // Relative to the real clock: the reload reads the window ending today.
      final t = DateTime.now();
      final yesterday = DateTime(t.year, t.month, t.day - 1);
      final morning = DateTime(yesterday.year, yesterday.month, yesterday.day, 7);
      await BiometricsService.saveEnteredWorkout(
          activityType: 'YOGA',
          startedAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 18),
          durationMinutes: 30);
      await BiometricsService.syncFromHealth(days: 3, now: t, samples: {
        key(yesterday): [
          watchRun(morning),
          heartRate(morning.add(const Duration(minutes: 10)), 140),
          heartRate(morning.add(const Duration(minutes: 20)), 150),
          heartRate(DateTime(yesterday.year, yesterday.month, yesterday.day, 3), 55),
        ],
      });
      await BiometricsService.reloadFromDb();
      expect(BiometricsService.workoutsForDate(yesterday), hasLength(2));
    });
  });
}
