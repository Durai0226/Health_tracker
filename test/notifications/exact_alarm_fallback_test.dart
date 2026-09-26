import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

/// The exact→inexact fallback, driven instead of grepped.
///
/// `USE_EXACT_ALARM` is deliberately absent from the manifest — Play restricts
/// that auto-granted, non-revocable permission to alarm-clock and calendar apps,
/// which this is not. So on Android 14+ `SCHEDULE_EXACT_ALARM` is DENIED BY
/// DEFAULT and `flutter_local_notifications` throws `exact_alarms_not_permitted`
/// for both exact modes. 20 of the 22 `zonedSchedule` call sites let that throw
/// land in an outer `catch` that only `debugPrint`ed, so on a default Android 14+
/// install water reminders, every snooze, and every weekly / weekdays / weekends
/// / custom generic reminder were **silently never armed** — the user saw
/// "reminder set" and was never reminded.
///
/// `exact_alarm_fallback_guard_test.dart` used to assert all of this by reading
/// this app's own source, under a doc comment that said outright:
///
///   > No behavioural test can catch this: `FlutterLocalNotificationsPlugin` is
///   > a concrete class with no injection seam.
///
/// The first clause did not follow from the second. `NotificationScheduler` is
/// that seam, and these are the same invariants asserted by *running* the helper:
/// `expect(helper, contains('AndroidScheduleMode.inexactAllowWhileIdle'))` passes
/// on a helper that mentions the constant in a branch it never takes, and fails
/// on a rename that changed nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingNotificationScheduler scheduler;
  late tz.TZDateTime when;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    scheduler = RecordingNotificationScheduler();
    when = tz.TZDateTime(tz.local, 2026, 9, 20, 8, 0);
  });

  const details = NotificationDetails();

  Future<bool> arm({
    AndroidScheduleMode mode = AndroidScheduleMode.exactAllowWhileIdle,
    bool? recordDowngrade,
    int id = 42,
  }) =>
      zonedScheduleGuarded(
        scheduler,
        id,
        'Insulin',
        'Time to take Insulin',
        when,
        details,
        androidScheduleMode: mode,
        recordDowngrade: recordDowngrade,
        debugLabel: 'test reminder',
      );

  Future<bool> downgradeFlag() async =>
      (await SharedPreferences.getInstance()).getBool(exactAlarmsDowngradedKey) ??
      false;

  group('when Android permits exact alarms', () {
    test('the reminder is armed exactly, once', () async {
      final exact = await arm();

      expect(exact, isTrue);
      expect(scheduler.scheduled, hasLength(1),
          reason: 'a permitted exact request must not also arm a fallback copy '
              '— that is two notifications for one reminder');
      expect(scheduler.scheduled.single.mode,
          AndroidScheduleMode.exactAllowWhileIdle);
      expect(scheduler.scheduled.single.when, when);
    });

    test('the "reminders may arrive late" banner is cleared', () async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{exactAlarmsDowngradedKey: true});

      await arm();

      expect(await downgradeFlag(), isFalse,
          reason: 'the grant arrived and the reminder is exact again, so the '
              'banner must come down — a warning that outlives its cause is '
              'one the user learns to ignore');
    });
  });

  group('when Android refuses exact alarms (the Android 14+ default)', () {
    setUp(() => scheduler.exactAllowed = false);

    test('the reminder is still armed — inexactly, not dropped', () async {
      final exact = await arm();

      expect(exact, isFalse, reason: 'the caller must be told it is inexact');
      expect(scheduler.scheduled, hasLength(1),
          reason: 'THE defect: before the fallback the plugin threw, the throw '
              'landed in an outer catch that only debugPrinted, and the '
              'reminder was never armed at all. Late is survivable; never is '
              'not.');
      expect(scheduler.scheduled.single.mode,
          AndroidScheduleMode.inexactAllowWhileIdle);
      expect(scheduler.scheduled.single.when, when,
          reason: 'the fallback must arm the SAME instant');
    });

    test('the capability is pre-checked, so the throw is never provoked',
        () async {
      await arm();
      expect(scheduler.exactAlarmChecks, 1);
      expect(scheduler.scheduled.map((s) => s.isExact), everyElement(isFalse),
          reason: 'the pre-check exists so the common Android 14+ path costs '
              'one query instead of a thrown exception per reminder');
    });

    test('the downgrade banner is raised', () async {
      await arm();
      expect(await downgradeFlag(), isTrue);
    });

    test('a caller that opted out of the banner still gets armed', () async {
      await arm(recordDowngrade: false);

      expect(scheduler.scheduled.single.mode,
          AndroidScheduleMode.inexactAllowWhileIdle);
      expect(await downgradeFlag(), isFalse,
          reason: 'recordDowngrade: false is for reminders that are inexact by '
              'design; raising a "doses may be late" banner for them is a lie');
    });
  });

  group('a grant revoked between the check and the call', () {
    test('the exact attempt throws, and the inexact retry lands', () async {
      scheduler.refuseExactMidCall.add(42);

      final exact = await arm();

      expect(exact, isFalse);
      expect(scheduler.scheduled, hasLength(1),
          reason: 'the exact attempt threw before recording, so the one '
              'registration on file must be the inexact retry');
      expect(scheduler.scheduled.single.mode,
          AndroidScheduleMode.inexactAllowWhileIdle);
      expect(await downgradeFlag(), isTrue);
    });

    test('anything that is NOT a permission refusal propagates', () async {
      // Same mechanics as the case above — the exact attempt throws and the
      // inexact retry WOULD land — so the only thing separating the two tests is
      // whether the helper reads the error code. Remove the rethrow and this is
      // the test that notices.
      scheduler.refuseExactMidCall.add(42);
      scheduler.midCallError =
          PlatformException(code: 'invalid_notification_id');

      await expectLater(
        arm(),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'invalid_notification_id')),
      );
      expect(scheduler.scheduled, isEmpty,
          reason: 'a bad id must not be silently re-armed inexactly — that '
              'would turn a programming error into a mystery notification and '
              'leave the real fault unreported');
      expect(await downgradeFlag(), isFalse,
          reason: 'and it must not raise the "reminders may arrive late" '
              'banner, which would blame the exact-alarm grant for an error '
              'that has nothing to do with it');
    });
  });

  group('a caller that asked for inexact', () {
    test('is armed as asked, with no capability check and no banner', () async {
      scheduler.exactAllowed = false;

      final exact =
          await arm(mode: AndroidScheduleMode.inexactAllowWhileIdle);

      expect(exact, isFalse);
      expect(scheduler.scheduled.single.mode,
          AndroidScheduleMode.inexactAllowWhileIdle);
      expect(scheduler.exactAlarmChecks, 0,
          reason: 'bedtime, steps and focus reminders are inexact BY DESIGN, '
              'so the exact-alarm grant is irrelevant to them');
      expect(await downgradeFlag(), isFalse,
          reason: 'they were never downgraded, so they must not raise a '
              '"Reminders may arrive late" banner that reads as being about '
              'doses');
    });
  });
}
