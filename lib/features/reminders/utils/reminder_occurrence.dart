import 'package:clock/clock.dart';

import '../models/reminder_model.dart';
import '../models/reminder_recurrence.dart';

/// The occurrence a tick belongs to — the most recent one at or before [now].
///
/// `Reminder.scheduledTime` is an ANCHOR, not the instant that just came due:
/// for a repeating reminder it is where the last roll-forward left it (or the
/// creation time, for one that has never been ticked), which can be days behind
/// the occurrence the user is actually ticking off. Recording `done` against the
/// anchor wrote the outcome onto an occurrence that was already history and left
/// the one that was genuinely due sitting `pending` — until the reconcile sweep
/// wrote it off as MISSED. So a reminder answered every single day still
/// reported poor adherence, and the "still pending" follow-up (keyed by
/// occurrence instant) fired anyway for something already done.
///
/// The direct analogue of `resolveDoseInstant` on the medication side. Steps
/// through [ReminderRecurrence] — the same walk
/// `CleanStorageService.recordDueReminderOccurrences` uses — so the tick lands
/// on the very row that pass derived, and by CALENDAR day, so an 08:00 reminder
/// is still 08:00 across a DST transition.
DateTime resolveReminderOccurrence(Reminder reminder, {DateTime? now}) {
  final at = now ?? clock.now();
  // Nothing has come due yet (or it is paused): the anchor IS the occurrence.
  if (reminder.isPaused || !reminder.scheduledTime.isBefore(at)) {
    return reminder.scheduledTime;
  }
  final recurrence = ReminderRecurrence.parse(
    reminder.recurrenceRule,
    fallback: reminder.repeatType,
    fallbackDays: reminder.customDays,
  );
  if (!recurrence.repeats) return reminder.scheduledTime;

  var latest = reminder.scheduledTime;
  // Bounded exactly as the derive pass bounds its own walk: a malformed rule
  // must not spin on a tap.
  for (var i = 0; i < 400; i++) {
    final next =
        recurrence.nextAfter(start: reminder.scheduledTime, after: latest);
    if (next == null || next.isAfter(at)) break;
    if (reminder.endsAt != null && next.isAfter(reminder.endsAt!)) break;
    latest = next;
  }
  return latest;
}
