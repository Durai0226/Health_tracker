import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart'
    show ReminderKind;
import 'package:tablet_remainder/features/reminders/models/reminder_escalation.dart';

/// The single biggest adherence lever in the research, and the failure every
/// review of this category converges on: *most apps send one normal
/// notification; you swipe it away and the app assumes you took the dose.*
///
/// Before this, escalation was all-or-nothing — a reminder either rang as a
/// full-screen alarm or it did not, and which one you got was decided by the
/// code path that happened to schedule it, not by how much the reminder
/// mattered.
void main() {
  group('escalation is graded, not global', () {
    test('only critical earns exact alarms and a full-screen takeover', () {
      // Play can revoke USE_FULL_SCREEN_INTENT for over-reach, and
      // USE_EXACT_ALARM is deliberately absent from the manifest — so widening
      // this is a policy decision, not a product one.
      for (final e in ReminderEscalation.values) {
        final expected = e == ReminderEscalation.critical;
        expect(e.wantsExactAlarm, expected, reason: e.name);
        expect(e.wantsFullScreen, expected, reason: e.name);
      }
    });

    test('quiet and normal stay off the alarm channel entirely', () {
      expect(ReminderEscalation.gentle.kind, ReminderKind.quiet);
      expect(ReminderEscalation.standard.kind, ReminderKind.gentle);
      expect(ReminderEscalation.gentle.kind.isAlarmGrade, isFalse);
      expect(ReminderEscalation.standard.kind.isAlarmGrade, isFalse);
      // Neither follows up: Quiet differs from Normal in loudness, which is what
      // its label says.
      expect(ReminderEscalation.gentle.hasFollowUp, isFalse);
      expect(ReminderEscalation.standard.hasFollowUp, isFalse);
    });

    test('insistent and critical are alarm-grade', () {
      expect(ReminderEscalation.insistent.kind, ReminderKind.alarm);
      expect(ReminderEscalation.critical.kind, ReminderKind.alarm);
    });

    test('an unknown stored name degrades to standard, not to silence', () {
      // A tier written by a newer build must not make a reminder stop firing.
      expect(ReminderEscalation.fromName('nuclear'), ReminderEscalation.standard);
      expect(ReminderEscalation.fromName(null), ReminderEscalation.standard);
      for (final e in ReminderEscalation.values) {
        expect(ReminderEscalation.fromName(e.name), e);
      }
    });
  });

  group('what happens when an occurrence goes unanswered', () {
    EscalationStep step(
      ReminderEscalation e, {
      Duration since = const Duration(hours: 1),
      int snoozes = 0,
      int max = 3,
      bool resolved = false,
    }) =>
        nextEscalationStep(
          escalation: e,
          sinceFired: since,
          snoozeCount: snoozes,
          maxSnoozes: max,
          resolved: resolved,
        );

    test('a resolved occurrence is never escalated', () {
      for (final e in ReminderEscalation.values) {
        expect(step(e, resolved: true), EscalationStep.none, reason: e.name);
      }
    });

    test('quiet and normal never follow up at all', () {
      expect(step(ReminderEscalation.gentle), EscalationStep.none);
      expect(step(ReminderEscalation.standard), EscalationStep.none);
    });

    test('nothing happens before the follow-up window elapses', () {
      // The Apple Health pattern is a second notification at 30 minutes, not an
      // immediate second buzz.
      expect(
        step(ReminderEscalation.critical, since: const Duration(minutes: 29)),
        EscalationStep.none,
      );
      expect(
        step(ReminderEscalation.critical, since: const Duration(minutes: 30)),
        EscalationStep.followUp,
      );
    });

    test('the first escalation is one polite follow-up', () {
      expect(step(ReminderEscalation.insistent), EscalationStep.followUp);
      expect(step(ReminderEscalation.critical), EscalationStep.followUp);
    });

    test('insistent stops after the follow-up; critical keeps going', () {
      // Insistent nudges once and lets it go. Critical is the Due pattern —
      // keep asking until the user completes or reschedules.
      expect(step(ReminderEscalation.insistent, snoozes: 1), EscalationStep.none);
      expect(
          step(ReminderEscalation.critical, snoozes: 1), EscalationStep.autoSnooze);
    });

    test('"until acted on" is still capped', () {
      // Otherwise it is not persistence, it is harassment — and the reminder
      // would nag forever with no way out but deleting it.
      expect(step(ReminderEscalation.critical, snoozes: 3, max: 3),
          EscalationStep.finalNotice);
      expect(step(ReminderEscalation.critical, snoozes: 9, max: 3),
          EscalationStep.finalNotice);
    });

    test('at the cap it shows a final notice rather than vanishing', () {
      // Android's ActionBroadcastReceiver has already removed the tapped
      // notification by the time the handler runs, so "stop escalating" must
      // not mean "the reminder silently disappears".
      expect(step(ReminderEscalation.critical, snoozes: 3, max: 3),
          isNot(EscalationStep.none));
    });

    test('the cap honours the user setting, not a constant', () {
      expect(step(ReminderEscalation.critical, snoozes: 1, max: 1),
          EscalationStep.finalNotice);
      expect(step(ReminderEscalation.critical, snoozes: 1, max: 5),
          EscalationStep.autoSnooze);
    });
  });

  group('every tier is presentable in a picker', () {
    test('labels and descriptions exist and are distinct', () {
      final labels = ReminderEscalation.values.map((e) => e.label).toList();
      expect(labels.toSet().length, labels.length);
      for (final e in ReminderEscalation.values) {
        expect(e.label, isNotEmpty);
        expect(e.description, isNotEmpty);
      }
    });
  });
}
