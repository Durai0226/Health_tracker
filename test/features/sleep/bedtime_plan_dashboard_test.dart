/// Tonight's plan on the Sleep screen, and the switch that has the wind-down
/// reminder follow it.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_schedule.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_schedule_settings_screen.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/sleep/widgets/bedtime_plan_card.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/font_free_theme.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late RecordingNotificationScheduler scheduler;
  final now = DateTime(2026, 6, 20, 12);

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await SleepService.resetForTesting();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
    // The health probe awaits this channel; unanswered, the screen never leaves
    // its loading skeleton under FakeAsync.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (_) async => <String, dynamic>{},
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/device_info'), null);
    await database.close();
  });

  String key(int daysAgo) {
    final d = DateTime(now.year, now.month, now.day - daysAgo);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> night(int daysAgo, int asleep) async {
    final wake = DateTime(now.year, now.month, now.day - daysAgo, 7);
    await database.sleepDao.upsert(db.SleepSessionsCompanion(
      id: Value('n$daysAgo'),
      dateKey: Value(key(daysAgo)),
      bedtime: Value(wake.subtract(const Duration(minutes: 480))),
      wakeTime: Value(wake),
      inBedMinutes: const Value(480),
      asleepMinutes: Value(asleep),
      sourceIndex: Value(SleepSource.healthConnect.index),
      createdAt: Value(wake),
      updatedAt: Value(wake),
    ));
  }

  const schedule = SleepSchedule(
    targetMinutes: 465,
    wakeHour: 7,
    wakeMinute: 0,
    bedtimeHour: 22,
    bedtimeMinute: 30,
    windDownMinutes: 30,
    reminderEnabled: true,
  );

  Future<void> frames(WidgetTester tester, [int n = 8]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Tap in the test's own zone — a toast raised by the tap must run its timers
  /// there — and then give the real event loop, where the database lives, time
  /// to finish what the tap started.
  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await frames(tester, 6);
  }

  Future<void> openDashboard(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 6000);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // overflow is the responsive suite's job
    try {
      await tester.pumpWidget(
          MaterialApp(theme: fontFreeTheme(), home: const SleepDashboardScreen()));
      await frames(tester, 12);
    } finally {
      FlutterError.onError = prev;
    }
  }

  /// Eight nights at 6 h 40 m: a debt with a catch-up, and last night logged.
  Future<void> behindOnSleep() async {
    for (var i = 0; i < 8; i++) {
      await night(i, 400);
    }
    await SleepService.saveSchedule(schedule);
    await SleepService.reloadFromDb();
  }

  testWidgets('the Sleep screen shows tonight\'s plan', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await behindOnSleep();
      await openDashboard(tester);
      expect(find.byType(BedtimePlanCard), findsOneWidget);
      expect(find.text("TONIGHT'S BEDTIME"), findsOneWidget);
      expect(find.textContaining('of catch-up'), findsOneWidget);
      expect(find.textContaining('Your wind-down reminder is at 10:00 PM.'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('"Move it" has the reminder follow the plan, and arms it there',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await behindOnSleep();
      await openDashboard(tester);

      final plan = SleepService.bedtimePlan();
      final windDown = plan.windDownMinuteOfDay(30);
      expect(windDown, isNot(22 * 60 + 30), reason: 'the premise: it would move');

      await tapAndSettle(tester, find.textContaining('Move it to'));

      expect(SleepService.getSchedule().followPlan, isTrue);
      final armed = scheduler.lastFor(NotificationService.bedtimeReminderId)!;
      expect(armed.when.hour * 60 + armed.when.minute, windDown);
      expect(find.text("The wind-down reminder now follows tonight's plan."),
          findsOneWidget);
      expect(find.textContaining('follows this plan'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('and Undo puts it back where it was', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await behindOnSleep();
      await openDashboard(tester);
      await tapAndSettle(tester, find.textContaining('Move it to'));
      await tapAndSettle(tester, find.text('Undo'));

      expect(SleepService.getSchedule().followPlan, isFalse);
      final armed = scheduler.lastFor(NotificationService.bedtimeReminderId)!;
      expect(armed.when.hour * 60 + armed.when.minute, 22 * 60,
          reason: 'back to the schedule\'s own bedtime less the lead: 10:00 PM');
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('opening Sleep keeps a reminder that follows the plan at the plan\'s time',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await behindOnSleep();
      await SleepService.saveSchedule(schedule.copyWith(followPlan: true));
      scheduler.clear();

      await openDashboard(tester);

      final windDown = SleepService.bedtimePlan().windDownMinuteOfDay(30);
      final armed = scheduler.lastFor(NotificationService.bedtimeReminderId)!;
      expect(armed.when.hour * 60 + armed.when.minute, windDown);
      expect(windDown, isNot(22 * 60), reason: 'the premise: it is not the fixed time');
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('the schedule screen', () {
    Future<void> openSettings(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: fontFreeTheme(), home: const SleepScheduleSettingsScreen()));
      await frames(tester, 4);
    }

    testWidgets('has the switch only while the reminder is on', (tester) async {
      await SleepService.saveSchedule(schedule.copyWith(reminderEnabled: false));
      await openSettings(tester);
      expect(find.text("Follow tonight's plan"), findsNothing);

      await tapAndSettle(tester, find.text('Bedtime reminder'));
      expect(find.text("Follow tonight's plan"), findsOneWidget);
    });

    testWidgets('turning it on moves the reminder to the plan and keeps it there',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await behindOnSleep();
        await openSettings(tester);
        final windDown = SleepService.bedtimePlan().windDownMinuteOfDay(30);

        await tapAndSettle(tester, find.text("Follow tonight's plan"));

        expect(SleepService.getSchedule().followPlan, isTrue);
        final armed = scheduler.lastFor(NotificationService.bedtimeReminderId)!;
        expect(armed.when.hour * 60 + armed.when.minute, windDown);
      });
    });
  });
}
