/// Answering a check-in from the notification: "Good · Okay · Bad" on the mood
/// check-in, "Started today · Not yet" on the period reminder.
///
/// A notification button runs in a background isolate with no Drift, so it can
/// only QUEUE what was asked for; the main isolate writes it on its next resume.
/// This covers each hop: what the notification carries, what the handler queues,
/// what the queue keeps, what the resume writes, and what is scheduled with it.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/nudge_answer_queues.dart';
import 'package:tablet_remainder/features/medication/services/mood_answer_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_reminder_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/period/models/cycle_prediction.dart';
import 'package:tablet_remainder/features/period/models/flow_intensity.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/models/period_reminder_config.dart';
import 'package:tablet_remainder/features/period/models/period_settings.dart';
import 'package:tablet_remainder/features/period/services/cycle_privacy.dart';
import 'package:tablet_remainder/features/period/services/period_answer_service.dart';
import 'package:tablet_remainder/features/period/services/period_reminder_service.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what the notification carries', () {
    AlarmPresentation look(NudgeAnswers? a,
            {ReminderKind kind = ReminderKind.gentle}) =>
        alarmPresentationFor(kind, snoozeMinutes: 10, answers: a);

    test('the mood check-in: Good, Okay, Bad', () {
      final actions = look(NudgeAnswers.mood).actions;
      expect(actions.map((a) => a.id),
          ['mood_good', 'mood_okay', 'mood_bad']);
      expect(actions.map((a) => a.title), ['Good', 'Okay', 'Bad']);
    });

    test('the period reminder: Started today, Not yet', () {
      final actions = look(NudgeAnswers.period).actions;
      expect(actions.map((a) => a.id), ['period_started', 'period_not_yet']);
      expect(actions.map((a) => a.title), ['Started today', 'Not yet']);
    });

    test('every button answers without opening the app, and closes the '
        'notification', () {
      for (final a in NudgeAnswers.values) {
        for (final action in look(a).actions) {
          expect(action.showsUserInterface, isFalse, reason: action.id);
          expect(action.cancelNotification, isTrue, reason: action.id);
        }
      }
    });

    test('within Android\'s three buttons, and nothing but answers', () {
      for (final a in NudgeAnswers.values) {
        final ids = look(a).actions.map((x) => x.id).toList();
        expect(ids.length, lessThanOrEqualTo(3));
        expect(ids, everyElement(isIn(NudgeAnswers.actionIds)));
      }
    });

    test('still a nudge: no dose, no takeover, no alarm stream', () {
      final l = look(NudgeAnswers.mood);
      expect(l.offersDoseLogging, isFalse);
      expect(l.fullScreenIntent, isFalse);
      expect(l.ongoing, isFalse);
      expect(l.audioUsage, AudioAttributesUsage.notification);
    });

    test('without answers a nudge has no buttons at all, as before', () {
      expect(look(null).actions, isEmpty);
    });

    test('an alarm-grade alert keeps its own buttons whatever it is asked for',
        () {
      for (final kind in [ReminderKind.dose, ReminderKind.alarm]) {
        final plain = look(null, kind: kind).actions.map((a) => a.id);
        final asked =
            look(NudgeAnswers.mood, kind: kind).actions.map((a) => a.id);
        expect(asked, plain, reason: '$kind');
        expect(asked, isNot(contains('mood_good')));
      }
    });
  });

  group('the answers themselves', () {
    test('Good, Okay and Bad are the middle three of the Mood log\'s five', () {
      expect(NudgeAnswers.moodIndexFor('mood_good'), 1);
      expect(NudgeAnswers.moodIndexFor('mood_okay'), 2);
      expect(NudgeAnswers.moodIndexFor('mood_bad'), 3);
    });

    test('anything else is not a mood', () {
      expect(NudgeAnswers.moodIndexFor('period_started'), isNull);
      expect(NudgeAnswers.moodIndexFor('take'), isNull);
      expect(NudgeAnswers.moodIndexFor(null), isNull);
    });

    test('an alarm blob says which, by name', () {
      expect(NudgeAnswers.fromBlob({'answers': 'mood'}), NudgeAnswers.mood);
      expect(NudgeAnswers.fromBlob({'answers': 'period'}), NudgeAnswers.period);
      expect(NudgeAnswers.fromBlob({}), isNull,
          reason: 'every blob written before this existed');
      expect(NudgeAnswers.fromBlob({'answers': 'something_later'}), isNull,
          reason: 'a blob from a newer build must not crash an older one');
    });

    test('every id the answers produce is listed, for the handlers to know',
        () {
      expect(NudgeAnswers.actionIds, {
        'mood_good',
        'mood_okay',
        'mood_bad',
        'period_started',
        'period_not_yet',
      });
    });
  });

  group('the handler queues the answer', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    final tap = DateTime(2026, 6, 15, 12, 30);

    test('a mood: its index, and the moment of the tap', () async {
      expect(await handleNudgeAnswerAction('mood_bad', at: tap), isTrue);

      final queued = await MoodAnswerQueue.drain();
      expect(queued.single.moodIndex, 3);
      expect(queued.single.at, tap);
    });

    test('"Started today"', () async {
      expect(await handleNudgeAnswerAction('period_started', at: tap), isTrue);
      expect((await PeriodStartQueue.drain()).single.at, tap);
    });

    test('"Not yet" is ours, and records nothing', () async {
      expect(await handleNudgeAnswerAction('period_not_yet', at: tap), isTrue);
      expect(await PeriodStartQueue.drain(), isEmpty);
      expect(await MoodAnswerQueue.drain(), isEmpty);
    });

    test('a button that is not ours is not claimed, and queues nothing',
        () async {
      for (final id in ['take', 'snooze', 'dismiss', 'log_water', 'whatever', null]) {
        expect(await handleNudgeAnswerAction(id, at: tap), isFalse, reason: '$id');
      }
      expect(await MoodAnswerQueue.drain(), isEmpty);
      expect(await PeriodStartQueue.drain(), isEmpty);
    });
  });

  group('the queue', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps what it was given, oldest first, without clearing it',
        () async {
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: DateTime(2026, 6, 15, 9));
      await MoodAnswerQueue.enqueue(moodIndex: 3, at: DateTime(2026, 6, 15, 12));

      expect((await MoodAnswerQueue.drain()).map((m) => m.moodIndex), [1, 3]);
      expect((await MoodAnswerQueue.drain()).map((m) => m.moodIndex), [1, 3],
          reason: 'reading is not consuming: a write that fails must not lose it');
    });

    test('forgets exactly what was acked', () async {
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: DateTime(2026, 6, 15, 9));
      await MoodAnswerQueue.enqueue(moodIndex: 3, at: DateTime(2026, 6, 15, 12));
      final first = (await MoodAnswerQueue.drain()).first;

      await MoodAnswerQueue.ack([first]);
      expect((await MoodAnswerQueue.drain()).map((m) => m.moodIndex), [3]);
    });

    test('two identical taps need two acks', () async {
      final at = DateTime(2026, 6, 15, 9);
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: at);
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: at);
      final both = await MoodAnswerQueue.drain();
      expect(both, hasLength(2));

      await MoodAnswerQueue.ack([both.first]);
      expect(await MoodAnswerQueue.drain(), hasLength(1));
    });

    test('drops what could never be applied, and keeps the rest', () async {
      SharedPreferences.setMockInitialValues({
        'pending_mood_answers': [
          'not json at all',
          '{"moodIndex": 9, "at": "2026-06-15T09:00:00.000"}',
          '{"moodIndex": 2}',
          '{"moodIndex": "2", "at": "2026-06-15T09:00:00.000"}',
          '{"moodIndex": 2, "at": "2026-06-15T10:00:00.000"}',
        ],
      });
      final queued = await MoodAnswerQueue.drain();
      expect(queued.map((m) => m.moodIndex), [2]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('pending_mood_answers'), hasLength(1),
          reason: 'nothing will ever ack the bad ones, so they must not stay');
    });

    test('a time that arrives in UTC is read as local', () async {
      final utc = DateTime.utc(2026, 6, 14, 20, 30);
      SharedPreferences.setMockInitialValues({
        'pending_mood_answers': [
          '{"moodIndex": 1, "at": "${utc.toIso8601String()}"}',
        ],
      });
      final at = (await MoodAnswerQueue.drain()).single.at;
      expect(at.isUtc, isFalse);
      expect(at, utc.toLocal());
    });

    test('acking something that is not there is harmless', () async {
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: DateTime(2026, 6, 15, 9));
      final queued = await MoodAnswerQueue.drain();
      await MoodAnswerQueue.ack(queued);
      await MoodAnswerQueue.ack(queued);
      expect(await MoodAnswerQueue.drain(), isEmpty);
    });
  });

  group('on resume, a mood answer becomes a Mood log entry', () {
    late AppDatabase db;
    final tapDay = DateTime(2026, 6, 15);
    final tap = DateTime(2026, 6, 15, 12, 30);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      await ActiveProfileService().init();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      PeriodService.clearInMemory();
      await PeriodService.resetForTesting();
      await PeriodService.init();
      await SleepService.resetForTesting();
    });

    tearDown(() async {
      ActiveProfileService().resetForTesting();
      await db.close();
    });

    test('logged at the moment of the tap, not at resume', () async {
      await MoodAnswerQueue.enqueue(moodIndex: 2, at: tap);

      final applied = await withClock(
          Clock.fixed(DateTime(2026, 6, 15, 19)), MoodAnswers.drainPending);

      expect(applied.single.moodIndex, 2);
      final saved = (await VitalsStorageService.getAllMood()).single;
      expect(saved.moodIndex, 2);
      expect(saved.takenAt, tap,
          reason: 'a noon answer opened that evening is a noon mood');
    });

    test('tagged from the day it is for, as a mood logged in the app is',
        () async {
      await SleepService.logManualSession(
        bedtime: DateTime(2026, 6, 15, 2),
        wakeTime: DateTime(2026, 6, 15, 7),
      );
      await MoodAnswerQueue.enqueue(moodIndex: 3, at: tap);

      await withClock(Clock.fixed(tap), MoodAnswers.drainPending);

      expect((await VitalsStorageService.getAllMood()).single.tags,
          contains('short_night'));
    });

    test('and what was applied is no longer queued', () async {
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: tap);
      await MoodAnswers.drainPending();
      expect(await MoodAnswerQueue.drain(), isEmpty);
      expect(await MoodAnswers.drainPending(), isEmpty);
    });

    test('a drain that is replayed after the app was killed adds nothing',
        () async {
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: tap);
      await MoodAnswers.drainPending();
      // Killed between the write and the ack: the same answer is still queued.
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: tap);

      await MoodAnswers.drainPending();
      expect(await VitalsStorageService.getAllMood(), hasLength(1),
          reason: 'its id comes from the tap time, so a replay overwrites it');
    });

    test('two drains at once write each answer once', () async {
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: tap);

      final results =
          await Future.wait([MoodAnswers.drainPending(), MoodAnswers.drainPending()]);

      expect(results.expand((r) => r), hasLength(1));
      expect(await VitalsStorageService.getAllMood(), hasLength(1));
    });

    test('several answers, each at its own time', () async {
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: DateTime(2026, 6, 14, 12));
      await MoodAnswerQueue.enqueue(moodIndex: 3, at: DateTime(2026, 6, 15, 12));

      final applied = await MoodAnswers.drainPending();
      expect(applied.map((a) => a.moodIndex), [1, 3]);
      final saved = await VitalsStorageService.getAllMood();
      expect(saved.map((m) => m.takenAt.day).toSet(), {14, 15});
    });

    test('a failed write leaves the answer queued for next time', () async {
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: tap);
      await db.close(); // every write now throws

      final applied = await MoodAnswers.drainPending();

      expect(applied, isEmpty);
      expect(await MoodAnswerQueue.drain(), hasLength(1),
          reason: 'an answer the person gave from a notification is the one '
              'they cannot see go missing');
      // The tearDown closes it again; reopen so it has something to close.
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
    });

    test('Undo takes them back out', () async {
      await MoodAnswerQueue.enqueue(moodIndex: 1, at: tap);
      final applied = await MoodAnswers.drainPending();
      expect(await VitalsStorageService.getAllMood(), hasLength(1));

      await MoodAnswers.undo(applied);
      expect(await VitalsStorageService.getAllMood(), isEmpty);
    });

    // ---- the period ---------------------------------------------------------

    test('"Started today" starts a period on the day of the tap', () async {
      await PeriodStartQueue.enqueue(at: tap);

      final out = await PeriodAnswers.drainPending();

      expect(out.applied.single.date, tapDay);
      final day = PeriodService.getDay(tapDay)!;
      expect(day.isBleeding, isTrue);
      expect(day.flowIndex, PeriodAnswers.startFlow.flowIndex);
      expect(await PeriodStartQueue.drain(), isEmpty);
    });

    test('a day already logged as bleeding is left exactly as it was', () async {
      await PeriodService.logDay(
          PeriodDay(id: PeriodDay.keyFor(tapDay), date: tapDay, flowIndex: 4));
      await PeriodStartQueue.enqueue(at: tap);

      final out = await PeriodAnswers.drainPending();

      expect(out.applied, isEmpty);
      expect(PeriodService.getDay(tapDay)!.flowIndex, 4,
          reason: 'heavy stays heavy: a second tap is not a change');
      expect(await PeriodStartQueue.drain(), isEmpty,
          reason: 'and it is not left to be tried again');
    });

    test('keeps what else the day has, and Undo puts it back', () async {
      await PeriodService.logDay(PeriodDay(
          id: PeriodDay.keyFor(tapDay),
          date: tapDay,
          flowIndex: 0,
          symptomIds: const ['cramps'],
          note: 'tired'));
      await PeriodStartQueue.enqueue(at: tap);

      final out = await PeriodAnswers.drainPending();
      final started = PeriodService.getDay(tapDay)!;
      expect(started.isBleeding, isTrue);
      expect(started.symptomIds, ['cramps']);
      expect(started.note, 'tired');

      await PeriodAnswers.undo(out.applied);
      final back = PeriodService.getDay(tapDay)!;
      expect(back.isBleeding, isFalse);
      expect(back.symptomIds, ['cramps']);
    });

    test('Undo of a day that did not exist before removes it', () async {
      await PeriodStartQueue.enqueue(at: tap);
      final out = await PeriodAnswers.drainPending();
      expect(PeriodService.getDay(tapDay), isNotNull);

      await PeriodAnswers.undo(out.applied);
      expect(PeriodService.getDay(tapDay), isNull);
    });

    test('a start too soon after the last one is NOT written, and says why',
        () async {
      // A period that began ten days before the tap.
      final last = DateTime(2026, 6, 5);
      await PeriodService.logDay(
          PeriodDay(id: PeriodDay.keyFor(last), date: last, flowIndex: 3));
      await PeriodStartQueue.enqueue(at: tap);

      final out = await PeriodAnswers.drainPending();

      expect(out.applied, isEmpty);
      expect(out.tooSoon, 10);
      expect(PeriodService.getDay(tapDay), isNull,
          reason: 'the Log sheet asks before starting a period this soon, and a '
              'button cannot ask');
      expect(await PeriodStartQueue.drain(), isEmpty);
    });

    test('two drains at once write it once', () async {
      await PeriodStartQueue.enqueue(at: tap);
      final results = await Future.wait(
          [PeriodAnswers.drainPending(), PeriodAnswers.drainPending()]);
      expect(results.expand((r) => r.applied), hasLength(1));
    });
  });

  group('what is scheduled with the buttons', () {
    test('only the mood check-in asks for them among the vitals', () {
      expect(VitalsReminderService.mood.answers, NudgeAnswers.mood);
      for (final s in VitalsReminderService.all) {
        if (s == VitalsReminderService.mood) continue;
        expect(s.answers, isNull, reason: s.title);
      }
    });

    CyclePrediction prediction(DateTime start) => CyclePrediction(
          predictedStart: start,
          fertileStart: start.subtract(const Duration(days: 14)),
          fertileEnd: start.subtract(const Duration(days: 9)),
        );

    List<PlannedReminder> plan({required bool private, TrackingMode? mode}) =>
        PeriodReminderPlanner.plan(
          prediction: prediction(DateTime(2026, 7, 10)),
          mode: mode ?? TrackingMode.ttc,
          config: const PeriodReminderConfig(
            periodSoonEnabled: true,
            pmsEnabled: true,
            logReminderEnabled: true,
            fertileEnabled: true,
          ),
          now: DateTime(2026, 6, 15),
          private: private,
        );

    test('on the period reminder, only the one that asks "anything to note '
        'today?"', () {
      final planned = plan(private: false);
      expect(planned.length, 4, reason: 'all four are armed in this fixture');
      final asking = planned.where((r) => r.answers != null).toList();
      expect(asking.single.answers, NudgeAnswers.period);
      expect(asking.single.title, 'Anything to note today?');
    });

    test('never on a private reminder: "Started today" on a lock screen says '
        'what it is about', () {
      final planned = plan(private: true);
      expect(planned, isNotEmpty);
      expect(planned.every((r) => r.answers == null), isTrue);
    });
  });

  group('armed with the buttons', () {
    late AppDatabase db;
    late RecordingNotificationScheduler scheduler;

    setUpAll(() {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      await ActiveProfileService().init();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      PeriodService.clearInMemory();
      await PeriodService.resetForTesting();
      await PeriodService.init();
      scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;
    });

    tearDown(() async {
      ActiveProfileService().resetForTesting();
      await db.close();
    });

    String? category(RecordedSchedule s) => s.details?.iOS?.categoryIdentifier;

    test('the mood check-in carries the mood buttons; the other vitals none',
        () async {
      for (final spec in VitalsReminderService.all) {
        await VitalsReminderService.apply(spec,
            enabled: true, hour: spec.defaultHour, minute: 0);
      }
      for (final spec in VitalsReminderService.all) {
        final armed = scheduler.scheduled.lastWhere((s) => s.id == spec.id);
        expect(category(armed),
            spec == VitalsReminderService.mood
                ? NotificationService.darwinMoodCategoryId
                : isNull,
            reason: spec.title);
      }
    });

    Future<void> armPeriodReminders() async {
      final today = DateTime.now();
      for (var i = 0; i < 4; i++) {
        final d = DateTime(today.year, today.month, today.day - 5 - 28 * i);
        await PeriodService.logDay(
            PeriodDay(id: PeriodDay.keyFor(d), date: d, flowIndex: 2));
      }
      scheduler.clear();
      await PeriodReminderService.saveConfig(const PeriodReminderConfig(
          periodSoonEnabled: true, pmsEnabled: true, logReminderEnabled: true));
    }

    test('of the period reminders only "anything to note today?" asks', () async {
      await armPeriodReminders();

      final armed = {for (final s in scheduler.scheduled) s.id: s};
      expect(armed.keys, containsAll([990001, 990002, 990003]));
      expect(category(armed[990003]!), NotificationService.darwinPeriodCategoryId);
      expect(category(armed[990001]!), isNull);
      expect(category(armed[990002]!), isNull);
    });

    test('and not once they are private', () async {
      await CyclePrivacy.setPrivateNotifications(true);
      await armPeriodReminders();

      expect(scheduler.scheduled, isNotEmpty);
      for (final s in scheduler.scheduled) {
        expect(category(s), isNull, reason: 'reminder ${s.id}');
      }
    });
  });

  group('every response handler routes answers through the one function', () {
    // The alarm isolate registers its own handler, the main isolate another and
    // the background entry point a third; two copies of the routing drift.
    String code(String path) => File(path)
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('the background entry point', () {
      final bg = code('lib/core/services/background_alarm_service.dart');
      final fn = bg.substring(bg.indexOf('void notificationTapBackground('));
      expect(fn.substring(0, fn.indexOf('Future<bool> handleNudgeAnswerAction')),
          contains('handleNudgeAnswerAction(response.actionId)'));
    });

    test('the handler inside the alarm isolate', () {
      final bg = code('lib/core/services/background_alarm_service.dart');
      expect(
          RegExp(r'await handleNudgeAnswerAction\(response\.actionId\)')
              .hasMatch(bg),
          isTrue);
    });

    test('the foreground handler', () {
      final ns = code('lib/core/services/notification_service.dart');
      expect(ns, contains('NudgeAnswers.actionIds.contains(response.actionId)'));
      expect(ns, contains('handleNudgeAnswerAction(response.actionId'));
    });

    test('the alarm blob carries the answers, both daily and one-shot', () {
      final bg = code('lib/core/services/background_alarm_service.dart');
      expect(RegExp(r"if \(answers != null\) 'answers': answers\.name")
          .allMatches(bg)
          .length, 2);
      expect(bg, contains('answers: NudgeAnswers.fromBlob(alarmData)'),
          reason: 'and the fire-time presentation reads them back');
    });

    test('the iOS categories are registered and referenced', () {
      final ns = code('lib/core/services/notification_service.dart');
      final init = ns.substring(
        ns.indexOf('notificationCategories: <DarwinNotificationCategory>['),
        ns.indexOf('final initSettings = InitializationSettings('),
      );
      expect(init, contains('darwinMoodCategoryId'));
      expect(init, contains('darwinPeriodCategoryId'));
      for (final id in ['moodGoodId', 'moodOkayId', 'moodBadId',
          'periodStartedId', 'periodNotYetId']) {
        expect(init, contains('NudgeAnswers.$id'));
      }
      expect(ns, contains('_darwinCategoryFor(answers)'));
    });

    test('the shell applies them on cold start, on a signal and on resume', () {
      final shell = code('lib/features/home/screens/app_shell.dart');
      expect(RegExp(r'_drainQueuedAnswers\(\);').allMatches(shell).length, 3,
          reason: 'initState (a tap while the app was dead), the queue signal '
              '(a tap while it is open) and resume');
      expect(shell, contains('MoodAnswers.drainPending()'));
      expect(shell, contains('PeriodAnswers.drainPending()'));
    });

    test('nothing else drains them: one owner, or two race for the answers',
        () {
      final callers = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final c = f.readAsStringSync();
        if (c.contains('MoodAnswers.drainPending(') ||
            c.contains('PeriodAnswers.drainPending(')) {
          callers.add(f.path);
        }
      }
      expect(callers, ['lib/features/home/screens/app_shell.dart']);
    });
  });
}
