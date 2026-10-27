import 'package:flutter/foundation.dart';

import '../../../core/services/clean_storage_service.dart';
import '../models/reminder_model.dart';
import '../utils/reminder_helper.dart';
import '../utils/reminder_later.dart';
import '../utils/reminder_occurrence.dart';
import 'reminder_alarm.dart';

/// What a triage did, so it can be taken back: every reminder as it was, and
/// the occurrence each one's outcome was written against.
@immutable
class TriageUndo {
  const TriageUndo(this.originals, this.occurrences);

  final List<Reminder> originals;

  /// Reminder id → the occurrence whose outcome was settled.
  final Map<String, DateTime> occurrences;

  int get count => originals.length;
  bool get isEmpty => originals.isEmpty;
}

/// Catching up on a heap of overdue reminders in one go: move them to later,
/// or let them go.
///
/// Swiping one card is fine for one card. After a few days away there are a
/// dozen, and a dozen swipes is the reason the Overdue list becomes something
/// people stop looking at.
///
/// **Moving** applies to one-off reminders only. A repeating reminder's time IS
/// its schedule: moving one to tonight would move every future occurrence with
/// it. **Skipping** applies to everything: a one-off is closed, and a repeating
/// one jumps to its next time with this occurrence recorded as a deliberate
/// skip, which adherence does not count against anyone.
class OverdueTriage {
  const OverdueTriage._();

  /// The first moment "tonight" can be, and the evening slot itself.
  static const int eveningHour = ReminderLater.eveningHour;

  /// Past this hour there is no "later today" left to offer.
  static const int lastSlotHour = 22;

  /// Reminders that came due and are still open, oldest first. Paused ones are
  /// not overdue: nothing is being asked of the person.
  static List<Reminder> overdueOf(Iterable<Reminder> reminders, DateTime now) {
    final out = [
      for (final r in reminders)
        if (!r.isCompleted && !r.isPaused && r.scheduledTime.isBefore(now)) r,
    ]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return out;
  }

  /// A one-off can be moved; a repeating reminder is edited, not moved.
  static bool canMove(Reminder r) =>
      r.repeatType == RepeatType.none && r.recurrenceRule == null;

  /// The slot "later today" means from [now], or null once it is too late for
  /// one. 18:00 in the daytime; after that, an hour on from now, rounded up to
  /// the half hour, so "tonight" is never a time that has already gone.
  static DateTime? tonight(DateTime now) {
    final evening = DateTime(now.year, now.month, now.day, eveningHour);
    final inAnHour = now.add(const Duration(hours: 1));
    if (!inAnHour.isAfter(evening)) return evening;
    // An hour from now is already tomorrow: nothing left of today.
    if (inAnHour.day != now.day) return null;

    final minutes = inAnHour.hour * 60 + inAnHour.minute;
    final rounded = ((minutes + 29) ~/ 30) * 30;
    // Through the constructor, so a rounding that crosses the hour (or midnight)
    // normalises instead of overflowing a field.
    final slot = DateTime(now.year, now.month, now.day, 0, rounded);
    if (slot.day != now.day || slot.hour >= lastSlotHour) return null;
    return slot;
  }

  /// "This evening" or "Tonight", for the button.
  static String tonightLabel(DateTime slot) =>
      slot.hour < 20 ? 'This evening' : 'Tonight';

  /// Tomorrow at 9:30. Built through the constructor so the wall-clock time
  /// survives a DST change.
  static DateTime tomorrowMorning(DateTime now) => DateTime(now.year, now.month,
      now.day + 1, ReminderLater.morningHour, ReminderLater.morningMinute);

  // ---- doing it ----------------------------------------------------------

  /// Move every one-off in [overdue] to [to]. Repeating reminders are left
  /// alone. The occurrence each one leaves behind is settled as skipped: it was
  /// put off on purpose, not missed, and the sweep must not write it off.
  static Future<TriageUndo> move(
    List<Reminder> overdue, {
    required DateTime to,
    ReminderAlarm alarm = const NotificationReminderAlarm(),
  }) async {
    final originals = <Reminder>[];
    final occurrences = <String, DateTime>{};
    for (final r in overdue) {
      if (!canMove(r)) continue;
      await CleanStorageService.recordReminderOutcome(
        reminderId: r.id,
        scheduledFor: r.scheduledTime,
        outcome: ReminderOutcome.skipped,
        source: 'triage',
      );
      final moved = r.copyWith(scheduledTime: to, isCompleted: false);
      await CleanStorageService.saveReminder(moved);
      await _arm(moved, alarm);
      originals.add(r);
      occurrences[r.id] = r.scheduledTime;
    }
    return TriageUndo(originals, occurrences);
  }

  /// Let every reminder in [overdue] go. A one-off is closed; a repeating one
  /// jumps to its next time, or closes if it has none left.
  static Future<TriageUndo> skip(
    List<Reminder> overdue, {
    ReminderAlarm alarm = const NotificationReminderAlarm(),
  }) async {
    final originals = <Reminder>[];
    final occurrences = <String, DateTime>{};
    for (final r in overdue) {
      final occurrence = resolveReminderOccurrence(r);
      await CleanStorageService.recordReminderOutcome(
        reminderId: r.id,
        scheduledFor: occurrence,
        outcome: ReminderOutcome.skipped,
        source: 'triage',
      );

      final next = canMove(r) ? null : ReminderHelper.nextOccurrenceOrNull(r);
      if (next != null) {
        final rolled = r.copyWith(scheduledTime: next, isCompleted: false);
        await CleanStorageService.saveReminder(rolled);
        await _arm(rolled, alarm);
      } else {
        // A one-off, or a repeating reminder with nothing left to come.
        await CleanStorageService.saveReminder(r.copyWith(isCompleted: true));
        try {
          // disarm(), not a bare cancel: it also withdraws the follow-up.
          await alarm.disarm(
            id: r.notificationSlot,
            repeatType: r.repeatType,
            customDays: r.customDays,
          );
        } catch (e) {
          debugPrint('⚠️ Disarming "${r.title}" after a skip failed: $e');
        }
      }
      originals.add(r);
      occurrences[r.id] = occurrence;
    }
    return TriageUndo(originals, occurrences);
  }

  /// Put everything back as it was: the rows, the alarms, and each occurrence
  /// returned to pending (the row is the evidence it came due).
  static Future<void> undo(
    TriageUndo undo, {
    ReminderAlarm alarm = const NotificationReminderAlarm(),
  }) async {
    for (final r in undo.originals) {
      final occurrence = undo.occurrences[r.id];
      if (occurrence != null) {
        await CleanStorageService.recordReminderOutcome(
          reminderId: r.id,
          scheduledFor: occurrence,
          outcome: ReminderOutcome.pending,
          // The shape the derive pass writes a pending row in, so an undone
          // triage is indistinguishable from one that was never made.
          firedAt: occurrence,
          source: 'triage',
        );
      }
      await CleanStorageService.saveReminder(r);
      await _arm(r, alarm);
    }
  }

  /// Best-effort, like every other arm after a change that is already saved: the
  /// next launch's re-arm pass recovers anything the OS refused.
  static Future<void> _arm(Reminder r, ReminderAlarm alarm) async {
    final request = ReminderArmRequest.forNextOccurrence(r);
    if (request == null) return;
    try {
      await alarm.arm(request);
    } catch (e) {
      debugPrint('⚠️ Re-arming "${r.title}" after a triage failed: $e');
    }
  }
}
