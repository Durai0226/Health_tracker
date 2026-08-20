import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';
import 'package:tablet_remainder/features/focus/models/breathing_exercise.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';

/// Pure model invariants for Focus — no binding, no storage, no device.
///
/// Harvested from `focus_feature_e2e_test.dart` before that file was deleted.
/// That 673-line suite was disabled in its entirety by a `skip:` on its
/// outermost group, so none of its ~100 assertions had executed in months; its
/// stated reason (sqlite/path_provider unavailable headlessly) was also false,
/// since `responsive_overflow_test.dart` already builds `FocusScreen` headlessly
/// via `AppDatabase.forTesting`. Most of it asserted strings that had since been
/// renamed in `lib/`, so unskipping it would have produced failures rather than
/// coverage. These are the parts that were real, kept and strengthened.
void main() {
  group('the persisted wire format', () {
    // Focus history is stored as JSON in app preferences, and every enum in it
    // is serialised as `.index` (see FocusSession.toJson). Reordering or
    // inserting an enum value therefore silently REINTERPRETS every session,
    // plant and sound a user has ever recorded — a 25-minute "work" session
    // becomes "study", an oak becomes a cactus. Nothing guarded that, and no
    // behavioural test can: the old and new code are both self-consistent.
    //
    // These ordinals are a storage contract. Appending a new value at the END is
    // safe and deliberately still passes; inserting or reordering is what breaks
    // existing users, so each existing value is pinned individually rather than
    // by comparing the whole list (which would also fail on a legal append).
    //
    // Note `.name` is NOT used here: both enums carry an extension that shadows
    // it with a human display string ('Deep Work', 'Cherry Blossom'), so a test
    // written against `.name` asserts the label, not the wire format.
    test('FocusActivityType ordinals are frozen', () {
      const expected = {
        FocusActivityType.work: 0,
        FocusActivityType.study: 1,
        FocusActivityType.reading: 2,
        FocusActivityType.meditation: 3,
        FocusActivityType.creative: 4,
        FocusActivityType.exercise: 5,
        FocusActivityType.coding: 6,
        FocusActivityType.writing: 7,
        FocusActivityType.other: 8,
      };
      expected.forEach((value, index) {
        expect(value.index, index,
            reason: '$value moved to ${value.index}; every stored session with '
                'index $index now reads as something else');
      });
    });

    test('PlantType ordinals are frozen', () {
      const expected = {
        PlantType.seedling: 0,
        PlantType.sprout: 1,
        PlantType.sapling: 2,
        PlantType.tree: 3,
        PlantType.floweringTree: 4,
        PlantType.sakura: 5,
        PlantType.bamboo: 6,
        PlantType.bonsai: 7,
        PlantType.cactus: 8,
        PlantType.sunflower: 9,
        PlantType.lavender: 10,
        PlantType.oak: 11,
      };
      expected.forEach((value, index) {
        expect(value.index, index,
            reason: '$value moved to ${value.index}; every stored plant with '
                'index $index now renders as a different species');
      });
    });

    test('AmbientSoundType keeps none at index 0', () {
      // `_loadData` falls back to index 0 for a missing key, and `playSound`
      // treats `none` as "stop". If anything else took index 0, every user with
      // no stored preference would start a session playing that sound.
      expect(AmbientSoundType.values.first, AmbientSoundType.none);
    });
  });

  group('FocusSession', () {
    FocusSession sample() => FocusSession(
          id: 'session-1',
          startedAt: DateTime(2024, 1, 1, 10, 0),
          completedAt: DateTime(2024, 1, 1, 10, 25),
          targetMinutes: 25,
          actualMinutes: 25,
          wasCompleted: true,
          wasAbandoned: false,
          activityType: FocusActivityType.study,
          plantType: PlantType.tree,
          soundUsed: AmbientSoundType.rain,
          tagIds: const ['tag-a', 'tag-b'],
        );

    test('round-trips every field it persists', () {
      final restored = FocusSession.fromJson(sample().toJson());
      final original = sample();
      expect(restored.id, original.id);
      expect(restored.startedAt, original.startedAt);
      expect(restored.completedAt, original.completedAt);
      expect(restored.targetMinutes, original.targetMinutes);
      expect(restored.actualMinutes, original.actualMinutes);
      expect(restored.wasCompleted, original.wasCompleted);
      expect(restored.wasAbandoned, original.wasAbandoned);
      expect(restored.activityType, original.activityType);
      expect(restored.plantType, original.plantType);
      expect(restored.soundUsed, original.soundUsed);
      expect(restored.tagIds, original.tagIds);
    });

    test('tolerates a session written before tagIds existed', () {
      final json = sample().toJson()..remove('tagIds');
      expect(FocusSession.fromJson(json).tagIds, isEmpty);
    });

    test('an out-of-range enum index does not throw', () {
      // FAILS TODAY, deliberately — `PlantType.values[json['plantType']]`
      // throws RangeError on an index this build does not have. That happens for
      // real: a user on a newer build records `PlantType.oak` (index 11), rolls
      // back, and every subsequent read of their history throws. Worse, the same
      // pattern in FocusService._loadData sits inside one broad try/catch, so a
      // single bad value silently discards sessions, garden, stats AND
      // achievements together.
      final json = sample().toJson()
        ..['plantType'] = 999
        ..['activityType'] = 999;
      expect(() => FocusSession.fromJson(json), returnsNormally,
          reason: 'unknown enum indices must degrade to a default, not throw — '
              'persisted data outlives the code that wrote it');
    });
  });

  group('FocusPlant', () {
    test('round-trips', () {
      final plant = FocusPlant(
        id: 'plant-1',
        type: PlantType.sapling,
        plantedAt: DateTime(2024, 1, 1, 10, 0),
        durationMinutes: 30,
        isAlive: true,
        growthProgress: 1.0,
        activity: 'study',
      );
      final restored = FocusPlant.fromJson(plant.toJson());
      expect(restored.id, plant.id);
      expect(restored.type, plant.type);
      expect(restored.plantedAt, plant.plantedAt);
      expect(restored.durationMinutes, plant.durationMinutes);
      expect(restored.isAlive, plant.isAlive);
      expect(restored.growthProgress, plant.growthProgress);
    });

    test('the starting plant is free and no threshold is negative', () {
      // The harvested version of this test asserted that `unlockMinutes` rises
      // monotonically with enum order. It does not, and never did:
      //
      //   0, 30, 60, 120, 180, [300, 240], 360, [150], 200, 250, 500
      //
      // sakura(300) precedes bamboo(240), and cactus(150) sits after bonsai(360).
      // The enum is a CATALOGUE of unlockables, not a linear ladder — the picker
      // renders a grid where locked and unlocked items legitimately interleave.
      //
      // That assertion is not restored here, deliberately. It was inherited from
      // a suite disabled by a `skip:`, so it had never executed; had it ever run
      // it would have failed. Changing shipped unlock thresholds to satisfy an
      // invariant nobody designed for would alter what existing users have
      // earned, to make a test green. The real invariants are narrower:
      final thresholds = {
        for (final p in PlantType.values) p: p.unlockMinutes
      };
      expect(thresholds[PlantType.values.first], 0,
          reason: 'a new user with zero minutes must have something to plant');
      thresholds.forEach((plant, minutes) {
        expect(minutes, greaterThanOrEqualTo(0), reason: '$plant');
      });
    });
  });

  group('FocusStats', () {
    test('defaults to a clean slate', () {
      const stats = FocusStats();
      expect(stats.totalMinutes, 0);
      expect(stats.totalSessions, 0);
      expect(stats.completedSessions, 0);
      expect(stats.abandonedSessions, 0);
      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 0);
    });

    test('derives hours, alive plants and completion rate', () {
      const stats = FocusStats(
        totalMinutes: 120,
        totalSessions: 10,
        completedSessions: 8,
        abandonedSessions: 2,
        totalPlants: 10,
        deadPlants: 2,
      );
      expect(stats.totalHours, 2);
      expect(stats.alivePlants, 8);
      expect(stats.completionRate, 0.8);
    });

    test('completionRate does not divide by zero on a fresh install', () {
      const stats = FocusStats();
      expect(stats.completionRate, 0.0);
      expect(stats.completionRate.isNaN, isFalse);
    });

    test('round-trips', () {
      const stats = FocusStats(
        totalMinutes: 60,
        totalSessions: 5,
        completedSessions: 4,
        abandonedSessions: 1,
        currentStreak: 3,
        longestStreak: 7,
      );
      final restored = FocusStats.fromJson(stats.toJson());
      expect(restored.totalMinutes, stats.totalMinutes);
      expect(restored.totalSessions, stats.totalSessions);
      expect(restored.currentStreak, stats.currentStreak);
      expect(restored.longestStreak, stats.longestStreak);
    });
  });

  group('BreathingPattern', () {
    test('every pattern is fully specified', () {
      for (final p in BreathingPattern.values) {
        expect(p.name, isNotEmpty);
        expect(p.description, isNotEmpty);
        expect(p.inhaleSeconds, greaterThan(0));
        expect(p.exhaleSeconds, greaterThan(0));
        expect(p.recommendedCycles, greaterThan(0));
      }
    });

    test('totalCycleDuration is the sum of its four phases', () {
      for (final p in BreathingPattern.values) {
        expect(
            p.totalCycleDuration,
            p.inhaleSeconds +
                p.holdAfterInhaleSeconds +
                p.exhaleSeconds +
                p.holdAfterExhaleSeconds,
            reason: '${p.name} advertises a cycle length its phases do not sum '
                'to, so the breathing animation and the countdown disagree');
      }
    });
  });
}
