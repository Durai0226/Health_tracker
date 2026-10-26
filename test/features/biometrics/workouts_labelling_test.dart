/// The Workouts list's two pieces of derived presentation.
///
/// Both were found by opening the screen on a device with the seeded sessions:
///
///  * the day headers read `2026-09-28`, `2026-09-26`, `2026-09-24` — the raw
///    storage key, shown to the user directly above rows formatted as
///    "32 min · 5.20 km · 320 kcal". Only "Today" and "Yesterday" were ever
///    translated; everything older fell through;
///  * every row carried the same `exercise_rounded` dumbbell, so Running,
///    Walking and Strength training were identical at a glance and the icon
///    column carried no information at all.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/features/biometrics/screens/workouts_screen.dart';

void main() {
  /// Pinned mid-month so "yesterday" never crosses a month or year boundary.
  final now = DateTime(2026, 9, 30, 12);
  String label(String key) =>
      withClock(Clock.fixed(now), () => workoutDayLabel(key));

  group('day headers', () {
    test('today and yesterday are named', () {
      expect(label('2026-09-30'), 'Today');
      expect(label('2026-09-29'), 'Yesterday');
    });

    test('older days are formatted, not printed as storage keys', () {
      // The three headers that were on screen.
      expect(label('2026-09-28'), 'Sep 28');
      expect(label('2026-09-26'), 'Sep 26');
      expect(label('2026-09-24'), 'Sep 24');
    });

    test('a day in another year keeps its year', () {
      expect(label('2025-12-31'), 'Dec 31, 2025',
          reason: 'dropping the year would make an old session read as this '
              "year's");
    });

    test('no header is ever an ISO key', () {
      for (final key in const [
        '2026-09-30',
        '2026-09-29',
        '2026-09-28',
        '2026-01-01',
        '2025-12-31',
      ]) {
        expect(label(key), isNot(matches(RegExp(r'^\d{4}-\d{2}-\d{2}$'))),
            reason: '$key rendered as itself');
      }
    });

    test('an unparseable key is shown rather than dropped', () {
      expect(label('not-a-date'), 'not-a-date');
    });
  });

  group('type icons', () {
    test('the common families each get their own glyph', () {
      expect(workoutIconFor('RUNNING'), Symbols.directions_run_rounded);
      expect(workoutIconFor('WALKING'), Symbols.directions_walk_rounded);
      expect(workoutIconFor('STRENGTH_TRAINING'),
          Symbols.fitness_center_rounded);
      expect(workoutIconFor('SWIMMING_POOL'), Symbols.pool_rounded);
      expect(workoutIconFor('BIKING'), Symbols.directions_bike_rounded);
      expect(workoutIconFor('YOGA'), Symbols.self_improvement_rounded);
    });

    test('the three seeded sessions are told apart', () {
      // Exactly the rows that were on screen, all sharing one dumbbell.
      final icons = {
        workoutIconFor('RUNNING'),
        workoutIconFor('WALKING'),
        workoutIconFor('STRENGTH_TRAINING'),
      };
      expect(icons, hasLength(3),
          reason: 'Running, Walking and Strength training sat in one list and '
              'were visually identical');
    });

    test('compound plugin names match on their family', () {
      expect(workoutIconFor('RUNNING_TREADMILL'),
          Symbols.directions_run_rounded);
      expect(workoutIconFor('WALKING_STROLLER'),
          Symbols.directions_walk_rounded);
      expect(workoutIconFor('BIKING_STATIONARY'),
          Symbols.directions_bike_rounded);
    });

    test('an unknown type falls back rather than throwing', () {
      // There are 80+ plugin activity types and the list grows; an unmapped
      // one must degrade to the generic glyph.
      expect(workoutIconFor('SCUBA_DIVING'), Symbols.exercise_rounded);
      expect(workoutIconFor(''), Symbols.exercise_rounded);
    });
  });
}
