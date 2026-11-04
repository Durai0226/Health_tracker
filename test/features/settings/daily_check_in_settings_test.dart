/// The daily check-in has a home in Notifications: switch it, move it, stop it.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/daily_check_in.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show SettingsTile;
import 'package:tablet_remainder/features/settings/screens/notification_settings_screen.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  Future<void> boot([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  }

  tearDown(() async => db.close());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: NotificationSettingsScreen()));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  Finder row() => find.widgetWithText(SettingsTile, 'Daily check-in');

  bool on(WidgetTester tester) => tester.widget<SettingsTile>(row()).switchValue!;

  Future<void> toggle(WidgetTester tester) async {
    await tester.tap(row());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('is there, off, with no time row until it is on', (tester) async {
    await boot();
    await open(tester);

    expect(find.text('Daily check-in'), findsWidgets);
    expect(on(tester), isFalse);
    expect(find.widgetWithText(SettingsTile, 'Time'), findsNothing);
    expect(find.textContaining('One gentle nudge a day'), findsOneWidget);
  });

  testWidgets('turned on: armed at 09:00 by default, and the time is shown',
      (tester) async {
    await boot();
    await open(tester);

    await toggle(tester);

    expect(on(tester), isTrue);
    expect(await DailyCheckIn.isEnabled(), isTrue);
    final a = scheduler.lastFor(DailyCheckIn.notificationId)!;
    expect([a.when.hour, a.when.minute], [9, 0]);
    expect(find.widgetWithText(SettingsTile, 'Time'), findsOneWidget);
    expect(find.text('9:00 AM'), findsOneWidget);
  });

  testWidgets('turned on without the notification permission: it stays off and says why',
      (tester) async {
    await boot();
    NotificationService().permissionForTesting = () async => false;
    addTearDown(() => NotificationService().permissionForTesting = null);
    await open(tester);

    await toggle(tester);

    expect(on(tester), isFalse, reason: 'it would never be shown');
    expect(await DailyCheckIn.isEnabled(), isFalse);
    expect(scheduler.lastFor(DailyCheckIn.notificationId), isNull,
        reason: 'and nothing was armed');
    expect(find.textContaining('Notifications are off for DlyMinder'), findsOneWidget);
    expect(find.textContaining("Allow them in your phone's settings"), findsOneWidget,
        reason: 'and says what to do about it');
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('and with it granted it turns on as before', (tester) async {
    await boot();
    NotificationService().permissionForTesting = () async => true;
    addTearDown(() => NotificationService().permissionForTesting = null);
    await open(tester);

    await toggle(tester);

    expect(on(tester), isTrue);
    expect(scheduler.lastFor(DailyCheckIn.notificationId), isNotNull);
  });

  testWidgets('turning it OFF never asks: nothing to arm', (tester) async {
    await boot();
    await open(tester);
    await toggle(tester);
    var asked = 0;
    NotificationService().permissionForTesting = () async {
      asked++;
      return true;
    };
    addTearDown(() => NotificationService().permissionForTesting = null);

    await toggle(tester);

    expect(on(tester), isFalse);
    expect(asked, 0);
  });

  testWidgets('turned off: withdrawn, recorded, and the time row goes', (tester) async {
    await boot();
    await open(tester);
    await toggle(tester);
    scheduler.clear();

    await toggle(tester);

    expect(on(tester), isFalse);
    expect(await DailyCheckIn.isEnabled(), isFalse);
    expect(scheduler.cancelled, contains(DailyCheckIn.notificationId));
    expect(find.widgetWithText(SettingsTile, 'Time'), findsNothing);
  });

  testWidgets('an install that already had it armed opens with the switch on',
      (tester) async {
    await boot({'alarm_900001': '{"hour":9,"minute":0}'});
    await open(tester);

    expect(on(tester), isTrue);
    expect(find.widgetWithText(SettingsTile, 'Time'), findsOneWidget);
  });

  testWidgets('shows the time the setup recorded', (tester) async {
    await boot();
    await CleanStorageService.setAppPreference(DailyCheckIn.enabledKey, true);
    await CleanStorageService.setAppPreference(DailyCheckIn.hourKey, 20);
    await CleanStorageService.setAppPreference(DailyCheckIn.minuteKey, 30);
    await open(tester);

    expect(find.text('8:30 PM'), findsOneWidget);
  });

  testWidgets('the Time row opens the picker, and Set time arms it again',
      (tester) async {
    await boot();
    await CleanStorageService.setAppPreference(DailyCheckIn.enabledKey, true);
    await CleanStorageService.setAppPreference(DailyCheckIn.hourKey, 7);
    await CleanStorageService.setAppPreference(DailyCheckIn.minuteKey, 15);
    await open(tester);

    await tester.tap(find.widgetWithText(SettingsTile, 'Time'));
    await tester.pumpAndSettle();
    expect(find.text('Check-in time'), findsOneWidget);

    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();

    final a = scheduler.lastFor(DailyCheckIn.notificationId)!;
    expect([a.when.hour, a.when.minute], [7, 15]);
    expect(find.text('7:15 AM'), findsOneWidget);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await boot();
    await CleanStorageService.setAppPreference(DailyCheckIn.enabledKey, true);
    await open(tester);

    await tester.tap(find.widgetWithText(SettingsTile, 'Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(scheduler.scheduled, isEmpty);
  });
}
