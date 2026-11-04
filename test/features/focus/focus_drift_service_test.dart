/// Leaving the app mid-round, as the focus service sees it: the lifecycle changes
/// the OS delivers in, what is kept, what is offered and how it is forgotten.
///
/// Every case drives the real sequence — `inactive → hidden → paused` on the way
/// out, `resumed` on the way back — under a fixed clock, because the rules are
/// about WHEN: how far into the round, how long away, whether the round was still
/// running on return.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart' show FocusMode;
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_drift.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final focus = FocusService();
  final t0 = DateTime(2026, 3, 14, 13);

  Duration min(num m) => Duration(milliseconds: (m * 60000).round());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
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

  /// A [minutes]-minute round started at [at].
  Future<void> start({int minutes = 25, DateTime? at}) =>
      withClock(Clock.fixed(at ?? t0), () async {
        focus.setDuration(minutes);
        await focus.startSession();
      });

  void lifecycle(DateTime at, AppLifecycleState state) =>
      withClock(Clock.fixed(at), () => focus.didChangeAppLifecycleState(state));

  /// What the OS sends when the app goes away.
  void leave(DateTime at) {
    lifecycle(at, AppLifecycleState.inactive);
    lifecycle(at, AppLifecycleState.hidden);
    lifecycle(at, AppLifecycleState.paused);
  }

  /// And when it comes back.
  void back(DateTime at) {
    lifecycle(at, AppLifecycleState.inactive);
    lifecycle(at, AppLifecycleState.resumed);
  }

  /// A step away starting [from] after [t0] and lasting [away].
  void stepAway(Duration from, Duration away, {DateTime? origin}) {
    final base = origin ?? t0;
    leave(base.add(from));
    back(base.add(from).add(away));
  }

  group('what is noticed', () {
    test('leaving at minute 22 and coming back two minutes later is one', () async {
      await start();

      stepAway(min(22), min(2));

      final e = focus.driftEventsForTesting.single;
      expect(e.minute, 22);
      expect(e.plannedMinutes, 25);
      expect(e.at, t0.add(min(22)));
    });

    test('the three steps out are one departure — the first is the time', () async {
      await start();

      lifecycle(t0.add(min(21.8)), AppLifecycleState.hidden);
      lifecycle(t0.add(min(22.4)), AppLifecycleState.paused);
      back(t0.add(min(24)));

      final e = focus.driftEventsForTesting.single;
      expect(e.minute, 21, reason: 'when `hidden` came, not when `paused` did');
      expect(e.at, t0.add(min(21.8)));
    });

    test('coming back twice is one event, not two', () async {
      await start();
      stepAway(min(22), min(2));

      back(t0.add(min(23)));

      expect(focus.driftEventsForTesting, hasLength(1));
    });

    test('a second step away later in the round is a second event', () async {
      await start(minutes: 60);

      stepAway(min(15), min(2));
      stepAway(min(30), min(2));

      expect(focus.driftEventsForTesting.map((e) => e.minute), [15, 30]);
    });

    test('at the cap the oldest goes as the newest comes in', () async {
      await CleanStorageService.setAppPreference('focusDriftLog', [
        for (var i = 0; i < 200; i++)
          DriftEvent(at: t0.add(Duration(minutes: i)), minute: 15, plannedMinutes: 30)
              .toJson(),
      ]);
      focus.resetForTesting();
      await focus.init();
      expect(focus.driftEventCount, 200, reason: 'the premise');
      final later = t0.add(const Duration(hours: 10));
      await start(at: later);

      stepAway(min(22), min(2), origin: later);

      final kept = focus.driftEventsForTesting;
      expect(kept, hasLength(200));
      expect(kept.first.at, t0.add(const Duration(minutes: 1)));
      expect(kept.last.at, later.add(min(22)));
    });

    test('it is kept: written where a restart will find it', () async {
      await start();
      stepAway(min(22), min(2));

      final stored = CleanStorageService.getAppPreference('focusDriftLog');
      expect(stored, isA<List>());
      expect((stored as List).single, containsPair('minute', 22));
    });
  });

  group('what is not', () {
    test('the first ten minutes: start-and-switch, and the screen timeout', () async {
      await start();

      stepAway(min(1), min(2));
      stepAway(min(9.9), min(2));

      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('ten minutes in exactly is', () async {
      await start();
      stepAway(min(10), min(2));
      expect(focus.driftEventsForTesting, hasLength(1));
    });

    test('the last tenth of the round', () async {
      await start();

      stepAway(min(22.6), min(1));

      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('the round ended while they were away: a phone put down, not a drift',
        () async {
      await start();

      leave(t0.add(min(20)));
      back(t0.add(min(26)));

      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('a glance of a few seconds', () async {
      await start();
      stepAway(min(15), const Duration(seconds: 3));
      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('more than ten minutes away', () async {
      await start(minutes: 60);

      stepAway(min(15), min(11));

      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('while paused', () async {
      await start();
      withClock(Clock.fixed(t0.add(min(12))), focus.pauseSession);

      stepAway(min(14), min(2));

      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('with nothing running', () {
      stepAway(min(15), min(2));
      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('a count-up session: it has no end to come back before', () async {
      withClock(Clock.fixed(t0), () => focus.setMode(FocusMode.flow));
      await withClock(Clock.fixed(t0), focus.startSession);

      stepAway(min(22), min(2));

      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('a break between pomodoro rounds', () async {
      withClock(Clock.fixed(t0), () {
        focus.setMode(FocusMode.pomodoro);
        focus.setPomodoroConfig(workMinutes: 15, shortBreakMinutes: 20);
      });
      await withClock(Clock.fixed(t0), focus.startSession);
      // The work round ends; a twenty-minute break begins.
      final endOfWork = t0.add(min(15)).add(const Duration(seconds: 1));
      withClock(Clock.fixed(endOfWork), focus.applyTickFromClockForTesting);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!focus.isOnBreak && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(focus.isOnBreak, isTrue, reason: 'the premise');

      stepAway(min(12), min(2), origin: endOfWork);

      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('a pomodoro round counts from its own start, not the session\'s', () async {
      withClock(Clock.fixed(t0), () {
        focus.setMode(FocusMode.pomodoro);
        focus.setPomodoroConfig(workMinutes: 30, shortBreakMinutes: 5);
      });
      await withClock(Clock.fixed(t0), focus.startSession);

      stepAway(min(22), min(2));

      final e = focus.driftEventsForTesting.single;
      expect(e.minute, 22);
      expect(e.plannedMinutes, 30);
    });

    test('with noticing switched off', () async {
      await focus.setDriftNoticing(false);
      await start();

      stepAway(min(22), min(2));

      expect(focus.driftEventsForTesting, isEmpty);
    });
  });

  group('switching it off', () {
    test('forgets what was noticed, here and on disk', () async {
      await start();
      stepAway(min(22), min(2));
      expect(focus.driftEventCount, 1);

      await focus.setDriftNoticing(false);

      expect(focus.driftNoticing, isFalse);
      expect(focus.driftEventCount, 0);
      expect(CleanStorageService.getAppPreference('focusDriftLog'), isEmpty);
      expect(CleanStorageService.getAppPreference('focusDriftNoticing'), false);
    });

    test('and back on starts from nothing', () async {
      await start();
      stepAway(min(22), min(2));
      await focus.setDriftNoticing(false);

      await focus.setDriftNoticing(true);

      expect(focus.driftNoticing, isTrue);
      expect(focus.driftEventCount, 0);
    });

    test('a departure already begun when it was switched off is not recorded',
        () async {
      await start();
      leave(t0.add(min(22)));

      await focus.setDriftNoticing(false);
      await focus.setDriftNoticing(true);
      back(t0.add(min(24)));

      expect(focus.driftEventsForTesting, isEmpty);
    });
  });

  group('after a restart', () {
    Future<void> restart() async {
      focus.resetForTesting();
      await focus.init();
    }

    test('what was kept is read back', () async {
      await start();
      stepAway(min(22), min(2));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await restart();

      final e = focus.driftEventsForTesting.single;
      expect(e.minute, 22);
      expect(e.at, t0.add(min(22)));
    });

    test('off stays off', () async {
      await focus.setDriftNoticing(false);

      await restart();

      expect(focus.driftNoticing, isFalse);
    });

    test('off with the log still on disk: forgotten on the way in, as switching off does',
        () async {
      await _seedHabit(t0);
      await CleanStorageService.setAppPreference('focusDriftNoticing', false);
      await CleanStorageService.setAppPreference(
          'focusDriftDismissedAt', t0.millisecondsSinceEpoch);

      await restart();

      expect(focus.driftNoticing, isFalse);
      expect(focus.driftEventCount, 0);
      expect(CleanStorageService.getAppPreference('focusDriftLog'), isEmpty);
      expect(CleanStorageService.getAppPreference('focusDriftDismissedAt'), 0);
      expect(withClock(Clock.fixed(t0), () => focus.driftSuggestion), isNull);
    });

    test('a dismissal alone, with it off, is forgotten too', () async {
      await CleanStorageService.setAppPreference('focusDriftNoticing', false);
      await CleanStorageService.setAppPreference(
          'focusDriftDismissedAt', t0.millisecondsSinceEpoch);

      await restart();

      expect(CleanStorageService.getAppPreference('focusDriftDismissedAt'), 0);
    });

    test('entries that are damaged are dropped, the rest kept', () async {
      await CleanStorageService.setAppPreference('focusDriftLog', [
        'junk',
        42,
        {'at': 'yesterday', 'minute': 22, 'planned': 25},
        {'at': t0.millisecondsSinceEpoch, 'minute': 22, 'planned': 25},
        null,
      ]);

      await restart();

      expect(focus.driftEventsForTesting, hasLength(1));
    });

    test('a value that is not a list is nothing', () async {
      await CleanStorageService.setAppPreference('focusDriftLog', 'not a list');

      await restart();

      expect(focus.driftEventsForTesting, isEmpty);
    });

    test('only the newest two hundred are kept', () async {
      await CleanStorageService.setAppPreference('focusDriftLog', [
        for (var i = 0; i < 250; i++)
          DriftEvent(at: t0.add(Duration(minutes: i)), minute: 15, plannedMinutes: 30)
              .toJson(),
      ]);

      await restart();

      final kept = focus.driftEventsForTesting;
      expect(kept, hasLength(200));
      expect(kept.first.at, t0.add(const Duration(minutes: 50)));
      expect(kept.last.at, t0.add(const Duration(minutes: 249)));
    });

    test('the dismissal is remembered', () async {
      await _seedHabit(t0);
      await restart();
      expect(withClock(Clock.fixed(t0), () => focus.driftSuggestion), isNotNull);

      await withClock(Clock.fixed(t0), focus.dismissDriftSuggestion);
      await restart();

      expect(withClock(Clock.fixed(t0), () => focus.driftSuggestion), isNull);
    });

    test('every key it writes is one "Delete all data" removes', () async {
      await start();
      stepAway(min(22), min(2));
      await focus.setDriftNoticing(false);
      await withClock(Clock.fixed(t0), focus.dismissDriftSuggestion);

      final keys = CleanStorageService.getAppPreferences()
          .keys
          .where((k) => k.toLowerCase().contains('drift'));

      expect(keys, isNotEmpty);
      for (final k in keys) {
        expect(k.startsWith('focus'), isTrue,
            reason: '$k would survive the wipe, which removes `focus*` preferences');
      }
    });

    test('the wipe forgets them in memory too, or the next one brings them back',
        () async {
      await start();
      stepAway(min(22), min(2));
      expect(focus.driftEventCount, 1);

      focus.resetAfterWipe();

      expect(focus.driftEventCount, 0);
      expect(focus.driftNoticing, isTrue);
    });
  });

  group('the suggestion', () {
    DriftPattern? suggestion() =>
        withClock(Clock.fixed(t0), () => focus.driftSuggestion);

    setUp(() async {
      await _seedHabit(t0);
      focus.resetForTesting();
      await focus.init();
    });

    test('a habit of leaving at minute 22 offers a round that ends before it', () {
      final p = suggestion()!;
      expect(p.minute, 22);
      expect(p.suggestedWorkMinutes, 20);
      expect(p.suggestedBreakMinutes, 5);
    });

    test('not while a round is running', () async {
      await start();
      expect(suggestion(), isNull);
    });

    test('not when noticing is off', () async {
      await focus.setDriftNoticing(false);
      expect(suggestion(), isNull);
    });

    test('not when the single round chosen already ends before that', () {
      withClock(Clock.fixed(t0), () => focus.setDuration(20));
      expect(suggestion(), isNull);
      withClock(Clock.fixed(t0), () => focus.setDuration(15));
      expect(suggestion(), isNull);
      withClock(Clock.fixed(t0), () => focus.setDuration(25));
      expect(suggestion(), isNotNull);
    });

    test('not when the pomodoro round chosen already ends before that', () {
      withClock(Clock.fixed(t0), () {
        focus.setMode(FocusMode.pomodoro);
        focus.setPomodoroConfig(workMinutes: 20);
      });
      expect(suggestion(), isNull);
      withClock(Clock.fixed(t0), () => focus.setPomodoroConfig(workMinutes: 25));
      expect(suggestion(), isNotNull);
    });

    test('in flow mode there is no round chosen, so it is still offered', () {
      withClock(Clock.fixed(t0), () => focus.setMode(FocusMode.flow));
      expect(suggestion(), isNotNull);
    });

    test('it ages out as the days pass', () {
      // Forty days on, the five newest of the six are still inside the
      // forty-five-day window ...
      final later = t0.add(const Duration(days: 40));
      expect(withClock(Clock.fixed(later), () => focus.driftSuggestion), isNotNull);
      // ... and fifty days on, none of them are. Nothing about the events changed:
      // the answer must follow the date, not a stored result.
      final muchLater = t0.add(const Duration(days: 50));
      expect(withClock(Clock.fixed(muchLater), () => focus.driftSuggestion), isNull);
    });

    test('Not now: it goes, and stays gone', () async {
      expect(suggestion(), isNotNull, reason: 'seen first, so it has been remembered');
      await withClock(Clock.fixed(t0), focus.dismissDriftSuggestion);

      expect(suggestion(), isNull);
      // A day later, still nothing: the old departures are set aside.
      final tomorrow = t0.add(const Duration(days: 1));
      expect(withClock(Clock.fixed(tomorrow), () => focus.driftSuggestion), isNull);
    });

    test('a departure made after it was last looked at is not hidden by what was remembered',
        () async {
      // Four days of it: not a habit yet — and that answer has now been given once.
      await _seedHabit(t0, days: 4);
      focus.resetForTesting();
      await focus.init();
      expect(suggestion(), isNull, reason: 'the premise');
      final soon = t0.add(const Duration(hours: 1));
      await start(at: soon);

      stepAway(min(22), min(2), origin: soon);
      await withClock(Clock.fixed(soon.add(min(30))), focus.abandonSession);

      final later = soon.add(const Duration(hours: 1));
      expect(withClock(Clock.fixed(later), () => focus.driftSuggestion), isNotNull,
          reason: 'five days now');
    });

    test('it can come back — from departures made AFTER it was dismissed', () async {
      await withClock(Clock.fixed(t0), focus.dismissDriftSuggestion);
      expect(suggestion(), isNull, reason: 'the premise');

      // Five new days of it, each a real round.
      for (var d = 1; d <= 5; d++) {
        final day = DateTime(2026, 3, 14 + d, 10);
        await start(at: day);
        stepAway(min(22), min(2), origin: day);
        await withClock(Clock.fixed(day.add(min(30))), focus.abandonSession);
      }

      final after = DateTime(2026, 3, 20, 12);
      expect(withClock(Clock.fixed(after), () => focus.driftSuggestion), isNotNull);
    });

    test('four new days are not enough to bring it back', () async {
      await withClock(Clock.fixed(t0), focus.dismissDriftSuggestion);

      for (var d = 1; d <= 4; d++) {
        final day = DateTime(2026, 3, 14 + d, 10);
        await start(at: day);
        stepAway(min(22), min(2), origin: day);
        await withClock(Clock.fixed(day.add(min(30))), focus.abandonSession);
      }

      final after = DateTime(2026, 3, 20, 12);
      expect(withClock(Clock.fixed(after), () => focus.driftSuggestion), isNull);
    });
  });

  group('trying it', () {
    setUp(() async {
      await _seedHabit(t0);
      focus.resetForTesting();
      await focus.init();
    });

    Future<AppliedSuggestion<DriftPattern>?> apply() =>
        withClock(Clock.fixed(t0), focus.applyDriftSuggestion);

    test('sets a 20 + 5 pomodoro, and the card goes', () async {
      final applied = await apply();

      expect(applied, isNotNull);
      expect(applied!.suggestion.suggestedWorkMinutes, 20,
          reason: 'it says what it applied, not what the card was showing');
      expect(applied.suggestion.suggestedBreakMinutes, 5);
      expect(focus.mode, FocusMode.pomodoro);
      expect(focus.workMinutes, 20);
      expect(focus.shortBreakMinutes, 5);
      expect(withClock(Clock.fixed(t0), () => focus.driftSuggestion), isNull);
    });

    test('leaves the long break and the number of rounds as they were', () async {
      withClock(Clock.fixed(t0), () {
        focus.setPomodoroConfig(longBreakMinutes: 30, roundsBeforeLongBreak: 3, totalRounds: 6);
      });

      await apply();

      expect(focus.longBreakMinutes, 30);
      expect(focus.roundsBeforeLongBreak, 3);
      expect(focus.totalRounds, 6);
    });

    test('after trying it, raising the round again does not bring the card back',
        () async {
      await apply();

      withClock(Clock.fixed(t0), () => focus.setPomodoroConfig(workMinutes: 25));

      expect(withClock(Clock.fixed(t0), () => focus.driftSuggestion), isNull,
          reason: 'they have seen it and chosen');
    });

    test('Undo puts back the mode and both lengths, and the card returns', () async {
      withClock(Clock.fixed(t0), () {
        focus.setMode(FocusMode.single);
        focus.setPomodoroConfig(workMinutes: 45, shortBreakMinutes: 10);
      });
      final undo = (await apply())!.undo;
      expect(focus.mode, FocusMode.pomodoro);
      expect(withClock(Clock.fixed(t0), () => focus.driftSuggestion), isNull,
          reason: 'seen while dismissed, so that answer has been remembered');

      await withClock(Clock.fixed(t0), undo);

      expect(focus.mode, FocusMode.single);
      expect(focus.workMinutes, 45);
      expect(focus.shortBreakMinutes, 10);
      expect(withClock(Clock.fixed(t0), () => focus.driftSuggestion), isNotNull);
    });

    test('once it has been dismissed there is nothing to apply', () async {
      await withClock(Clock.fixed(t0), focus.dismissDriftSuggestion);

      expect(await apply(), isNull);
    });

    test('a suggestion that has gone still tells the screen, so the card that offered it goes',
        () async {
      await withClock(Clock.fixed(t0), focus.dismissDriftSuggestion);
      var notified = 0;
      void listener() => notified++;
      focus.addListener(listener);
      addTearDown(() => focus.removeListener(listener));

      expect(await apply(), isNull);

      expect(notified, greaterThan(0));
    });

    test('nothing to apply: nothing changes', () async {
      await focus.setDriftNoticing(false);
      final before = (focus.mode, focus.workMinutes, focus.shortBreakMinutes);

      expect(await apply(), isNull);

      expect((focus.mode, focus.workMinutes, focus.shortBreakMinutes), before);
    });

    test('while a round runs it does nothing', () async {
      await start();
      final before = (focus.mode, focus.workMinutes, focus.shortBreakMinutes);

      expect(await apply(), isNull);

      expect((focus.mode, focus.workMinutes, focus.shortBreakMinutes), before);
    });
  });
}

/// [days] days of leaving at minute 22 of a 25-minute round, the newest the day
/// before [now] — written the way a real run would leave them.
Future<void> _seedHabit(DateTime now, {int days = 6}) async {
  await CleanStorageService.setAppPreference('focusDriftLog', [
    for (var d = 1; d <= days; d++)
      DriftEvent(
        at: DateTime(now.year, now.month, now.day - d, 10, 0),
        minute: 22,
        plannedMinutes: 25,
      ).toJson(),
  ]);
}
