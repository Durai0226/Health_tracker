import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';

/// `ReminderRescheduleService.rescheduleAllReminders()` is the app's only
/// "rebuild everything" pass, and it covered **three** of the roughly twelve
/// reminder families: medicines, water, appointments.
///
/// What that left broken is not a reboot — flutter_local_notifications'
/// `ScheduledNotificationBootReceiver` and AlarmManager's `rescheduleOnReboot`
/// handle that. It is everything else that invalidates an armed registration and
/// has no boot broadcast behind it:
///
/// * a notification-id scheme change (exactly what schema v16 is),
/// * a Drift restore from backup,
/// * an exact-alarm grant arriving after the reminders were armed inexactly.
///
/// In all three the reminder is simply gone, while the toggle that switched it
/// on still reads "On". Generic user reminders were the largest gap: nothing
/// re-armed them at all.
String _codeOnly(String source) => source
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

void main() {
  late String reschedule;
  late String shell;

  setUpAll(() {
    reschedule = _codeOnly(
        File('lib/core/services/reminder_reschedule_service.dart')
            .readAsStringSync());
    shell = _codeOnly(
        File('lib/features/home/screens/app_shell.dart').readAsStringSync());
  });

  group('the reschedule pass covers every family that needs it', () {
    test('all five families are registered', () {
      // These used to be five near-identical inline try/catch blocks, which is
      // how two families ended up missing entirely: adding one meant editing
      // the method, and nothing made an omission visible.
      expect(
        ReminderRescheduleService.familyNames,
        containsAll(<String>[
          'medicines',
          'appointments',
          'generic reminders',
          'vitals',
          'water',
        ]),
      );
    });

    test('doses are armed before nudges', () {
      // If the OS pending-notification ceiling is hit, the thing that does not
      // fit must be a hydration nudge, not a dose.
      final names = ReminderRescheduleService.familyNames;
      expect(names.indexOf('medicines'), lessThan(names.indexOf('water')));
    });

    test('registering the same family twice is a no-op', () {
      final before = ReminderRescheduleService.familyNames.length;
      ReminderRescheduleService.register(
          ReminderFamily('water', () async => 0));
      expect(ReminderRescheduleService.familyNames.length, before,
          reason: 'a duplicate would double-arm and double-count');
    });

    test('one family throwing does not stop the others', () {
      // The difference between losing one family's reminders and losing all of
      // them. Asserted against the loop rather than by running it, because
      // every rearm here reaches a platform channel.
      final loop = reschedule.substring(
        reschedule.indexOf('for (final family in _families)'),
        reschedule.indexOf('debugPrint(\'✓ Rescheduled'),
      );
      expect(loop, contains('try {'));
      expect(loop, contains('catch (e)'));
      expect(loop, contains('failed++'));
    });

    test('vitals — four daily nudges nothing used to re-arm', () {
      expect(reschedule, contains('VitalsReminderService.rescheduleAll'));
    });

    test('generic user reminders — the largest gap', () {
      expect(reschedule, contains('rescheduleGenericReminders'));
      final fn = reschedule.substring(
          reschedule.indexOf('static Future<int> rescheduleGenericReminders'));
      expect(fn, contains('scheduleGenericReminder'));
    });

    // The cancel-before-allocate ordering used to be grepped for here. It now
    // has real behavioural coverage in
    // `test/reminders/reschedule_generic_test.dart` ("disarm precedes arm",
    // "a pre-v16 reminder is disarmed under its LEGACY id"), which asserts the
    // actual call sequence through the injected ReminderAlarm rather than the
    // order two identifiers happen to appear in the source. Keeping the weaker
    // grep beside the stronger test would only be one more thing to update when
    // a symbol is renamed — which is exactly how it went stale.

    test('a completed one-off is not re-armed', () {
      final fn = reschedule.substring(
          reschedule.indexOf('static Future<int> rescheduleGenericReminders'));
      expect(fn, contains('isCompleted'),
          reason: 're-arming a ticked-off reminder rings for nothing');
      expect(fn, contains('isBefore(now)'),
          reason: 'a one-off whose time has passed has nothing left to fire');
    });
  });

  group('an exact-alarm grant re-arms what was armed inexactly', () {
    test('resume checks for the grant', () {
      // Android 14+ denies SCHEDULE_EXACT_ALARM by default. The grant does not
      // retroactively upgrade already-armed alarms — they must be rescheduled,
      // exactly as after a reboot.
      expect(shell, contains('_rearmIfExactAlarmsWereGranted'));
      final fn = shell
          .substring(shell.indexOf('Future<void> _rearmIfExactAlarmsWereGranted'));
      expect(fn, contains('remindersDowngradedToInexact'));
      expect(fn, contains('canScheduleExactAlarms'));
      expect(fn, contains('rescheduleAllReminders'));
    });

    test('it fires only when the flag and the permission disagree', () {
      final fn = shell
          .substring(shell.indexOf('Future<void> _rearmIfExactAlarmsWereGranted'));
      // Rebuilding everything on every resume would be a real cost; the whole
      // point is that this is the narrow "was downgraded, now permitted" case.
      expect(fn, contains('if (!downgraded) return;'));
      expect(fn, contains('canScheduleExactAlarms()) return;'));
    });

    test('it is wired to resume, not only to cold start', () {
      // End anchor must be code, not a doc comment — _codeOnly strips those.
      final onResume = shell.substring(
        shell.indexOf('void didChangeAppLifecycleState'),
        shell.indexOf('Future<void> _rearmIfExactAlarmsWereGranted'),
      );
      expect(onResume, contains('_rearmIfExactAlarmsWereGranted()'),
          reason: 'the grant happens while the user is away in system '
              'settings, so resume is the moment that matters');
    });
  });
}
