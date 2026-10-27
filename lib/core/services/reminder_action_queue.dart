import 'intent_queue.dart';

/// What a reminder's notification button asked for.
enum ReminderNotificationAction {
  /// "Done": the person did it.
  done,

  /// "Later": not now; this evening, or tomorrow morning.
  later,
}

/// A reminder answered from its notification, waiting for the main isolate to
/// write it down.
///
/// The button runs in a background isolate with no Drift, so it only records what
/// was asked ([ReminderActionQueue.enqueue]); the main isolate applies it on its
/// next resume and acknowledges what landed. The same hand-off the dose, water
/// and check-in answers use.
class PendingReminderAction {
  const PendingReminderAction({
    required this.reminderId,
    required this.action,
    required this.at,
    required this.intent,
    this.laterAt,
  });

  final String reminderId;
  final ReminderNotificationAction action;

  /// When the button was tapped.
  final DateTime at;

  /// For [ReminderNotificationAction.later]: when the notification was set to
  /// ring again.
  final DateTime? laterAt;

  final PendingIntent intent;
}

class ReminderActionQueue {
  ReminderActionQueue._();

  static const IntentQueue _queue = IntentQueue('pending_reminder_actions');

  static Future<void> enqueue({
    required String reminderId,
    required ReminderNotificationAction action,
    required DateTime at,
    DateTime? laterAt,
  }) =>
      _queue.enqueue({
        'reminderId': reminderId,
        'action': action.name,
        if (laterAt != null) 'laterMs': laterAt.millisecondsSinceEpoch,
      }, at: at);

  /// Everything queued, oldest first, without clearing it. A record without a
  /// reminder id, or with an action this build does not know, is dropped.
  static Future<List<PendingReminderAction>> drain() async {
    final pending = await _queue.drain(isValid: (d) {
      final id = d['reminderId'];
      return id is String &&
          id.isNotEmpty &&
          ReminderNotificationAction.values.any((a) => a.name == d['action']);
    });
    return [
      for (final p in pending)
        PendingReminderAction(
          reminderId: p.data['reminderId'] as String,
          action: ReminderNotificationAction.values
              .firstWhere((a) => a.name == p.data['action']),
          at: p.at,
          laterAt: p.data['laterMs'] is int
              ? DateTime.fromMillisecondsSinceEpoch(p.data['laterMs'] as int)
              : null,
          intent: p,
        ),
    ];
  }

  static Future<void> ack(Iterable<PendingReminderAction> applied) =>
      _queue.ack(applied.map((a) => a.intent));
}
