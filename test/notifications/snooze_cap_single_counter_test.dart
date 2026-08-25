import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/models/user_settings.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

/// The snooze cap used to be bypassable, indefinitely.
///
/// Two handlers competed for flutter_local_notifications' single app-wide
/// background callback handle, and they counted snoozes in two different stores:
/// `notification_service.dart` used the SharedPreferences key
/// `snooze_count_$baseId`, while `background_alarm_service.dart` kept its count
/// inside the `alarm_$id` JSON blob. Long comments in both files asserted they
/// shared one counter. They did not.
///
/// Which handler Android invoked depended on whether the alarm isolate or the
/// main isolate had most recently called `initialize()` — i.e. on whether the app
/// happened to be running. So a user alternating "tap snooze with the app closed"
/// and "tap snooze with the app open" incremented two independent counters,
/// neither of which ever reached the cap. A medicine dose could be deferred
/// forever with no final reminder.
///
/// [handleSnoozeAction] is now the single entry point and both paths share
/// [snoozeCountKeyFor]. Each path still reschedules differently — an AlarmManager
/// alarm carries a blob with the dose's identity, a `zonedSchedule` notification
/// has only its payload — but the counter is one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseId = 4242;
  final counterKey = snoozeCountKeyFor(baseId);

  /// A persisted AlarmManager blob — the "app was closed" path.
  String blob({int? carriedBaseId}) => jsonEncode({
        'title': 'Take Metformin',
        'body': '500mg',
        'channelId': 'medicine_channel',
        'hour': 8,
        'minute': 0,
        if (carriedBaseId != null) 'baseId': carriedBaseId,
      });

  /// An `alarm:` payload — the "app was open" / zonedSchedule path.
  String payload({int? carriedBaseId}) => 'alarm:${jsonEncode({
        'id': baseId,
        'title': 'Take Metformin',
        'body': '500mg',
        if (carriedBaseId != null) 'baseId': carriedBaseId,
      })}';

  group('one counter, whichever path the tap lands on', () {
    test('the blob path increments the shared SharedPreferences key', () async {
      // A snoozed re-fire (id != baseId) so the fresh-fire reset does not apply.
      const refireId = baseId + snoozeIdOffset;
      SharedPreferences.setMockInitialValues({
        'alarm_$refireId': blob(carriedBaseId: baseId),
        counterKey: 1,
      });
      await handleSnoozeAction(refireId, null);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(counterKey), 2,
          reason: 'the count used to live in the blob, invisible to the '
              'payload path');
    });

    test('the payload path increments the same key', () async {
      SharedPreferences.setMockInitialValues({counterKey: 1});
      await handleSnoozeAction(baseId + snoozeIdOffset,
          payload(carriedBaseId: baseId));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(counterKey), 2);
    });

    test('ALTERNATING paths cannot exceed the cap — the actual bug', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(maxSnoozeCountKey, 3);
      const refireId = baseId + snoozeIdOffset;

      // Payload, blob, payload — three snoozes alternating across both paths.
      // Each carries the base forward the way its own mechanism does: the
      // payload path in the `alarm:` JSON, the blob path in `alarm_$id`.
      await handleSnoozeAction(refireId, payload(carriedBaseId: baseId));
      await prefs.setString('alarm_$refireId', blob(carriedBaseId: baseId));
      await handleSnoozeAction(refireId, null); // blob present -> blob path
      await prefs.remove('alarm_$refireId');
      await handleSnoozeAction(refireId, payload(carriedBaseId: baseId));

      expect(prefs.getInt(counterKey), 3,
          reason: 'each path must see what the other wrote');

      // The fourth is capped: the counter must not advance past the cap.
      await prefs.setString('alarm_$refireId', blob(carriedBaseId: baseId));
      await handleSnoozeAction(refireId, null);
      expect(prefs.getInt(counterKey), 3,
          reason: 'a capped snooze shows a final reminder instead of '
              'rescheduling, so it must not consume another count');
    });

    test('the cap is the mirrored user setting, not a hardcoded 3', () async {
      SharedPreferences.setMockInitialValues({maxSnoozeCountKey: 1});
      final prefs = await SharedPreferences.getInstance();
      await handleSnoozeAction(
          baseId + snoozeIdOffset, payload(carriedBaseId: baseId));
      expect(prefs.getInt(counterKey), 1);
      await handleSnoozeAction(
          baseId + snoozeIdOffset, payload(carriedBaseId: baseId));
      expect(prefs.getInt(counterKey), 1, reason: 'capped at the user-set 1');
    });

    test('an absent cap falls back to the documented default', () async {
      SharedPreferences.setMockInitialValues({counterKey: defaultMaxSnoozeCount});
      final prefs = await SharedPreferences.getInstance();
      await handleSnoozeAction(
          baseId + snoozeIdOffset, payload(carriedBaseId: baseId));
      expect(prefs.getInt(counterKey), defaultMaxSnoozeCount,
          reason: 'already at the default cap, so no further snooze');
    });
  });

  group('a fresh fire starts a new snooze chain', () {
    test('resets the counter rather than inheriting yesterday\'s', () async {
      // Without this, three snoozes yesterday would cap today's first dose
      // instantly — the counter is keyed by reminder, not by occurrence.
      SharedPreferences.setMockInitialValues({counterKey: 99});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alarm_$baseId', blob());
      await handleSnoozeAction(baseId, null);
      expect(prefs.getInt(counterKey), 1);
    });

    test('a fresh fire is one whose id IS its base', () {
      expect(resolveSnoozeBaseId(baseId, null), baseId);
      expect(resolveSnoozeBaseId(baseId + snoozeIdOffset, baseId), baseId);
    });

    test('the base is carried, never derived by subtraction', () {
      // Deriving it would be ambiguous: the medicine slot block
      // (100000-101439) overlaps the snooze-twin range of the ids below it, so
      // `id - snoozeIdOffset` cannot tell a fresh slot from a snoozed reminder.
      expect(resolveSnoozeBaseId(100_500, null), 100_500,
          reason: 'a medicine slot id is its own base, not 500');
    });
  });

  group('the settings the alarm isolate reads actually get written', () {
    test('one save mirrors all four keys', () async {
      // These used to be mirrored only at cold start, and only two of them:
      // changing the snooze interval in Settings did nothing until the next
      // launch, and `max_snooze_count` was never written at all — so the cap the
      // alarm isolate enforced was permanently the default, whatever the user
      // chose.
      SharedPreferences.setMockInitialValues({});
      await CleanStorageService.mirrorSettingsForAlarmIsolate(UserSettings(
        snoozeIntervalMinutes: 17,
        snoozeEnabled: false,
        maxSnoozeCount: 6,
        showOnLockScreen: true,
      ));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(snoozeIntervalMinutesKey), 17);
      expect(prefs.getBool(snoozeEnabledKey), isFalse);
      expect(prefs.getInt(maxSnoozeCountKey), 6);
      expect(prefs.getBool(kShowOnLockScreenPref), isTrue);
    });

    test('a mirrored cap is the one handleSnoozeAction enforces', () async {
      SharedPreferences.setMockInitialValues({});
      await CleanStorageService.mirrorSettingsForAlarmIsolate(
          UserSettings(maxSnoozeCount: 1));
      final prefs = await SharedPreferences.getInstance();
      await handleSnoozeAction(
          baseId + snoozeIdOffset, payload(carriedBaseId: baseId));
      expect(prefs.getInt(counterKey), 1);
      await handleSnoozeAction(
          baseId + snoozeIdOffset, payload(carriedBaseId: baseId));
      expect(prefs.getInt(counterKey), 1,
          reason: 'the user set 1; the isolate must not fall back to 3');
    });
  });

  group('both isolates use the identical handler', () {
    test('the rival handler is gone', () async {
      final code = await _codeOf('lib/core/services/background_alarm_service.dart');
      expect(code.contains('_backgroundNotificationCallback'), isFalse,
          reason: 'two handlers for one app-wide slot is the defect');
    });

    test('every registration points at notificationTapBackground', () async {
      for (final path in [
        'lib/core/services/background_alarm_service.dart',
        'lib/core/services/notification_service.dart',
      ]) {
        final code = await _codeOf(path);
        for (final m in RegExp(r'onDidReceiveBackgroundNotificationResponse:\s*(\w+)')
            .allMatches(code)) {
          expect(m.group(1), 'notificationTapBackground', reason: path);
        }
      }
    });

    test('the handler covers every action, including log_water', () async {
      final code = await _codeOf('lib/core/services/background_alarm_service.dart');
      final handler = code.substring(
        code.indexOf('void notificationTapBackground('),
        code.indexOf('Future<void> handleSnoozeAction('),
      );
      // log_water lived in only ONE of the two handlers, so whether a widget tap
      // was recorded depended on which isolate had initialised last.
      for (final action in ["'snooze'", "'dismiss'", "'take'", "'skip'", 'waterLogActionId']) {
        expect(handler, contains(action));
      }
    });
  });
}

Future<String> _codeOf(String path) async {
  final raw = await File(path).readAsString();
  return raw
      .split('\n')
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');
}
