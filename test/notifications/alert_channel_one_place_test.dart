/// Which channel an alert is posted to is decided in one place.
///
/// With Vibration off an alert goes to a twin channel without the buzz, and on
/// Android 8 and later a channel's importance, sound and vibration are fixed the
/// first time anything posts to it. So the rule that picks the channel is the one
/// thing the paths that post an alert must not disagree on: a twin created by a
/// path that chose differently stays different for the life of the install.
///
/// The rule had been written out in four places — the alarm, the foreground post,
/// the re-fire after Snooze and the notification at the end of the snoozes. These
/// pin that all of them ask `alertChannelFor` / `channelForVibration`, and that a
/// fifth cannot be written out beside them.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rule', () {
    test('vibrating: the channel as it is', () {
      final c = channelForVibration('medicine_channel', 'Medicine Reminders', vibrate: true);

      expect(c.id, 'medicine_channel');
      expect(c.name, 'Medicine Reminders');
    });

    test('not vibrating: its twin, named for it', () {
      final c = channelForVibration('medicine_channel', 'Medicine Reminders', vibrate: false);

      expect(c.id, 'medicine_channel_still');
      expect(c.name, 'Medicine Reminders (no vibration)');
    });

    test('the quiet channel is its own twin, and keeps its name', () {
      final c = channelForVibration(quietChannelId, 'Quiet Reminders', vibrate: false);

      expect(c.id, quietChannelId);
      expect(c.name, 'Quiet Reminders');
    });

    test('a twin is not made twice', () {
      final c = channelForVibration(
          'alarm_channel_still', 'Alarm Reminders (no vibration)', vibrate: false);

      expect(c.id, 'alarm_channel_still');
      expect(c.name, 'Alarm Reminders (no vibration)');
    });
  });

  group('by kind', () {
    test('an alarm or a dose: the alarm channel, buzzing hard', () {
      for (final kind in [ReminderKind.alarm, ReminderKind.dose]) {
        final c = alertChannelFor(kind, vibrate: true);

        expect(c.id, 'alarm_channel', reason: '$kind');
        expect(c.name, 'Alarm Reminders');
        expect(c.vibrationPattern, [0, 1000, 500, 1000, 500, 1000]);
        expect(c.vibrates, isTrue);
      }
    });

    test('a nudge: the check-in channel, buzzing lightly', () {
      final c = alertChannelFor(ReminderKind.gentle, vibrate: true);

      expect(c.id, 'checkin_channel');
      expect(c.name, 'Check-ins & Nudges');
      expect(c.vibrationPattern, [0, 250, 250, 250]);
    });

    test('a quiet reminder: the quiet channel, and no buzz either way', () {
      for (final vibrate in [true, false]) {
        final c = alertChannelFor(ReminderKind.quiet, vibrate: vibrate);

        expect(c.id, quietChannelId);
        expect(c.name, 'Quiet Reminders');
        expect(c.vibrates, isFalse, reason: 'vibrate=$vibrate');
      }
    });

    test('Vibration off: every kind but quiet goes to its twin, with no buzz', () {
      for (final kind in ReminderKind.values) {
        final on = alertChannelFor(kind, vibrate: true);
        final off = alertChannelFor(kind, vibrate: false);

        expect(off.vibrates, isFalse, reason: '$kind');
        expect(off.vibrationPattern, isEmpty);
        expect(off.id, kind == ReminderKind.quiet ? on.id : '${on.id}_still', reason: '$kind');
      }
    });

    test('a channel the alarm carries with it is honoured for an alarm, not for a nudge', () {
      final alarm = alertChannelFor(ReminderKind.dose,
          vibrate: true,
          requestedChannelId: 'medicine_channel',
          requestedChannelName: 'Medicine Reminders');
      final nudge = alertChannelFor(ReminderKind.gentle,
          vibrate: true,
          requestedChannelId: 'medicine_channel',
          requestedChannelName: 'Medicine Reminders');

      expect(alarm.id, 'medicine_channel');
      expect(nudge.id, 'checkin_channel',
          reason: 'medicine_channel carries alarm audio attributes; a nudge there rings');
    });
  });

  group('the alarm path asks it', () {
    test('every kind, with Vibration on and off, and a carried channel or none', () {
      for (final kind in ReminderKind.values) {
        for (final vibrate in [true, false]) {
          for (final carried in [null, 'medicine_channel']) {
            final look = alarmPresentationFor(kind,
                snoozeMinutes: 10,
                requestedChannelId: carried,
                requestedChannelName: carried == null ? null : 'Medicine Reminders',
                switches: AlarmSwitches(vibrate: vibrate));
            final channel = alertChannelFor(kind,
                vibrate: vibrate,
                requestedChannelId: carried,
                requestedChannelName: carried == null ? null : 'Medicine Reminders');
            final why = '$kind vibrate=$vibrate carried=$carried';

            expect(look.channelId, channel.id, reason: why);
            expect(look.channelName, channel.name, reason: why);
            expect(look.vibrationPattern, channel.vibrationPattern, reason: why);
          }
        }
      }
    });
  });

  group('the foreground post asks it', () {
    setUpAll(() {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    });

    late AppDatabase db;
    late RecordingNotificationScheduler scheduler;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;
    });
    tearDown(() async => db.close());

    test('every kind, with Vibration on and off', () async {
      for (final kind in ReminderKind.values) {
        for (final vibrate in [true, false]) {
          SharedPreferences.setMockInitialValues({});
          CleanStorageService.resetForTesting();
          await CleanStorageService.setAppPreference('vibrationEnabled', vibrate);
          scheduler.shown.clear();

          final shown = await NotificationService()
              .showImmediateNotification(title: 'Hello', body: 'There', kind: kind);

          expect(shown, isTrue);
          final android = scheduler.shown.single.details!.android!;
          final channel = alertChannelFor(kind, vibrate: vibrate);
          final why = '$kind vibrate=$vibrate';
          expect(android.channelId, channel.id, reason: why);
          expect(android.channelName, channel.name, reason: why);
          expect(android.enableVibration, channel.vibrates, reason: why);
          expect(android.vibrationPattern?.toList(),
              channel.vibrates ? channel.vibrationPattern : isNull,
              reason: why);
        }
      }
    });
  });

  group('and nothing writes it out again', () {
    // The twin is named in exactly one place. A path that does it inline compiles,
    // passes the tests that existed when it was written, and diverges the first
    // time the rule changes — which is how there came to be four.
    String code(String path) => File(path)
        .readAsLinesSync()
        .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n');

    final libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .map((f) => f.path)
        .toList();

    int calls(String name) {
      var n = 0;
      for (final path in libFiles) {
        n += RegExp('\\b$name\\(').allMatches(code(path)).length;
      }
      return n;
    }

    test('stillChannelId is defined once and called once: by channelForVibration', () {
      expect(calls('stillChannelId'), 2,
          reason: 'its definition, and the one call in channelForVibration. A new call '
              'means a path is choosing the twin itself: use alertChannelFor or '
              'channelForVibration, so that it cannot choose differently from the rest.');
    });

    test('and so is stillChannelName', () {
      expect(calls('stillChannelName'), 2,
          reason: 'its definition, and the one call in channelForVibration.');
    });

    test('and the paths that post an alert go through the helper', () {
      final service = code('lib/core/services/notification_service.dart');
      final alarm = code('lib/core/services/background_alarm_service.dart');

      expect(RegExp(r'\balertChannelFor\(').allMatches(service).length, greaterThanOrEqualTo(1),
          reason: 'NotificationService._notificationDetails');
      expect(RegExp(r'\balertChannelFor\(').allMatches(alarm).length, greaterThanOrEqualTo(3),
          reason: 'its definition, alarmPresentationFor and the re-fire after Snooze');
      expect(RegExp(r'\bchannelForVibration\(').allMatches(alarm).length, greaterThanOrEqualTo(3),
          reason: 'its definition, alertChannelFor and snoozeLimitDetails');
    });
  });
}
