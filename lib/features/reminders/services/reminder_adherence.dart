import 'package:tablet_remainder/core/database/app_database.dart'
    show ReminderOccurrence;

import '../../../core/health/health_windows.dart';
import '../../../core/health/streak_engine.dart';
import '../models/reminder_model.dart';

/// A day's worth of occurrences, reduced to whether it counts and whether it
/// went well.
class ReminderDay {
  const ReminderDay({
    required this.date,
    required this.due,
    required this.done,
  });

  final DateTime date;

  /// Occurrences that count toward the denominator — `done` or `missed`.
  final int due;

  /// Of those, how many were actually done.
  final int done;

  /// Every due occurrence was done.
  bool get covered => due > 0 && done == due;
}

/// Adherence over the occurrence log, in the shape a clinician report wants.
///
/// Modelled on **PDC** (proportion of days covered), which the Pharmacy Quality
/// Alliance prefers over MPR because MPR can exceed 100% — it counts total
/// supply dispensed rather than days actually covered, so an early refill
/// inflates it. The conventional adherent threshold is ≥80%.
///
/// Two deliberate deviations from clinical PDC, both following the honesty rules
/// the rest of `lib/core/health/` already enforces:
///
/// * **A day with nothing resolved is excluded, not scored zero.** The engines
///   here already reason that "a zero would measure app-opening, not drinking".
///   A day the user never opened the app is unknown, not a failure.
/// * **A deliberate skip does not count against you.** Clinically a skipped dose
///   is an uncovered day; here, marking something skipped is the user being
///   honest, and an adherence figure that punishes honesty teaches people to
///   stop being honest. A day whose only occurrences were skipped drops out of
///   both numerator and denominator.
/// What a surface needs to report how the last N days went.
///
/// Both rates on purpose. `proportionOfDaysCovered` is all-or-nothing per day —
/// the clinical convention, and the one with the ≥80% threshold behind it — while
/// `proportionOfOccurrencesDone` counts individual occurrences. A user who does
/// three of four reminders every single day scores 75% on the second and **0%**
/// on the first, and both are true about different things. Where they disagree,
/// the disagreement is the insight.
class ReminderAdherenceSummary {
  const ReminderAdherenceSummary({
    required this.proportionOfDaysCovered,
    required this.proportionOfOccurrencesDone,
    required this.daysCounted,
    required this.streak,
  });

  final double proportionOfDaysCovered;
  final double? proportionOfOccurrencesDone;

  /// The denominator, so a surface can state it rather than showing a bare
  /// percentage. Days with nothing resolved are not in here.
  final int daysCounted;

  final StreakResult streak;

  bool get isAdherent => ReminderAdherence.isAdherent(proportionOfDaysCovered);

  /// True when the two rates tell materially different stories — the
  /// "most of them, most days" pattern that a single figure hides.
  bool get ratesDisagree {
    final per = proportionOfOccurrencesDone;
    return per != null && (per - proportionOfDaysCovered).abs() >= 0.15;
  }
}

class ReminderAdherence {
  const ReminderAdherence._();

  /// Group occurrences into days that count.
  static List<ReminderDay> byDay(Iterable<ReminderOccurrence> occurrences) {
    final buckets = <String, ({DateTime date, int due, int done})>{};
    for (final o in occurrences) {
      final outcome = ReminderOutcome.fromName(o.outcome);
      // Pending: still due, not yet anything. Skipped: a deliberate non-action.
      // Neither is evidence of a missed reminder.
      if (outcome == ReminderOutcome.pending ||
          outcome == ReminderOutcome.skipped) {
        continue;
      }
      final key = dateKeyOf(o.scheduledFor);
      final prev = buckets[key] ??
          (date: dayOnly(o.scheduledFor), due: 0, done: 0);
      buckets[key] = (
        date: prev.date,
        due: prev.due + 1,
        done: prev.done + (outcome == ReminderOutcome.done ? 1 : 0),
      );
    }
    final days = buckets.values
        .map((b) => ReminderDay(date: b.date, due: b.due, done: b.done))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return days;
  }

  /// Proportion of counted days on which every due occurrence was done, 0..1.
  ///
  /// Returns null when there is nothing to measure. Null is not zero: showing
  /// "0% adherence" to someone who has simply not used the feature yet is both
  /// wrong and discouraging.
  static double? proportionOfDaysCovered(
      Iterable<ReminderOccurrence> occurrences) {
    final days = byDay(occurrences);
    if (days.isEmpty) return null;
    final covered = days.where((d) => d.covered).length;
    return covered / days.length;
  }

  /// The conventional threshold. ≥80% is "adherent" in the PQA sense.
  static bool isAdherent(double? pdc) => pdc != null && pdc >= 0.8;

  /// Per-occurrence rate — done ÷ (done + missed).
  ///
  /// Distinct from [proportionOfDaysCovered], which is all-or-nothing per day.
  /// A user who takes three of four daily doses every day scores 75% here and
  /// 0% there, and both numbers are true about different things.
  static double? proportionOfOccurrencesDone(
      Iterable<ReminderOccurrence> occurrences) {
    final days = byDay(occurrences);
    final due = days.fold<int>(0, (a, d) => a + d.due);
    if (due == 0) return null;
    return days.fold<int>(0, (a, d) => a + d.done) / due;
  }

  /// Streak over covered days, with the app's existing grace-day forgiveness.
  ///
  /// Reuses `StreakEngine` rather than counting consecutive days here: it
  /// already forgives one miss per rolling week and exposes `atRisk` and
  /// `gracesRemaining`, and the deliberate design that the shield is visible
  /// *before* the miss is worth inheriting, not reimplementing.
  static StreakResult streak(
    Iterable<ReminderOccurrence> occurrences, {
    required DateTime today,
    Set<DateTime> frozenDays = const {},
  }) =>
      StreakEngine.compute(
        completedDays:
            byDay(occurrences).where((d) => d.covered).map((d) => d.date).toSet(),
        today: today,
        frozenDays: frozenDays,
      );

  /// Rows for a CSV or PDF export, oldest first.
  ///
  /// Plain records rather than formatted strings so the caller decides the
  /// separator, the date format and the locale.
  static List<({String date, int due, int done, bool covered})> exportRows(
          Iterable<ReminderOccurrence> occurrences) =>
      byDay(occurrences)
          .map((d) => (
                date: dateKeyOf(d.date),
                due: d.due,
                done: d.done,
                covered: d.covered,
              ))
          .toList();
}
