import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show ReminderOccurrence;
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_tune_up.dart';

void main() {
  // A daily 20:00 reminder.
  Reminder rem({ReminderEscalation e = ReminderEscalation.standard, bool paused = false, RepeatType r = RepeatType.daily}) =>
      Reminder(
        id: 'r',
        title: 'Stretch',
        body: '',
        scheduledTime: DateTime(2026, 3, 1, 20, 0),
        repeatType: r,
        escalation: e,
        isPaused: paused,
      );

  DateTime day(int d, [int h = 20, int m = 0]) => DateTime(2026, 3, d, h, m);

  ReminderOccurrence occ(int d, ReminderOutcome o, {DateTime? actedAt}) =>
      ReminderOccurrence(
        id: 'r_$d',
        reminderId: 'r',
        scheduledFor: day(d),
        actedAt: actedAt,
        outcome: o.name,
        snoozeCount: 0,
      );

  /// Done at 21:40 every time: a consistent, confident shift.
  List<ReminderOccurrence> doneLate() => [
        for (var d = 1; d <= 6; d++)
          occ(d, ReminderOutcome.done, actedAt: day(d, 21, 40)),
      ];

  List<ReminderOccurrence> missed(int n) => [
        for (var d = 1; d <= 6; d++)
          occ(d, d <= n ? ReminderOutcome.missed : ReminderOutcome.done,
              actedAt: d <= n ? null : day(d, 20, 2)),
      ];

  group('nothing to say', () {
    test('a one-off has no history to learn from', () {
      expect(
          ReminderTuneUp.suggest(
              reminder: rem(r: RepeatType.none), occurrences: doneLate()),
          isNull);
    });

    test('a paused reminder is left alone', () {
      expect(
          ReminderTuneUp.suggest(reminder: rem(paused: true), occurrences: doneLate()),
          isNull);
    });

    test('under 4 resolved occurrences is not history', () {
      expect(
          ReminderTuneUp.suggest(
              reminder: rem(), occurrences: doneLate().take(3)),
          isNull);
    });

    test('a reminder that is being done on time needs nothing', () {
      final onTime = [
        for (var d = 1; d <= 6; d++)
          occ(d, ReminderOutcome.done, actedAt: day(d, 20, 3)),
      ];
      expect(ReminderTuneUp.suggest(reminder: rem(), occurrences: onTime), isNull);
    });

    test('pending occurrences are not failures', () {
      final rows = [
        ...doneLate().take(3),
        occ(7, ReminderOutcome.pending),
        occ(8, ReminderOutcome.pending),
        occ(9, ReminderOutcome.pending),
      ];
      expect(ReminderTuneUp.suggest(reminder: rem(), occurrences: rows), isNull,
          reason: 'only 3 resolved');
    });
  });

  group('move it', () {
    test('a consistent late time is offered, with the time in words', () {
      final t = ReminderTuneUp.suggest(reminder: rem(), occurrences: doneLate())!;
      expect(t.kind, TuneUpKind.move);
      expect(t.message, 'Usually done around 9:40 PM');
      expect(t.actionLabel, 'Move it');
      expect(t.moveToMinutes, 21 * 60 + 40);
    });

    test('with snoozes the message leads with them', () {
      final snoozes = [for (var d = 1; d <= 6; d++) if (d != 2 && d != 5) day(d, 20, 10)];
      final t = ReminderTuneUp.suggest(
          reminder: rem(), occurrences: doneLate(), snoozes: snoozes)!;
      expect(t.message,
          'Snoozed 4 of last 6 · usually done around 9:40 PM');
    });

    test('a single snooze is not worth mentioning', () {
      final t = ReminderTuneUp.suggest(
          reminder: rem(), occurrences: doneLate(), snoozes: [day(3, 20, 10)])!;
      expect(t.message, 'Usually done around 9:40 PM');
    });

    test('applying it changes only the time of day', () {
      final r = rem();
      final t = ReminderTuneUp.suggest(reminder: r, occurrences: doneLate())!;
      final moved = ReminderTuneUp.apply(r, t);
      expect(moved.scheduledTime, DateTime(2026, 3, 1, 21, 40));
      expect(moved.repeatType, r.repeatType);
      expect(moved.escalation, r.escalation);
    });
  });

  group('make it louder', () {
    test('a reminder that is mostly missed is offered the next tier', () {
      final t = ReminderTuneUp.suggest(reminder: rem(), occurrences: missed(5))!;
      expect(t.kind, TuneUpKind.louder);
      expect(t.escalation, ReminderEscalation.insistent);
      expect(t.actionLabel, 'Make it louder');
      expect(t.message, 'Missed 5 of your last 6');
    });

    test('never proposes critical, and never past what it already is', () {
      final t = ReminderTuneUp.suggest(
          reminder: rem(e: ReminderEscalation.insistent), occurrences: missed(5));
      expect(t?.kind, isNot(TuneUpKind.louder));
      expect(t?.escalation, isNot(ReminderEscalation.critical));
    });

    test('applying it changes only the tier', () {
      final r = rem();
      final t = ReminderTuneUp.suggest(reminder: r, occurrences: missed(5))!;
      final loud = ReminderTuneUp.apply(r, t);
      expect(loud.escalation, ReminderEscalation.insistent);
      expect(loud.scheduledTime, r.scheduledTime);
    });
  });

  group('pause it', () {
    test('ignored almost every time lately, at the loudest it will go', () {
      final t = ReminderTuneUp.suggest(
          reminder: rem(e: ReminderEscalation.insistent), occurrences: missed(6))!;
      expect(t.kind, TuneUpKind.pause);
      expect(t.message, 'Not done in 6 of your last 6');
      expect(ReminderTuneUp.apply(rem(), t).isPaused, isTrue);
    });
  });

  group('one at a time, in order', () {
    test('move beats louder: a consistent late time is the cheaper fix', () {
      // Done at 21:40 four times, missed twice: both signals present.
      final rows = [
        for (var d = 1; d <= 6; d++)
          d <= 2
              ? occ(d, ReminderOutcome.missed)
              : occ(d, ReminderOutcome.done, actedAt: day(d, 21, 40)),
      ];
      final t = ReminderTuneUp.suggest(reminder: rem(), occurrences: rows)!;
      expect(t.kind, TuneUpKind.move);
    });
  });

  group('snoozedCount', () {
    final occs = [occ(1, ReminderOutcome.done), occ(2, ReminderOutcome.done)];

    test('a snooze belongs to the occurrence it followed', () {
      expect(ReminderTuneUp.snoozedCount(occs, [day(1, 20, 10)]), 1);
    });

    test('two snoozes of the same occurrence count it once', () {
      expect(
          ReminderTuneUp.snoozedCount(occs, [day(1, 20, 10), day(1, 20, 40)]), 1);
    });

    test('a snooze more than six hours later belongs to nothing', () {
      expect(ReminderTuneUp.snoozedCount(occs, [day(2, 3, 30)]), 0,
          reason: '7.5 hours after the 20:00 occurrence');
    });

    test('a snooze before the occurrence was due does not count', () {
      expect(ReminderTuneUp.snoozedCount(occs, [day(1, 19, 30)]), 0);
    });
  });
}
