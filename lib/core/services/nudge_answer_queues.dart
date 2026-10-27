import 'intent_queue.dart';

/// A mood answered from the "How are you feeling?" notification, waiting to be
/// written to the Mood log. The index is the log's own scale (0 = Great …
/// 4 = Terrible).
class PendingMoodAnswer {
  const PendingMoodAnswer({
    required this.moodIndex,
    required this.at,
    required this.intent,
  });

  final int moodIndex;
  final DateTime at;
  final PendingIntent intent;
}

class MoodAnswerQueue {
  MoodAnswerQueue._();

  static const IntentQueue _queue = IntentQueue('pending_mood_answers');

  static Future<void> enqueue({required int moodIndex, required DateTime at}) =>
      _queue.enqueue({'moodIndex': moodIndex}, at: at);

  static Future<List<PendingMoodAnswer>> drain() async {
    final pending = await _queue.drain(isValid: (d) {
      final i = d['moodIndex'];
      return i is int && i >= 0 && i <= 4;
    });
    return [
      for (final p in pending)
        PendingMoodAnswer(
            moodIndex: p.data['moodIndex'] as int, at: p.at, intent: p),
    ];
  }

  static Future<void> ack(Iterable<PendingMoodAnswer> applied) =>
      _queue.ack(applied.map((a) => a.intent));
}

/// "Started today", answered from the period reminder, waiting to be written to
/// the cycle log.
class PendingPeriodStart {
  const PendingPeriodStart({required this.at, required this.intent});

  final DateTime at;
  final PendingIntent intent;
}

class PeriodStartQueue {
  PeriodStartQueue._();

  static const IntentQueue _queue = IntentQueue('pending_period_starts');

  static Future<void> enqueue({required DateTime at}) =>
      _queue.enqueue(const {}, at: at);

  static Future<List<PendingPeriodStart>> drain() async => [
        for (final p in await _queue.drain())
          PendingPeriodStart(at: p.at, intent: p),
      ];

  static Future<void> ack(Iterable<PendingPeriodStart> applied) =>
      _queue.ack(applied.map((a) => a.intent));
}
