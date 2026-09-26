import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase, ReminderOccurrence;
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/health/adherence_analyzer.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_insights.dart';

/// None of the analytics here is new. `AdaptiveTiming` (robust median with an
/// IQR confidence gate) and `AdherenceAnalyzer` (Laplace-smoothed miss risk)
/// have been in `lib/core/health/` all along — wired only to medication.
/// `AdaptiveTiming`'s own docstring frames it: *"Most apps market 'AI reminders'
/// that are really this: shift a fixed alarm toward when the user actually
/// acts."*
///
/// Generic reminders could not use any of it because there was nothing to read:
/// a single mutable `isCompleted` boolean that roll-forward overwrote. This
/// tests the adapter between the occurrence log and those engines.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ReminderOccurrence row(
    DateTime scheduledFor,
    ReminderOutcome outcome, {
    DateTime? actedAt,
  }) =>
      ReminderOccurrence(
        id: RemindersDao.occurrenceId('r-1', scheduledFor),
        reminderId: 'r-1',
        scheduledFor: scheduledFor,
        outcome: outcome.name,
        actedAt: actedAt,
        snoozeCount: 0,
      );

  Reminder reminderAt(DateTime at) =>
      Reminder(id: 'r-1', title: 't', body: '', scheduledTime: at);

  group('a delta across midnight takes the shorter way round', () {
    test('23:55 due, 00:05 acted is ten minutes LATE', () {
      // Naively this is -1430 minutes "early". One such occurrence poisons the
      // median for any late-evening reminder, and the suggestion it produces is
      // garbage the user is then invited to apply.
      expect(
        ReminderInsights.signedDeltaMinutes(
            DateTime(2026, 6, 10, 23, 55), DateTime(2026, 6, 11, 0, 5)),
        10,
      );
    });

    test('00:05 due, 23:55 acted the night before is ten minutes EARLY', () {
      expect(
        ReminderInsights.signedDeltaMinutes(
            DateTime(2026, 6, 11, 0, 5), DateTime(2026, 6, 10, 23, 55)),
        -10,
      );
    });

    test('an ordinary same-day delta is unaffected', () {
      expect(
        ReminderInsights.signedDeltaMinutes(
            DateTime(2026, 6, 10, 9, 0), DateTime(2026, 6, 10, 9, 25)),
        25,
      );
      expect(
        ReminderInsights.signedDeltaMinutes(
            DateTime(2026, 6, 10, 9, 0), DateTime(2026, 6, 10, 8, 40)),
        -20,
      );
    });

    test('exactly twelve hours resolves one way, not both', () {
      // The wrap threshold has to pick a side or the sign flips arbitrarily.
      final d = ReminderInsights.signedDeltaMinutes(
          DateTime(2026, 6, 10, 0, 0), DateTime(2026, 6, 10, 12, 0));
      expect(d.abs(), 720);
    });
  });

  group('pending is excluded, never counted as a miss', () {
    test('a still-due occurrence is not an event', () {
      // Otherwise adherence falls every evening and recovers every morning.
      final events = ReminderInsights.toEvents([
        row(DateTime(2026, 6, 10, 9), ReminderOutcome.pending),
        row(DateTime(2026, 6, 11, 9), ReminderOutcome.done,
            actedAt: DateTime(2026, 6, 11, 9)),
      ]);
      expect(events, hasLength(1));
      expect(events.single.outcome, DoseOutcome.taken);
    });

    test('adherence is computed over resolved occurrences only', () {
      final rows = [
        row(DateTime(2026, 6, 10, 9), ReminderOutcome.done,
            actedAt: DateTime(2026, 6, 10, 9)),
        row(DateTime(2026, 6, 11, 9), ReminderOutcome.missed),
        row(DateTime(2026, 6, 12, 9), ReminderOutcome.pending),
      ];
      // 1 of 2 resolved, not 1 of 3.
      expect(ReminderInsights.adherence(rows), 0.5);
    });

    test('skipped and missed are distinct events', () {
      final events = ReminderInsights.toEvents([
        row(DateTime(2026, 6, 10, 9), ReminderOutcome.skipped),
        row(DateTime(2026, 6, 11, 9), ReminderOutcome.missed),
      ]);
      expect(events.map((e) => e.outcome),
          [DoseOutcome.skipped, DoseOutcome.missed]);
    });
  });

  group('the suggestion is gated, not eager', () {
    List<ReminderOccurrence> consistentlyLate(int n, int lateBy) => [
          for (var i = 0; i < n; i++)
            row(DateTime(2026, 6, 1 + i, 9, 0), ReminderOutcome.done,
                actedAt: DateTime(2026, 6, 1 + i, 9, lateBy)),
        ];

    test('enough consistent history produces a confident shift', () {
      final s = ReminderInsights.suggestTimeShift(
        reminder: reminderAt(DateTime(2026, 6, 10, 9, 0)),
        occurrences: consistentlyLate(6, 40),
      );
      expect(s.confident, isTrue);
      expect(s.deltaMinutes, 40);
      expect(s.suggestedMinutes, 9 * 60 + 40);
    });

    test('too few samples is not confident', () {
      expect(
        ReminderInsights.suggestTimeShift(
          reminder: reminderAt(DateTime(2026, 6, 10, 9, 0)),
          occurrences: consistentlyLate(3, 40),
        ).confident,
        isFalse,
      );
    });

    test('a shift too small to matter is not confident', () {
      // Moving a reminder by five minutes is churn, not insight.
      expect(
        ReminderInsights.suggestTimeShift(
          reminder: reminderAt(DateTime(2026, 6, 10, 9, 0)),
          occurrences: consistentlyLate(6, 5),
        ).confident,
        isFalse,
      );
    });

    test('erratic history is not confident however many samples', () {
      final erratic = [
        for (var i = 0; i < 10; i++)
          row(DateTime(2026, 6, 1 + i, 9, 0), ReminderOutcome.done,
              actedAt: DateTime(2026, 6, 1 + i, 9 + (i % 5), 0)),
      ];
      expect(
        ReminderInsights.suggestTimeShift(
          reminder: reminderAt(DateTime(2026, 6, 10, 9, 0)),
          occurrences: erratic,
        ).confident,
        isFalse,
        reason: 'the IQR gate exists so a scattered history cannot masquerade '
            'as a preference',
      );
    });

    test('no history at all suggests nothing', () {
      final s = ReminderInsights.suggestTimeShift(
        reminder: reminderAt(DateTime(2026, 6, 10, 9, 0)),
        occurrences: const [],
      );
      expect(s.confident, isFalse);
      expect(s.sampleCount, 0);
    });

    test('a late-evening reminder is not wrecked by midnight crossings', () {
      // The end-to-end version of the wrap test above.
      final rows = [
        for (var i = 0; i < 6; i++)
          row(DateTime(2026, 6, 1 + i, 23, 50), ReminderOutcome.done,
              actedAt: DateTime(2026, 6, 2 + i, 0, 10)),
      ];
      final s = ReminderInsights.suggestTimeShift(
        reminder: reminderAt(DateTime(2026, 6, 10, 23, 50)),
        occurrences: rows,
      );
      expect(s.deltaMinutes, 20);
      expect(s.confident, isTrue);
    });
  });

  group('escalation is proposed, never imposed', () {
    List<ReminderOccurrence> mostlyMissed(int n) => [
          for (var i = 0; i < n; i++)
            row(DateTime(2026, 6, 1 + i, 21, 0), ReminderOutcome.missed),
        ];

    Reminder at(DateTime t, ReminderEscalation e) => Reminder(
          id: 'r-1',
          title: 't',
          body: '',
          scheduledTime: t,
          escalation: e,
        );

    test('a heavily missed reminder is nudged exactly one step up', () {
      // One step, not straight to the top: escalating a quiet reminder to a
      // full-screen alarm because of a bad fortnight is how people end up
      // turning notifications off wholesale.
      final due = DateTime(2026, 6, 1, 21, 0);
      expect(
        ReminderInsights.suggestEscalation(
            reminder: at(due, ReminderEscalation.gentle),
            occurrences: mostlyMissed(8)),
        ReminderEscalation.standard,
      );
      expect(
        ReminderInsights.suggestEscalation(
            reminder: at(due, ReminderEscalation.standard),
            occurrences: mostlyMissed(8)),
        ReminderEscalation.insistent,
      );
    });

    test('it never proposes critical', () {
      // Critical means exact alarms and a full-screen takeover — a judgement
      // about how much something matters, which a miss rate cannot make.
      final r = Reminder(
        id: 'r-1',
        title: 't',
        body: '',
        scheduledTime: DateTime(2026, 6, 1, 21, 0),
        escalation: ReminderEscalation.insistent,
      );
      expect(
        ReminderInsights.suggestEscalation(
            reminder: r, occurrences: mostlyMissed(20)),
        isNull,
      );
    });

    test('a well-kept reminder is left alone', () {
      final kept = [
        for (var i = 0; i < 10; i++)
          row(DateTime(2026, 6, 1 + i, 9, 0), ReminderOutcome.done,
              actedAt: DateTime(2026, 6, 1 + i, 9, 2)),
      ];
      expect(
        ReminderInsights.suggestEscalation(
            reminder: reminderAt(DateTime(2026, 6, 1, 9, 0)),
            occurrences: kept),
        isNull,
      );
    });

    test('too little history proposes nothing', () {
      expect(
        ReminderInsights.suggestEscalation(
            reminder: reminderAt(DateTime(2026, 6, 1, 21, 0)),
            occurrences: mostlyMissed(2)),
        isNull,
        reason: 'two misses is a bad week, not a pattern',
      );
    });
  });
}
