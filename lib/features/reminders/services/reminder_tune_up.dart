import 'package:tablet_remainder/core/database/app_database.dart' show ReminderOccurrence;

import '../models/reminder_model.dart';
import 'reminder_insights.dart';

/// What a reminder could change so it works better for this person.
enum TuneUpKind { move, louder, pause }

/// One concrete suggestion, ready to show and ready to apply.
class TuneUp {
  final TuneUpKind kind;

  /// "Snoozed 4 of last 6 · usually done around 9:40 PM".
  final String message;

  /// The button: "Move it", "Make it louder", "Pause it".
  final String actionLabel;

  /// For [TuneUpKind.move], the new time of day in minutes since midnight.
  final int? moveToMinutes;

  /// For [TuneUpKind.louder], the tier to switch to.
  final ReminderEscalation? escalation;

  const TuneUp({
    required this.kind,
    required this.message,
    required this.actionLabel,
    this.moveToMinutes,
    this.escalation,
  });
}

/// The one suggestion worth making for a repeating reminder, or nothing.
///
/// Built entirely from engines that already existed (`AdaptiveTiming` for "when
/// you actually do it", the miss-risk model for "this one is being missed") plus
/// the snooze events the alarm paths now record. It only ever SUGGESTS: the user
/// taps the button or ignores it, and nothing here changes a reminder by itself.
///
/// One at a time, in this order — move it, make it louder, pause it — because
/// three nags on one card is how a helpful feature gets switched off:
///  * **move** when the history shows a consistent time the person really does
///    it, which is the cheapest fix and often the whole problem;
///  * **louder** when it is being missed and is not already as loud as the app
///    will propose (never to `critical`; that is the user's call);
///  * **pause** when it has been ignored almost every time lately.
class ReminderTuneUp {
  const ReminderTuneUp._();

  /// How many recent occurrences the suggestion is based on.
  static const int window = 6;

  /// Fewest resolved occurrences before anything is suggested. Fewer than this
  /// is not history.
  static const int minHistory = 4;

  /// Occurrences snoozed, out of the window, before the move message leads with
  /// it.
  static const int snoozeMention = 2;

  /// Not done in at least this many of a full [window] means "ignored".
  static const int ignoredThreshold = 5;

  /// A snooze belongs to the occurrence it followed if it happened within this
  /// long after the occurrence was due.
  static const Duration snoozeReach = Duration(hours: 6);

  /// The last [window] RESOLVED occurrences, newest first. Pending ones are not
  /// failures yet, so they are left out, exactly as `ReminderInsights` does.
  static List<ReminderOccurrence> recent(Iterable<ReminderOccurrence> rows) {
    final resolved = rows
        .where((r) => ReminderOutcome.fromName(r.outcome).isResolved)
        .toList()
      ..sort((a, b) => b.scheduledFor.compareTo(a.scheduledFor));
    return resolved.take(window).toList();
  }

  /// How many of [occurrences] were followed by at least one snooze.
  static int snoozedCount(
      Iterable<ReminderOccurrence> occurrences, Iterable<DateTime> snoozes) {
    final times = snoozes.toList();
    var n = 0;
    for (final o in occurrences) {
      final from = o.scheduledFor;
      final to = from.add(snoozeReach);
      if (times.any((t) => !t.isBefore(from) && t.isBefore(to))) n++;
    }
    return n;
  }

  static String _clock(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
  }

  /// The suggestion for [reminder], or null.
  ///
  /// Only for a repeating reminder: a one-off has no history to learn from.
  static TuneUp? suggest({
    required Reminder reminder,
    required Iterable<ReminderOccurrence> occurrences,
    Iterable<DateTime> snoozes = const [],
  }) {
    final repeats = reminder.repeatType != RepeatType.none ||
        reminder.recurrenceRule != null;
    if (!repeats || reminder.isPaused) return null;

    final last = recent(occurrences);
    if (last.length < minHistory) return null;

    final snoozed = snoozedCount(last, snoozes);
    final notDone = last
        .where((o) => ReminderOutcome.fromName(o.outcome) != ReminderOutcome.done)
        .length;

    // 1. Move it: a consistent time the person actually does it.
    final shift =
        ReminderInsights.suggestTimeShift(reminder: reminder, occurrences: occurrences);
    if (shift.confident) {
      final when = _clock(shift.suggestedMinutes);
      final lead = snoozed >= snoozeMention
          ? 'Snoozed $snoozed of last ${last.length} · usually done around $when'
          : 'Usually done around $when';
      return TuneUp(
        kind: TuneUpKind.move,
        message: lead,
        actionLabel: 'Move it',
        moveToMinutes: shift.suggestedMinutes,
      );
    }

    // 2. Louder: being missed, and not already as loud as we would propose.
    final louder = ReminderInsights.suggestEscalation(
        reminder: reminder, occurrences: occurrences);
    if (louder != null) {
      return TuneUp(
        kind: TuneUpKind.louder,
        message: 'Missed ${last.where((o) => ReminderOutcome.fromName(o.outcome) == ReminderOutcome.missed).length} '
            'of your last ${last.length}',
        actionLabel: 'Make it louder',
        escalation: louder,
      );
    }

    // 3. Pause: ignored almost every time lately.
    if (last.length >= window && notDone >= ignoredThreshold) {
      return TuneUp(
        kind: TuneUpKind.pause,
        message: 'Not done in $notDone of your last ${last.length}',
        actionLabel: 'Pause it',
      );
    }
    return null;
  }

  /// [reminder] with [tuneUp] applied. Only the one field the suggestion is
  /// about changes; the date is kept, so a move shifts the time of day and
  /// nothing else.
  static Reminder apply(Reminder reminder, TuneUp tuneUp) {
    switch (tuneUp.kind) {
      case TuneUpKind.move:
        final m = tuneUp.moveToMinutes!;
        final t = reminder.scheduledTime;
        return reminder.copyWith(
            scheduledTime: DateTime(t.year, t.month, t.day, m ~/ 60, m % 60));
      case TuneUpKind.louder:
        return reminder.copyWith(escalation: tuneUp.escalation);
      case TuneUpKind.pause:
        return reminder.copyWith(isPaused: true);
    }
  }
}
