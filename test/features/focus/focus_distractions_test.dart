import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/detailed_stats.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// The distraction tally and the session review — accountability with no
/// permissions.
///
/// The "Distractions" list has always been an honest note-to-self;
/// `AppAllowList.isAppAllowed` was deleted precisely because it enforced nothing.
/// This is what that list can DO without monitoring anything: the user says what
/// pulled them away, and the act of saying it is the intervention.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final focus = FocusService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    await focus.init();
  });

  tearDown(() async {
    focus.resetForTesting();
    await db.close();
  });

  Future<void> waitUntil(bool Function() condition, {String? because}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: because ?? 'never became true');
  }

  final t0 = DateTime(2026, 3, 15, 10, 0);

  group('logging a distraction', () {
    test('is ignored when nothing is running', () {
      focus.logDistraction('instagram');
      expect(focus.pendingDistractions, isEmpty,
          reason: 'a tally has to belong to a session');
    });

    test('records how far into the session it happened', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 3))), () {
        focus.logDistraction('instagram');
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 11))), () {
        focus.logDistraction('instagram');
      });

      expect(focus.pendingDistractions.map((d) => d.atSecond), [180, 660],
          reason: 'seconds elapsed, not wall clock — comparable across sessions '
              'of different lengths and times of day');
    });

    test('lands on an ABANDONED session record', () async {
      // The most valuable case: what won, on the sessions that were lost.
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 4))), () async {
        focus.logDistraction('twitter');
        await focus.abandonSession();
      });

      final s = focus.sessions.single;
      expect(s.wasAbandoned, isTrue);
      expect(s.distractions.single.appId, 'twitter');
      expect(s.distractions.single.atSecond, 240);
    });

    test('lands on a COMPLETED session record too', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(seconds: 20))), () {
        focus.logDistraction('news');
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1, seconds: 1))),
          () {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => !focus.isRunning);
      expect(focus.sessions.single.distractions.single.appId, 'news',
          reason: 'being pulled at and still finishing is worth recording');
    });

    test('does not carry into the next session', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 2))), () async {
        focus.logDistraction('instagram');
        await focus.abandonSession();
      });
      expect(focus.pendingDistractions, isEmpty);
    });

    test('survives a round trip through storage', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 2))), () async {
        focus.logDistraction('instagram');
        await focus.abandonSession();
      });

      final exported = focus.exportSessionsJson();
      focus.resetForTesting();
      await focus.importSessionsJson(exported);
      expect(focus.sessions.single.distractions.single.appId, 'instagram');
    });
  });

  group('records written before these fields existed still load', () {
    test('a session with no quality and no distractions', () {
      // The pattern `tagIds` already established. One old record must not take
      // the whole history down with it.
      final legacy = FocusSession.fromJson({
        'id': 'old',
        'startedAt': t0.toIso8601String(),
        'targetMinutes': 25,
        'actualMinutes': 25,
        'wasCompleted': true,
        'activityType': 0,
        'plantType': 0,
      });
      expect(legacy.quality, isNull);
      expect(legacy.distractions, isEmpty);
    });

    test('a garbage distractions value does not throw', () {
      final broken = FocusSession.fromJson({
        'id': 'x',
        'startedAt': t0.toIso8601String(),
        'targetMinutes': 25,
        'activityType': 0,
        'plantType': 0,
        'distractions': 'not a list',
        'quality': 'not an int',
      });
      expect(broken.distractions, isEmpty);
      expect(broken.quality, isNull);
    });
  });

  group('the session review', () {
    test('attaches to the most recent session', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1, seconds: 1))),
          () {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => focus.sessions.isNotEmpty);

      await focus.setLastSessionQuality(2);
      expect(focus.sessions.single.quality, 2);
    });

    test('is clamped, and lower is better', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1, seconds: 1))),
          () {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => focus.sessions.isNotEmpty);

      await focus.setLastSessionQuality(99);
      expect(focus.sessions.single.quality, 2,
          reason: '0 = went well … 2 = struggled, the same direction as the mood '
              'index the correlation engine is written against');
    });

    test('does nothing when there is no session to rate', () async {
      await focus.setLastSessionQuality(0);
      expect(focus.sessions, isEmpty);
    });
  });

  group('the tally is summarised, never scored', () {
    FocusSession session(String id, List<int> seconds, String appId) =>
        FocusSession(
          id: id,
          startedAt: t0,
          targetMinutes: 25,
          activityType: FocusActivityType.work,
          plantType: PlantType.seedling,
          distractions: [
            for (final s in seconds) DistractionTap(appId: appId, atSecond: s)
          ],
        );

    test('counts taps and the sessions they happened in', () {
      final out = DistractionSummary.summarise([
        session('a', [60, 120], 'instagram'),
        session('b', [30], 'instagram'),
        session('c', [90], 'twitter'),
      ]);
      expect(out.first.appId, 'instagram', reason: 'ranked by taps');
      expect(out.first.taps, 3);
      expect(out.first.sessions, 2,
          reason: 'two taps in one session is one session, not two');
      expect(out.last.appId, 'twitter');
    });

    test('uses the median position, so one late tap does not move it', () {
      final out = DistractionSummary.summarise([
        session('a', [60, 120, 180, 5400], 'instagram'),
      ]);
      expect(out.single.medianSecond, 150);
      expect(out.single.whenLabel, contains('first 10 minutes'));
    });

    test('describes when in buckets, not to the second', () {
      // A handful of self-reported taps does not support "at 7m 12s", and quoting
      // it would imply precision the data has not got.
      expect(
          DistractionSummary.summarise([session('a', [1200], 'x')])
              .single
              .whenLabel,
          contains('10–30 minutes'));
      expect(
          DistractionSummary.summarise([session('a', [3600], 'x')])
              .single
              .whenLabel,
          contains('later'));
    });

    test('is empty when nothing was ever logged', () {
      expect(DistractionSummary.summarise([session('a', const [], 'x')]),
          isEmpty);
      expect(DistractionSummary.summarise(const []), isEmpty);
    });

    test('exposes no ratio, rate or score of any kind', () {
      // Taps ÷ minutes would turn a self-awareness tool into a thing you can be
      // bad at, and would punish the honest logger: the user who taps every time
      // would look worse than the one who never opens the screen.
      final s = DistractionSummary.summarise([session('a', [60], 'x')]).single;
      expect(s.taps, isA<int>());
      expect(s.sessions, isA<int>());
      expect(s.medianSecond, isA<int>());
    });
  });
}
