import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/models/water_reminder_config.dart';
import 'package:tablet_remainder/features/water/screens/water_reminder_settings_screen.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/recording_notification_scheduler.dart';

/// W7 — "0 water reminders scheduled" was shown as a green success toast.
///
/// `ReminderRescheduleService.rescheduleWaterReminders()` returns 0 from
/// several paths: a fluid restriction, a goal already met, the pacing prune
/// dropping every remaining slot, a refused notification permission. Only one
/// of them was explained; the rest fell through to
/// `_snack('$scheduled water reminders scheduled', success: true)` — nothing
/// was armed, and the user was told it had worked.
///
/// The fluid-restriction path is the one a headless test can drive end to end:
/// the reschedule service bails on it before it touches the notification
/// plugin at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final now = DateTime(2026, 9, 26, 9, 0);

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    // The reschedule service sweeps stale water ids before deciding anything,
    // and `FlutterLocalNotificationsPlugin` has no instance in a headless test.
    // This is the app's own seam for standing in for it.
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async => database.close());

  /// An enabled schedule with real times, so the screen gets past its own
  /// "add at least one reminder time" guard.
  Future<void> seedEnabledConfig({bool pauseWhenGoalReached = true}) async {
    await CleanStorageService.saveWaterReminderConfig(WaterReminderConfig(
      enabled: true,
      startHour: 8,
      startMinute: 0,
      endHour: 22,
      endMinute: 0,
      intervalMinutes: 120,
      reminderMinutes: const [8 * 60, 12 * 60, 16 * 60, 20 * 60],
      pauseWhenGoalReached: pauseWhenGoalReached,
    ));
  }

  Future<void> openScreen(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    // Tall enough that Save is laid out and hit-testable without scrolling.
    tester.view.physicalSize = const Size(400, 3200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const WaterReminderSettingsScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text('Save Water Reminders'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a fluid restriction is explained, not reported as a success',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await WaterService.init();
      await WaterService.saveProfile(HydrationProfile(
        id: 'profile',
        createdAt: now,
        fluidCeilingMl: 1500,
      ));
      await seedEnabledConfig();

      await openScreen(tester);
      await tapSave(tester);

      expect(find.textContaining('0 water reminders scheduled'), findsNothing,
          reason: 'nothing was armed — reporting it as a success is the '
              'defect');
      expect(
          find.textContaining('reminders stay off while a fluid limit is set'),
          findsOneWidget,
          reason: 'the reason is knowable here and the user needs it: their '
              'prescribed limit is why the nudges are off');
    });
  });

  testWidgets('a met goal pauses even with pauseWhenGoalReached OFF',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await WaterService.init();
      final water = WaterService.getBeverage('water')!;
      final goal = WaterService.getDailyGoal();
      await WaterService.addWaterLog(amountMl: goal + 500, beverage: water);
      expect(WaterService.getTodayData().goalReached, isTrue);
      // Deliberately OFF. The old branch only explained the zero when this was
      // on, but `_pruneToRemainingNeed` returns an empty schedule whenever the
      // remaining gap is zero — so the toggle being off was a second, silent
      // route to "0 water reminders scheduled" as a success.
      await seedEnabledConfig(pauseWhenGoalReached: false);

      await openScreen(tester);
      await tapSave(tester);

      expect(find.textContaining('0 water reminders scheduled'), findsNothing);
      expect(find.textContaining('paused until tomorrow'), findsOneWidget);
    });
  });
}
