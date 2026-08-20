import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_coins.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// Flow mode — the count-up timer.
///
/// The right fit for this app because the completion model here is already "you
/// decide when it is over": `abandonSession` is literally a Give Up button and
/// the crash-recovery path refuses to guess intent. Flow mode is that stance
/// expressed as a timer rather than as an escape hatch.
///
/// The property worth protecting most is at the bottom: a flow session's
/// `actualMinutes` IS a completed length, so it feeds the median that single mode
/// offers back as "your usual". Flow mode teaches the app the length you
/// naturally stop at.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final focus = FocusService();
  final coins = CoinsService();
  final t0 = DateTime(2026, 3, 15, 10, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
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

  Future<void> startFlow([DateTime? at]) =>
      withClock(Clock.fixed(at ?? t0), () async {
        focus.setMode(FocusMode.flow);
        await focus.startSession();
      });

  group('the enum is append-only', () {
    test('single and pomodoro keep their ordinals', () {
      // The mode is persisted by `.index`, in `focusMode` AND inside the
      // `focusActiveSession` crash-recovery snapshot. Inserting a value would
      // silently reinterpret every stored session and every recovered timer.
      expect(FocusMode.single.index, 0);
      expect(FocusMode.pomodoro.index, 1);
      expect(FocusMode.flow.index, 2);
    });

    test('an unknown ordinal falls back rather than throwing', () async {
      await CleanStorageService.setAppPreference('focusMode', 99);
      focus.resetForTesting();
      await focus.init();
      expect(focus.mode, FocusMode.single);
    });
  });

  group('counting up', () {
    test('elapsed grows from the absolute start time', () async {
      await startFlow();
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 7))), () {
        expect(focus.elapsedSeconds, 420);
        expect(focus.formattedTime, '07:00');
      });
    });

    test('progress stays 0 — there is no denominator to invent', () async {
      // Dividing by the ten-hour safety cap would render a good forty-minute
      // session as 6% done, which is worse than showing nothing. `isCountUp` is
      // the signal to render elapsed instead.
      await startFlow();
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 40))), () {
        expect(focus.isCountUp, isTrue);
        expect(focus.progress, 0.0);
      });
    });

    test('elapsed is 0 when nothing is running', () {
      expect(focus.elapsedSeconds, 0);
    });

    test('it does not drift across a background cycle', () async {
      await startFlow();
      focus.didChangeAppLifecycleState(AppLifecycleState.paused);
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 20))), () {
        focus.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(focus.elapsedSeconds, 1200,
            reason: 'derived from the wall clock, not accumulated by a ticker');
      });
    });
  });

  group('stopping is success, not abandonment', () {
    test('Done banks a completed session of the elapsed length', () async {
      await startFlow();
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 37))), () async {
        await focus.stopFlowSession();
      });
      await waitUntil(() => focus.sessions.isNotEmpty);

      final s = focus.sessions.single;
      expect(s.wasCompleted, isTrue,
          reason: 'routing this through abandonSession would wither the plant '
              'and file it as abandoned — the app disagreeing with its own '
              'premise');
      expect(s.wasAbandoned, isFalse);
      expect(s.actualMinutes, 37);
    });

    test('a mis-tap under a minute is not banked as a session', () async {
      await startFlow();
      await withClock(Clock.fixed(t0.add(const Duration(seconds: 20))), () async {
        await focus.stopFlowSession();
      });
      await waitUntil(() => !focus.isRunning);
      expect(focus.sessions.single.wasCompleted, isFalse,
          reason: 'a 0-minute "completed" row would poison the median');
    });

    test('it does nothing in the other modes', () async {
      await withClock(Clock.fixed(t0), () async {
        focus.setMode(FocusMode.single);
        focus.setDuration(25);
        await focus.startSession();
      });
      await focus.stopFlowSession();
      expect(focus.isRunning, isTrue, reason: 'wrong mode — must be inert');
    });
  });

  group('the safety cap', () {
    test('a forgotten timer stops at ten hours', () async {
      // Without this a count-up left running overnight logs a fourteen-hour
      // session, which then poisons `suggestedMinutes` (a median), the daily
      // totals, and the coin economy.
      await startFlow();
      await withClock(Clock.fixed(t0.add(const Duration(hours: 11))), () {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => !focus.isRunning);
      expect(focus.sessions.single.actualMinutes, kMaxSessionMinutes);
    });

    test('coins are capped well above any honest session', () async {
      await startFlow();
      await withClock(Clock.fixed(t0.add(const Duration(hours: 11))), () {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => coins.totalCoins > 0);
      // 2 coins a minute, uncapped, would pay 1,200 — twice the most expensive
      // tree — from one forgotten timer.
      expect(coins.transactions
              .where((t) => t.type == CoinTransactionType.earned)
              .first
              .amount,
          kMaxCoinEarningMinutes * 2);
    });

    test('an ordinary session is nowhere near the cap', () async {
      await startFlow();
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 45))), () async {
        await focus.stopFlowSession();
      });
      await waitUntil(() => coins.totalCoins > 0);
      expect(coins.transactions
              .where((t) => t.type == CoinTransactionType.earned)
              .first
              .amount,
          90,
          reason: 'the cap must never touch a real session');
    });
  });

  group('the proportional break', () {
    test('is focused time divided by five', () {
      expect(FocusService.suggestedBreakMinutes(50), 10);
      expect(FocusService.suggestedBreakMinutes(75), 15);
    });

    test('is clamped at both ends', () {
      expect(FocusService.suggestedBreakMinutes(5), 5,
          reason: 'a one-minute break is not a break');
      expect(FocusService.suggestedBreakMinutes(600), 30,
          reason: 'a two-hour break is not a break either');
      expect(FocusService.suggestedBreakMinutes(0), 5);
    });

    test('is never started automatically', () async {
      // Auto-starting would put a timer back in charge of deciding when the
      // user's attention is finished, which is the one thing this mode exists to
      // stop doing.
      await startFlow();
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 50))), () async {
        await focus.stopFlowSession();
      });
      await waitUntil(() => !focus.isRunning);
      expect(focus.isRunning, isFalse,
          reason: 'the break is offered by the screen, with a button');
    });
  });

  group('flow feeds the suggestion loop', () {
    test('its length counts toward "your usual"', () async {
      // The property no competitor has: they only ever measure whether you hit a
      // number you picked in advance, so they cannot learn where you naturally
      // stop.
      for (var i = 0; i < 5; i++) {
        final at = t0.add(Duration(days: i));
        await startFlow(at);
        await withClock(Clock.fixed(at.add(const Duration(minutes: 40))),
            () async {
          await focus.stopFlowSession();
        });
        await waitUntil(() => focus.sessions.length == i + 1);
      }

      final lengths =
          focus.sessions.where((s) => s.wasCompleted).map((s) => s.actualMinutes);
      expect(lengths, everyElement(40));
      expect(lengths.length, 5,
          reason: 'five completed sessions is exactly the threshold '
              'FocusInsights.suggestedMinutes needs before it will speak');
    });
  });
}
