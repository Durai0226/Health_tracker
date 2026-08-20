import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// Timer integrity: the countdown, the session record, and what survives death.
///
/// None of this had any executable coverage. The reason was structural, not
/// neglect: `testWidgets` already runs inside `FakeAsync`, so pumping fires the
/// 1 Hz callbacks instantly — but `FakeAsync` does **not** fake `DateTime.now()`,
/// and the countdown is derived from an absolute `_endTime` minus the wall clock.
/// A test could pump twenty-five minutes and the session would never complete.
/// Production now reads `clock.now()`, so `withClock` closes that gap.
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

  /// Wait for [condition], polling the real event loop.
  ///
  /// These are plain `test()` bodies, so there is no FakeAsync and
  /// `pumpEventQueue()` yields for a fixed number of turns — enough when the file
  /// runs alone, NOT enough when the whole directory runs and the machine is busy
  /// finishing another isolate's Drift writes. `_completeSession` awaits storage,
  /// so the assertion after it was racing. That produced a failure that appeared
  /// only in combined runs, which is the most expensive kind to diagnose.
  Future<void> waitUntil(bool Function() condition, {String? because}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue,
        reason: because ?? 'condition never became true within 5s');
  }

  group('the countdown spends the whole duration', () {
    test('does not complete a second early, and publishes 00:00', () async {
      // `Duration.inSeconds` truncates toward zero, so with 400ms left of a
      // 25-minute session the old tick reported 0 and completed — every session
      // ran up to a second SHORT, and the readout jumped from 00:01 to finished
      // without ever showing 00:00.
      final focus = FocusService();
      final seen = <int>[];
      focus.tick.addListener(() => seen.add(focus.tick.value));

      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });

      // 59.5s in: still one whole second to go.
      await withClock(Clock.fixed(t0.add(const Duration(milliseconds: 59500))),
          () async => focus.applyTickFromClockForTesting());
      expect(focus.isRunning, isTrue,
          reason: 'a session must not finish before its duration elapses');
      expect(focus.remainingSeconds, 1);
      expect(focus.formattedTime, '00:01');

      // Exactly at the end.
      await withClock(Clock.fixed(t0.add(const Duration(seconds: 60))),
          () async {
        focus.applyTickFromClockForTesting();
        // Completion is async (_completeSession awaits storage), so wait for it
        // rather than assuming a fixed number of event-loop turns is enough.
        await waitUntil(() => !focus.isRunning,
            because: 'the session must finish once its end time is reached');
      });
      expect(seen, contains(0),
          reason: 'the readout must be given a 00:00 to show for the final '
              'second rather than skipping it');
      expect(focus.isRunning, isFalse);
    });
  });

  group('an in-flight session survives the process dying', () {
    test('a running session is persisted the moment it starts', () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });

      final saved = CleanStorageService.getAppPreferences()['focusActiveSession'];
      expect(saved, isA<Map>(),
          reason: 'BEFORE THE FIX nothing was written: _isRunning, _startTime and '
              '_endTime lived only in memory, so a process kill discarded the '
              'session with no row, no plant, and not even an abandoned record');
      expect((saved as Map)['endsAtMs'], isNotNull);
    });

    test('a session still running is resumed with the right time left', () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });

      // The process dies and comes back ten minutes later.
      FocusService().resetForTesting();
      expect(focus.isRunning, isFalse, reason: 'sanity: memory really is gone');

      await withClock(Clock.fixed(t0.add(const Duration(minutes: 10))),
          () async => focus.init());

      expect(focus.isRunning, isTrue, reason: 'the session must come back');
      expect(focus.remainingSeconds, closeTo(15 * 60, 2),
          reason: 'time left is recomputed from the wall clock, not from ticks '
              'that never fired');
    });

    test('a session that ended while away is credited, not lost', () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });

      FocusService().resetForTesting();

      // Back an hour later — the session's end time is long past.
      await withClock(Clock.fixed(t0.add(const Duration(hours: 1))),
          () async {
        await focus.init();
        await waitUntil(() => !focus.isRunning,
            because: 'a recovered session past its end must be credited and '
                'closed, not left running');
      });

      expect(focus.isRunning, isFalse);
      expect(focus.sessions, isNotEmpty,
          reason: 'the session ran its full length while the app was dead; '
              'crediting it matches what _syncTimer already does for a merely '
              'backgrounded app, and punitive heuristics are what generate '
              'unfair-loss complaints in this category');
      expect(focus.sessions.first.wasCompleted, isTrue);
    });

    test('the persisted record is cleared once the session ends', () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
        await focus.abandonSession();
      });

      final saved = CleanStorageService.getAppPreferences()['focusActiveSession'];
      expect(saved, isNull,
          reason: 'a stale record would resurrect a finished session on next '
              'launch');
    });
  });

  group('abandoning reports the time actually spent', () {
    test('30 seconds into a 25-minute session is 0 minutes, not 1', () async {
      // `_selectedMinutes - (_remainingSeconds ~/ 60)` rounded the subtraction
      // UP, so a 30-second abandon logged a full minute and 90 seconds logged two.
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(seconds: 30))),
          () async {
        focus.applyTickFromClockForTesting();
        await focus.abandonSession();
      });

      expect(focus.sessions.single.actualMinutes, 0,
          reason: 'thirty seconds is not a minute of focus');
      expect(focus.sessions.single.wasAbandoned, isTrue);
    });
  });

  group('the ticker stops while the app is away', () {
    test('backgrounding cancels it and returning restarts it', () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      expect(focus.debugTimerActive, isTrue);

      focus.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(focus.debugTimerActive, isFalse,
          reason: 'only `resumed` used to be handled, so a 1 Hz timer kept '
              'recomputing a countdown nobody could see');

      await withClock(Clock.fixed(t0.add(const Duration(minutes: 5))),
          () async => focus.didChangeAppLifecycleState(
              AppLifecycleState.resumed));
      expect(focus.debugTimerActive, isTrue,
          reason: 'without restarting it the clock would freeze on return');
      expect(focus.remainingSeconds, closeTo(20 * 60, 2));
    });
  });

  group('relaxation keeps honest time', () {
    test('does not drift by the time spent backgrounded', () async {
      // This was the only one of the three timers in the feature with neither a
      // wall-clock anchor nor a lifecycle observer: it decremented a counter once
      // a second. Suspended in the background, the countdown stalled while the
      // audio played on, so the session overshot by however long you were away.
      final relax = RelaxationService();
      await withClock(Clock.fixed(t0), () async {
        relax.setDuration(15);
        // startSession() returns early with no track chosen.
        relax.setMusic(RelaxationMusicType.values.first);
        await relax.startSession();
      });
      expect(relax.remainingSeconds, 15 * 60);

      // Five minutes pass with no ticks delivered at all.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 5))),
          () async => relax.applyTick());

      expect(relax.remainingSeconds, closeTo(10 * 60, 2),
          reason: 'BEFORE THE FIX this was still 15:00 minus however many ticks '
              'happened to fire — the clock owed the user five minutes');
    });
  });
}
