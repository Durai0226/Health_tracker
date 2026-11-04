import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/focus_insights.dart';
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/focus_reminder_scheduler.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/recording_notification_scheduler.dart';

/// "Time to focus" moves to the user's best hour and stays quiet once they have
/// focused. The pure planner is covered by `focus_nudge_planner_test`; this
/// pins that the scheduler feeds it the user's real sessions and that what it
/// arms is that plan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  // Wednesday 11 March 2026, 07:00.
  final now = DateTime(2026, 3, 11, 7, 0);

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    // Fresh preferences too: a rest day marked by one test must not quiet the next.
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await FocusService().reloadSessionsFromDb();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  tearDown(() async => db.close());

  FocusSession session(String id, DateTime at, {bool completed = true}) =>
      FocusSession(
        id: id,
        startedAt: at,
        completedAt: completed ? at.add(const Duration(minutes: 30)) : null,
        targetMinutes: 30,
        actualMinutes: 30,
        wasCompleted: completed,
        wasAbandoned: !completed,
        activityType: FocusActivityType.values.first,
        plantType: PlantType.values.first,
      );

  Future<void> seed(List<FocusSession> sessions) =>
      FocusService().importSessionsJson([for (final s in sessions) s.toJson()]);

  /// Mon/Wed/Fri at 14:00 for the three weeks before [now]: 9 sessions, best
  /// hour 14, usual weekdays Mon/Wed/Fri.
  List<FocusSession> pattern() => [
        for (final d in const [
          [2, 25], [2, 27], [3, 2], [3, 4], [3, 6], [3, 9],
          [2, 18], [2, 20], [2, 23],
        ])
          session('s-${d[0]}-${d[1]}', DateTime(2026, d[0], d[1], 14, 5)),
      ];

  group('planNextNudge', () {
    test('too little history means no plan', () async {
      await seed([session('a', DateTime(2026, 3, 9, 14))]);
      expect(FocusReminderScheduler.planNextNudge(now: now), isNull);
    });

    test('aims ten minutes before the hour the Focus screen calls your best',
        () async {
      await seed(pattern());
      final refs = [
        for (final s in FocusService().sessions)
          FocusSessionRef(
              startHour: s.startedAt.hour,
              minutes: s.actualMinutes,
              completed: s.wasCompleted),
      ];
      expect(FocusInsights.bestFocusHour(refs), 14, reason: 'premise');
      expect(FocusReminderScheduler.planNextNudge(now: now),
          DateTime(2026, 3, 11, 13, 50));
    });

    test('stays quiet today once the user has focused, skips a non-focus day',
        () async {
      await seed([...pattern(), session('today', DateTime(2026, 3, 11, 6, 30))]);
      // Wed is done; Thu is not a day they focus; Fri is.
      expect(FocusReminderScheduler.planNextNudge(now: now),
          DateTime(2026, 3, 13, 13, 50));
    });

    test('an abandoned session today does not count as having focused',
        () async {
      await seed([
        ...pattern(),
        session('gave-up', DateTime(2026, 3, 11, 6, 30), completed: false),
      ]);
      expect(FocusReminderScheduler.planNextNudge(now: now),
          DateTime(2026, 3, 11, 13, 50));
    });
  });

  group('apply', () {
    // Reminders are opt-in: the person has switched the daily one on. (They used
    // to be on for everyone; see 'off until switched on' below.)
    setUp(() => SharedPreferences.setMockInitialValues(
        {'focus_daily_reminder': true}));

    test('off until switched on: nothing is armed for someone who has not asked',
        () async {
      SharedPreferences.setMockInitialValues({});
      await seed(pattern());
      await withClock(Clock.fixed(now), () async {
        await FocusReminderScheduler.apply();
      });
      expect(scheduler.armedIds,
          isNot(contains(NotificationService.focusDailyReminderId)),
          reason: 'completing a first session used to arm a daily 9:00 nudge '
              'nobody had asked for');
      expect(scheduler.armedIds,
          isNot(contains(NotificationService.focusStreakReminderId)));
    });

    test('the streak nudge is off until switched on, even for a streak at risk',
        () async {
      // Three days running up to yesterday, nothing yet today: at risk.
      final run = [
        session('a', DateTime(2026, 3, 10, 10)),
        session('b', DateTime(2026, 3, 9, 10)),
        session('c', DateTime(2026, 3, 8, 10)),
      ];

      SharedPreferences.setMockInitialValues({});
      // Imported and initialised at the pinned time, so the streak (and whether
      // it is at risk) is worked out against it.
      addTearDown(FocusService().resetForTesting);
      await withClock(Clock.fixed(now), () async {
        await seed(run);
        await FocusService().init();
      });
      await withClock(Clock.fixed(now), () async {
        await FocusReminderScheduler.apply();
      });
      expect(scheduler.armedIds,
          isNot(contains(NotificationService.focusStreakReminderId)));

      // The premise, proved: switched on, the same streak IS nudged.
      SharedPreferences.setMockInitialValues({'focus_streak_reminder': true});
      await withClock(Clock.fixed(now), () async {
        await FocusReminderScheduler.apply();
      });
      expect(scheduler.armedIds,
          contains(NotificationService.focusStreakReminderId),
          reason: 'otherwise the test above proves nothing');
    });

    test('a rest or unwell day: no streak nudge, but the same streak is nudged without it',
        () async {
      final run = [
        session('a', DateTime(2026, 3, 10, 10)),
        session('b', DateTime(2026, 3, 9, 10)),
        session('c', DateTime(2026, 3, 8, 10)),
      ];
      SharedPreferences.setMockInitialValues({'focus_streak_reminder': true});
      addTearDown(FocusService().resetForTesting);
      await withClock(Clock.fixed(now), () async {
        await seed(run);
        await FocusService().init();
        await FocusReminderScheduler.apply();
      });
      expect(scheduler.armedIds,
          contains(NotificationService.focusStreakReminderId),
          reason: 'the premise: this streak is at risk and is nudged');

      // Let anything the service started on its own settle first, so it cannot
      // land on the fresh scheduler below.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;
      await withClock(Clock.fixed(now), () async {
        await RestDayStore.markDays(RestKind.rest, 1);
        await FocusReminderScheduler.apply();
      });
      expect(scheduler.armedIds,
          isNot(contains(NotificationService.focusStreakReminderId)),
          reason: 'a streak that is paused today is not something to be nudged about');
    });

    test('a rest day is not a missed day: the streak runs through it', () async {
      // Completed on the 10th and the 7th; the 8th and 9th were rest days. Two
      // missed days in a week would break it (one is forgiven), so it is the
      // marks that keep it whole.
      final sessions = [
        session('a', DateTime(2026, 3, 10, 10)),
        session('b', DateTime(2026, 3, 7, 10)),
      ];
      addTearDown(FocusService().resetForTesting);

      await withClock(Clock.fixed(now), () async {
        await seed(sessions);
        await FocusService().init();
      });
      final without = FocusService().stats.currentStreak;

      await withClock(Clock.fixed(now), () async {
        await RestDayStore.markDays(RestKind.rest, 2, now: DateTime(2026, 3, 8));
        FocusService().resetForTesting();
        await seed(sessions);
        await FocusService().init();
      });
      expect(FocusService().stats.currentStreak, greaterThan(without),
          reason: 'with the two rest days the 7th and the 10th join up');
      expect(FocusService().stats.currentStreak, 2);
    });

    test('a nudge planned for a rest day is not armed', () async {
      await seed(pattern());
      await withClock(Clock.fixed(now), () async {
        await FocusReminderScheduler.apply();
      });
      expect(scheduler.armedIds, contains(NotificationService.focusDailyReminderId),
          reason: 'the premise: 13:50 today is planned');

      scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;
      await withClock(Clock.fixed(now), () async {
        await RestDayStore.markDays(RestKind.rest, 1);
        await FocusReminderScheduler.apply();
      });
      expect(scheduler.armedIds,
          isNot(contains(NotificationService.focusDailyReminderId)),
          reason: 'it is a one-off for a day that is a rest day');
    });

    test('arms ONE non-repeating nudge at the planned time', () async {
      await seed(pattern());
      await withClock(Clock.fixed(now), () async {
        await FocusReminderScheduler.apply();
      });
      final armed = scheduler.lastFor(NotificationService.focusDailyReminderId);
      expect(armed, isNotNull);
      // Compared as an instant: the plan is in the machine's zone, the recorded
      // schedule in tz.local.
      expect(armed!.when.isAtSameMomentAs(DateTime(2026, 3, 11, 13, 50)), isTrue,
          reason: 'armed at ${armed.when}');
      expect(armed.matchDateTimeComponents, isNull,
          reason: 'a one-shot: it is re-planned after every session');
    });

    test('turned off, it keeps the fixed repeating daily reminder', () async {
      SharedPreferences.setMockInitialValues({
        'focus_daily_reminder': true,
        FocusReminderScheduler.kAdaptive: false,
        'focus_reminder_time': '9:0',
      });
      await seed(pattern());
      await withClock(Clock.fixed(now), () async {
        await FocusReminderScheduler.apply();
      });
      final armed = scheduler.lastFor(NotificationService.focusDailyReminderId);
      expect(armed, isNotNull);
      expect(armed!.when.isAtSameMomentAs(DateTime(2026, 3, 11, 9, 0)), isTrue,
          reason: 'armed at ${armed.when}');
      expect(armed.matchDateTimeComponents, isNotNull,
          reason: 'the old behaviour: repeats daily at the chosen time');
    });

    test('without enough history it falls back to the fixed time', () async {
      await withClock(Clock.fixed(now), () async {
        await FocusReminderScheduler.apply();
      });
      final armed = scheduler.lastFor(NotificationService.focusDailyReminderId);
      expect(armed, isNotNull);
      expect(armed!.when.isAtSameMomentAs(DateTime(2026, 3, 11, 9, 0)), isTrue,
          reason: 'armed at ${armed.when}');
      expect(armed.matchDateTimeComponents, isNotNull);
    });
  });
}
