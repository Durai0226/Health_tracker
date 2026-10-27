/// What can be typed in for a workout the watch never saw: the kinds offered and
/// what makes an entry believable.
///
/// A person who ran with no watch, swam, or did a class has a workout the health
/// app will never hold. The Workouts list is otherwise read-only, so those days
/// looked like rest days. Pure rules; the form and the store use them.
library;

class WorkoutActivity {
  const WorkoutActivity(this.type, this.label);

  /// The same plugin-style name an imported workout carries
  /// (`HealthWorkoutActivityType.name`), so an entered session reads like an
  /// imported one everywhere that labels it.
  final String type;

  /// What the form's chip says. The Workouts list derives its own label from
  /// [type] (`BIKING` → "Biking"), so this must be exactly that: a chip that
  /// said "Cycling" over a row that said "Biking" would read as two kinds.
  final String label;
}

class WorkoutEntry {
  const WorkoutEntry._();

  static const List<WorkoutActivity> activities = [
    WorkoutActivity('WALKING', 'Walking'),
    WorkoutActivity('RUNNING', 'Running'),
    WorkoutActivity('BIKING', 'Biking'),
    WorkoutActivity('SWIMMING', 'Swimming'),
    WorkoutActivity('STRENGTH_TRAINING', 'Strength training'),
    WorkoutActivity('YOGA', 'Yoga'),
    WorkoutActivity('HIKING', 'Hiking'),
    WorkoutActivity('OTHER', 'Other'),
  ];

  /// A session this long or longer is a mistake (a day is 1,440 minutes).
  static const int maxMinutes = 24 * 60;
  static const int maxKcal = 20000;
  static const double maxDistanceKm = 1000;

  /// How far ahead of now a start may be before it is refused: a workout that
  /// has not happened is not a record.
  static const Duration futureSlack = Duration(minutes: 5);

  /// Why this entry cannot be saved, or null when it is believable.
  ///
  /// Refuses what no one could mean — no time at all, more than a day, a start in
  /// the future, a negative figure — and nothing merely unusual: an ultramarathon
  /// is a workout.
  static String? validate({
    required DateTime startedAt,
    required int durationMinutes,
    required DateTime now,
    int? kcal,
    double? distanceKm,
  }) {
    if (durationMinutes < 1) return 'How long did it last? At least a minute.';
    if (durationMinutes > maxMinutes) {
      return 'That is more than a day. Check the length.';
    }
    if (startedAt.isAfter(now.add(futureSlack))) {
      return 'That start time has not happened yet.';
    }
    if (kcal != null && (kcal < 0 || kcal > maxKcal)) {
      return 'Calories should be between 0 and $maxKcal.';
    }
    if (distanceKm != null && (distanceKm < 0 || distanceKm > maxDistanceKm)) {
      return 'Distance should be between 0 and ${maxDistanceKm.round()} km.';
    }
    return null;
  }

  /// The id of an entered workout: its start, with a prefix an import never uses,
  /// so entering one can never overwrite a session a watch wrote.
  static String idFor(DateTime startedAt, String activityType) =>
      'wm_${startedAt.millisecondsSinceEpoch}_$activityType';

  /// Whether [id] is one entered by hand.
  static bool isEntered(String id) => id.startsWith('wm_');
}
