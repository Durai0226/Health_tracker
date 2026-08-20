import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// The armed completion notification: when it is set, and when it is withdrawn.
///
/// ## What this proves, and what it deliberately does not
///
/// The background-completion notification went unwritten for a long time behind
/// one objection: *scheduled delivery cannot be verified headlessly.* That is
/// true, and it is too broad. Delivery is an OS behaviour, and it is not where
/// the defects are. The defects are in the arm/disarm decisions — arming against
/// a stale end time after a pause, leaking a pending notification into an idle
/// service, announcing twice — and those are ordinary logic.
///
/// So [FocusSessionAlarm] is a seam, exactly like `AudioEngine`, and everything
/// below asserts the decision rather than the delivery.
///
/// **Not covered here, by design:** that Android actually delivers, Doze
/// behaviour, and rescheduling across a reboot. Those need a device, and they are
/// written down as manual checks in `docs/release-checklist.md` rather than
/// implied to be covered.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late RecordingFocusSessionAlarm alarm;

  final t0 = DateTime(2026, 3, 14, 13, 0, 0);
  const armedId = NotificationService.focusSessionEndId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    alarm = RecordingFocusSessionAlarm();
    FocusService().alarmForTesting = alarm;
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    await db.close();
  });

  Future<void> waitUntil(bool Function() condition, {String? because}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue,
        reason: because ?? 'condition never became true within 5s');
  }

  final focus = FocusService();

  group('arming', () {
    test('a session arms exactly one notification, at its end time', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });

      expect(alarm.pending, hasLength(1));
      expect(alarm.pending.single.id, armedId);
      expect(alarm.pending.single.at, t0.add(const Duration(minutes: 25)),
          reason: 'must be the absolute end time, not a duration from "now"');
    });

    test('arms at START, not only when the app is backgrounded', () async {
      // Waiting for `paused` would mean the sessions most likely to need this are
      // the ones that never armed: `detached` is not a reliable place to do I/O,
      // and a force-stop or an OOM kill can skip `paused` entirely.
      await withClock(Clock.fixed(t0), () async {
        await focus.startSession();
      });
      expect(alarm.pending, hasLength(1),
          reason: 'nothing has been backgrounded yet');
    });

    test('an idle service arms nothing when backgrounded', () async {
      focus.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(alarm.armed, isEmpty);
      expect(alarm.pending, isEmpty);
    });

    test('a non-final pomodoro round announces the ROUND, not the session',
        () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.pomodoro);
        focus.setPomodoroConfig(totalRounds: 4);
        await focus.startSession();
      });

      final copy = alarm.pending.single;
      expect(copy.title, contains('Round 1 of 4'),
          reason: 'a user who is away has only this text to tell a round '
              'handover from the end of the whole session');
      expect(copy.title, isNot(contains('session')));
    });

    test('a single-mode session announces the session', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.single);
        await focus.startSession();
      });
      expect(alarm.pending.single.title.toLowerCase(), contains('session'));
    });
  });

  group('disarming', () {
    test('resuming re-arms against the NEW end time', () async {
      // The regression this pins: `resumeSession` pushes `_endTime` forward by the
      // pause duration. A notification armed before the pause points at an instant
      // that is no longer the end of anything, so it would fire early — while the
      // session is still running.
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
        focus.pauseSession();
      });
      expect(alarm.pending, isEmpty,
          reason: 'a paused session has no end time to announce');

      final resumedAt = t0.add(const Duration(minutes: 5));
      await withClock(Clock.fixed(resumedAt), () async {
        focus.resumeSession();
      });

      expect(alarm.pending, hasLength(1));
      expect(alarm.pending.single.at, t0.add(const Duration(minutes: 30)),
          reason: 'the five paused minutes must move the armed instant too');
    });

    test('abandoning withdraws it', () async {
      await withClock(Clock.fixed(t0), () async {
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 3))), () async {
        await focus.abandonSession();
      });
      expect(alarm.pending, isEmpty);
      expect(alarm.disarmed, contains(armedId));
    });

    test('completing withdraws it', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1, seconds: 1))),
          () async {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => !focus.isRunning);
      expect(alarm.pending, isEmpty,
          reason: 'an idle service must never have a notification pending');
    });

    test('the last foreground seconds are handed to the in-app celebration',
        () async {
      // AlarmManager can fire exactly at `_endTime` while this ticker reaches it up
      // to a second later, so a user watching the screen would get a system banner
      // just BEFORE the toast — the one moment in the feature that should feel
      // good, pre-empted by a notification about it.
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      expect(alarm.pending, hasLength(1));

      await withClock(Clock.fixed(t0.add(const Duration(seconds: 58))), () async {
        focus.applyTickFromClockForTesting();
      });
      expect(alarm.pending, isEmpty,
          reason: 'two seconds left, on screen — the toast will do it');
      expect(focus.isRunning, isTrue, reason: 'not finished, just disarmed');
    });

    test('backgrounding inside that window re-arms', () async {
      // Otherwise the pre-emption above becomes a hole: disarmed for the toast,
      // then the user leaves and nothing tells them at all.
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(seconds: 58))), () async {
        focus.applyTickFromClockForTesting();
      });
      expect(alarm.pending, isEmpty);

      await withClock(Clock.fixed(t0.add(const Duration(seconds: 58))), () async {
        focus.didChangeAppLifecycleState(AppLifecycleState.paused);
      });
      expect(alarm.pending, hasLength(1),
          reason: 'left the screen with two seconds to go — arm it again');
      expect(alarm.pending.single.at, t0.add(const Duration(minutes: 1)));
    });
  });

  group('never announces twice', () {
    test('a completion the OS already delivered is not repeated', () async {
      // The defect a naive version of this fix introduces. Once completion can be
      // delivered in the background, the resume path runs `_completeSession()` and
      // announces AGAIN — so a user who stepped away gets the scheduled banner,
      // then a second one the instant they reopen the app.
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
        focus.didChangeAppLifecycleState(AppLifecycleState.paused);
      });
      expect(alarm.pending, hasLength(1));
      final armedAt = alarm.pending.single.at;

      // Return well after the armed instant: the OS has already told them.
      await withClock(Clock.fixed(armedAt.add(const Duration(minutes: 4))),
          () async {
        focus.didChangeAppLifecycleState(AppLifecycleState.resumed);
      });
      await waitUntil(() => !focus.isRunning,
          because: 'resuming past the end time must credit the session');

      expect(focus.completionAlreadyAnnouncedForTesting, isTrue,
          reason: 'the armed instant had passed, so _announceCompletion must '
              'stay silent rather than duplicate it');
      expect(alarm.pending, isEmpty);
      expect(focus.sessions.single.wasCompleted, isTrue);
    });

    test('a completion the OS did NOT deliver is still announced', () async {
      // The other half, and the reason the flag is computed at disarm rather than
      // simply set: pre-empting in the foreground must not silence the app.
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(seconds: 58))), () async {
        focus.applyTickFromClockForTesting();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1, seconds: 1))),
          () async {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => !focus.isRunning);

      expect(focus.completionAlreadyAnnouncedForTesting, isFalse,
          reason: 'disarmed BEFORE the instant passed, so nothing was '
              'delivered and the app still owes the user the news');
    });
  });
}
