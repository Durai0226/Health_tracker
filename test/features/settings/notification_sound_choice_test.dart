/// Where a person picks which sound a kind of reminder uses.
///
/// The Notifications screen has Sound on or off and nothing else, so the water
/// reminder's sound — fixed by its Android channel, which only the phone's own
/// settings can change — looked unchangeable. An iPhone has no per-category sound
/// to pick, so the row is Android's.
library;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show SettingsTile;
import 'package:tablet_remainder/features/settings/screens/notification_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // What ships, kept before any test replaces it.
  final shippedOpen = NotificationSettingsScreen.openPhoneSettings;

  late AppDatabase db;
  var opened = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    NotificationSettingsScreen.rearmReminders = () async {};
    opened = 0;
    NotificationSettingsScreen.openPhoneSettings = () async {
      opened++;
      return true;
    };
  });

  tearDown(() async {
    NotificationSettingsScreen.rearmReminders =
        ReminderRescheduleService.rearmReminders;
    NotificationSettingsScreen.openPhoneSettings = shippedOpen;
    await db.close();
  });

  /// Opens the screen as [android] or an iPhone. The platform override is reset
  /// inside the test body: the framework checks it is unset BEFORE any tearDown.
  void onPlatform(String name,
      {required bool android, required Future<void> Function(WidgetTester) body}) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride =
          android ? TargetPlatform.android : TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(1000, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
            const MaterialApp(home: NotificationSettingsScreen()));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  onPlatform('on Android the row opens the phone\'s settings for the app',
      android: true, body: (tester) async {
    await tester.tap(find.widgetWithText(SettingsTile, 'Choose sounds'));
    await tester.pump();

    expect(opened, 1);
  });

  onPlatform('and the section says where the sound is picked',
      android: true, body: (tester) async {
    expect(find.textContaining('which sound each kind of reminder uses'),
        findsOneWidget);
  });

  onPlatform('on an iPhone there is nothing to choose, so no row',
      android: false, body: (tester) async {
    expect(find.text('Choose sounds'), findsNothing);
    expect(find.textContaining('which sound each kind of reminder uses'),
        findsNothing);
    expect(find.widgetWithText(SettingsTile, 'Sound'), findsOneWidget,
        reason: 'the on/off switch stays on both');
  });
}
