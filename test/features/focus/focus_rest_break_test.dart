import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart' show FocusMode;
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// A rest break — what Flow offers when a session ends.
///
/// It used to be started as a one-off FOCUS session of the suggested length, so
/// resting grew a plant, paid two coins a minute, kept the streak and went into
/// the history that "your usual length" is the median of. A break recorded as the
/// opposite of a break.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late RecordingFocusSessionAlarm alarm;
  final focus = FocusService();
  final coins = CoinsService();
  final t0 = DateTime(2026, 3, 15, 10, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    alarm = RecordingFocusSessionAlarm();
    focus.alarmForTesting = alarm;
    focus.resetForTesting();
    coins.resetForTesting();
    TagService().resetForTesting();
    await focus.init();
  });

  tearDown(() async {
    focus.resetForTesting();
    await db.close();
  });

  Future<void> waitUntil(bool Function() c, {String? because}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!c() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(c(), isTrue, reason: because ?? 'never became true');
  }

  Future<void> startBreak(int minutes, {DateTime? at}) =>
      withClock(Clock.fixed(at ?? t0), () => focus.startRestBreak(minutes));

  /// Let the clock run to [later] and let the service notice.
  Future<void> runTo(DateTime later) => withClock(Clock.fixed(later), () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => !focus.isRunning, because: 'the break should end');
      });

  group('starting', () {
    test('counts down the minutes asked for, as a break', () async {
      await startBreak(10);

      expect(focus.isRunning, isTrue);
      expect(focus.isOnBreak, isTrue);
      expect(focus.isRestBreak, isTrue);
      expect(focus.remainingSeconds, 600);
      expect(focus.isCountUp, isFalse);
    });

    test('keeps the length of the next focus session as it was', () async {
      focus.setDuration(40);
      await startBreak(10);
      expect(focus.selectedMinutes, 40,
          reason: 'a break must not rewrite what the person chose to focus for');
    });

    test('is a minute at least and an hour at most', () async {
      await startBreak(0);
      expect(focus.remainingSeconds, 60);
      await withClock(Clock.fixed(t0), () => focus.abandonSession());

      await startBreak(500);
      expect(focus.remainingSeconds, 3600);
    });

    test('will not start over something already running', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      await startBreak(10, at: t0.add(const Duration(minutes: 1)));

      expect(focus.isRestBreak, isFalse, reason: 'the session is still the session');
      expect(focus.isOnBreak, isFalse);
    });

    test('arms the end-of-break notification, in words about a break', () async {
      await startBreak(10);
      expect(alarm.armed, hasLength(1));
      expect(alarm.armed.single.at, t0.add(const Duration(minutes: 10)));
      expect(alarm.armed.single.title, 'Break over ☕');
      expect(alarm.armed.single.body, 'Ready when you are.',
          reason: 'there is nothing to "focus again" on: it is only a break');
    });

    test('retires the previous celebration', () async {
      // A screen is listening, so a finished session is published to it.
      void listener() {}
      focus.justCompleted.addListener(listener);
      addTearDown(() => focus.justCompleted.removeListener(listener));
      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.single);
        focus.setDuration(1);
        await focus.startSession();
      });
      await runTo(t0.add(const Duration(minutes: 1)));
      expect(focus.justCompleted.value, isNotNull, reason: 'the premise');

      await startBreak(5, at: t0.add(const Duration(minutes: 2)));
      expect(focus.justCompleted.value, isNull,
          reason: 'the last session\'s plant is not left on screen over a break');
    });
  });

  group('finishing', () {
    test('records nothing: no session, no plant, no coins, no streak', () async {
      final sessionsBefore = focus.sessions.length;
      final gardenBefore = focus.garden.length;
      final statsBefore = focus.stats;
      final coinsBefore = coins.coins.totalCoins;

      await startBreak(10);
      await runTo(t0.add(const Duration(minutes: 10)));

      expect(focus.sessions.length, sessionsBefore);
      expect(focus.garden.length, gardenBefore);
      expect(coins.coins.totalCoins, coinsBefore);
      expect(focus.stats.totalSessions, statsBefore.totalSessions);
      expect(focus.stats.totalMinutes, statsBefore.totalMinutes);
      expect(focus.stats.currentStreak, statsBefore.currentStreak);
      expect(focus.justCompleted.value, isNull,
          reason: 'a break is not something to celebrate');
    });

    test('nothing starts after it, unlike the break between pomodoro rounds', () async {
      await startBreak(5);
      await runTo(t0.add(const Duration(minutes: 5)));

      expect(focus.isRunning, isFalse);
      expect(focus.isOnBreak, isFalse);
      expect(focus.isRestBreak, isFalse);
      expect(focus.remainingSeconds, 0);
    });

    test('and the next session is an ordinary one', () async {
      await startBreak(5);
      await runTo(t0.add(const Duration(minutes: 5)));

      await withClock(Clock.fixed(t0.add(const Duration(minutes: 6))), () async {
        focus.setMode(FocusMode.single);
        focus.setDuration(25);
        await focus.startSession();
      });

      expect(focus.isRunning, isTrue);
      expect(focus.isOnBreak, isFalse);
      expect(focus.isRestBreak, isFalse);
      expect(focus.remainingSeconds, 25 * 60);
    });

    test('takes the pending notification off', () async {
      await startBreak(5);
      expect(alarm.pending, hasLength(1), reason: 'the premise: it was armed');
      await runTo(t0.add(const Duration(minutes: 5)));
      expect(alarm.pending, isEmpty);
    });
  });

  group('giving it up', () {
    test('costs nothing: no abandoned session, no withered plant', () async {
      final abandonedBefore = focus.stats.abandonedSessions;
      final gardenBefore = focus.garden.length;
      final sessionsBefore = focus.sessions.length;

      await startBreak(10);
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 2))),
          () => focus.abandonSession());

      expect(focus.isRunning, isFalse);
      expect(focus.isRestBreak, isFalse);
      expect(focus.stats.abandonedSessions, abandonedBefore);
      expect(focus.garden.length, gardenBefore);
      expect(focus.sessions.length, sessionsBefore);
    });
  });

  group('across a restart', () {
    test('is still a break when the app comes back while it is running', () async {
      await startBreak(10);
      final saved = CleanStorageService.getAppPreferences()['focusActiveSession'];
      expect(saved, isNotNull);

      // The process dies; what is on disk is what comes back.
      focus.resetForTesting();
      await CleanStorageService.setAppPreference('focusActiveSession', saved);
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 3))),
          () => focus.init());

      expect(focus.isRunning, isTrue);
      expect(focus.isRestBreak, isTrue,
          reason: 'recovered as a single session, finishing it would be credited '
              'as focus');
      expect(focus.isOnBreak, isTrue);
      expect(focus.remainingSeconds, 7 * 60);
    });

    test('ending while the app was away ends quietly, with nothing credited', () async {
      await startBreak(10);
      final saved = CleanStorageService.getAppPreferences()['focusActiveSession'];

      final sessionsBefore = focus.sessions.length;
      focus.resetForTesting();
      await CleanStorageService.setAppPreference('focusActiveSession', saved);
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 30))), () async {
        await focus.init();
        await waitUntil(() => !focus.isRunning);
      });

      expect(focus.sessions.length, sessionsBefore,
          reason: 'a break that finished while the app was closed is not a session');
      expect(focus.garden, isEmpty);
      expect(coins.coins.totalCoins, 0);
    });

    test('a snapshot with the flag but no break is not trusted', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      final saved = Map<String, dynamic>.from(
          CleanStorageService.getAppPreferences()['focusActiveSession'] as Map);
      saved['restBreak'] = true; // isOnBreak stays false

      focus.resetForTesting();
      await CleanStorageService.setAppPreference('focusActiveSession', saved);
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1))),
          () => focus.init());

      expect(focus.isRestBreak, isFalse,
          reason: 'a rest break is by definition on a break');
    });
  });

  group('pausing', () {
    test('a paused break holds its time, and resumes', () async {
      await startBreak(10);
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 3))), () async {
        focus.pauseSession();
      });
      expect(focus.isPaused, isTrue);
      expect(focus.isRestBreak, isTrue);

      await withClock(Clock.fixed(t0.add(const Duration(minutes: 20))), () async {
        focus.resumeSession();
        expect(focus.isPaused, isFalse);
        focus.applyTickFromClockForTesting();
        expect(focus.remainingSeconds, 7 * 60,
            reason: 'the time spent paused was not spent resting');
      });
    });
  });

  group('app lifecycle', () {
    test('a break that ended while backgrounded ends on return', () async {
      await startBreak(5);
      focus.didChangeAppLifecycleState(AppLifecycleState.paused);
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 8))), () async {
        focus.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await waitUntil(() => !focus.isRunning);
      });
      expect(focus.sessions, isEmpty);
      expect(focus.isRestBreak, isFalse);
    });
  });
}
