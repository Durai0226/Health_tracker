import 'package:flutter/foundation.dart';

import '../../../core/services/clean_storage_service.dart';
import '../models/reminder_model.dart';
import '../utils/reminder_helper.dart';
import '../utils/reminder_occurrence.dart';
import 'reminder_alarm.dart';

/// What marking a reminder done changed, so it can be taken back.
@immutable
class DoneUndo {
  const DoneUndo({required this.original, required this.occurrence, required this.armed});

  /// The reminder as it was before.
  final Reminder original;

  /// The occurrence the outcome was written against.
  final DateTime occurrence;

  /// Whether the next occurrence, if there is one, is armed. False when the OS
  /// refused it, which the person should be told: the tick itself stuck.
  final bool armed;
}

/// Marking a reminder done, wherever it is asked from: its card, its
/// notification's Done button, the answers drained on resume.
///
/// One implementation, so the three cannot drift apart: what "done" does to the
/// occurrence log, to a repeating reminder's next time and to what is armed is
/// the same however the person said it.
class ReminderCompletion {
  const ReminderCompletion._();

  /// Mark [reminder] done at [now] (the moment of the tap, for an answer that
  /// waited in a queue). Null when it already is: a second Done — from a
  /// notification left on a lock screen — must not undo the first.
  ///
  /// The occurrence is written BEFORE anything changes the reminder: the
  /// roll-forward below overwrites its time, and until the row exists a
  /// completed repeat leaves no evidence it was ever due. It is written against
  /// the occurrence the tick belongs to, never the stored anchor — see
  /// [resolveReminderOccurrence].
  static Future<DoneUndo?> markDone(
    Reminder reminder, {
    DateTime? now,
    String source = 'app',
    ReminderAlarm alarm = const NotificationReminderAlarm(),
  }) async {
    if (reminder.isCompleted) return null;

    final occurrence = resolveReminderOccurrence(reminder, now: now);
    await CleanStorageService.recordReminderOutcome(
      reminderId: reminder.id,
      scheduledFor: occurrence,
      outcome: ReminderOutcome.done,
      actedAt: now,
      source: source,
    );

    // A repeat is a repeat whether it came from the form's choices or from a
    // rule; one with nothing left to come is finished, not rolled "forward" to
    // the instant it already had.
    final repeats = reminder.repeatType != RepeatType.none || reminder.recurrenceRule != null;
    final next = repeats ? ReminderHelper.nextOccurrenceOrNull(reminder) : null;
    var armed = true;

    // A PAUSED repeat has no next occurrence either, but is not finished:
    // ticking it leaves its schedule as it was.
    if (repeats && (next != null || reminder.isPaused)) {
      final rolled = reminder.copyWith(
        scheduledTime: next ?? reminder.scheduledTime,
        isCompleted: false,
      );
      await CleanStorageService.saveReminder(rolled);
      final request = ReminderArmRequest.forNextOccurrence(rolled);
      if (request != null) {
        // Best-effort: the tick is already saved, and the next launch's re-arm
        // pass recovers what the OS refused.
        try {
          armed = await alarm.arm(request);
        } catch (e) {
          armed = false;
          debugPrint('⚠️ Re-arming "${rolled.title}" after a tick failed: $e');
        }
      }
    } else {
      await CleanStorageService.toggleReminderCompletion(reminder);
      // disarm(), not a bare cancel: it also withdraws the follow-up, which
      // would otherwise fire "Still pending: …" for something already done.
      try {
        await alarm.disarm(
          id: reminder.notificationSlot,
          repeatType: reminder.repeatType,
          customDays: reminder.customDays,
        );
      } catch (e) {
        debugPrint('⚠️ Disarming "${reminder.title}" after a tick failed: $e');
      }
    }
    return DoneUndo(original: reminder, occurrence: occurrence, armed: armed);
  }

  /// Un-tick a finished reminder: its occurrence back to pending and the row
  /// open again. A correction, not an event — it records no second occurrence —
  /// and it arms nothing: what was finished is in the past.
  static Future<void> reopen(Reminder reminder, {String source = 'app'}) async {
    await CleanStorageService.recordReminderOutcome(
      reminderId: reminder.id,
      scheduledFor: resolveReminderOccurrence(reminder),
      outcome: ReminderOutcome.pending,
      source: source,
    );
    await CleanStorageService.toggleReminderCompletion(reminder);
  }

  /// Put back everything [markDone] changed: the reminder row, what is armed,
  /// and the occurrence (back to pending — the row is the evidence it came due).
  static Future<void> undo(
    DoneUndo done, {
    String source = 'app',
    ReminderAlarm alarm = const NotificationReminderAlarm(),
  }) async {
    await CleanStorageService.recordReminderOutcome(
      reminderId: done.original.id,
      scheduledFor: done.occurrence,
      outcome: ReminderOutcome.pending,
      // The shape the derive pass writes a pending row in, so an undone tick is
      // indistinguishable from one that was never made.
      firedAt: done.occurrence,
      source: source,
    );
    await CleanStorageService.saveReminder(done.original);
    final request = ReminderArmRequest.forNextOccurrence(done.original);
    if (request != null) {
      try {
        await alarm.arm(request);
      } catch (e) {
        debugPrint('⚠️ Re-arming "${done.original.title}" after an undo failed: $e');
      }
    }
  }
}
