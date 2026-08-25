import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';

/// `alarmCallback` used to build ONE hardcoded notification shape for everything
/// it fired: `alarm_channel`, `fullScreenIntent: true`, `ongoing: true`, and the
/// `✓ Take` / `⏰ Snooze` / `✕ Dismiss` action set — discarding the `channelId`
/// its caller had passed.
///
/// The consequence shipped: the four vitals reminders ("time to check your blood
/// pressure") and the onboarding daily check-in arrived as full-screen ringing
/// medicine alarms, offering to log a dose that does not exist. Focus and water
/// each escaped it by bypassing the service; nothing generalised the fix.
///
/// The decision is now pure and public, so it can be asserted here rather than
/// only observed on a device.
void main() {
  group('a gentle nudge is not an alarm', () {
    final look = alarmPresentationFor(ReminderKind.gentle, snoozeMinutes: 10);

    test('never offers to log a dose', () {
      expect(look.offersDoseLogging, isFalse);
      expect(look.actions, isEmpty,
          reason: 'a nudge that offers Snooze trains the user to dismiss it');
    });

    test('never takes over the screen', () {
      expect(look.fullScreenIntent, isFalse,
          reason: 'Play can revoke USE_FULL_SCREEN_INTENT for this over-reach');
      expect(look.ongoing, isFalse);
      expect(look.autoCancel, isTrue, reason: 'swipe must dismiss a nudge');
      expect(look.timeoutAfterMs, isNull);
    });

    test('uses the notification audio stream, not the alarm stream', () {
      expect(look.audioUsage, AudioAttributesUsage.notification,
          reason: 'the alarm stream ignores notification volume and DND');
      expect(look.category, AndroidNotificationCategory.reminder);
      expect(look.importance, Importance.high);
    });

    test('cannot be pushed onto an alarm-configured channel', () {
      // Channel audio attributes are immutable once created, and both of these
      // are created with `audioAttributesUsage: alarm`. Honouring the request
      // would ring a nudge at alarm volume whatever this notification asks for.
      for (final requested in ['reminders_channel', 'medicine_channel', 'alarm_channel']) {
        final forced = alarmPresentationFor(ReminderKind.gentle,
            snoozeMinutes: 10, requestedChannelId: requested);
        expect(forced.channelId, 'checkin_channel', reason: 'requested $requested');
      }
    });
  });

  group('a user-set alarm rings but has nothing to take', () {
    final look = alarmPresentationFor(ReminderKind.alarm, snoozeMinutes: 15);

    test('is alarm-grade', () {
      expect(look.fullScreenIntent, isTrue);
      expect(look.ongoing, isTrue);
      expect(look.audioUsage, AudioAttributesUsage.alarm);
      expect(look.timeoutAfterMs, 300000);
    });

    test('offers Snooze and Dismiss but never Take', () {
      expect(look.offersDoseLogging, isFalse,
          reason: 'the wake alarm and generic reminders have no dose to log; '
              'this button was on them for years');
      expect(look.actions.map((a) => a.id), ['snooze', 'dismiss']);
      expect(look.actions.first.title, contains('15'),
          reason: 'the snooze label must reflect the interval actually used');
    });

    test('honours the channel its caller asked for', () {
      expect(
        alarmPresentationFor(ReminderKind.alarm,
                snoozeMinutes: 5,
                requestedChannelId: 'alarm_channel',
                requestedChannelName: 'Alarm Reminders')
            .channelId,
        'alarm_channel',
      );
    });
  });

  group('a dose keeps every bit of its alarm behaviour', () {
    test('solo: Take / Snooze / Dismiss, in that order', () {
      final look = alarmPresentationFor(ReminderKind.dose, snoozeMinutes: 5);
      expect(look.actions.map((a) => a.id), ['take', 'snooze', 'dismiss']);
      expect(look.offersDoseLogging, isTrue);
      expect(look.channelId, 'alarm_channel',
          reason: 'default when the blob carries no channelId');
    });

    test('grouped: trades Dismiss for "Take all" — never a 4th button', () {
      final look =
          alarmPresentationFor(ReminderKind.dose, isGroup: true, snoozeMinutes: 5);
      expect(look.actions.map((a) => a.id), ['take', 'snooze']);
      expect(look.actions.first.title, contains('Take all'));
    });

    test('no kind ever exceeds Android\'s 3-action cap', () {
      // A 4th action makes the last one silently disappear, which is how
      // "Dismiss" would vanish without any error.
      for (final kind in ReminderKind.values) {
        for (final grouped in [false, true]) {
          expect(
            alarmPresentationFor(kind, isGroup: grouped, snoozeMinutes: 5)
                .actions
                .length,
            lessThanOrEqualTo(3),
            reason: '$kind (grouped: $grouped)',
          );
        }
      }
    });
  });

  group('legacy alarm blobs written before `kind` existed', () {
    test('an explicit kind wins, and is matched by name not index', () {
      for (final kind in ReminderKind.values) {
        expect(ReminderKind.fromBlob({'kind': kind.name}), kind);
      }
    });

    test('an unknown kind string falls through to inference, not a crash', () {
      expect(ReminderKind.fromBlob({'kind': 'telepathy'}), ReminderKind.alarm);
    });

    test('a medicine slot blob is still a dose', () {
      expect(
        ReminderKind.fromBlob({
          'channelId': 'medicine_channel',
          'medicines': [
            {'id': 'm1'}
          ],
        }),
        ReminderKind.dose,
      );
      // Single-medicine legacy blobs carried no `medicines` list.
      expect(ReminderKind.fromBlob({'channelId': 'medicine_channel'}),
          ReminderKind.dose);
    });

    test('an empty medicines list does not masquerade as a dose', () {
      expect(
        ReminderKind.fromBlob({'channelId': 'reminders_channel', 'medicines': []}),
        ReminderKind.alarm,
      );
    });

    test('anything else is inferred alarm-grade — but never dose-loggable', () {
      // Biased toward over-alerting: a user-set reminder that goes quiet is a
      // worse failure than a nudge louder than it needs to be for one cycle.
      // The `✓ Take` button — the actually-wrong part — is withheld either way.
      final inferred = ReminderKind.fromBlob({'channelId': 'reminders_channel'});
      expect(inferred, ReminderKind.alarm);
      expect(
        alarmPresentationFor(inferred, snoozeMinutes: 5).offersDoseLogging,
        isFalse,
      );
    });

    test('an empty blob does not throw', () {
      expect(ReminderKind.fromBlob(const {}), ReminderKind.alarm);
    });
  });
}
