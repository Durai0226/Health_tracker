import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/daos/reminders_dao.dart'
    show genericReminderFollowUpOffset;
import '../../../core/services/background_alarm_service.dart' show snoozeIdOffset;
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/reminder_action_queue.dart';
import '../models/reminder_model.dart';
import '../utils/reminder_later.dart';
import 'reminder_alarm.dart';
import 'reminder_completion.dart';

/// A reminder answered from its notification, now written down.
@immutable
class AppliedReminderAction {
  const AppliedReminderAction({
    required this.title,
    required this.action,
    this.done,
    this.movedTo,
    this.movedLabel,
  });

  final String title;
  final ReminderNotificationAction action;

  /// For a Done: what it changed, so it can be taken back.
  final DoneUndo? done;

  /// For a Later that moved the reminder: where to, and how to say it ("this
  /// evening", "tomorrow morning").
  final DateTime? movedTo;
  final String? movedLabel;
}

/// Writes down what the Done and Later buttons on a reminder's notification
/// asked for.
///
/// The buttons run in a background isolate with no Drift, so they only queued the
/// answer ([ReminderActionQueue]); this is where it becomes a reminder ticked off
/// or put off, on the next resume — by the same code a tick in the app uses
/// ([ReminderCompletion]).
class ReminderActionService {
  const ReminderActionService._();

  /// True while a drain is in flight: the shell drains on cold start AND on
  /// resume, and the queue is read-then-ack, so two overlapping drains would each
  /// apply the same answer.
  static bool _draining = false;

  /// Apply what is queued, oldest first. Returns what changed.
  ///
  /// An answer about a reminder that has since been deleted, or already done, is
  /// acknowledged and says nothing. One that fails to write is left queued for
  /// the next resume — never acknowledged, so never lost.
  static Future<List<AppliedReminderAction>> drainPending({
    ReminderAlarm alarm = const NotificationReminderAlarm(),
  }) async {
    if (_draining) return const [];
    _draining = true;
    try {
      final pending = await ReminderActionQueue.drain();
      final applied = <AppliedReminderAction>[];
      for (final p in pending) {
        try {
          final result = await _apply(p, alarm);
          if (result != null) applied.add(result);
          // One at a time, immediately: being killed half way leaves the rest
          // queued and the written ones forgotten.
          await ReminderActionQueue.ack([p]);
        } catch (e) {
          debugPrint('⚠️ applying a queued reminder answer failed: $e');
        }
      }
      return applied;
    } finally {
      _draining = false;
    }
  }

  static Future<AppliedReminderAction?> _apply(
      PendingReminderAction p, ReminderAlarm alarm) async {
    final reminder = CleanStorageService.getReminders()
        .where((r) => r.id == p.reminderId)
        .firstOrNull;
    if (reminder == null) return null;

    switch (p.action) {
      case ReminderNotificationAction.done:
        // At the moment of the tap, not of this resume: a Done at 09:05 applied
        // that evening is the 09:00 occurrence's, however late it is written.
        final done = await ReminderCompletion.markDone(reminder,
            now: p.at, source: 'notification', alarm: alarm);
        if (done == null) return null;
        return AppliedReminderAction(
            title: reminder.title,
            action: p.action,
            done: done);

      case ReminderNotificationAction.later:
        final laterAt = p.laterAt;
        if (laterAt == null) return null;
        // A repeating reminder is put off for ONE ring, which the background
        // handler already armed; its schedule stays as it is. And one that is
        // done, or that the person has since moved on past this time, is left
        // alone.
        final repeats = reminder.repeatType != RepeatType.none ||
            reminder.recurrenceRule != null;
        if (repeats ||
            reminder.isCompleted ||
            !reminder.scheduledTime.isBefore(laterAt)) {
          return null;
        }
        final moved =
            reminder.copyWith(scheduledTime: laterAt, isCompleted: false);
        await CleanStorageService.saveReminder(moved);
        if (laterAt.isAfter(clock.now())) {
          final request = ReminderArmRequest.forNextOccurrence(moved);
          var armed = false;
          if (request != null) {
            try {
              armed = await alarm.arm(request);
            } catch (e) {
              debugPrint('⚠️ Re-arming "${moved.title}" after Later failed: $e');
            }
          }
          // The reminder's own alarm is the one that counts from here, so the
          // ring the button set up in the background is withdrawn — left alone
          // it would ring a second time at the same minute. But only once the
          // reminder's own stands: until then that ring is all there is.
          if (armed) await _withdrawBackgroundRing(reminder, alarm);
        }
        return AppliedReminderAction(
            title: reminder.title,
            action: p.action,
            movedTo: laterAt,
            movedLabel: ReminderLater.label(p.at));
    }
  }

  /// Cancel the snooze-id rings a Later may have set up for [reminder]: one hop
  /// from its own slot, two when the button was tapped on a snoozed re-fire, and
  /// one from its "Still pending" follow-up's id when it was tapped there.
  static Future<void> _withdrawBackgroundRing(
      Reminder reminder, ReminderAlarm alarm) async {
    final slot = reminder.notificationSlot & 0x7FFFFFFF;
    final ids = <int>{
      slot + snoozeIdOffset,
      slot + 2 * snoozeIdOffset,
      slot + genericReminderFollowUpOffset + snoozeIdOffset,
    };
    for (final id in ids) {
      try {
        await alarm.disarm(id: id & 0x7FFFFFFF, repeatType: RepeatType.none);
      } catch (e) {
        debugPrint('⚠️ Withdrawing a Later ring failed: $e');
      }
    }
  }

  /// Take back what [applied] did: only a Done can be undone. A Later is the
  /// person's to move again from the reminder itself.
  static Future<void> undo(
    Iterable<AppliedReminderAction> applied, {
    ReminderAlarm alarm = const NotificationReminderAlarm(),
  }) async {
    for (final a in applied) {
      final done = a.done;
      if (done != null) await ReminderCompletion.undo(done, alarm: alarm);
    }
  }

  /// What to tell the person, in a few words: null when nothing changed.
  ///
  /// "Marked "Call the clinic" done", "Marked 3 reminders done", "Moved "Call
  /// the clinic" to this evening", or both, joined.
  static String? say(List<AppliedReminderAction> applied) {
    final dones = [
      for (final a in applied)
        if (a.action == ReminderNotificationAction.done) a
    ];
    final moves = [
      for (final a in applied)
        if (a.action == ReminderNotificationAction.later) a
    ];
    final parts = <String>[
      if (dones.length == 1)
        'Marked "${dones.single.title}" done'
      else if (dones.length > 1)
        'Marked ${dones.length} reminders done',
      if (moves.length == 1)
        'Moved "${moves.single.title}" to ${moves.single.movedLabel}'
      else if (moves.length > 1)
        'Moved ${moves.length} reminders to later',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Whether anything in [applied] can be taken back.
  static bool canUndo(Iterable<AppliedReminderAction> applied) =>
      applied.any((a) => a.done != null);
}
