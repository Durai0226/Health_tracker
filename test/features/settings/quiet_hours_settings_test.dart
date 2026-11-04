/// Quiet hours have a home in Notifications: switch them, set them, follow the
/// sleep schedule.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/quiet_window.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show SettingsTile;
import 'package:tablet_remainder/features/reminders/services/quiet_hours.dart';
import 'package:tablet_remainder/features/settings/screens/notification_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  var rearmed = 0;

  Future<void> boot() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    rearmed = 0;
    NotificationSettingsScreen.rearmReminders = () async => rearmed++;
  }

  tearDown(() async {
    NotificationSettingsScreen.rearmReminders =
        ReminderRescheduleService.rearmReminders;
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: NotificationSettingsScreen()));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  Finder row(String title) => find.widgetWithText(SettingsTile, title);
  bool on(WidgetTester tester) =>
      tester.widget<SettingsTile>(row('Quiet hours')).switchValue!;

  Future<void> toggle(WidgetTester tester) async {
    await tester.tap(row('Quiet hours'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('is there, off, with no times until it is on', (tester) async {
    await boot();
    await open(tester);

    expect(find.text('Quiet hours'), findsWidgets);
    expect(on(tester), isFalse);
    expect(row('From'), findsNothing);
    expect(row('Until'), findsNothing);
    expect(row('Use my sleep schedule'), findsNothing);
  });

  testWidgets('says what it holds and what it never does', (tester) async {
    await boot();
    await open(tester);

    expect(find.textContaining('Reminders you made, set to Normal, wait'),
        findsOneWidget);
    expect(find.textContaining('always arrive on time'), findsOneWidget);
    expect(find.textContaining('medicines'), findsWidgets);
  });

  testWidgets('turned on: kept, 10 PM to 7 AM offered, and reminders re-armed',
      (tester) async {
    await boot();
    await open(tester);

    await toggle(tester);

    expect(on(tester), isTrue);
    expect(QuietHours.enabled, isTrue);
    expect(QuietHours.window,
        const QuietWindow(startMinute: 22 * 60, endMinute: 7 * 60));
    expect(find.descendant(of: row('From'), matching: find.text('10:00 PM')),
        findsOneWidget);
    expect(find.descendant(of: row('Until'), matching: find.text('7:00 AM')),
        findsOneWidget);
    expect(rearmed, 1,
        reason: 'reminders already armed inside the window have to move');
  });

  testWidgets('turned off: recorded, the rows go, reminders re-armed', (tester) async {
    await boot();
    await open(tester);
    await toggle(tester);

    await toggle(tester);

    expect(on(tester), isFalse);
    expect(QuietHours.enabled, isFalse);
    expect(row('From'), findsNothing);
    expect(rearmed, 2);
  });

  testWidgets('an install that had it on opens with the switch on and its times',
      (tester) async {
    await boot();
    await QuietHours.save(
        enabled: true,
        window: const QuietWindow(startMinute: 23 * 60 + 15, endMinute: 6 * 60 + 30));
    await open(tester);

    expect(on(tester), isTrue);
    expect(find.descendant(of: row('From'), matching: find.text('11:15 PM')),
        findsOneWidget);
    expect(find.descendant(of: row('Until'), matching: find.text('6:30 AM')),
        findsOneWidget);
  });

  testWidgets('"Use my sleep schedule" takes bedtime and wake time', (tester) async {
    await boot();
    await open(tester);
    await toggle(tester);

    await tester.tap(row('Use my sleep schedule'));
    await tester.pumpAndSettle();

    // The default schedule: bed at 10:30 PM, up at 7:00 AM.
    expect(QuietHours.window,
        const QuietWindow(startMinute: 22 * 60 + 30, endMinute: 7 * 60));
    expect(find.descendant(of: row('From'), matching: find.text('10:30 PM')),
        findsOneWidget);
    expect(rearmed, 2, reason: 'one for switching on, one for the new times');
  });

  testWidgets('the From row opens a picker, and Set time keeps the time',
      (tester) async {
    await boot();
    await QuietHours.save(
        enabled: true,
        window: const QuietWindow(startMinute: 21 * 60, endMinute: 6 * 60));
    await open(tester);

    await tester.tap(row('From'));
    await tester.pumpAndSettle();
    expect(find.text('Quiet hours start'), findsOneWidget);

    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();

    expect(QuietHours.window,
        const QuietWindow(startMinute: 21 * 60, endMinute: 6 * 60));
    expect(find.descendant(of: row('From'), matching: find.text('9:00 PM')),
        findsOneWidget);
  });

  testWidgets('the Until row names its own picker', (tester) async {
    await boot();
    await QuietHours.save(
        enabled: true,
        window: const QuietWindow(startMinute: 21 * 60, endMinute: 6 * 60));
    await open(tester);

    await tester.tap(row('Until'));
    await tester.pumpAndSettle();

    expect(find.text('Quiet hours end'), findsOneWidget);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await boot();
    await QuietHours.save(
        enabled: true,
        window: const QuietWindow(startMinute: 21 * 60, endMinute: 6 * 60));
    await open(tester);

    await tester.tap(row('From'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(rearmed, 0);
    expect(QuietHours.window,
        const QuietWindow(startMinute: 21 * 60, endMinute: 6 * 60));
  });

  testWidgets('a start equal to the end is refused, and nothing is saved',
      (tester) async {
    await boot();
    // Stored with start == end (a hand-edited backup): picking "Set time" on
    // From would make the window zero-length.
    await QuietHours.save(
        enabled: true,
        window: const QuietWindow(startMinute: 420, endMinute: 420));
    await open(tester);

    await tester.tap(row('From'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();

    expect(find.textContaining('differ'), findsOneWidget);
    expect(rearmed, 0);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('if re-arming fails the choice is still kept', (tester) async {
    await boot();
    NotificationSettingsScreen.rearmReminders = () async => throw StateError('no');
    await open(tester);

    await toggle(tester);

    expect(on(tester), isTrue);
    expect(QuietHours.enabled, isTrue,
        reason: 'the next start of the app arms every reminder again');
    expect(find.textContaining("Couldn't change quiet hours"), findsNothing);
  });
}
