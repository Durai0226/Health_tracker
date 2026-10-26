import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/step_reminder_plan.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

/// The evening step reminder knows how far there is to go: silent today once the
/// goal is met, "N steps to go" when the number is fresh, and the old generic
/// repeating reminder otherwise. The decision itself is pinned in
/// `step_reminder_plan_test`; this checks it reaches the scheduler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late RecordingNotificationScheduler scheduler;

  final evening = DateTime(2026, 3, 10, 18, 30);
  final seven = DateTime(2026, 3, 10, 19);
  final tomorrowSeven = DateTime(2026, 3, 11, 19);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  tearDown(() async => database.close());

  bool at(RecordedSchedule s, DateTime t) => s.when.isAtSameMomentAs(t);

  RecordedSchedule? todayShot() => scheduler.scheduled
      .where((s) => s.id == NotificationService.stepReminderTodayId)
      .firstOrNull;
  RecordedSchedule repeating() => scheduler.scheduled
      .singleWhere((s) => s.id == NotificationService.stepReminderId);

  group('scheduleStepReminder', () {
    test('with no step data it is the old generic repeating reminder', () async {
      await withClock(Clock.fixed(evening), () async {
        await NotificationService()
            .scheduleStepReminder(enabled: true, minuteOfDay: 19 * 60);
        expect(todayShot(), isNull);
        final r = repeating();
        expect(at(r, seven), isTrue, reason: 'starts today, as it always did');
        expect(r.matchDateTimeComponents, isNotNull);
      });
    });

    test('short of the goal with a fresh count: a one-off that says how far',
        () async {
      await withClock(Clock.fixed(evening), () async {
        await NotificationService().scheduleStepReminder(
          enabled: true,
          minuteOfDay: 19 * 60,
          stepsToday: 6200,
          goal: 8000,
          stepsAsOf: evening,
        );
        final shot = todayShot()!;
        expect(at(shot, seven), isTrue);
        expect(shot.body, '1,800 steps to go — about 18 minutes of walking.');
        expect(shot.matchDateTimeComponents, isNull, reason: 'a one-off');
        expect(at(repeating(), tomorrowSeven), isTrue,
            reason: 'the repeating one steps aside for today only');
      });
    });

    test('goal met: nothing today, the repeating reminder starts tomorrow',
        () async {
      await withClock(Clock.fixed(evening), () async {
        await NotificationService().scheduleStepReminder(
          enabled: true,
          minuteOfDay: 19 * 60,
          stepsToday: 8400,
          goal: 8000,
          stepsAsOf: evening,
        );
        expect(todayShot(), isNull);
        expect(at(repeating(), tomorrowSeven), isTrue);
      });
    });

    test('re-planning clears a one-off that no longer applies', () async {
      await withClock(Clock.fixed(evening), () async {
        final n = NotificationService();
        await n.scheduleStepReminder(
            enabled: true,
            minuteOfDay: 19 * 60,
            stepsToday: 6200,
            goal: 8000,
            stepsAsOf: evening);
        scheduler.cancelled.clear();
        await n.scheduleStepReminder(
            enabled: true,
            minuteOfDay: 19 * 60,
            stepsToday: 8100,
            goal: 8000,
            stepsAsOf: evening);
        expect(scheduler.cancelled,
            containsAll([NotificationService.stepReminderTodayId,
              NotificationService.stepReminderId]));
      });
    });

    test('off cancels both and arms neither', () async {
      await withClock(Clock.fixed(evening), () async {
        await NotificationService().scheduleStepReminder(
            enabled: false, minuteOfDay: 19 * 60, stepsToday: 1, goal: 2);
        expect(scheduler.scheduled, isEmpty);
        expect(scheduler.cancelled,
            containsAll([NotificationService.stepReminderTodayId,
              NotificationService.stepReminderId]));
      });
    });
  });

  group('StepService.replanReminder', () {
    test('does nothing while the reminder is off', () async {
      await withClock(Clock.fixed(evening), () async {
        expect(await StepService.replanReminder(), isFalse);
        expect(scheduler.scheduled, isEmpty);
      });
    });

    test('with no observation yet it leaves what is armed alone — an empty day '
        'must not read as "8,000 to go"', () async {
      await withClock(Clock.fixed(evening), () async {
        await StepService.setReminder(true, 19 * 60);
        expect(await StepService.replanReminder(), isFalse);
        expect(scheduler.scheduled, isEmpty);
        expect(scheduler.cancelled, isEmpty);
      });
    });

    test('...unless asked to keep the generic reminder alive', () async {
      await withClock(Clock.fixed(evening), () async {
        await StepService.setReminder(true, 19 * 60);
        expect(await StepService.replanReminder(rearmIfUnknown: true), isTrue);
        expect(todayShot(), isNull);
        expect(at(repeating(), seven), isTrue);
      });
    });

    test('after steps are logged it quotes what is left, then goes quiet at '
        'the goal', () async {
      await withClock(Clock.fixed(evening), () async {
        await StepService.setReminder(true, 19 * 60);
        final goal = StepService.getTodayData().goalSteps;

        await StepService.addManualSteps(200);
        await StepService.replanReminder();
        final left = goal - 200;
        expect(
            todayShot()!.body,
            '${StepReminderPlanner.groupThousands(left)} steps to go — about '
            '${StepReminderPlanner.walkMinutes(left)} minutes of walking.');

        scheduler.scheduled.clear();
        await StepService.addManualSteps(goal);
        await StepService.replanReminder();
        expect(todayShot(), isNull,
            reason: 'the goal is met: the reminder has nothing to say today');
        expect(at(repeating(), tomorrowSeven), isTrue);
      });
    });
  });
}
