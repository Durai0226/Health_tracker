import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';
import 'package:tablet_remainder/features/focus/models/focus_coins.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding;
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// The negative matrix: what happens when things go wrong.
///
/// Every case here is one the feature could actually hit and had no coverage for.
/// A few are deliberately *not* here, because pretending to test them would be
/// worse than admitting they need hardware:
///
///  * **device muted / volume at zero** — an OS state the player does not report.
///    The honest proxy (volume 0 keeps the session running) is asserted; the rest
///    belongs on a manual checklist.
///  * **a real phone-call interruption** — an emulator cannot take a call. The
///    state-machine contract is covered in `test/core/audio_service_test.dart`
///    via an externally-driven pause; the physical event is manual.
///  * **`am force-stop` mid-session** — killing the process under a test harness
///    kills the harness. The persistence *contract* is covered in
///    `focus_timer_integrity_test.dart`; the real kill is a device step.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeAudioEngine engine;

  final t0 = DateTime(2026, 3, 14, 13, 0, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    engine = FakeAudioEngine();
    AudioService().engineForTesting = engine;
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    RelaxationService().resetForTesting();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    await db.close();
  });

  Future<void> waitUntil(bool Function() c, {String? because}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!c() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(c(), isTrue, reason: because ?? 'never became true');
  }

  group('offline / dead audio', () {
    test('a session runs to completion with no sound available', () async {
      // The single most important negative: audio is a nice-to-have, the timer is
      // the product. `startSession` AWAITS `playSound`, so an engine that threw
      // outside its try/catch would abort the session start entirely.
      engine.throwOn.add('setAsset');

      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setSound(AmbientSoundType.rain);
        focus.setDuration(1);
        await focus.startSession();
      });

      expect(focus.isRunning, isTrue,
          reason: 'a dead audio source must never stop the user focusing');
      expect(AudioService().isPlaying, isFalse);

      await withClock(Clock.fixed(t0.add(const Duration(seconds: 60))),
          () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => !focus.isRunning);
      });
      expect(focus.sessions.single.wasCompleted, isTrue,
          reason: 'the session is still credited — silence is not failure');
    });
  });

  group('rapid taps', () {
    test('five Start taps in one frame produce one session', () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await Future.wait([
          focus.startSession(),
          focus.startSession(),
          focus.startSession(),
          focus.startSession(),
          focus.startSession(),
        ]);
      });

      expect(focus.isRunning, isTrue);
      expect(engine.loadCalls, lessThanOrEqualTo(1),
          reason: 'a second start must not re-load audio over a live session');

      await withClock(Clock.fixed(t0.add(const Duration(minutes: 25))),
          () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => !focus.isRunning);
      });
      expect(focus.sessions, hasLength(1),
          reason: 'five taps, one session — `if (_isRunning) return` has to hold '
              'even when the taps land inside one frame');
    });

    test('ten pause/resume toggles do not inflate the session', () async {
      // `resumeSession` pushes `_endTime` forward by the pause duration. Ten fast
      // toggles must not add ten pauses worth of time to a session that was never
      // actually paused for any measurable period.
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
        for (var i = 0; i < 10; i++) {
          focus.pauseSession();
          focus.resumeSession();
        }
        focus.applyTickFromClockForTesting();
      });

      expect(focus.remainingSeconds, closeTo(25 * 60, 2),
          reason: 'no wall-clock time passed, so nothing should have been added');
      expect(focus.isPaused, isFalse, reason: 'ends resumed, not paused');
    });
  });

  group('config changes mid-session', () {
    test('the settings that would corrupt a running session are locked',
        () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        focus.setPlant(PlantType.sprout);
        focus.setActivity(FocusActivityType.work);
        await focus.startSession();

        focus.setDuration(90);
        focus.setPlant(PlantType.seedling);
        focus.setActivity(FocusActivityType.reading);
        focus.setMode(FocusMode.pomodoro);
      });

      expect(focus.selectedMinutes, 25, reason: 'the running length is fixed');
      expect(focus.selectedPlant, PlantType.sprout,
          reason: 'sprout is unlocked from the start; setPlant also '
              'requires the plant to be unlocked, which is why this '
              'test cannot use tree');
      expect(focus.selectedActivity, FocusActivityType.work);
      expect(focus.mode, FocusMode.single);
    });

    test('sound and volume ARE changeable mid-session, deliberately', () async {
      // Asserted on purpose so nobody "fixes" the asymmetry: swapping the ambient
      // sound or nudging the volume while focusing is a legitimate thing to want,
      // and neither can corrupt the session record.
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
        focus.setSound(AmbientSoundType.ocean);
        focus.setSoundVolume(0.3);
      });

      expect(focus.selectedSound, AmbientSoundType.ocean);
      expect(focus.soundVolume, closeTo(0.3, 1e-9));
      expect(focus.isRunning, isTrue, reason: 'the session is undisturbed');
    });

    test('volume 0 is silence, not a stopped session', () async {
      // The honest proxy for "device muted", which the player does not report.
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
        focus.setSoundVolume(0);
      });
      expect(focus.soundVolume, 0);
      expect(focus.isRunning, isTrue);
    });
  });

  group('coins', () {
    test('an unaffordable redemption changes nothing at all', () async {
      final coins = CoinsService();
      await coins.earnCoins(minutes: 10, sessionId: 's1'); // 20 coins
      final before = coins.totalCoins;

      final ok = await coins.redeemGardenTree(RealTreeType.oak); // costs 500

      expect(ok, isFalse);
      expect(coins.totalCoins, before, reason: 'no partial debit');
      expect(coins.plantedTrees, isEmpty, reason: 'and no partial record');
    });

    test('exactly enough coins is enough', () async {
      // Boundary: `<` vs `<=` here is the difference between honouring and
      // refusing a redemption the user has exactly saved for.
      final coins = CoinsService();
      const cost = 200; // bamboo
      await coins.earnCoins(minutes: cost ~/ 2, sessionId: 's1');
      expect(coins.totalCoins, cost, reason: 'sanity: exactly the cost');

      expect(coins.canAfford(RealTreeType.bamboo), isTrue);
      expect(await coins.redeemGardenTree(RealTreeType.bamboo), isTrue);
      expect(coins.totalCoins, 0);
      expect(coins.plantedTrees, hasLength(1));
    });
  });

  group('tags', () {
    test('a default tag cannot be deleted', () async {
      final tags = TagService();
      await tags.init();
      final defaults = tags.tags.where((t) => t.isDefault).toList();
      expect(defaults, isNotEmpty, reason: 'sanity: there are default tags');

      await tags.deleteTag(defaults.first.id);

      expect(tags.tags.any((t) => t.id == defaults.first.id), isTrue,
          reason: 'deleteTag guards on !isDefault — the UI must not offer it '
              'either, or the user taps and nothing happens');
    });
  });

  group('corrupt persisted state', () {
    test('a garbage value does not wipe the rest of the feature', () async {
      // `_loadData` parses twenty keys inside ONE try/catch, so anything that
      // throws part-way silently discards everything after it. This is the shape
      // of "the user opens Focus and all their history is gone".
      await CleanStorageService.setAppPreference('focusSelectedPlant', 999);
      await CleanStorageService.setAppPreference('focusSelectedSound', -3);
      await CleanStorageService.setAppPreference('focusSelectedMinutes', 0);
      await CleanStorageService.setAppPreference('focusSessions', 'not-a-list');
      await CleanStorageService.setAppPreference('focusStats', 'not-a-map');

      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        await expectLater(focus.init(), completes,
            reason: 'a corrupt preference must not throw out of init');
      });

      expect(focus.selectedPlant, PlantType.seedling,
          reason: 'an unknown ordinal falls back rather than exploding');
      expect(focus.selectedSound, AmbientSoundType.none);
      expect(focus.selectedMinutes, greaterThanOrEqualTo(kMinSessionMinutes),
          reason: 'a persisted 0 would make progress divide by zero');
      expect(focus.achievements, isNotEmpty,
          reason: 'achievements are initialised even when earlier keys were bad '
              '— that is the whole point of not aborting the load');
    });
  });

  group('history cap', () {
    test('the 100-session cap does not shrink the longest streak', () async {
      // `_saveData` trims to the last 100 sessions, and the streak is derived
      // FROM that list — so a user with a 30-day record could silently lose it.
      // `_checkAndUpdateStreak` keeps a max() floor precisely to stop that, and
      // that floor deserves a test.
      final sessions = <Map<String, dynamic>>[];
      for (var i = 0; i < 150; i++) {
        sessions.add(FocusSession(
          id: 'old-$i',
          startedAt: t0.subtract(Duration(days: 150 - i)),
          completedAt: t0.subtract(Duration(days: 150 - i)),
          targetMinutes: 25,
          actualMinutes: 25,
          wasCompleted: true,
          activityType: FocusActivityType.work,
          plantType: PlantType.tree,
        ).toJson());
      }
      await CleanStorageService.setAppPreference('focusSessions', sessions);
      await CleanStorageService.setAppPreference(
          'focusStats', const FocusStats(longestStreak: 30).toJson());

      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async => focus.init());

      expect(focus.sessions.length, lessThanOrEqualTo(150));
      expect(focus.stats.longestStreak, greaterThanOrEqualTo(30),
          reason: 'trimming history must never reduce a record the user earned');
    });
  });

  group('abandoning during a pomodoro break', () {
    test('records nothing, because a break grows no plant', () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.pomodoro);
        focus.setPomodoroConfig(workMinutes: 1, shortBreakMinutes: 1);
        await focus.startSession();
        // Finish the work interval so the break starts.
        focus.applyTick(0);
        await waitUntil(() => focus.isOnBreak,
            because: 'the work interval should hand over to a break');
      });

      final sessionsAfterWork = focus.sessions.length;
      final abandonedBefore = focus.stats.abandonedSessions;

      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1))),
          () async => focus.abandonSession());

      expect(focus.sessions.length, sessionsAfterWork,
          reason: 'a break is not a session, so quitting one records nothing');
      expect(focus.stats.abandonedSessions, abandonedBefore,
          reason: 'and it must not count against the user as an abandonment');
      expect(focus.isRunning, isFalse);
    });
  });

  group('a singleton registers ONE lifecycle observer', () {
    test('RelaxationService.init() is idempotent', () async {
      // A real regression, found by audit and confirmed live. `RelaxationScreen`
      // calls `init()` from initState, and RelaxationService is a process-wide
      // singleton, so every mount added ANOTHER `WidgetsBinding` observer to the
      // same object — with no `removeObserver` anywhere. Open the screen three
      // times and one app-resume fired `didChangeAppLifecycleState` three times,
      // ran `_syncTimer()` three times, and completed one elapsed session three
      // times over: triple coins, triple stats, triple notification.
      //
      // `FocusService` has had the guard since it was written. This asserts the
      // observable consequence rather than the private flag: N resumes must credit
      // ONE session, however many times init() was called.
      final relax = RelaxationService();
      await relax.init();
      await relax.init();
      await relax.init();

      final before = relax.sessions.length;

      await withClock(Clock.fixed(t0), () async {
        relax.setMusic(RelaxationMusicType.values.first);
        relax.setDuration(1);
        await relax.startSession();
      });
      expect(relax.isRunning, isTrue, reason: 'sanity: the session started');

      // Resume with the session already elapsed, THROUGH THE BINDING.
      //
      // Calling `relax.didChangeAppLifecycleState(...)` directly — which is what
      // the first version of this test did — invokes the callback exactly once by
      // construction and so cannot observe the defect at all: it bypasses the
      // observer LIST, which is the only place a duplicate registration exists.
      // Verified by mutation: with the `_didInit` guard deleted, the direct-call
      // version still passed.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 2))), () async {
        // ignore: invalid_use_of_protected_member
        WidgetsBinding.instance
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await waitUntil(() => !relax.isRunning,
            because: 'the elapsed session should complete on resume');
      });

      expect(relax.sessions.length, before + 1,
          reason: 'three init() calls must still mean one recorded session');
    });
  });

  group('a completion is never announced to nobody', () {
    test('with no screen listening, the in-app channel is NOT used', () async {
      // The regression this exists for: `FocusScreen` is the only consumer of
      // `justCompleted`, and it is a PUSHED ROUTE (`app_shell.dart:190-194`), not
      // one of the four live IndexedStack tabs. Start a session, press back, and
      // the listener is disposed — so the app was foregrounded, the notifier was
      // set, nothing read it, and the user was never told the session finished.
      // Before the in-app celebration existed they got a notification.
      //
      // Asserted through the observable consequence: with no consumer the service
      // must NOT publish in-app (it takes the notification branch instead), and
      // the session must still be credited either way.
      final focus = FocusService();
      expect(focus.justCompleted.hasConsumer, isFalse,
          reason: 'sanity: nothing is listening in this test');

      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1))), () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => !focus.isRunning);
      });

      expect(focus.sessions.single.wasCompleted, isTrue,
          reason: 'the session is credited regardless of how it was announced');
      expect(focus.justCompleted.value, isNull,
          reason: 'publishing to a notifier with no listener drops the '
              'celebration on the floor; the notification branch must be taken '
              'instead');
    });

    test('with a screen listening, the in-app channel IS used', () async {
      // The negative control. Without this, the fix above could be satisfied by
      // never publishing in-app at all.
      final focus = FocusService();
      var fires = 0;
      void onFire() => fires++;
      focus.justCompleted.addListener(onFire);
      addTearDown(() => focus.justCompleted.removeListener(onFire));

      expect(focus.justCompleted.hasConsumer, isTrue);

      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1))), () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => !focus.isRunning);
      });

      expect(focus.justCompleted.value, isNotNull);
      expect(fires, greaterThan(0));
    });
  });

  group('the celebration fires once per session, not once per round', () {
    test('a 2-round pomodoro celebrates once', () async {
      // `_completeSession` runs at the end of EVERY work interval in pomodoro
      // mode, and it is what publishes `justCompleted` — which the Focus screen
      // turns into "🎉 Session Complete!" with achievement styling, particles, a
      // haptic and a streak-milestone check.
      //
      // So a 4-round pomodoro celebrated four times and told the user the session
      // was complete three times while it was not. The break starting is its own
      // visible signal (the phase pill, the ring recolouring to the break tone);
      // it does not need a party.
      final focus = FocusService();
      var fires = 0;
      void onFire() {
        if (focus.justCompleted.value != null) fires++;
      }

      focus.justCompleted.addListener(onFire);
      addTearDown(() => focus.justCompleted.removeListener(onFire));

      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.pomodoro);
        focus.setPomodoroConfig(
            workMinutes: 1, shortBreakMinutes: 1, totalRounds: 2);
        await focus.startSession();
      });
      expect(focus.isRunning, isTrue, reason: 'sanity: the pomodoro started');

      // Round 1 work ends -> a break begins. No celebration is due yet.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1))), () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => focus.isOnBreak,
            because: 'work round 1 should hand over to a break');
      });
      expect(fires, 0,
          reason: 'round 1 of 2 finishing is not the session completing, and '
              'saying so is worse than saying nothing');

      // Break ends -> round 2 work begins.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 2))), () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => !focus.isOnBreak && focus.isRunning,
            because: 'the break should hand back to work');
      });

      // Round 2 work ends -> the whole pomodoro is done.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 3))), () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => !focus.isRunning,
            because: 'the final round should end the session');
      });

      expect(fires, 1,
          reason: 'exactly one celebration, at the end — not one per round');
      expect(focus.sessions.length, 2,
          reason: 'both work rounds are still CREDITED as sessions; this is '
              'about how loudly completion is announced, not about accounting');
    });

    test('a single-mode session still celebrates exactly once', () async {
      // The negative control for the test above: if the fix suppressed the
      // celebration too broadly, this is what would catch it.
      final focus = FocusService();
      var fires = 0;
      void onFire() {
        if (focus.justCompleted.value != null) fires++;
      }

      focus.justCompleted.addListener(onFire);
      addTearDown(() => focus.justCompleted.removeListener(onFire));

      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1))), () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => !focus.isRunning);
      });

      expect(fires, 1);
      expect(focus.justCompleted.value, isNotNull,
          reason: 'and it must still be readable by a screen that mounts after');
    });
  });
}
