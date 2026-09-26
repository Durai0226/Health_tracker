import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/focus_insights.dart';
import 'package:tablet_remainder/core/health/insight_engine.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// The intention, and the suggestion the app already computed but never offered.
///
/// `FocusSession.note` round-tripped through `toJson`/`fromJson` from the day the
/// model was written and had zero writers and zero readers — so the storage for
/// this existed, persisted, and rode the backup, waiting for something to put a
/// value in it. `FocusInsights.suggestedMinutes` was the mirror image: computed,
/// said out loud in the coach line, and then not offered as a choice.
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

  group('the intention', () {
    test('is empty by default and normalises blanks to null', () {
      expect(focus.pendingIntention, isNull);
      focus.setIntention('   ');
      expect(focus.pendingIntention, isNull,
          reason: 'whitespace is not an intention');
      focus.setIntention('  Draft the report  ');
      expect(focus.pendingIntention, 'Draft the report',
          reason: 'trimmed, so the summary line does not render padding');
    });

    test('is capped at the persistence boundary', () {
      // Capped in the service rather than on the text field, because an import or
      // a restore can carry a string the field never saw into a one-line summary.
      focus.setIntention('x' * 500);
      expect(focus.pendingIntention!.length,
          FocusService.kMaxIntentionChars);
    });

    test('reaches the completed session record', () async {
      focus.setIntention('Finish the migration');
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 10, 0)), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 10, 1, 1)), () async {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => !focus.isRunning);

      expect(focus.sessions.single.note, 'Finish the migration',
          reason: 'the field existed; it just had nothing writing to it');
    });

    test('reaches an ABANDONED session record too', () async {
      // The more useful half, and the easy one to miss: what you meant to do when
      // you gave up is exactly the thing worth being able to look back on.
      focus.setIntention('Reply to email');
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 10, 0)), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 10, 4)), () async {
        await focus.abandonSession();
      });
      expect(focus.sessions.single.wasAbandoned, isTrue);
      expect(focus.sessions.single.note, 'Reply to email');
    });

    test('is NOT carried over to the next session', () async {
      // Pre-filling turns the decision into a default, and an implementation
      // intention that is a default is not an intention.
      focus.setIntention('One specific thing');
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 10, 0)), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 10, 1, 1)), () async {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => !focus.isRunning);

      expect(focus.pendingIntention, isNull,
          reason: 'the next session starts from a blank field');
    });

    test('survives a round trip through storage', () async {
      focus.setIntention('Ship phase five');
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 10, 0)), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 10, 1, 1)), () async {
        focus.applyTickFromClockForTesting();
      });
      await waitUntil(() => focus.sessions.isNotEmpty);

      final exported = focus.exportSessionsJson();
      focus.resetForTesting();
      await focus.importSessionsJson(exported);
      expect(focus.sessions.single.note, 'Ship phase five');
    });
  });

  group('the breathing pre-roll', () {
    test('is off by default', () {
      expect(focus.breathingPreroll, isFalse,
          reason: 'a ritual the user did not ask for is friction');
    });

    test('persists as a single key', () async {
      focus.setBreathingPreroll(true);
      await waitUntil(() =>
          CleanStorageService.getAppPreference('focusBreathingPreroll') == true);
      expect(focus.breathingPreroll, isTrue);
    });

    test('survives a reload', () async {
      focus.setBreathingPreroll(true);
      await waitUntil(() =>
          CleanStorageService.getAppPreference('focusBreathingPreroll') == true);
      focus.resetForTesting();
      expect(focus.breathingPreroll, isFalse,
          reason: 'reset returns it to the fresh-install default');
      await focus.init();
      expect(focus.breathingPreroll, isTrue,
          reason: 'and init() reads it back from storage');
    });

    test('does not itself start or delay a session', () async {
      // The pre-roll runs BEFORE startSession, never during: the timer is
      // anchored to an absolute end time, so starting it and then covering the
      // screen with a breathing exercise would spend the first minute of the
      // session breathing.
      focus.setBreathingPreroll(true);
      expect(focus.isRunning, isFalse);
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 10, 0)), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      expect(focus.isRunning, isTrue);
      expect(focus.remainingSeconds, 25 * 60,
          reason: 'the full duration, not the duration minus a ritual');
    });
  });

  group('the suggestion is offered, not applied', () {
    test('suggestedMinutes stays null until there is evidence', () {
      final thin = List.generate(
          4, (_) => const FocusSessionRef(startHour: 9, minutes: 20));
      expect(FocusInsights.suggestedMinutes(thin), isNull,
          reason: 'four data points is not a recommendation');
    });

    test('the completion insight offers the finishable length', () {
      final insight = InsightEngine.focus(
        sessionCount: 8,
        completionRate: 0.25,
        suggestedMinutes: 20,
      );
      expect(insight!.id, 'focus_completion');
      expect(insight.actionLabel, 'Try 20m',
          reason: 'actionLabel and InsightCard(onAction:) both existed and Focus '
              'set neither, so every insight was unactionable');
    });

    test('it offers no action when it does not know the length', () {
      final insight = InsightEngine.focus(
        sessionCount: 8,
        completionRate: 0.25,
      );
      expect(insight!.id, 'focus_completion');
      expect(insight.actionLabel, isNull,
          reason: 'a button labelled "Try nullm" is worse than no button');
    });

    test('the best-hour insight offers a reminder', () {
      final insight = InsightEngine.focus(sessionCount: 8, bestFocusHour: 14);
      expect(insight!.id, 'focus_besthour');
      expect(insight.actionLabel, isNotNull);
    });

    test('setDuration is never called by the engine itself', () {
      // The engine is pure. Anything that could change the user's chosen duration
      // without them tapping would make the suggestion unfalsifiable — you could
      // not tell whether you picked 20 or the app did.
      final before = focus.selectedMinutes;
      InsightEngine.focus(
          sessionCount: 20, completionRate: 0.1, suggestedMinutes: 15);
      expect(focus.selectedMinutes, before);
    });
  });
}
