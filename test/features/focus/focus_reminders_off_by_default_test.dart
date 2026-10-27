/// Focus reminders are opt-in.
///
/// They were on for every install: the first completed session ran the
/// scheduler, whose defaults were `true`, and a daily 9:00 "Time to focus" (plus
/// a streak nudge) appeared that nobody had asked for. A reminder is a thing a
/// person agrees to, not a thing the app starts doing after they use a feature.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/focus/screens/settings/focus_reminders_settings_screen.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    FocusService().resetForTesting();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  tearDown(() async {
    FocusService().resetForTesting();
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 1600);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FocusRemindersSettingsScreen()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = prev;
    }
  }

  bool on(WidgetTester tester, String title) => tester
      .widget<SettingsTile>(find.widgetWithText(SettingsTile, title))
      .switchValue!;

  testWidgets('a new install has the daily reminder and the streak nudge off',
      (tester) async {
    await open(tester);

    expect(on(tester, 'Daily reminder'), isFalse);
    expect(find.text('Best hour'), findsNothing,
        reason: 'its options appear once the reminder is switched on');
    expect(find.text('Reminder time'), findsNothing);
    expect(scheduler.armedIds,
        isNot(contains(NotificationService.focusDailyReminderId)),
        reason: 'merely opening the screen must not arm anything');
  });

  testWidgets('switching it on arms it, and shows its options', (tester) async {
    await open(tester);

    await tester.tap(find.widgetWithText(SettingsTile, 'Daily reminder'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(on(tester, 'Daily reminder'), isTrue);
    expect(find.text('Best hour'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);
    expect(scheduler.armedIds,
        contains(NotificationService.focusDailyReminderId));
  });

  testWidgets('someone who already turned it on keeps it on', (tester) async {
    SharedPreferences.setMockInitialValues({'focus_daily_reminder': true});
    await open(tester);

    expect(on(tester, 'Daily reminder'), isTrue);
    expect(find.text('Reminder time'), findsOneWidget);
  });
}
