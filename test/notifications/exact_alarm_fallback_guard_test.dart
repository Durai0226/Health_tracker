import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A source-grep guard, in the spirit of `background_health_sync_policy_test.dart`
/// and `no_generative_ai_guard_test.dart`.
///
/// `USE_EXACT_ALARM` is deliberately absent from the manifest — Play's
/// acceptable-use policy for that auto-granted, non-revocable permission covers
/// alarm-clock and calendar apps, which this is not. The consequence is that on
/// Android 14+ `SCHEDULE_EXACT_ALARM` is denied by default and
/// `flutter_local_notifications` throws `exact_alarms_not_permitted` for BOTH
/// exact schedule modes.
///
/// 20 of the 22 `zonedSchedule` call sites used to let that throw land in an
/// outer `catch` that only `debugPrint`ed. So on a default Android 14+ install,
/// water reminders, every snooze, and every weekly / weekdays / weekends /
/// custom generic reminder were **silently never armed** — the user saw
/// "reminder set" and was never reminded.
///
/// No behavioural test can catch this: `FlutterLocalNotificationsPlugin` is a
/// concrete class with no injection seam, the platform channel is unregistered
/// headlessly, and the failure is a swallowed exception on a real device. So the
/// invariant is asserted against the source: **every scheduling path goes through
/// the guarded helper**, which cannot forget the fallback.
///
/// Comments are stripped before every check — both files explain the ban by
/// naming the very symbols being banned, and flagging that documentation would
/// make this a nuisance rather than a guard.
String _guardedHelper(Map<String, String> byPath) {
  final home = byPath['lib/core/services/background_alarm_service.dart']!;
  final from = home.indexOf('Future<bool> zonedScheduleGuarded(');
  // The next top-level declaration after it.
  final to = home.indexOf('void notificationTapBackground(', from);
  return home.substring(from, to > from ? to : home.length);
}

String _codeOnly(String source) => source
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

void main() {
  // Both files schedule notifications, so the invariant spans both. The helper
  // itself lives in background_alarm_service.dart, next to the exact-alarm
  // capability check and downgrade flag it has to agree with.
  const paths = [
    'lib/core/services/background_alarm_service.dart',
    'lib/core/services/notification_service.dart',
  ];
  final byPath = {
    for (final p in paths) p: _codeOnly(File(p).readAsStringSync()),
  };
  final code = byPath.values.join('\n');

  group('every zonedSchedule goes through the exact→inexact fallback', () {
    test('no call site reaches the scheduler directly', () {
      // The one legitimate `scheduler.zonedSchedule` is inside
      // `zonedScheduleGuarded` itself, which is the thing being funnelled into.
      //
      // This used to read `plugin.zonedSchedule`. The plugin is now behind the
      // `NotificationScheduler` seam (lib/core/services/notification_scheduler.dart)
      // so scheduling decisions can be asserted behaviourally instead of by
      // grep — see the test below, which pins the raw plugin call to that one
      // adapter. The invariant here is unchanged and is checked the same way:
      // exactly one call, and it is inside the helper.
      final direct = RegExp(r'(?<!scheduler)\.zonedSchedule\s*\(')
          .allMatches(code)
          .length;
      expect(
        direct,
        0,
        reason: 'A `<something>.zonedSchedule(` call bypasses '
            'zonedScheduleGuarded, so an Android 14+ exact-alarm denial will be '
            'swallowed and that reminder will never fire. Route it through '
            '`_zonedSchedule` (in-class) or `zonedScheduleGuarded` (top-level, '
            'for background isolates).',
      );
    });

    test('the guarded helper is the sole owner of scheduler.zonedSchedule', () {
      expect(
          RegExp(r'scheduler\.zonedSchedule\s*\(').allMatches(code).length, 1);
      // ...and that one call is inside zonedScheduleGuarded, not somewhere else.
      final home = byPath['lib/core/services/background_alarm_service.dart']!;
      final helperStart = home.indexOf('Future<bool> zonedScheduleGuarded(');
      expect(helperStart, greaterThan(-1),
          reason: 'zonedScheduleGuarded was renamed, removed, or moved file');
      expect(home.indexOf('scheduler.zonedSchedule('), greaterThan(helperStart));
    });

    test('the raw plugin call lives ONLY in the scheduler adapter', () {
      // The seam is only worth having if nothing routes around it. One adapter
      // owns `_plugin.zonedSchedule`; every other file in lib/ must go through
      // NotificationScheduler, and therefore through the fallback above.
      final offenders = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (f.path.endsWith('lib/core/services/notification_scheduler.dart')) {
          continue;
        }
        final body = _codeOnly(f.readAsStringSync());
        if (RegExp(r'_?plugin\.zonedSchedule\s*\(').hasMatch(body)) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'these call the plugin directly instead of going through '
              'NotificationScheduler, so they skip the exact→inexact '
              'fallback:\n  ${offenders.join('\n  ')}');

      final adapter = _codeOnly(
          File('lib/core/services/notification_scheduler.dart')
              .readAsStringSync());
      expect(RegExp(r'_plugin\.zonedSchedule\s*\(').allMatches(adapter).length,
          1,
          reason: 'the adapter is meant to be the single narrow point where '
              'this app touches the plugin');
    });

    test('the helper retries inexact and pre-checks the capability', () {
      final helper = _guardedHelper(byPath);
      expect(helper, contains('AndroidScheduleMode.inexactAllowWhileIdle'),
          reason: 'the whole point is the inexact retry');
      expect(helper, contains('exactAlarmsAllowed()'),
          reason: 'pre-check keeps the common Android 14+ path off the throw, '
              'and keeps this track in agreement with _registerAlarm');
      expect(helper, contains("e.code != 'exact_alarms_not_permitted'"),
          reason: 'a racy revocation between check and call must still fall back, '
              'and anything else must rethrow rather than be treated as a denial');
    });

    test('a caller that asks for inexact never raises the downgrade banner', () {
      final helper = _guardedHelper(byPath);
      // Bedtime, steps and focus reminders are inexact BY DESIGN. Raising
      // `exactAlarmsDowngradedKey` for them would show the user a
      // "Reminders may arrive late" banner that reads as being about doses.
      expect(helper, contains('recordDowngrade ?? wantsExact'));
      expect(helper, contains('if (!wantsExact)'));
    });

    test('alarmCallback derives its presentation instead of hardcoding one', () {
      // The behavioural contract lives in reminder_kind_presentation_test.dart.
      // This only pins that `alarmCallback` still ASKS — the bug was a ~90-line
      // AndroidNotificationDetails inlined there with `alarm_channel`,
      // `fullScreenIntent: true` and the dose action set baked in.
      final alarmSvc = _codeOnly(
          File('lib/core/services/background_alarm_service.dart')
              .readAsStringSync());
      final callback = alarmSvc.substring(
        alarmSvc.indexOf('Future<void> alarmCallback(int alarmId)'),
        alarmSvc.indexOf('Future<void> _handleWindowNudge('),
      );
      expect(callback, contains('alarmPresentationFor('),
          reason: 'the presentation must come from the pure, tested descriptor');
      expect(callback, contains('ReminderKind.fromBlob(alarmData)'));
      expect(callback.contains('fullScreenIntent: true'), isFalse,
          reason: 'a hardcoded full-screen intent is the original defect: it '
              'made vitals check-ins and the onboarding prompt take over the '
              'screen like a dose alarm');
      expect(callback.contains("'✓ Take'"), isFalse,
          reason: 'the action set belongs to _actionsFor, keyed on ReminderKind');
    });

    test('USE_EXACT_ALARM stays out of the manifest', () {
      // The fallback above is only necessary because of this, and is only
      // correct while this holds. If someone adds the permission, the fallback
      // becomes dead code and this guard should be revisited deliberately.
      final manifest = _codeOnly(
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync());
      expect(
        manifest.contains('android.permission.USE_EXACT_ALARM'),
        isFalse,
        reason: 'USE_EXACT_ALARM is auto-granted and non-revocable, and Play '
            'restricts it to alarm-clock/calendar apps. Adding it here is a '
            'policy decision, not a bug fix.',
      );
    });
  });
}
