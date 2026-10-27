import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/nudge_answer_queues.dart';
import '../models/mood_entry.dart';
import 'mood_day_tags.dart';
import 'vitals_storage_service.dart';

/// A mood the person answered from the notification, now in the Mood log.
typedef AppliedMood = ({String id, int moodIndex, DateTime at});

/// Writes the moods answered from the "How are you feeling?" notification.
///
/// The button runs in a background isolate with no Drift, so it only queued the
/// answer ([MoodAnswerQueue]); this is where it becomes a Mood log entry, on the
/// next resume.
class MoodAnswers {
  const MoodAnswers._();

  /// True while a drain is in flight: the shell drains on cold start AND on
  /// resume, and the queue is read-then-ack, so two overlapping drains would
  /// each write the same answer.
  static bool _draining = false;

  /// Apply what is queued, oldest first. Returns what landed.
  ///
  /// Each entry is logged at the moment the button was tapped, not at resume —
  /// a mood answered at noon and an app opened that evening is a noon mood — and
  /// tagged from THAT day, the way a mood logged in the app is. Its id comes from
  /// the tap time, so a drain that is interrupted between the write and the ack
  /// and runs again overwrites the same entry instead of adding a second.
  static Future<List<AppliedMood>> drainPending() async {
    if (_draining) return const [];
    _draining = true;
    try {
      final pending = await MoodAnswerQueue.drain();
      final applied = <AppliedMood>[];
      for (final p in pending) {
        try {
          var tags = const <String>[];
          try {
            tags = await MoodDayTags.forDate(p.at);
          } catch (_) {}
          final id = 'mood_${p.at.microsecondsSinceEpoch}';
          await VitalsStorageService.saveMood(MoodEntry(
            id: id,
            moodIndex: p.moodIndex,
            takenAt: p.at,
            tags: tags,
            createdAt: clock.now(),
          ));
          applied.add((id: id, moodIndex: p.moodIndex, at: p.at));
          // One at a time, immediately: being killed half way leaves the rest
          // queued and the written ones forgotten.
          await MoodAnswerQueue.ack([p]);
        } catch (e) {
          debugPrint('⚠️ applying a queued mood answer failed: $e');
        }
      }
      return applied;
    } finally {
      _draining = false;
    }
  }

  /// Take [applied] back out of the log.
  static Future<void> undo(Iterable<AppliedMood> applied) async {
    for (final a in applied) {
      await VitalsStorageService.deleteMood(a.id);
    }
  }
}
