import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The three "silent no-op" schedulers.
///
/// `scheduleBedtimeReminder`, `scheduleWakeAlarm` and `scheduleStepReminder`
/// all returned `void` and bailed on a permission refusal with nothing but a
/// `debugPrint`. The Sleep and Steps settings screens therefore persisted the
/// toggle, left the switch ON and rendered "Rings at 7:00 AM" while NOTHING was
/// scheduled — someone who declined notifications at onboarding, or revoked
/// them later, slept through their alarm with the app insisting it was set.
/// The medicine flows in this app already surface permission problems; these
/// three did not, and `scheduleHealthCheckReminder` already returned a bool.
///
/// A source guard rather than a widget test: the defect is a RETURN TYPE and
/// the callers' handling of it, and the real behaviour needs a platform channel
/// (the notification plugin) that a headless test cannot exercise. This pins
/// the contract so it cannot silently revert; the device pass covers the rest.
void main() {
  final notif =
      File('lib/core/services/notification_service.dart').readAsStringSync();
  final sleepSettings = File(
          'lib/features/sleep/screens/sleep_schedule_settings_screen.dart')
      .readAsStringSync();
  final stepsSettings =
      File('lib/features/steps/screens/steps_goal_settings_screen.dart')
          .readAsStringSync();

  group('the schedulers report whether they armed', () {
    for (final name in const [
      'scheduleBedtimeReminder',
      'scheduleWakeAlarm',
      'scheduleStepReminder',
    ]) {
      test('$name returns Future<bool>', () {
        expect(notif, contains('Future<bool> $name('),
            reason: 'a void scheduler cannot tell its caller it did nothing');
        expect(notif, isNot(contains('Future<void> $name(')));
      });
    }

    test('the permission refusal returns false rather than falling through',
        () {
      for (final msg in const [
        '❌ Bedtime reminder: notifications not permitted',
        '❌ Wake alarm: notifications not permitted',
        '❌ Step reminder: notifications not permitted',
      ]) {
        final at = notif.indexOf(msg);
        expect(at, greaterThan(-1), reason: 'the guard should still exist');
        final after = notif.substring(at, at + 120);
        expect(after, contains('return false'),
            reason: 'a bare `return` here is what made the failure invisible');
      }
    });

    test('the Android wake alarm reports the OS result, not the request', () {
      // This is the path where SCHEDULE_EXACT_ALARM can be refused.
      expect(notif, contains('await BackgroundAlarmService().scheduleDailyAlarm('),
          reason: 'sanity: the call should still be here');
      expect(notif, contains('return armed;'),
          reason: 'returning true unconditionally would re-hide an OS refusal');
    });
  });

  group('the settings screens act on the result', () {
    test('sleep reverts the toggle and says why', () {
      expect(sleepSettings, contains('await NotificationService().scheduleBedtimeReminder('));
      expect(sleepSettings, contains('await NotificationService().scheduleWakeAlarm('));
      expect(sleepSettings, contains('toastWarning'),
          reason: 'the user has to learn the alarm is not set');
      expect(sleepSettings, contains('Open settings'),
          reason: 'a warning with no way to fix it is a dead end');
      expect(sleepSettings, contains('SleepService.saveSchedule(reverted)'),
          reason: 'the reverted switch must persist, or a relaunch shows it on '
              'again with still nothing scheduled');
    });

    test('steps reverts the toggle and says why', () {
      expect(stepsSettings,
          contains('await NotificationService().scheduleStepReminder('));
      expect(stepsSettings, contains('StepService.setReminder(false, minute)'),
          reason: 'the reverted switch must persist');
      expect(stepsSettings, contains('toastWarning'));
      expect(stepsSettings, contains('Open settings'));
    });

    test('negative: turning a reminder OFF is not reported as a failure', () {
      // `false` for `enabled: false` is the expected answer, and warning there
      // would fire a scary toast every time someone switched a reminder off.
      expect(sleepSettings, contains('next.reminderEnabled && !bedtimeOk'));
      expect(sleepSettings, contains('next.alarmEnabled && !wakeOk'));
      expect(stepsSettings, contains('if (!enabled || armed) return;'));
    });
  });
}
