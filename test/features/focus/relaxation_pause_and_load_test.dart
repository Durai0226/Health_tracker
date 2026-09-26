import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// Pausing a relaxation track must stop its clock, and one bad byte on disk must
/// not delete the history.
///
/// **Pause did not pause.** `pauseSession` set `_isPaused` and paused the audio,
/// and that was all: the ticker kept running and `_endTime` never moved. Because
/// `applyTick` derives the countdown from that absolute end time, every paused
/// second was still charged to the user — pause a 15-minute session at the
/// 5-minute mark, take a 7-minute phone call, and it came back with three minutes
/// left instead of ten. Pause for longer than the session had left and it
/// completed the moment you returned, crediting fifteen minutes of relaxation
/// nobody listened to. `FocusService` had already solved this with
/// `_pauseStartTime`; this service was written from the same shape and missed it.
///
/// **And one enum index took the whole feature with it.** `_loadData` read both
/// persisted enums as raw ordinals inside a single `try`, so an index the running
/// build does not have — a downgrade, a renamed enum — threw before the stats and
/// the session list were ever reached. The user opens Relaxation and every minute
/// they ever logged is gone, while the data still sits on disk.
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
  /// `_completeSession` awaits the audio stop and a notification, so a fixed
  /// delay races it — and loses only when the whole directory runs.
  Future<void> waitUntil(bool Function() condition, {String? because}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue,
        reason: because ?? 'condition never became true within 5s');
  }

  Future<RelaxationService> started({int minutes = 15}) async {
    final relax = RelaxationService();
    await withClock(Clock.fixed(t0), () async {
      relax.setMusic(RelaxationMusicType.values.first);
      relax.setDuration(minutes);
      await relax.startSession();
    });
    return relax;
  }

  group('pausing a relaxation session stops its clock', () {
    test('a seven-minute pause costs the user nothing', () async {
      final relax = await started();

      // Five minutes in, pause.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 5))), () async {
        relax.applyTick();
        relax.pauseSession();
      });
      expect(relax.remainingSeconds, closeTo(10 * 60, 2));

      // Seven minutes on the phone, then resume.
      final resumedAt = t0.add(const Duration(minutes: 12));
      await withClock(Clock.fixed(resumedAt), () async => relax.resumeSession());
      await withClock(Clock.fixed(resumedAt.add(const Duration(seconds: 1))),
          () async => relax.applyTick());

      expect(relax.remainingSeconds, closeTo(10 * 60, 2),
          reason: 'BEFORE THE FIX `_endTime` never moved, so the countdown '
              'jumped ahead by the whole pause: 180s left instead of 600s');
      expect(relax.isRunning, isTrue);
      expect(relax.isPaused, isFalse);
    });

    test('resuming after a pause longer than the session does not complete it',
        () async {
      final relax = await started();

      await withClock(Clock.fixed(t0.add(const Duration(minutes: 5))), () async {
        relax.applyTick();
        relax.pauseSession();
      });

      // An hour paused: the original end time is long past in wall-clock terms.
      final resumedAt = t0.add(const Duration(hours: 1));
      await withClock(Clock.fixed(resumedAt), () async {
        relax.resumeSession();
        relax.applyTick();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(relax.isRunning, isTrue,
          reason: 'BEFORE THE FIX resuming completed the session on its very '
              'first tick, because `_endTime` was still the pre-pause instant — '
              'crediting fifteen minutes of relaxation the user never heard');
      expect(relax.sessions, isEmpty);
      expect(relax.stats.totalMinutes, 0);
      expect(relax.remainingSeconds, closeTo(10 * 60, 2));
    });

    test('the guard does not over-fire: an unpaused session still completes',
        () async {
      // The negative case. Pushing `_endTime` forward must depend on a pause
      // actually having happened — a session left alone has to finish on time.
      final relax = await started(minutes: 15);
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 15))),
          () async {
        relax.applyTick();
        await waitUntil(() => !relax.isRunning,
            because: 'a session nobody paused must finish on time');
      });

      expect(relax.isRunning, isFalse);
      expect(relax.sessions.single.wasCompleted, isTrue);
      expect(relax.stats.totalMinutes, 15);
    });
  });

  group('abandoning a relaxation session reports the time actually spent', () {
    test('30 seconds into a 15-minute track is 0 minutes, not 1', () async {
      final relax = await started();
      await withClock(Clock.fixed(t0.add(const Duration(seconds: 30))),
          () async {
        relax.applyTick();
        await relax.abandonSession();
      });

      expect(relax.sessions.single.actualMinutes, 0,
          reason: 'BEFORE THE FIX `_selectedMinutes - (_remainingSeconds ~/ 60)` '
              'rounded the subtraction UP, so half a minute was logged as a '
              'full minute of relaxation');
      expect(relax.sessions.single.wasAbandoned, isTrue);
    });

    test('and 90 seconds is 1 minute, not 2', () async {
      final relax = await started();
      await withClock(Clock.fixed(t0.add(const Duration(seconds: 90))),
          () async {
        relax.applyTick();
        await relax.abandonSession();
      });
      expect(relax.sessions.single.actualMinutes, 1);
    });
  });

  group('a bad persisted enum index costs one field, not the history', () {
    test('an out-of-range category leaves the sessions and stats intact',
        () async {
      // What a downgrade looks like on disk: an ordinal this build does not have.
      await CleanStorageService.setAppPreference(
          'relaxationSelectedCategory', 999);
      await CleanStorageService.setAppPreference('relaxationSelectedMusic', 999);
      await CleanStorageService.setAppPreference('relaxationStats', {
        'totalMinutes': 120,
        'totalSessions': 8,
        'completedSessions': 7,
        'abandonedSessions': 1,
      });
      await CleanStorageService.setAppPreference('relaxationSessions', [
        {
          'id': 'a',
          'startedAt': t0.toIso8601String(),
          'completedAt': t0.add(const Duration(minutes: 15)).toIso8601String(),
          'targetMinutes': 15,
          'actualMinutes': 15,
          'wasCompleted': true,
          'wasAbandoned': false,
          'musicType': 0,
          'category': 0,
        },
      ]);

      final relax = RelaxationService();
      await withClock(Clock.fixed(t0), () async => relax.init());

      expect(relax.stats.totalMinutes, 120,
          reason: 'BEFORE THE FIX `RelaxationCategory.values[999]` threw on the '
              'second line of _loadData, so the stats and the whole session '
              'history were never read and the feature looked empty');
      expect(relax.sessions.length, 1);
      expect(relax.sessions.single.id, 'a');
      // The one field that genuinely cannot be recovered falls back rather than
      // taking anything with it.
      expect(relax.selectedCategory, RelaxationCategory.deepFocus);
      expect(relax.selectedMusic, isNull,
          reason: 'no track is a real state; substituting the first one would '
              'put a track the user never chose under the play button');
    });

    test('one unreadable session row does not delete the others', () async {
      await CleanStorageService.setAppPreference('relaxationSessions', [
        {
          'id': 'good',
          'startedAt': t0.toIso8601String(),
          'targetMinutes': 15,
          'actualMinutes': 15,
          'wasCompleted': true,
          'wasAbandoned': false,
          'musicType': 0,
          'category': 0,
        },
        // A truncated write: no `startedAt` for DateTime.parse to read.
        {'id': 'broken', 'targetMinutes': 15},
      ]);

      final relax = RelaxationService();
      await withClock(Clock.fixed(t0), () async => relax.init());

      expect(relax.sessions.map((s) => s.id), ['good']);
    });

    test('the guard does not over-fire: valid values are still honoured',
        () async {
      await CleanStorageService.setAppPreference('relaxationSelectedCategory',
          RelaxationCategory.values.last.index);
      await CleanStorageService.setAppPreference('relaxationSelectedMusic',
          RelaxationMusicType.values.last.index);
      await CleanStorageService.setAppPreference('relaxationSelectedMinutes', 30);

      final relax = RelaxationService();
      await withClock(Clock.fixed(t0), () async => relax.init());

      expect(relax.selectedCategory, RelaxationCategory.values.last);
      expect(relax.selectedMusic, RelaxationMusicType.values.last);
      expect(relax.selectedMinutes, 30);
    });
  });
}
