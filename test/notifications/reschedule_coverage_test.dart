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

    // Family isolation — one family throwing must not stop the rest — used to be
    // asserted here by slicing this file's own source for the substrings
    // `try {`, `catch (e)` and `failed++`. That passes on a `try` whose `catch`
    // rethrows and fails on a rename that changed nothing. It is now driven, in
    // the 'each family is isolated from the others' group below, against
    // `rearmFamilies` — which takes its families as an argument precisely so a
    // test can supply ones that do not reach a platform channel.

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

  group('each family is isolated from the others', () {
    /// A family that records that it ran and re-arms [armed] reminders.
    ReminderFamily ok(String name, List<String> log, {int armed = 1}) =>
        ReminderFamily(name, () async {
          log.add(name);
          return armed;
        });

    /// A family that throws, as a real one does when its platform channel is
    /// unavailable or its table is mid-restore.
    ReminderFamily boom(String name, List<String> log) =>
        ReminderFamily(name, () async {
          log.add(name);
          throw StateError('$name is broken');
        });

    test('a family that throws does not stop the ones after it', () async {
      // The whole point: losing one family's reminders instead of every
      // reminder in the app. Without the per-family catch, 'water' never runs.
      final ran = <String>[];
      final outcome = await ReminderRescheduleService.rearmFamilies([
        ok('medicines', ran),
        boom('appointments', ran),
        ok('water', ran),
      ]);

      expect(ran, ['medicines', 'appointments', 'water']);
      expect(outcome.attempted, 3);
      expect(outcome.failed, 1);
      expect(outcome.succeeded, 2);
    });

    test('the failure is counted, not swallowed', () async {
      // A pass that silently reported success for a family it never armed is
      // the shape this whole audit is about.
      final ran = <String>[];
      final outcome = await ReminderRescheduleService.rearmFamilies([
        boom('medicines', ran),
        boom('water', ran),
      ]);

      expect(outcome.failed, 2);
      expect(outcome.succeeded, 0);
    });

    test('a thrown family contributes no armed count', () async {
      final ran = <String>[];
      final outcome = await ReminderRescheduleService.rearmFamilies([
        ok('medicines', ran, armed: 4),
        boom('appointments', ran),
        ok('water', ran, armed: 3),
      ]);

      expect(outcome.armed, 7,
          reason: 'only the families that completed may count toward armed');
    });

    test('every family succeeding reports no failures', () async {
      final ran = <String>[];
      final outcome = await ReminderRescheduleService.rearmFamilies([
        ok('medicines', ran, armed: 2),
        ok('water', ran, armed: 5),
      ]);

      expect(outcome.failed, 0);
      expect(outcome.armed, 7);
      expect(outcome.succeeded, 2);
    });

    test('families run in the order given', () async {
      // Order is the budget guarantee: doses are armed before nudges, so if the
      // OS ceiling is reached it is a hydration nudge that does not fit.
      final ran = <String>[];
      await ReminderRescheduleService.rearmFamilies([
        ok('medicines', ran),
        ok('appointments', ran),
        ok('water', ran),
      ]);

      expect(ran, ['medicines', 'appointments', 'water']);
    });

    test('no families is a clean no-op', () async {
      final outcome = await ReminderRescheduleService.rearmFamilies([]);

      expect(outcome.armed, 0);
      expect(outcome.failed, 0);
      expect(outcome.attempted, 0);
    });
  });

}
