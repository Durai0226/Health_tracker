import 'package:tablet_remainder/core/database/app_database.dart' show ReminderOccurrence;

import '../../../core/health/adaptive_timing.dart';
import '../../../core/health/adherence_analyzer.dart';
import '../models/reminder_escalation.dart';
import '../models/reminder_model.dart';

/// Turns the occurrence log into the inputs the existing analytics engines
/// already understand.
///
/// Nothing here is new intelligence. `AdaptiveTiming` and `AdherenceAnalyzer`
/// have been in `lib/core/health/` all along — robust median with an IQR
/// confidence gate, Laplace-smoothed miss risk — wired only to medication.
/// Generic reminders could not use them because there was nothing to read: a
/// single mutable `isCompleted` boolean that roll-forward overwrote.
///
/// Pure and dependency-light on purpose, so every rule below is assertable
/// without a database or a notification queue.
class ReminderInsights {
  const ReminderInsights._();

  /// Map occurrences onto the engines' event type.
  ///
  /// **Pending rows are excluded, not counted as missed.** An occurrence that is
  /// merely still due is not a failure, and treating it as one would make
  /// adherence fall every evening and recover every morning. Only the sweep,
  /// which applies the user's own threshold, converts pending into missed.
  ///
  /// This mirrors the honesty rule the rest of `lib/core/health/` already
  /// follows: days with nothing logged are excluded rather than zeroed, because
  /// "a zero would measure app-opening, not drinking".
  static List<DoseEvent> toEvents(Iterable<ReminderOccurrence> rows) {
    final out = <DoseEvent>[];
    for (final r in rows) {
      final outcome = ReminderOutcome.fromName(r.outcome);
      switch (outcome) {
        case ReminderOutcome.pending:
          continue;
        case ReminderOutcome.done:
          out.add(DoseEvent(r.scheduledFor, DoseOutcome.taken));
        case ReminderOutcome.skipped:
          out.add(DoseEvent(r.scheduledFor, DoseOutcome.skipped));
        case ReminderOutcome.missed:
          out.add(DoseEvent(r.scheduledFor, DoseOutcome.missed));
      }
    }
    return out;
  }

  /// Minutes-since-midnight.
  static int _minutesOfDay(DateTime t) => t.hour * 60 + t.minute;

  /// The signed distance from [scheduled] to [acted], in minutes, taking the
  /// SHORTER way round the clock.
  ///
  /// A dose due at 23:55 and taken at 00:05 is ten minutes late, not
  /// 1,430 minutes early. Without this the median delta for any late-evening
  /// reminder is dominated by whichever occurrences happened to cross midnight,
  /// and the "suggestion" it produces is garbage — which is worse than no
  /// suggestion, because the user is invited to apply it.
  static int signedDeltaMinutes(DateTime scheduled, DateTime acted) {
    const day = 24 * 60;
    var delta = (_minutesOfDay(acted) - _minutesOfDay(scheduled)) % day;
    if (delta > day ~/ 2) delta -= day;
    return delta;
  }

  /// When the user actually acts on this reminder, expressed as the
  /// wrapped-corrected time-of-day the engine expects.
  static List<int> actualMinutesFor(
    Iterable<ReminderOccurrence> rows, {
    required int scheduledMinutes,
  }) {
    final out = <int>[];
    for (final r in rows) {
      if (ReminderOutcome.fromName(r.outcome) != ReminderOutcome.done) continue;
      final acted = r.actedAt;
      if (acted == null) continue;
      out.add(scheduledMinutes + signedDeltaMinutes(r.scheduledFor, acted));
    }
    return out;
  }

  /// "You usually do this at 08:40 — move it?"
  ///
  /// Always a suggestion. Applying it automatically is the line this does not
  /// cross: extraction can be automated, but the user keeps scheduling
  /// authority — and a bad shift on a reminder is worse than the fixed time,
  /// which is why `AdaptiveTiming` gates `confident` on ≥4 samples, a ≥15 minute
  /// shift and an IQR ≤90 minutes.
  static AdaptiveSuggestion suggestTimeShift({
    required Reminder reminder,
    required Iterable<ReminderOccurrence> occurrences,
  }) {
    final scheduledMinutes = _minutesOfDay(reminder.scheduledTime);
    return AdaptiveTiming.suggest(
      scheduledMinutes: scheduledMinutes,
      actualMinutes:
          actualMinutesFor(occurrences, scheduledMinutes: scheduledMinutes),
    );
  }

  /// How likely this reminder is to be missed at its current slot.
  static double missRisk({
    required Reminder reminder,
    required Iterable<ReminderOccurrence> occurrences,
  }) =>
      AdherenceAnalyzer.missRisk(
        weekday: reminder.scheduledTime.weekday,
        hour: reminder.scheduledTime.hour,
        history: toEvents(occurrences),
      );

  /// Proportion of resolved occurrences that were actually done. 0..1.
  static double adherence(Iterable<ReminderOccurrence> occurrences) =>
      AdherenceAnalyzer.adherence(toEvents(occurrences));

  /// A stronger escalation tier, when the history says this reminder is being
  /// missed and the current tier is doing nothing about it.
  ///
  /// Returns null when nothing should change — which is most of the time. Only
  /// ever a *suggestion*: silently making a reminder louder because a model said
  /// so is exactly the behaviour that gets notifications turned off wholesale.
  ///
  /// Never proposes `critical`. That tier means exact alarms and a full-screen
  /// takeover, which is a decision about how much a thing matters — a judgement
  /// only the user can make, not one to infer from a miss rate.
  static ReminderEscalation? suggestEscalation({
    required Reminder reminder,
    required Iterable<ReminderOccurrence> occurrences,
    int minSamples = 5,
  }) {
    final events = toEvents(occurrences);
    if (events.length < minSamples) return null;
    final risk = AdherenceAnalyzer.missRisk(
      weekday: reminder.scheduledTime.weekday,
      hour: reminder.scheduledTime.hour,
      history: events,
    );
    if (AdherenceAnalyzer.riskLabel(risk) != 'high') return null;

    switch (reminder.escalation) {
      case ReminderEscalation.gentle:
        return ReminderEscalation.standard;
      case ReminderEscalation.standard:
        return ReminderEscalation.insistent;
      case ReminderEscalation.insistent:
      case ReminderEscalation.critical:
        return null; // already as loud as this may propose
    }
  }
}
