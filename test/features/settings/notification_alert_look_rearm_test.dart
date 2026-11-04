/// Changing how alerts look reaches the reminders already waiting.
///
/// Vibration, Keep on screen and Full-screen alerts are fixed into a scheduled
/// notification when it is armed: the channel and the flags travel with it. A
/// reminder armed on the generic path — weekly, weekdays, custom — and then
/// affected by a change in Settings kept its old look until something armed it
/// again, which was the next start of the app. So the switch appeared to do
/// nothing. A new alarm reads the preferences when it rings and was never affected.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/models/user_settings.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/features/settings/screens/notification_settings_screen.dart';

import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // What the screen arms again with, before any test replaces it.
  final defaultRearm = NotificationSettingsScreen.rearmReminders;
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late int rearms;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    rearms = 0;
    NotificationSettingsScreen.rearmReminders = () async => rearms++;
  });

  tearDown(() async {
    NotificationSettingsScreen.rearmReminders =
        ReminderRescheduleService.rearmReminders;
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: NotificationSettingsScreen()));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  /// Taps the row and lets the debounced write, and what follows it, finish.
  Future<void> toggle(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  test('what the screen arms again by default is the re-arm, not the whole start-up pass',
      () {
    // The start-up pass opens by closing out past-due doses as missed; a switch is not
    // a reason to move the adherence numbers under the person looking at it.
    expect(defaultRearm, ReminderRescheduleService.rearmReminders);
    expect(defaultRearm, isNot(ReminderRescheduleService.rescheduleAllReminders));
  });

  group('which changes count', () {
    final base = UserSettings();

    test('vibration, keeping it on screen, and full-screen: each does', () {
      expect(
          NotificationSettingsScreen.alertLookChanged(
              base, base.copyWith(vibrationEnabled: !base.vibrationEnabled)),
          isTrue);
      expect(
          NotificationSettingsScreen.alertLookChanged(base,
              base.copyWith(persistentNotification: !base.persistentNotification)),
          isTrue);
      expect(
          NotificationSettingsScreen.alertLookChanged(base,
              base.copyWith(fullScreenNotification: !base.fullScreenNotification)),
          isTrue);
    });

    test('so does the lock screen: a reminder armed with its text there keeps showing it', () {
      // Armed through `zonedSchedule`, its visibility is fixed when it is armed; a
      // person who turns "Show on lock screen" off for privacy must not find "Take
      // sertraline" still there until the next time the app starts.
      expect(
          NotificationSettingsScreen.alertLookChanged(
              base, base.copyWith(showOnLockScreen: !base.showOnLockScreen)),
          isTrue);
    });

    test('and sound, which an iPhone fixes into what is armed', () {
      expect(
          NotificationSettingsScreen.alertLookChanged(
              base, base.copyWith(soundEnabled: !base.soundEnabled)),
          isTrue);
    });

    test('snoozing does not: it is read when the snooze is asked for', () {
      expect(
          NotificationSettingsScreen.alertLookChanged(
              base, base.copyWith(snoozeIntervalMinutes: 15, maxSnoozeCount: 5)),
          isFalse);
    });

    test('nothing changed is not a change', () {
      expect(NotificationSettingsScreen.alertLookChanged(base, base.copyWith()), isFalse);
    });
  });

  group('what the Alerts footer says', () {
    testWidgets('that Vibration off uses a separate entry, which starts with the defaults',
        (tester) async {
      // On Android vibration belongs to the channel, so "off" is a second channel in
      // the phone's own settings — which does not inherit a mute or a sound the person
      // set on the first. Said where they choose, not found out afterwards.
      await open(tester);

      expect(find.textContaining('"(no vibration)"'), findsOneWidget);
      expect(find.textContaining('starts with the app\'s own settings'), findsOneWidget);
    });
  });

  group('on the screen', () {
    testWidgets('Vibration re-arms the waiting reminders, once', (tester) async {
      await open(tester);

      await toggle(tester, 'Vibration');

      expect(rearms, 1);
      expect(CleanStorageService.getUserSettings().vibrationEnabled, isFalse,
          reason: 'and it is saved BEFORE they are re-armed, which is what they read');
    });

    testWidgets('so do Keep on screen and Full-screen alerts', (tester) async {
      await open(tester);

      await toggle(tester, 'Keep on screen');
      expect(rearms, 1);
      await toggle(tester, 'Full-screen alerts');
      expect(rearms, 2);
    });

    testWidgets('and so do Lock screen and Sound, which are fixed into what is armed',
        (tester) async {
      await open(tester);

      await toggle(tester, 'Lock screen');
      expect(rearms, 1, reason: 'a reminder armed with its text on the lock screen');
      await toggle(tester, 'Sound');
      expect(rearms, 2);
    });

    testWidgets('Mark as missed does not: it is read when the time comes', (tester) async {
      await open(tester);

      await toggle(tester, 'Mark as missed');

      expect(rearms, 0);
    });

    testWidgets('two switches inside the one debounce are one re-arm', (tester) async {
      await open(tester);

      await tester.tap(find.text('Vibration'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Keep on screen'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(rearms, 1);
      final saved = CleanStorageService.getUserSettings();
      expect(saved.vibrationEnabled, isFalse);
      expect(saved.persistentNotification, isFalse);
    });

    testWidgets('a re-arm that fails does not take the screen with it', (tester) async {
      NotificationSettingsScreen.rearmReminders = () async => throw StateError('no scheduler');
      await open(tester);

      await toggle(tester, 'Vibration');

      expect(tester.takeException(), isNull);
      expect(CleanStorageService.getUserSettings().vibrationEnabled, isFalse,
          reason: 'the choice is still saved');
    });
  });
}
