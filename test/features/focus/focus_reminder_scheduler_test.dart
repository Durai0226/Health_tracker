import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/features/focus/services/focus_reminder_scheduler.dart';

/// Cover for the Focus reminder scheduling contract.
///
/// What this CAN prove headlessly: the next-occurrence boundary, and that the
/// one-time migration off AlarmManager runs once and then stops. What it cannot
/// is that Android actually delivers — that needs the platform-channel seam
/// landing with the background-completion work, plus one manual device check
/// (see docs/release-checklist.md). Saying so here beats implying otherwise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nextOccurrence', () {
    test('a time later today is today', () {
      withClock(Clock.fixed(DateTime(2026, 8, 20, 8, 30)), () {
        expect(FocusReminderScheduler.nextOccurrence(9, 0),
            DateTime(2026, 8, 20, 9, 0));
      });
    });

    test('a time already past is tomorrow', () {
      withClock(Clock.fixed(DateTime(2026, 8, 20, 21, 15)), () {
        expect(FocusReminderScheduler.nextOccurrence(20, 0),
            DateTime(2026, 8, 21, 20, 0));
      });
    });

    test('the exact current minute is tomorrow, not now', () {
      // `isAfter`, not `isSameMomentAs`-or-after, and deliberately so: scheduling
      // for the instant that has just arrived is a notification that either fires
      // immediately or is dropped as being in the past, depending on how many
      // milliseconds the surrounding code took.
      withClock(Clock.fixed(DateTime(2026, 8, 20, 9, 0)), () {
        expect(FocusReminderScheduler.nextOccurrence(9, 0),
            DateTime(2026, 8, 21, 9, 0));
      });
    });

    test('crosses a month boundary', () {
      withClock(Clock.fixed(DateTime(2026, 8, 31, 23, 30)), () {
        expect(FocusReminderScheduler.nextOccurrence(9, 0),
            DateTime(2026, 9, 1, 9, 0));
      });
    });
  });

  group('the migration off AlarmManager', () {
    test('does NOT record success when the teardown could not run', () async {
      // The most important assertion in this file, and it only exists because
      // writing it exposed the opposite bug.
      //
      // The first version delegated the cancel to `scheduleFocusReminder`, which
      // swallows its own failures — so the migration could never fail, and the
      // flag was set even on a launch where no alarm was torn down. A migration
      // recorded as done is a migration nothing retries: the user keeps getting
      // a full-screen `✓ Take` alarm for their focus reminder, forever, and the
      // one mechanism that would have fixed it has marked itself complete.
      //
      // No notification platform is registered in a headless test, so the cancel
      // throws here — which is precisely the failure this must survive without
      // claiming success.
      SharedPreferences.setMockInitialValues({});
      await FocusReminderScheduler.migrateOffAlarmManager();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('focus_reminders_migrated_v2'), isNull,
          reason: 'the flag must only be set once the old AlarmManager '
              'registrations are actually gone');
    });

    test('an already-migrated install is left alone', () async {
      SharedPreferences.setMockInitialValues(
          {'focus_reminders_migrated_v2': true});
      await FocusReminderScheduler.migrateOffAlarmManager();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('focus_reminders_migrated_v2'), isTrue);
    });

    test('never throws, whatever the platform does', () async {
      // It is called unawaited from FocusService.init(), on the startup path.
      // An unhandled rejection there is a cold-start crash for a reminder.
      SharedPreferences.setMockInitialValues({});
      await expectLater(
          FocusReminderScheduler.migrateOffAlarmManager(), completes);
    });
  });
}
