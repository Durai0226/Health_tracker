import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_digest.dart';

/// The notification-fatigue guidance is consistent: keep high-urgency real-time,
/// move high-volume and low-urgency into a digest. `NudgeScheduler`'s own
/// docstring names the number — *2-5 notifications/week is the opt-out cliff*.
/// Past it people do not tune settings, they disable notifications wholesale,
/// and the dose reminders go with them.
void main() {
  Reminder r(
    String id, {
    ReminderEscalation escalation = ReminderEscalation.standard,
    bool paused = false,
    bool completed = false,
    String title = 'Stretch',
  }) =>
      Reminder(
        id: id,
        title: title,
        body: '',
        scheduledTime: DateTime(2026, 6, 10, 9),
        escalation: escalation,
        isPaused: paused,
        isCompleted: completed,
      );

  final noon = DateTime(2026, 6, 10, 12, 0);

  group('only the quiet tiers get batched', () {
    test('insistent and critical are never folded into a summary', () {
      // The user explicitly chose "interrupt me". Batching that would silently
      // undo the choice they made on the form.
      expect(ReminderDigest.isDigestible(ReminderEscalation.insistent), isFalse);
      expect(ReminderDigest.isDigestible(ReminderEscalation.critical), isFalse);
      expect(ReminderDigest.isDigestible(ReminderEscalation.gentle), isTrue);
      expect(ReminderDigest.isDigestible(ReminderEscalation.standard), isTrue);
    });

    test('digestible filters out paused, completed and loud reminders', () {
      final items = ReminderDigest.digestible([
        r('a'),
        r('b', escalation: ReminderEscalation.critical),
        r('c', paused: true),
        r('d', completed: true),
        r('e', escalation: ReminderEscalation.gentle),
      ]);
      expect(items.map((x) => x.id), ['a', 'e']);
    });
  });

  group('when a digest is worth sending', () {
    test('two or more outstanding reminders', () {
      expect(
        ReminderDigest.shouldSend(
            pending: [r('a'), r('b')], now: noon, recentDigests: const []),
        isTrue,
      );
    });

    test('one is not a summary, it is a notification', () {
      // And that reminder already fired on its own.
      expect(
        ReminderDigest.shouldSend(
            pending: [r('a')], now: noon, recentDigests: const []),
        isFalse,
      );
    });

    test('the frequency cap applies to the digest itself', () {
      // A digest that becomes daily noise has solved nothing.
      final recent = [
        noon.subtract(const Duration(hours: 2)),
      ];
      expect(
        ReminderDigest.shouldSend(
            pending: [r('a'), r('b')], now: noon, recentDigests: recent),
        isFalse,
        reason: "inside NudgeScheduler's 20-hour minimum gap",
      );
    });

    test('four in a week is the ceiling', () {
      final recent = [
        for (var i = 1; i <= 4; i++) noon.subtract(Duration(days: i)),
      ];
      expect(
        ReminderDigest.shouldSend(
            pending: [r('a'), r('b')], now: noon, recentDigests: recent),
        isFalse,
      );
    });
  });

  group('quiet hours DO apply here', () {
    test('nothing is sent at 3am', () {
      // The distinction written into core/utils/quiet_hours.dart: a digest hour
      // is app-generated, so suppressing it respects the user. A dose time is
      // user-picked, and overriding that could suppress a clinically-timed
      // reminder — which is why quiet hours must NOT be applied there.
      expect(
        ReminderDigest.shouldSend(
          pending: [r('a'), r('b')],
          now: DateTime(2026, 6, 10, 3, 0),
          recentDigests: const [],
        ),
        isFalse,
      );
    });

    test('a night-shift window that wraps past midnight is respected', () {
      // Wake 22:00, bed 06:00. 3am is inside their day.
      expect(
        ReminderDigest.shouldSend(
          pending: [r('a'), r('b')],
          now: DateTime(2026, 6, 10, 3, 0),
          recentDigests: const [],
          wakeHour: 22,
          bedHour: 6,
        ),
        isTrue,
      );
    });
  });

  group('the body stays readable', () {
    test('names a few and counts the rest', () {
      final many = [
        r('a', title: 'Stretch'),
        r('b', title: 'Water plants'),
        r('c', title: 'Call mum'),
        r('d', title: 'Read'),
        r('e', title: 'Journal'),
      ];
      expect(ReminderDigest.body(many), 'Stretch · Water plants · Call mum and 2 more');
      expect(ReminderDigest.title(many), '5 reminders still waiting');
    });

    test('no "and 0 more" when everything fits', () {
      expect(ReminderDigest.body([r('a', title: 'Stretch')]), 'Stretch');
    });

    test('an empty set produces an empty body, not a crash', () {
      expect(ReminderDigest.body(const []), '');
      expect(ReminderDigest.title(const []), '0 reminders still waiting');
    });
  });
}
