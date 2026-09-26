import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_escalation.dart';

/// Escalation tiers existed but never reached the OS.
///
/// The Add Reminder picker promises "Quiet — a silent notification" and
/// "Normal — a notification with sound", and `ReminderEscalation.kind` maps both
/// to `ReminderKind.gentle`. But `scheduleGenericReminder` hardcoded
/// `ReminderKind.alarm` on the Android branch and a literal
/// `alarm_channel` / `Importance.max` / `fullScreenIntent: true` /
/// `AudioAttributesUsage.alarm` block on the cross-platform one — and
/// `kind`, `wantsFullScreen` and `wantsExactAlarm` had no callers outside their
/// own file.
///
/// So a Quiet "water the plants" at 22:30 rang at ALARM volume (a stream that
/// deliberately ignores Do Not Disturb), lit the screen and took it over with
/// the full-screen AlarmScreen.
///
/// Separately, lock-screen visibility was pinned `public` on that same path, so
/// the 'Show on lock screen' toggle — honoured by `alarmCallback` — was a no-op
/// here: a weekdays reminder titled "Take sertraline" was readable by anyone
/// walking past a locked phone.
void main() {
  group('the presentation helper separates the tiers', () {
    test('positive: quiet and normal are not alarm-grade', () {
      for (final e in const [
        ReminderEscalation.gentle,
        ReminderEscalation.standard,
      ]) {
        final look = alarmPresentationFor(e.kind, snoozeMinutes: 5);
        expect(look.fullScreenIntent, isFalse,
            reason: '${e.name} must never take over the screen');
        expect(look.audioUsage.toString(), isNot(contains('alarm')),
            reason: '${e.name} must not use the alarm stream, which ignores '
                'Do Not Disturb');
        expect(look.channelId, 'checkin_channel');
      }
    });

    test('negative: critical still gets the alarm treatment', () {
      final look =
          alarmPresentationFor(ReminderEscalation.critical.kind, snoozeMinutes: 5);
      expect(look.fullScreenIntent, isTrue);
      expect(look.channelId, 'alarm_channel');
      expect(look.audioUsage.toString(), contains('alarm'));
    });

    test('insistent is alarm-grade too, and gentle/standard share a tier', () {
      expect(ReminderEscalation.insistent.kind,
          ReminderEscalation.critical.kind);
      expect(ReminderEscalation.gentle.kind, ReminderEscalation.standard.kind);
    });
  });

  group('the scheduler actually uses it', () {
    final notif =
        File('lib/core/services/notification_service.dart').readAsStringSync();
    final alarm =
        File('lib/features/reminders/services/reminder_alarm.dart')
            .readAsStringSync();

    test('scheduleGenericReminder takes an escalation', () {
      expect(notif, contains('ReminderEscalation escalation = ReminderEscalation.standard'),
          reason: 'an un-migrated caller should get the gentler default, not '
              'the loudest one');
    });

    /// The body of `scheduleGenericReminder`, bounded by the next declaration
    /// — a fixed character window silently stops covering the method as soon as
    /// anything is added to it, which makes the guard pass for the wrong reason.
    String genericBody() {
      final start = notif.indexOf('Future<bool> scheduleGenericReminder(');
      expect(start, greaterThan(-1));
      final end = notif.indexOf('\n  Future<', start + 10);
      return notif.substring(start, end > start ? end : notif.length);
    }

    test('the Android branch derives the kind instead of hardcoding alarm', () {
      final body = genericBody();
      expect(body, contains('kind: escalation.kind'));
      expect(body, isNot(contains('kind: ReminderKind.alarm')),
          reason: 'hardcoding alarm-grade is the whole defect');
    });

    test('the cross-platform branch builds from alarmPresentationFor', () {
      final body = genericBody();
      expect(body, contains('alarmPresentationFor('));
      expect(body, isNot(contains("'alarm_channel', // Use dedicated alarm channel")),
          reason: 'the hardcoded alarm-grade block must be gone');
    });

    test('lock-screen visibility follows the user setting, not a literal', () {
      final body = genericBody();
      expect(body, contains('kShowOnLockScreenPref'),
          reason: 'the toggle was already mirrored for the alarm isolate; this '
              'path simply never read it');
      expect(body, isNot(contains('visibility: NotificationVisibility.public')),
          reason: 'a health app must not pin drug names to a locked screen');
    });

    test('the snoozed-dose re-fire honours the lock-screen setting too', () {
      // R6's other half. This path re-fires a SNOOZED DOSE, so its title is a
      // medicine name — and it pinned `visibility: public` regardless of the
      // toggle that `alarmCallback` a few hundred lines up already honoured.
      final bg = File('lib/core/services/background_alarm_service.dart')
          .readAsStringSync();
      // Every `public` must be the true-branch of a ternary on the pref, so
      // none of them may appear as a bare `visibility:` assignment.
      expect(bg, isNot(contains('visibility: NotificationVisibility.public')),
          reason: 'no unconditional public visibility on an alarm path');
      expect('? NotificationVisibility.public'.allMatches(bg).length, 2,
          reason: 'both alarmCallback and the snooze re-fire must be gated');
    });

    test('the OS refusal is propagated, not swallowed as success', () {
      final body = genericBody();
      expect(body, contains('return armed;'),
          reason: 'both AlarmManager branches discarded the bool and returned '
              'an unconditional true, so a SCHEDULE_EXACT_ALARM refusal read '
              'as a scheduled reminder');
      expect(body, isNot(contains('            );\n            return true;')),
          reason: 'the unconditional success returns must be gone');
    });

    test('ReminderAlarm forwards the tier it has always carried', () {
      expect(alarm, contains('escalation: r.escalation'),
          reason: 'the request carried the tier; arm() dropped it on the floor');
    });
  });

  group('the follow-up is anchored to the next occurrence', () {
    final alarm =
        File('lib/features/reminders/services/reminder_alarm.dart')
            .readAsStringSync();

    test('positive: a follow-up already in the past is not armed', () {
      // `scheduledTime` for a repeating reminder is the CREATION instant and is
      // never advanced when the alarm fires, so `scheduledTime + 30min` was in
      // the past on every launch — and oneShotAt with a past time fires at
      // once. An Insistent daily reminder popped "Still pending: …" seconds
      // after every cold start.
      expect(alarm, contains('if (fireAt.isAfter(clock.now()))'));
      expect(alarm, contains('ReminderHelper.nextOccurrenceFrom('),
          reason: 'the anchor must be the occurrence that is actually next, '
              'resolved through the one shared rule');
      expect(alarm, isNot(contains('fireAt: r.scheduledTime.add(')),
          reason: 'the stale anchor must be gone');
    });
  });

  group('the screens use the seam, so nothing is orphaned', () {
    final addScreen =
        File('lib/features/reminders/screens/add_reminder_screen.dart')
            .readAsStringSync();
    final listScreen =
        File('lib/features/reminders/screens/reminders_screen.dart')
            .readAsStringSync();

    test('save, roll-forward, complete and delete all go through ReminderAlarm',
        () {
      // arm()/disarm() are the ONLY place the +2000 follow-up is armed and
      // cancelled, and they used to be called solely from the app-start re-arm
      // pass. cancelGenericReminder clears the base id and the weekday sub-ids
      // but NOT the follow-up — so a deleted Insistent reminder still popped
      // "Still pending: Call Dr Rao" half an hour later, for a reminder that no
      // longer existed.
      for (final src in [addScreen, listScreen]) {
        expect(src, isNot(contains('NotificationService().scheduleGenericReminder(')),
            reason: 'bypassing the seam skips the follow-up and the recurrence '
                'rule');
        // The CALL form, not the bare name — the comments beside the fix
        // mention it by name on purpose.
        expect(src, isNot(contains('NotificationService()\n            .cancelGenericReminder(')),
            reason: 'cancelGenericReminder leaves the follow-up armed');
        expect(src, isNot(contains('NotificationService().cancelGenericReminder(')),
            reason: 'cancelGenericReminder leaves the follow-up armed');
      }
      expect(addScreen, contains('NotificationReminderAlarm().arm('));
      expect(listScreen, contains('NotificationReminderAlarm().arm('));
      expect(listScreen, contains('NotificationReminderAlarm().disarm('));
    });

    test('a saved reminder that has nothing left to fire is disarmed', () {
      expect(addScreen, contains('ReminderArmRequest.forNextOccurrence(saved)'));
      expect(addScreen, contains('NotificationReminderAlarm().disarm('),
          reason: 'saving a paused or already-ended reminder must leave '
              'nothing armed');
    });
  });
}
