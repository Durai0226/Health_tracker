/// One gentle prompt to write about, chosen from what the app already knows.
///
/// It offers a question and never writes anything: the entry only exists if the
/// person opens it and types. Nothing here nags — no prompt on a day that has an
/// entry already, and none when nothing stands out.
library;

import '../../../core/health/mood_tags.dart';

class DiaryPrompt {
  const DiaryPrompt({required this.id, required this.text});

  /// Stable, for tests and for remembering a dismissal.
  final String id;

  /// The question. It becomes the entry's title when the person starts writing.
  final String text;
}

class DiaryPrompts {
  const DiaryPrompts._();

  /// The most pressing prompt for the day, or null.
  ///
  /// Order: a short night, a dose that was missed yesterday, a low mood in the
  /// last day, a great one. [sleepMinutes] is asleep time for last night (null
  /// when unknown), [recentMoodIndex] the latest mood in the last 24 hours on
  /// the log's 0 (Great) to 4 (Terrible) scale.
  static DiaryPrompt? pick({
    required bool wroteToday,
    int? sleepMinutes,
    int missedDosesYesterday = 0,
    int? recentMoodIndex,
  }) {
    if (wroteToday) return null;
    if (sleepMinutes != null &&
        sleepMinutes > 0 &&
        sleepMinutes < MoodTags.shortNightMinutes) {
      return const DiaryPrompt(
          id: 'short_night', text: 'What got in the way of sleep?');
    }
    if (missedDosesYesterday > 0) {
      return const DiaryPrompt(
          id: 'missed_dose', text: 'What made a dose hard to take yesterday?');
    }
    if (recentMoodIndex != null && recentMoodIndex >= 3) {
      return const DiaryPrompt(
          id: 'low_mood', text: 'What has been on your mind?');
    }
    if (recentMoodIndex == 0) {
      return const DiaryPrompt(id: 'great_mood', text: 'What went well today?');
    }
    return null;
  }
}
