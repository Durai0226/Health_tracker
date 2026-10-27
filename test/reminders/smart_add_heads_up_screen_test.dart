/// Smart Add hands a heads-up and "until done" to the form: the message says
/// what the reminder is early for, the time is the early one, and the Insistent
/// tier is already chosen. The parser is pinned in
/// `test/health/smart_add_heads_up_test.dart`; this is that it reaches the form.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  // Saturday 14 March 2026, 10:00.
  final now = DateTime(2026, 3, 14, 10, 0);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    ActiveProfileService().resetForTesting();
    await ReminderService.instance.resetForTesting();
  });

  tearDown(() async {
    await ReminderService.instance.resetForTesting();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// Open Smart Add on the Reminders screen, submit [phrase], and land on the
  /// prefilled form.
  Future<void> smartAdd(WidgetTester tester, String phrase) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const RemindersScreen(),
    ));
    await settle(tester);
    await tester.tap(find.byTooltip('Smart Add'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, phrase);
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(find.byType(AddReminderScreen), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Whether the escalation option called [label] is the selected one.
  bool selected(WidgetTester tester, String label) {
    final row = find.ancestor(
        of: find.text(label), matching: find.byType(GestureDetector)).first;
    return find
        .descendant(
            of: row, matching: find.byIcon(Symbols.radio_button_checked_rounded))
        .evaluate()
        .isNotEmpty;
  }

  testWidgets('a heads-up fills the early time and says what it is early for',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await smartAdd(tester, 'Dentist tomorrow 3pm 30 min before');

      expect(find.widgetWithText(TextField, 'Dentist'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'At 3:00 PM'), findsOneWidget,
          reason: 'the description says what the reminder is early for');
      expect(find.textContaining('2:30 PM'), findsWidgets,
          reason: 'the reminder itself is half an hour ahead');
      expect(selected(tester, 'Normal'), isTrue,
          reason: 'a heads-up alone does not change how insistent it is');
      await unmount(tester);
    });
  });

  testWidgets('"until done" selects the Insistent tier', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await smartAdd(tester, 'Pay the rent tomorrow 9am until done');

      expect(find.widgetWithText(TextField, 'Pay the rent'), findsOneWidget);
      expect(selected(tester, 'Insistent'), isTrue);
      expect(selected(tester, 'Normal'), isFalse);
      await unmount(tester);
    });
  });

  testWidgets('an ordinary phrase leaves the form as it always was',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await smartAdd(tester, 'Call the bank tomorrow 9am');

      expect(selected(tester, 'Normal'), isTrue);
      // Still showing its hint, which an empty field does and a filled one
      // does not.
      expect(find.widgetWithText(TextField, 'Add details...'), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('and what the form saves carries both through', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await smartAdd(tester, 'Dentist tomorrow 3pm 30 min before until done');
      await tester.ensureVisible(find.text('Create Reminder'));
      await tester.tap(find.text('Create Reminder'));
      await settle(tester);

      final saved = (await CleanStorageService.getAllReminders()).single;
      expect(saved.title, 'Dentist');
      expect(saved.body, 'At 3:00 PM');
      expect(saved.scheduledTime, DateTime(2026, 3, 15, 14, 30));
      expect(saved.escalation, ReminderEscalation.insistent);
      await unmount(tester);
    });
  });
}
