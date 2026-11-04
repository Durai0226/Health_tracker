/// A reminder can tick itself off when the steps show up.
///
/// The decisions worth pinning without a phone: it ticks only a reminder that
/// opted in, only once it has come due TODAY, never from an earlier day's walk,
/// and through the same completion every other Done uses.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/vacation_mode.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_step_targets.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_auto_complete.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';
import '../support/reminder_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  // Thursday 12 March 2026, 19:00: after a reminder due at 18:00 today.
  final evening = DateTime(2026, 3, 12, 19, 0);

  Reminder walk({
    String id = 'w',
    DateTime? at,
    RepeatType repeat = RepeatType.none,
    int? steps = 5000,
    bool isCompleted = false,
    bool isPaused = false,
  }) =>
      Reminder(
        id: id,
        title: 'Walk 20 min',
        body: '',
        scheduledTime: at ?? DateTime(2026, 3, 12, 18, 0),
        repeatType: repeat,
        autoCompleteSteps: steps,
        isCompleted: isCompleted,
        isPaused: isPaused,
      );

  group('the step counts', () {
    test('only the offered counts are known', () {
      expect(ReminderStepTargets.options, [1000, 2000, 5000, 8000, 10000]);
      for (final n in ReminderStepTargets.options) {
        expect(ReminderStepTargets.isKnown(n), isTrue);
      }
      for (final n in [null, 0, -1, 999, 4000, 80000]) {
        expect(ReminderStepTargets.isKnown(n), isFalse, reason: '$n');
      }
    });

    test('clean keeps an offered count and drops everything else', () {
      expect(ReminderStepTargets.clean(5000), 5000);
      expect(ReminderStepTargets.clean(5000.0), 5000);
      expect(ReminderStepTargets.clean(5000.5), isNull);
      expect(ReminderStepTargets.clean(double.nan), isNull);
      expect(ReminderStepTargets.clean(4000), isNull);
      expect(ReminderStepTargets.clean('5000'), isNull);
      expect(ReminderStepTargets.clean(null), isNull);
    });

    test('the label reads as a count of steps', () {
      expect(ReminderStepTargets.labelFor(1000), '1,000 steps');
      expect(ReminderStepTargets.labelFor(10000), '10,000 steps');
    });
  });

  group('the model', () {
    test('it survives JSON', () {
      final back = Reminder.fromJson(walk().toJson());
      expect(back.autoCompleteSteps, 5000);
    });

    test('no choice stays no choice', () {
      expect(Reminder.fromJson(walk(steps: null).toJson()).autoCompleteSteps,
          isNull);
    });

    test('a hand-edited count nobody offers reads as no choice', () {
      final json = walk().toJson()..['autoCompleteSteps'] = 80000;
      expect(Reminder.fromJson(json).autoCompleteSteps, isNull);
    });

    test('a backup from before this field reads as no choice', () {
      final json = walk().toJson()..remove('autoCompleteSteps');
      expect(Reminder.fromJson(json).autoCompleteSteps, isNull);
    });

    test('copyWith keeps it, changes it, and can clear it', () {
      expect(walk().copyWith(title: 'x').autoCompleteSteps, 5000);
      expect(walk().copyWith(autoCompleteSteps: 2000).autoCompleteSteps, 2000);
      expect(walk().copyWith(clearAutoCompleteSteps: true).autoCompleteSteps,
          isNull);
    });
  });

  group('storage', () {
    late ReminderHarness h;

    setUp(() async => h = await reminderSetUp(at: evening));
    tearDown(() async => h.tearDown());

    Future<Reminder> stored() async =>
        (await CleanStorageService.getAllReminders()).single;

    test('a chosen count is stored and read back', () async {
      await CleanStorageService.saveReminderAllocatingId(walk(steps: 8000));

      expect((await stored()).autoCompleteSteps, 8000);
    });

    test('no choice stays no choice', () async {
      await CleanStorageService.saveReminderAllocatingId(walk(steps: null));

      expect((await stored()).autoCompleteSteps, isNull);
    });

    test('a count nobody offers is not stored', () async {
      await CleanStorageService.saveReminderAllocatingId(walk(steps: 4000));

      expect((await stored()).autoCompleteSteps, isNull);
    });

    test('a count read back from the table that nobody offers is dropped',
        () async {
      await CleanStorageService.saveReminderAllocatingId(walk(steps: 5000));
      await h.database.customStatement(
          "UPDATE reminders SET auto_complete_steps = 4000 WHERE id = 'w'");
      await CleanStorageService.getAllReminders();

      expect((await stored()).autoCompleteSteps, isNull);
    });

    test('a reminder arriving from the cloud keeps its choice', () async {
      await CleanStorageService.saveSyncedReminderFromModel(walk(steps: 2000));

      expect((await stored()).autoCompleteSteps, 2000);
    });
  });

  group('when it is due', () {
    bool due(Reminder r, int steps, [DateTime? now]) =>
        ReminderAutoComplete.isDue(r, steps: steps, now: now ?? evening);

    test('opted in, due today, steps reached: yes', () {
      expect(due(walk(), 5000), isTrue);
      expect(due(walk(), 9000), isTrue);
    });

    test('one step short: no', () {
      expect(due(walk(), 4999), isFalse);
    });

    test('not opted in: never', () {
      expect(due(walk(steps: null), 99999), isFalse);
    });

    test('a count nobody offers is not a target', () {
      expect(due(walk(steps: 4000), 99999), isFalse);
    });

    test('not yet due today: no, the reminder still comes at its time', () {
      expect(due(walk(), 9000, DateTime(2026, 3, 12, 17, 59)), isFalse);
      expect(due(walk(), 9000, DateTime(2026, 3, 12, 18, 0)), isTrue);
    });

    test('overdue from yesterday: today\'s walk does not tick yesterday\'s',
        () {
      final yesterday = walk(at: DateTime(2026, 3, 11, 18, 0));
      expect(due(yesterday, 9000), isFalse);
    });

    test('overdue from a month or a year ago on the same day of the month: no',
        () {
      expect(due(walk(at: DateTime(2026, 2, 12, 18, 0)), 9000), isFalse);
      expect(due(walk(at: DateTime(2025, 3, 12, 18, 0)), 9000), isFalse);
    });

    test('a daily one is judged on today\'s occurrence, not its stale anchor', () {
      // Made two weeks ago: the stored time is the day it was created.
      final daily = walk(at: DateTime(2026, 2, 26, 18, 0), repeat: RepeatType.daily);

      expect(due(daily, 9000, DateTime(2026, 3, 12, 10, 0)), isFalse,
          reason: 'this morning the latest 18:00 is yesterday\'s');
      expect(due(daily, 9000, DateTime(2026, 3, 12, 19, 0)), isTrue,
          reason: 'after 18:00 today\'s has come due');
    });

    test('already done or paused: no', () {
      expect(due(walk(isCompleted: true), 9000), isFalse);
      expect(due(walk(isPaused: true), 9000), isFalse);
    });
  });

  group('running it', () {
    late ReminderHarness h;

    setUp(() async => h = await reminderSetUp(at: evening));
    tearDown(() async => h.tearDown());

    Future<Reminder> stored(String id) async =>
        (await CleanStorageService.getAllReminders()).firstWhere((r) => r.id == id);

    test('ticks a due reminder off and says it was the steps', () async {
      await CleanStorageService.saveReminderAllocatingId(walk());

      final n = await withClock(
          Clock.fixed(evening),
          () => ReminderAutoComplete.run(
              steps: 6000,
              reminders: CleanStorageService.getReminders(),
              alarm: h.alarm));

      expect(n, 1);
      expect((await stored('w')).isCompleted, isTrue);
      final log = await CleanStorageService.getReminderOccurrences('w');
      expect(log.single.outcome, 'done');
      expect(log.single.source, ReminderAutoComplete.source);
      expect(ReminderAutoComplete.source, 'steps');
    });

    test('and withdraws what was armed, as any Done does', () async {
      final r = await CleanStorageService.saveReminderAllocatingId(walk());

      await withClock(
          Clock.fixed(evening),
          () => ReminderAutoComplete.run(
              steps: 6000,
              reminders: CleanStorageService.getReminders(),
              alarm: h.alarm));

      expect(h.alarm.disarmed, contains(r.notificationSlot));
    });

    test('a daily one is not finished: it moves to its next time', () async {
      await CleanStorageService.saveReminderAllocatingId(
          walk(at: DateTime(2026, 3, 1, 18, 0), repeat: RepeatType.daily));

      final n = await withClock(
          Clock.fixed(evening),
          () => ReminderAutoComplete.run(
              steps: 6000,
              reminders: CleanStorageService.getReminders(),
              alarm: h.alarm));

      expect(n, 1);
      final r = await stored('w');
      expect(r.isCompleted, isFalse, reason: 'a repeat is a repeat');
      expect(r.scheduledTime.isAfter(evening), isTrue);
    });

    test('too few steps: nothing is ticked', () async {
      await CleanStorageService.saveReminderAllocatingId(walk());

      final n = await withClock(
          Clock.fixed(evening),
          () => ReminderAutoComplete.run(
              steps: 4999,
              reminders: CleanStorageService.getReminders(),
              alarm: h.alarm));

      expect(n, 0);
      expect((await stored('w')).isCompleted, isFalse);
      expect(h.alarm.disarmed, isEmpty);
    });

    test('only the reminders that opted in', () async {
      await CleanStorageService.saveReminderAllocatingId(walk(id: 'a'));
      await CleanStorageService.saveReminderAllocatingId(
          walk(id: 'b', steps: null));

      final n = await withClock(
          Clock.fixed(evening),
          () => ReminderAutoComplete.run(
              steps: 9000,
              reminders: CleanStorageService.getReminders(),
              alarm: h.alarm));

      expect(n, 1);
      expect((await stored('a')).isCompleted, isTrue);
      expect((await stored('b')).isCompleted, isFalse);
    });

    test('a second pass does not tick it twice', () async {
      await CleanStorageService.saveReminderAllocatingId(walk());
      Future<int> pass() => withClock(
          Clock.fixed(evening),
          () => ReminderAutoComplete.run(
              steps: 9000,
              reminders: CleanStorageService.getReminders(),
              alarm: h.alarm));

      expect(await pass(), 1);
      expect(await pass(), 0);
      expect(
          (await CleanStorageService.getReminderOccurrences('w')), hasLength(1));
    });

    test('on vacation nothing is ticked', () async {
      await CleanStorageService.saveReminderAllocatingId(walk());
      await VacationMode.start(until: DateTime(2026, 3, 20), now: evening);

      final n = await withClock(
          Clock.fixed(evening),
          () => ReminderAutoComplete.run(
              steps: 9000,
              reminders: CleanStorageService.getReminders(),
              alarm: h.alarm));

      expect(n, 0);
    });

    test('with no steps given it reads today\'s from the Steps screen', () async {
      await CleanStorageService.saveReminderAllocatingId(walk());
      await StepService.resetForTesting();
      StepService.clearInMemory();
      await StepService.init();
      StepService.storeHealthDayForTesting(evening, 6200, isToday: true);

      final n = await withClock(
          Clock.fixed(evening),
          () => ReminderAutoComplete.run(
              reminders: CleanStorageService.getReminders(), alarm: h.alarm));

      expect(n, 1);
    });
  });

  group('the watcher', () {
    late ReminderHarness h;
    var passes = 0;

    setUp(() async {
      h = await reminderSetUp(at: evening);
      await StepService.resetForTesting();
      StepService.clearInMemory();
      await StepService.init();
      passes = 0;
      ReminderAutoCompleteWatcher.quietFor = const Duration(milliseconds: 40);
      ReminderAutoCompleteWatcher.runPass = () async => passes++;
    });

    tearDown(() async {
      ReminderAutoCompleteWatcher.stop();
      ReminderAutoCompleteWatcher.quietFor = const Duration(seconds: 3);
      ReminderAutoCompleteWatcher.runPass = ReminderAutoComplete.run;
      await h.tearDown();
    });

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

    test('starting it makes one pass, for steps that landed before it did',
        () async {
      ReminderAutoCompleteWatcher.start();
      await settle();

      expect(passes, 1);
    });

    test('a change to the day\'s steps makes a pass', () async {
      ReminderAutoCompleteWatcher.start();
      await settle();

      StepService.storeHealthDayForTesting(evening, 3000, isToday: true);
      await settle();

      expect(passes, 2);
    });

    test('a burst of changes is one pass', () async {
      ReminderAutoCompleteWatcher.start();
      await settle();
      passes = 0;

      for (var i = 1; i <= 5; i++) {
        StepService.storeHealthDayForTesting(evening, 1000 * i, isToday: true);
      }
      await settle();

      expect(passes, 1);
    });

    test('stopped, it makes none', () async {
      ReminderAutoCompleteWatcher.start();
      await settle();
      ReminderAutoCompleteWatcher.stop();
      passes = 0;

      StepService.storeHealthDayForTesting(evening, 3000, isToday: true);
      await settle();

      expect(passes, 0);
    });

    test('a pass that throws does not break the next', () async {
      ReminderAutoCompleteWatcher.runPass = () async {
        passes++;
        throw StateError('boom');
      };
      ReminderAutoCompleteWatcher.start();
      await settle();

      StepService.storeHealthDayForTesting(evening, 3000, isToday: true);
      await settle();

      expect(passes, 2);
    });
  });

  group('the form', () {
    Future<void> pump(WidgetTester tester, {Reminder? reminder}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 3200);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: AddReminderScreen(
          reminder: reminder,
          initialTitle: reminder == null ? 'Walk' : null,
          initialTime: reminder == null ? evening.add(const Duration(hours: 2)) : null,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> save(WidgetTester tester, String label) async {
      final b = find.text(label);
      await tester.ensureVisible(b);
      await tester.tap(b);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    void formTest(String name, Future<void> Function(WidgetTester) body) {
      testWidgets(name, (tester) async {
        await withClock(Clock.fixed(evening), () async {
          final h = await reminderSetUp(at: evening);
          NotificationService().schedulerForTesting =
              RecordingNotificationScheduler();
          try {
            await body(tester);
          } finally {
            await h.tearDown();
          }
        });
      });
    }

    formTest('a new reminder follows no step count', (tester) async {
      await pump(tester);

      expect(find.text('Tick off by itself'), findsWidgets);
      expect(find.text("Don't tick it off for me"), findsOneWidget);
    });

    formTest('choosing a count saves it on the reminder', (tester) async {
      await pump(tester);

      await tester.ensureVisible(find.text("Don't tick it off for me"));
      await tester.tap(find.text("Don't tick it off for me"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('When I reach 8,000 steps'));
      await tester.pumpAndSettle();
      expect(find.text('When I reach 8,000 steps'), findsOneWidget);

      await save(tester, 'Create Reminder');

      expect((await CleanStorageService.getAllReminders()).single.autoCompleteSteps,
          8000);
    });

    formTest('an existing choice is shown, and "Don\'t" clears it', (tester) async {
      final saved = await CleanStorageService.saveReminderAllocatingId(
          walk(at: evening.add(const Duration(hours: 2)), steps: 2000));
      await pump(tester, reminder: saved);

      expect(find.text('When I reach 2,000 steps'), findsOneWidget);

      await tester.ensureVisible(find.text('When I reach 2,000 steps'));
      await tester.tap(find.text('When I reach 2,000 steps'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Don't tick it off for me").last);
      await tester.pumpAndSettle();

      await save(tester, 'Save Changes');

      expect((await CleanStorageService.getAllReminders()).single.autoCompleteSteps,
          isNull);
    });

    formTest('dismissing the sheet changes nothing', (tester) async {
      final saved = await CleanStorageService.saveReminderAllocatingId(
          walk(at: evening.add(const Duration(hours: 2)), steps: 2000));
      await pump(tester, reminder: saved);

      await tester.ensureVisible(find.text('When I reach 2,000 steps'));
      await tester.tap(find.text('When I reach 2,000 steps'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      expect(find.text('When I reach 2,000 steps'), findsOneWidget);
    });
  });
}
