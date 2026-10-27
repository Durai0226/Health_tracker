/// A workout typed in by hand: what is offered, and what is believable.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/workout_entry.dart';
import 'package:tablet_remainder/features/biometrics/models/workout_session.dart';

void main() {
  final now = DateTime(2026, 6, 20, 18);
  final earlier = DateTime(2026, 6, 20, 7);

  String? check({
    DateTime? start,
    int minutes = 45,
    int? kcal,
    double? km,
  }) =>
      WorkoutEntry.validate(
        startedAt: start ?? earlier,
        durationMinutes: minutes,
        now: now,
        kcal: kcal,
        distanceKm: km,
      );

  group('the kinds on offer', () {
    test('are distinct, labelled, and plugin-style so they read like imported ones', () {
      final types = WorkoutEntry.activities.map((a) => a.type).toList();
      expect(types.toSet(), hasLength(types.length));
      for (final a in WorkoutEntry.activities) {
        expect(a.type, matches(RegExp(r'^[A-Z_]+$')));
        expect(a.label, isNotEmpty);
      }
    });

    test('are named on the chip exactly as the list names them afterwards', () {
      for (final a in WorkoutEntry.activities) {
        final shown = WorkoutSession(
          id: WorkoutEntry.idFor(DateTime(2026, 6, 20, 7), a.type),
          dateKey: '2026-06-20',
          startedAt: DateTime(2026, 6, 20, 7),
          endedAt: DateTime(2026, 6, 20, 8),
          durationMinutes: 60,
          activityType: a.type,
          createdAt: DateTime(2026, 6, 20, 7),
          updatedAt: DateTime(2026, 6, 20, 7),
        ).activityLabel;
        expect(a.label, shown,
            reason: 'the chip for ${a.type} says "${a.label}" but the list would '
                'say "$shown" — one kind of workout under two names');
      }
    });

    test('include the plain ones and an Other', () {
      final types = WorkoutEntry.activities.map((a) => a.type);
      expect(types, containsAll(['WALKING', 'RUNNING', 'BIKING', 'SWIMMING', 'OTHER']));
    });
  });

  group('what is believable', () {
    test('an ordinary workout', () {
      expect(check(), isNull);
      expect(check(kcal: 320, km: 5.2), isNull);
    });

    test('some time at all, or it is not a workout', () {
      expect(check(minutes: 0), contains('At least a minute'));
      expect(check(minutes: -5), isNotNull);
      expect(check(minutes: 1), isNull);
    });

    test('and not more than a day', () {
      expect(check(minutes: WorkoutEntry.maxMinutes), isNull);
      expect(check(minutes: WorkoutEntry.maxMinutes + 1), contains('more than a day'));
    });

    test('that has already started', () {
      expect(check(start: now.add(const Duration(hours: 2))), contains('not happened yet'));
    });

    test('with a little slack for a clock that is a minute fast', () {
      expect(check(start: now.add(const Duration(minutes: 4))), isNull);
      expect(check(start: now.add(const Duration(minutes: 6))), isNotNull);
    });

    test('calories inside a real range', () {
      expect(check(kcal: 0), isNull);
      expect(check(kcal: -1), contains('Calories'));
      expect(check(kcal: WorkoutEntry.maxKcal), isNull);
      expect(check(kcal: WorkoutEntry.maxKcal + 1), contains('Calories'));
    });

    test('distance inside a real range', () {
      expect(check(km: 0), isNull);
      expect(check(km: -0.5), contains('Distance'));
      expect(check(km: WorkoutEntry.maxDistanceKm), isNull);
      expect(check(km: WorkoutEntry.maxDistanceKm + 1), contains('Distance'));
    });

    test('an ultramarathon is a workout', () {
      expect(check(minutes: 12 * 60, km: 100, kcal: 9000), isNull);
    });

    test('the first problem is the one said', () {
      expect(check(minutes: 0, kcal: -1), contains('At least a minute'));
    });
  });

  group('ids', () {
    test('an entered one can never be an imported one', () {
      final id = WorkoutEntry.idFor(DateTime(2026, 6, 20, 7), 'RUNNING');
      expect(id, startsWith('wm_'));
      expect(WorkoutEntry.isEntered(id), isTrue);
      expect(WorkoutEntry.isEntered('hw_1750000000000_RUNNING'), isFalse,
          reason: 'imports are hw_…');
    });

    test('the same start and kind is the same id: an edit, not a copy', () {
      final a = WorkoutEntry.idFor(DateTime(2026, 6, 20, 7), 'RUNNING');
      final b = WorkoutEntry.idFor(DateTime(2026, 6, 20, 7), 'RUNNING');
      expect(a, b);
      expect(WorkoutEntry.idFor(DateTime(2026, 6, 20, 7), 'WALKING'), isNot(a));
    });
  });
}
