/// Tags on a mood entry: what the person did, and what the day itself says.
///
/// Pure Dart. The tags are stored as plain ids on the entry (`MoodEntry.tags`),
/// so adding to this list never needs a migration and an id from a later version
/// is shown by its title-cased name rather than dropped.
library;

class MoodTags {
  const MoodTags._();

  /// What the person did: picked by hand, one tap each.
  static const List<String> manual = [
    'walk',
    'exercise',
    'friends',
    'family',
    'work',
    'outdoors',
    'rest',
    'hobby',
  ];

  /// What the day itself says, added for the person when they log and
  /// removable: nobody should have to tag "slept badly" by hand for the app to
  /// know it.
  static const List<String> automatic = [
    'slept_well',
    'short_night',
    'active_day',
    'quiet_day',
    'period',
    'took_doses',
    'missed_dose',
  ];

  static const Map<String, String> _labels = {
    'walk': 'Walk',
    'exercise': 'Exercise',
    'friends': 'Friends',
    'family': 'Family',
    'work': 'Work',
    'outdoors': 'Outdoors',
    'rest': 'Rest',
    'hobby': 'Hobby',
    'slept_well': 'Slept well',
    'short_night': 'Short night',
    'active_day': 'Active day',
    'quiet_day': 'Quiet day',
    'period': 'Period',
    'took_doses': 'Took all doses',
    'missed_dose': 'Missed a dose',
  };

  /// How the tag reads after "days with": "a walk", "a short night".
  static const Map<String, String> _phrases = {
    'walk': 'a walk',
    'exercise': 'exercise',
    'friends': 'time with friends',
    'family': 'family time',
    'work': 'work',
    'outdoors': 'time outdoors',
    'rest': 'rest',
    'hobby': 'time on a hobby',
    'slept_well': 'a good night\'s sleep',
    'short_night': 'a short night',
    'active_day': 'an active day',
    'quiet_day': 'a quiet day',
    'period': 'a period',
    'took_doses': 'every dose taken',
    'missed_dose': 'a missed dose',
  };

  static bool isAutomatic(String id) => automatic.contains(id);

  static String label(String id) => _labels[id] ?? _titleCase(id);

  static String phrase(String id) =>
      _phrases[id] ?? _titleCase(id).toLowerCase();

  static String _titleCase(String id) {
    final words = id.split(RegExp(r'[_\s]+')).where((w) => w.isNotEmpty);
    return words
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// A night of at least this long counts as sleeping well.
  static const int sleptWellMinutes = 7 * 60;

  /// Under this, a short night. The same line the Today briefing draws.
  static const int shortNightMinutes = 6 * 60;

  /// Under this share of the step goal, at the end of the day, a quiet one.
  static const double quietDayShare = 0.4;

  /// The tags a day earns by itself, from what the app already knows.
  ///
  /// Each is only ever added from a figure that exists: no sleep recorded means
  /// no sleep tag, no steps read means no activity tag. "Quiet" needs the day to
  /// be over, because steps are still being counted until it is, and a mood
  /// logged at nine in the morning is not about a quiet day.
  static List<String> forDay({
    int? sleepMinutes,
    int? steps,
    int? stepGoal,
    bool dayIsOver = false,
    bool bleeding = false,
    int dosesDue = 0,
    int dosesTaken = 0,
    int dosesMissed = 0,
  }) {
    final out = <String>[];
    if (sleepMinutes != null && sleepMinutes > 0) {
      if (sleepMinutes >= sleptWellMinutes) out.add('slept_well');
      if (sleepMinutes < shortNightMinutes) out.add('short_night');
    }
    if (steps != null && steps > 0 && stepGoal != null && stepGoal > 0) {
      if (steps >= stepGoal) {
        out.add('active_day');
      } else if (dayIsOver && steps < stepGoal * quietDayShare) {
        out.add('quiet_day');
      }
    }
    if (bleeding) out.add('period');
    if (dosesMissed > 0) {
      out.add('missed_dose');
    } else if (dosesDue > 0 && dosesTaken >= dosesDue) {
      out.add('took_doses');
    }
    return out;
  }
}
