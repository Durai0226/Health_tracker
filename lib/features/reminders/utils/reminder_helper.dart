import 'package:clock/clock.dart';

import '../models/reminder_model.dart';
import '../models/reminder_recurrence.dart';

class ReminderHelper {
  /// The next time this reminder should fire, or null if it never should again.
  ///
  /// Null is a real answer, not a failure: a paused reminder, one past its
  /// `endsAt`, or one that has used up its `occurrenceLimit` has no next
  /// occurrence. Before those existed a repeating reminder ran forever and
  /// deleting it was the only way to stop it.
  ///
  /// The stepping itself lives in [ReminderRecurrence], which handles both the
  /// legacy [RepeatType] enum and an RFC 5545 rule, and — critically — steps by
  /// CALENDAR day rather than by a 24-hour `Duration`, so an 08:00 reminder is
  /// still 08:00 on the far side of a DST transition.
  static DateTime? nextOccurrenceOrNull(Reminder reminder) {
    if (reminder.isPaused) return null;

    final recurrence = ReminderRecurrence.parse(
      reminder.recurrenceRule,
      fallback: reminder.repeatType,
      fallbackDays: reminder.customDays,
    );
    if (!recurrence.repeats) return null;

    // `clock.now()`, not `DateTime.now()` — the project convention (see the
    // rationale in pubspec.yaml beside the `clock` dependency). Everything here
    // is time-of-day dependent, so a test that cannot pin the wall clock can
    // only assert invariants, never an actual instant.
    final now = clock.now();
    final next = recurrence.nextAfter(
      start: reminder.scheduledTime,
      after: now.isAfter(reminder.scheduledTime) ? now : reminder.scheduledTime,
    );
    if (next == null) return null;
    if (reminder.endsAt != null && next.isAfter(reminder.endsAt!)) return null;
    return next;
  }

  /// Back-compatible shape: callers that cannot express "never again" get the
  /// current time back, which they already treat as "nothing to schedule".
  ///
  /// Prefer [nextOccurrenceOrNull]; this exists so the change to an end-capable
  /// recurrence did not have to land in every call site at once.
  static DateTime getNextOccurrence(Reminder reminder) {
    if (reminder.repeatType == RepeatType.none &&
        reminder.recurrenceRule == null) {
      return reminder.scheduledTime;
    }
    return nextOccurrenceOrNull(reminder) ?? reminder.scheduledTime;
  }
}
