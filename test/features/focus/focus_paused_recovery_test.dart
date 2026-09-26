import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:flutter/foundation.dart';

/// Resume must work on a paused session that came back from a process kill.
///
/// The user pauses a 25-minute session at the 10-minute mark, switches away, and
/// Android kills the app. Reopening Focus restored the paused session — the ring,
/// the remaining time, the Resume button — but `_pauseStartTime` lives only in
/// memory, and `resumeSession()` requires it. So Resume returned silently and did
/// nothing, over and over: a DEAD BUTTON whose only alternative was Give Up,
/// which withers the plant and files an abandoned session for one the user fully
/// intended to finish.
///
/// The second half of the defect is quieter. `_endTime` is also restored from the
/// pre-kill snapshot, so it is already in the past by the time the app comes
/// back; a Resume that merely pushed it forward by the pause duration would have
/// handed back a countdown that was minutes short, or instantly zero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  final t0 = DateTime(2026, 3, 14, 13, 0, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    RelaxationService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    RelaxationService().resetForTesting();
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

  /// Start a 25-minute session, run [runFor], pause, then kill the process.
  Future<FocusService> pausedThenKilled({
    Duration runFor = const Duration(minutes: 10),
  }) async {
    final focus = FocusService();
    await withClock(Clock.fixed(t0), () async {
      focus.setDuration(25);
      await focus.startSession();
    });
    await withClock(Clock.fixed(t0.add(runFor)), () async {
      focus.applyTickFromClockForTesting();
      focus.pauseSession();
    });
    // Memory is gone; the persisted snapshot is not.
    FocusService().resetForTesting();
    expect(focus.isRunning, isFalse, reason: 'sanity: memory really is gone');
    return focus;
  }

  group('a paused session recovered after a process kill', () {
    test('comes back paused, with the time that was left', () async {
      final focus = await pausedThenKilled();

      // Back an hour later. A pause is not a countdown, so an hour spent away
      // must not cost the user any of it.
      await withClock(
          Clock.fixed(t0.add(const Duration(hours: 1))), () async => focus.init());

      expect(focus.isRunning, isTrue);
      expect(focus.isPaused, isTrue);
      expect(focus.remainingSeconds, closeTo(15 * 60, 2),
          reason: 'fifteen minutes were left when they paused');
    });

    test('Resume actually resumes it — the button is not dead', () async {
      final focus = await pausedThenKilled();

      final back = t0.add(const Duration(hours: 1));
      await withClock(Clock.fixed(back), () async => focus.init());

      // Two minutes staring at the paused screen, then Resume.
      final tapped = back.add(const Duration(minutes: 2));
      await withClock(Clock.fixed(tapped), () async => focus.resumeSession());

      expect(focus.isPaused, isFalse,
          reason: 'BEFORE THE FIX `_pauseStartTime` was null after recovery, so '
              'resumeSession() returned silently and the session stayed paused '
              'forever — the only way out was Give Up, which withers the plant '
              'and records an abandoned session');
      expect(focus.isRunning, isTrue);

      // And the countdown has to pick up from the wall clock, not from the
      // pre-kill `_endTime` that was already an hour in the past.
      await withClock(Clock.fixed(tapped.add(const Duration(minutes: 5))),
          () async => focus.applyTickFromClockForTesting());
      expect(focus.remainingSeconds, closeTo(10 * 60, 2),
          reason: 'fifteen minutes left, five of them spent: ten to go');
      expect(focus.isRunning, isTrue,
          reason: 'a resumed session must not complete instantly because its '
              'restored end time was stale');
    });

    test('a paused snapshot with no time left is credited, not left hanging',
        () async {
      // Seeded rather than acted out: a snapshot whose `remainingSeconds` is 0 is
      // what a truncated write or an older build leaves behind, and restoring it
      // as a paused session shows 00:00 with a Resume that has nothing to resume.
      await CleanStorageService.setAppPreference('focusActiveSession', {
        'startedAtMs': t0.millisecondsSinceEpoch,
        'endsAtMs':
            t0.add(const Duration(minutes: 25)).millisecondsSinceEpoch,
        'phaseMinutes': 25,
        'selectedMinutes': 25,
        'mode': 0,
        'isOnBreak': false,
        'isLongBreak': false,
        'currentRound': 0,
        'isPaused': true,
        'remainingSeconds': 0,
      });

      final focus = FocusService();
      await withClock(Clock.fixed(t0.add(const Duration(hours: 1))), () async {
        await focus.init();
        await waitUntil(() => !focus.isRunning,
            because: 'a paused snapshot with nothing left must complete rather '
                'than restore as an unresumable session');
      });

      expect(focus.isRunning, isFalse);
      expect(focus.sessions.single.wasCompleted, isTrue);
    });

    test('the guard does not over-fire: a RUNNING session still recovers running',
        () async {
      // The fix only touches the `isPaused` branch. A plain in-flight session must
      // still come back unpaused and ticking.
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      FocusService().resetForTesting();

      await withClock(Clock.fixed(t0.add(const Duration(minutes: 10))),
          () async => focus.init());

      expect(focus.isRunning, isTrue);
      expect(focus.isPaused, isFalse,
          reason: 'nothing was paused, so nothing may come back paused');
      expect(focus.remainingSeconds, closeTo(15 * 60, 2));
    });
  });

  group('a pause is not banked as focused time', () {
    // Flow mode's whole record is "time spent", and `elapsedSeconds` measured
    // `now - _startTime` while neither pause nor resume ever moved
    // `_startTime`. So pausing for twenty minutes and tapping Done wrote twenty
    // minutes the user did not focus into the session, the daily total, the
    // streak and the median-duration suggestion that drives the app's own
    // recommendations. (Countdown mode was unaffected — it pushes `_endTime`
    // forward instead of counting up.)

    test('negative: paused minutes are excluded from the flow session',
        () async {
      final t0 = DateTime(2026, 4, 15, 10);
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.flow);
        await focus.startSession();
      });

      // Ten minutes of real focus.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 10))),
          () async => focus.pauseSession());
      // Twenty minutes paused — coffee, a phone call, anything.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 30))),
          () async => focus.resumeSession());
      // Five more minutes of real focus, then Done.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 35))),
          () async {
        expect(focus.elapsedSeconds, 15 * 60,
            reason: 'ten minutes before the pause plus five after it — the '
                'twenty paused minutes are not focus');
        await focus.stopFlowSession();
      });

      await waitUntil(() => focus.sessions.isNotEmpty,
          because: 'the flow session never completed');
      expect(focus.sessions.single.actualMinutes, 15,
          reason: 'banking 35 minutes credits time the user did not focus');
    });

    test('a pause STILL IN PROGRESS stops the readout climbing', () async {
      final t0 = DateTime(2026, 4, 15, 14);
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.flow);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 5))),
          () async => focus.pauseSession());

      // Ten minutes later, still paused: the number must not have moved.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 15))),
          () async {
        expect(focus.elapsedSeconds, 5 * 60,
            reason: 'a paused stopwatch does not run');
      });
    });

    test('positive: an unpaused session is unaffected', () async {
      final t0 = DateTime(2026, 4, 15, 16);
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.flow);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 22))),
          () async {
        expect(focus.elapsedSeconds, 22 * 60);
        await focus.stopFlowSession();
      });
      await waitUntil(() => focus.sessions.isNotEmpty);
      expect(focus.sessions.single.actualMinutes, 22);
    });
  });

  group('a malformed snapshot is not banked as a completed session', () {
    test('negative: a paused snapshot with NO remainingSeconds is restored, '
        'not credited', () async {
      // `remainingSeconds` used to default to 0 when the key was absent — an
      // older build, a partial write, or a pause persisted fire-and-forget and
      // then killed — and a 0 remaining meant "finished", so the recovery
      // credited a FULL session: a plant, the coins and the minutes, for a
      // session whose end time had not arrived.
      final focus = await pausedThenKilled(runFor: const Duration(minutes: 5));
      expect(focus.sessions, isEmpty, reason: 'sanity: nothing banked yet');

      // Strip the key from the persisted snapshot, leaving endsAt in the future.
      final prefs = CleanStorageService.getAppPreferences();
      final snap = Map<String, dynamic>.from(
          prefs['focusActiveSession'] as Map);
      snap.remove('remainingSeconds');
      await CleanStorageService.setAppPreference('focusActiveSession', snap);

      final revived = FocusService();
      // Back while the stored end time is still ahead.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 6))),
          () async => revived.init());

      expect(revived.sessions, isEmpty,
          reason: 'the interval had not finished — banking it invents a '
              'completed session, a plant and coins the user never earned');
      expect(revived.isRunning, isTrue,
          reason: 'it should come back as the paused session it was');
      expect(revived.remainingSeconds, greaterThan(0),
          reason: 'Resume must have something to resume');
    });

    test('a payout survives the state being reset underneath it', () async {
      // Found by this suite, not by the audit: `_completeSession` dereferenced
      // `_startTime!` AFTER its awaits, so a reset landing mid-payout crashed
      // with "Null check operator used on a null value". `_finishing` stops a
      // second CALL; it cannot stop the state being cleared from under one
      // already in flight — which is what a delete-all-data wipe does.
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });

      await withClock(Clock.fixed(t0.add(const Duration(minutes: 25))),
          () async {
        // Kick the completion, then pull the state out from under it before its
        // awaits finish.
        focus.applyTickFromClockForTesting();
        FocusService().resetForTesting();
      });

      // The assertion is that no error escapes: flutter_test fails a test on an
      // unhandled async error, and before the fix this run reported
      // "Null check operator used on a null value" from _completeSession.
      // Collected explicitly rather than relied on implicitly, so the reason is
      // visible in the output instead of arriving as a bare framework failure.
      final errors = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exception.toString());
      try {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      } finally {
        FlutterError.onError = prev;
      }
      expect(errors.where((e) => e.contains('Null check operator')), isEmpty,
          reason: 'a payout must not dereference state a reset has cleared: '
              '${errors.join(' | ')}');
      // And the service must be left usable, not half-torn-down.
      expect(FocusService().isRunning, isFalse);
    });
  });
}
