/// One mood per day, whichever screen it was tapped on.
///
/// The app held two mood records on OPPOSITE scales: the mood log
/// (`MoodEntry.moodIndex`, 0 = Great … 4 = Terrible, shared with the per-dose
/// mood) and the period sheet (`PeriodDay.mood`, 1 = very low … 5 = very good).
/// A user who tapped a face on the period sheet and then again on the mood
/// screen recorded the same day twice, on scales that disagree about which end
/// is good. This is the single place that translates between them and decides
/// which one is "the day's mood".
library;

class DayMood {
  const DayMood._();

  /// The period sheet's 1..5 (5 = best) as the mood log's 0..4 (0 = best).
  static int? toMoodIndex(int? periodMood) =>
      periodMood == null ? null : (5 - periodMood).clamp(0, 4);

  /// The mood log's 0..4 (0 = best) as the period sheet's 1..5 (5 = best).
  static int? toPeriodMood(int? moodIndex) =>
      moodIndex == null ? null : (5 - moodIndex).clamp(1, 5);

  /// The day's mood on the period sheet's scale, from whatever has been logged.
  ///
  /// Either source alone is simply used. When both exist the one written LAST
  /// wins, so tapping a face on either screen always overrides the other and
  /// neither can resurrect an older answer.
  ///
  /// [latestEntryAt] is when the mood-log entry was written; [periodUpdatedAt]
  /// when the period day was last saved. A missing [periodUpdatedAt] counts as
  /// older than any entry: a period day with no timestamp predates the feature.
  static int? resolve({
    int? periodMood,
    DateTime? periodUpdatedAt,
    int? latestEntryIndex,
    DateTime? latestEntryAt,
  }) {
    if (latestEntryIndex == null) return periodMood;
    if (periodMood == null) return toPeriodMood(latestEntryIndex);
    if (periodUpdatedAt == null ||
        (latestEntryAt != null && latestEntryAt.isAfter(periodUpdatedAt))) {
      return toPeriodMood(latestEntryIndex);
    }
    return periodMood;
  }

  /// Whether saving [periodMood] needs a NEW mood-log entry: it has to be a
  /// real answer and must differ from what the log already says for the day.
  /// Re-saving a sheet without touching the mood must not stack a duplicate.
  static bool needsLogEntry({int? periodMood, int? latestEntryIndex}) =>
      periodMood != null && toMoodIndex(periodMood) != latestEntryIndex;
}
