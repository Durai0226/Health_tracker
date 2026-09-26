import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_coins.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// One session may only ever be banked once.
///
/// `stopFlowSession`, `_completeSession` and `abandonSession` all checked
/// `_isRunning` on entry — but `_isRunning` is not cleared until `_resetSession`,
/// which runs AFTER the notification disarm, the audio stop, the session write,
/// the tag write and the coin award. Anything arriving inside that window passed
/// the guard and ran the whole payout a second time, and `AppButton` has no
/// debounce, so a double-tap on **Done** in flow mode banked two sessions, two
/// plants and 80 coins for one twenty-minute stretch — permanently skewing
/// `totalMinutes`, `totalSessions` and the median-length suggestion that flow
/// mode exists to feed.
///
/// The same window let **Give Up**, pressed in the final second, run alongside
/// the timer's own completion: one session recorded twice, once completed and
/// once abandoned, or a crash on `_startTime!` if the reset landed first.
///
/// `RelaxationService` has the identical shape, reached instead through
/// `_syncTimer()` on every lifecycle resume.
void main() {

  /// Wait for [condition] instead of guessing a duration.
  ///
  /// The completion path is kicked by an unawaited timer callback, so a fixed
  /// `Future.delayed(50ms)` is a race: it passed on a warm machine and failed
  /// on a loaded one (observed twice, in two different tests of this file). The
  /// sibling suites already use this poller for exactly that reason.
  Future<void> waitUntil(bool Function() condition, {String? because}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue,
        reason: because ?? 'condition never became true within 5s');
  }
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

  group('flow mode: a double-tap on Done', () {
    test('banks one session, one plant and one coin award', () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.flow);
        await focus.startSession();
      });

      // Both taps land inside the payout window: the second is issued before the
      // first has finished awaiting, which is exactly what an undebounced button
      // produces on a real device.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 20))),
          () async {
        final first = focus.stopFlowSession();
        final second = focus.stopFlowSession();
        await Future.wait([first, second]);
      });

      expect(focus.sessions.length, 1,
          reason: 'BEFORE THE FIX both taps passed the `_isRunning` check and '
              'wrote a session each, doubling totalMinutes and totalSessions');
      expect(focus.stats.totalSessions, 1);
      expect(focus.stats.completedSessions, 1);
      expect(focus.stats.totalMinutes, 20);
      expect(focus.garden.where((p) => p.isAlive).length, 1,
          reason: 'one session grows one plant');
      // Counted as transactions rather than as a balance, because achievement
      // and streak bonuses also land in the balance and would mask a duplicate.
      final earned = CoinsService()
          .transactions
          .where((t) => t.type == CoinTransactionType.earned)
          .toList();
      expect(earned.length, 1,
          reason: 'BEFORE THE FIX the session was paid out twice — 80 coins for '
              'twenty minutes, which is twice what any honest session earns');
      expect(earned.single.amount, 40,
          reason: 'two coins a minute for twenty minutes');
    });
  });

  group('Give Up in the final second', () {
    test('does not file an abandoned record alongside the completed one',
        () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });

      await withClock(Clock.fixed(t0.add(const Duration(seconds: 60))),
          () async {
        // The ticker reaches zero and starts the completion; the user's thumb was
        // already on Give Up.
        focus.applyTickFromClockForTesting();
        await focus.abandonSession();
        // Wait for the payout to land, not for a guessed 50 ms.
        await waitUntil(() => focus.sessions.isNotEmpty && !focus.isRunning,
            because: 'the completion never finished its awaits');
      });

      expect(focus.sessions.length, 1,
          reason: 'BEFORE THE FIX the timer-driven completion and the abandon '
              'both ran, so one minute of focus was recorded twice — once as a '
              'success and once as a failure');
      expect(focus.sessions.single.wasCompleted, isTrue,
          reason: 'the timer got there first, so the session is a completion');
      expect(focus.stats.abandonedSessions, 0);
      expect(focus.garden.where((p) => !p.isAlive), isEmpty,
          reason: 'a session that ran its full length must not also wither');
    });

    test('the guard does not over-fire: a genuine Give Up still abandons',
        () async {
      // The negative case for the guard itself. `_finishing` must be cleared on
      // every exit, or the FIRST abandon after any completion would be refused
      // and Give Up would become the dead button instead.
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 10))),
          () async {
        focus.applyTickFromClockForTesting();
        await focus.abandonSession();
      });

      expect(focus.sessions.single.wasAbandoned, isTrue);
      expect(focus.sessions.single.actualMinutes, 10);

      // And a second, separate session must still be completable afterwards.
      final t1 = t0.add(const Duration(hours: 2));
      await withClock(Clock.fixed(t1), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t1.add(const Duration(seconds: 60))),
          () async {
        focus.applyTickFromClockForTesting();
        await waitUntil(() => focus.sessions.length >= 2,
            because: 'the second session never completed');
      });

      expect(focus.sessions.length, 2,
          reason: 'the guard is per-payout, not permanent');
      expect(focus.sessions.first.wasCompleted, isTrue);
    });
  });

  group('relaxation: an elapsed session on lifecycle resume', () {
    test('is recorded once even if resume fires twice', () async {
      final relax = RelaxationService();
      await withClock(Clock.fixed(t0), () async {
        relax.setMusic(RelaxationMusicType.values.first);
        relax.setDuration(15);
        await relax.startSession();
      });

      // Back long after the end. Two resumes arriving back to back is what a
      // duplicated lifecycle observer produced, and the second used to run the
      // whole completion again while the first was still awaiting storage.
      await withClock(Clock.fixed(t0.add(const Duration(hours: 1))), () async {
        relax.applyTick();
        relax.applyTick();
        await waitUntil(() => relax.sessions.isNotEmpty,
            because: 'the relaxation completion never landed');
      });

      expect(relax.sessions.length, 1,
          reason: 'BEFORE THE FIX `_isRunning` was still true during the '
              'completion awaits, so a second resume credited the fifteen '
              'minutes twice');
      expect(relax.stats.totalMinutes, 15);
      expect(relax.stats.completedSessions, 1);
    });

    test('the guard does not over-fire: a later session still completes',
        () async {
      final relax = RelaxationService();
      await withClock(Clock.fixed(t0), () async {
        relax.setMusic(RelaxationMusicType.values.first);
        relax.setDuration(15);
        await relax.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 15))),
          () async {
        relax.applyTick();
        await waitUntil(() => relax.sessions.isNotEmpty,
            because: 'the first relaxation session never completed');
      });

      final t1 = t0.add(const Duration(hours: 2));
      await withClock(Clock.fixed(t1), () async {
        relax.setDuration(10);
        await relax.startSession();
      });
      await withClock(Clock.fixed(t1.add(const Duration(minutes: 10))),
          () async {
        relax.applyTick();
        await waitUntil(() => relax.sessions.length >= 2,
            because: 'the second relaxation session never completed');
      });

      expect(relax.sessions.length, 2);
      expect(relax.stats.totalMinutes, 25);
    });
  });
}
