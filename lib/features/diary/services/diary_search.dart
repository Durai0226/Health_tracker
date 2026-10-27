/// Finding an entry again: a few words, matched against everything the entry
/// says — its title, its body, the tags on it and the mood it was written in.
library;

import '../../../core/health/mood_tags.dart';
import '../../medication/models/medicine_log.dart' show moodRatingLabels;
import '../models/diary_entry.dart';

class DiarySearch {
  const DiarySearch._();

  /// The words of [query], lower-cased. Blank means no search.
  static List<String> words(String query) => [
        for (final w in query.toLowerCase().split(RegExp(r'\s+')))
          if (w.isNotEmpty) w,
      ];

  /// The entries that contain EVERY word of [query] somewhere, in their
  /// original order. A blank query returns them all.
  ///
  /// Every word, not any word: "walk friends" narrows to the days that had both,
  /// which is what typing a second word means.
  static List<DiaryEntry> filter(List<DiaryEntry> entries, String query) {
    final ws = words(query);
    if (ws.isEmpty) return entries;
    return [
      for (final e in entries)
        if (_matches(e, ws)) e,
    ];
  }

  static bool _matches(DiaryEntry e, List<String> ws) {
    final hay = [
      e.title ?? '',
      e.body,
      for (final t in e.tags) MoodTags.label(t),
      if (e.moodIndex != null)
        moodRatingLabels[e.moodIndex!.clamp(0, moodRatingLabels.length - 1)],
    ].join('\n').toLowerCase();
    return ws.every(hay.contains);
  }
}
