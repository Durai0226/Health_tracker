/// The Reminders screen's side of "Export reminder history": the button on the
/// adherence card, the question of how far back, and what the person is told when
/// there is nothing to share or sharing fails.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase, ReminderOccurrencesCompanion;
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/toast/toast_overlay.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_history_export.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 3, 14, 10);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    ActiveProfileService().resetForTesting();
    await ReminderService.instance.resetForTesting();
    ToastOverlay.instance.resetForTesting();
    ReminderHistoryExport.shareOverride = null;
  });

  tearDown(() async {
    ReminderHistoryExport.shareOverride = null;
    ToastOverlay.instance.resetForTesting();
    await ReminderService.instance.resetForTesting();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// A reminder with one finished occurrence [daysAgo] days back, so the
  /// adherence card — and the button on it — shows.
  Future<void> seed({int daysAgo = 2}) async {
    await CleanStorageService.saveReminder(Reminder(
      id: 'r-1',
      title: 'Call the bank',
      body: '',
      scheduledTime: DateTime(2026, 3, 14, 12),
      notificationId: 4242,
    ));
    final due = DateTime(2026, 3, 14 - daysAgo, 9);
    await db.remindersDao.recordOccurrence(ReminderOccurrencesCompanion.insert(
      id: RemindersDao.occurrenceId('r-1', due),
      reminderId: 'r-1',
      scheduledFor: due,
      outcome: Value(ReminderOutcome.done.name),
    ));
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const RemindersScreen(),
    ));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
  }

  testWidgets('the button is on the adherence card', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seed();
      await mount(tester);

      expect(find.byTooltip('Export reminder history'), findsOneWidget);
      await finish(tester);
    });
  });

  testWidgets('without any history there is no card, and so no button', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'r-1',
        title: 'Call the bank',
        body: '',
        scheduledTime: DateTime(2026, 3, 14, 12),
        notificationId: 4242,
      ));
      await mount(tester);

      expect(find.byTooltip('Export reminder history'), findsNothing);
      await finish(tester);
    });
  });

  testWidgets('it asks how far back, with the three choices', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seed();
      await mount(tester);

      await tester.tap(find.byTooltip('Export reminder history'));
      await settle(tester);

      expect(find.text('Export reminder history'), findsOneWidget);
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.text('Last 90 days'), findsOneWidget);
      expect(find.text('Everything'), findsOneWidget);
      expect(find.textContaining('a line for every time a reminder came due'),
          findsOneWidget);
      await finish(tester);
    });
  });

  testWidgets('a choice shares the file for that range', (tester) async {
    String? csv;
    String? name;
    ReminderHistoryExport.shareOverride = (c, n) async {
      csv = c;
      name = n;
    };
    await withClock(Clock.fixed(now), () async {
      await seed();
      await mount(tester);

      await tester.tap(find.byTooltip('Export reminder history'));
      await settle(tester);
      await tester.tap(find.text('Last 30 days'));
      await settle(tester);

      expect(name, 'dlyminder-reminders-20260314.csv');
      expect(csv, contains('Call the bank,2026-03-12 09:00,,,Done,0'));
      await finish(tester);
    });
  });

  testWidgets('each choice reaches the file as its own range', (tester) async {
    final shared = <String>[];
    ReminderHistoryExport.shareOverride = (c, _) async => shared.add(c);
    await withClock(Clock.fixed(now), () async {
      await seed();
      // And one that is two hundred days old: inside Everything only.
      final old = DateTime(2026, 3, 14 - 200, 9);
      await db.remindersDao.recordOccurrence(ReminderOccurrencesCompanion.insert(
        id: RemindersDao.occurrenceId('r-1', old),
        reminderId: 'r-1',
        scheduledFor: old,
        outcome: Value(ReminderOutcome.done.name),
      ));
      await mount(tester);

      for (final choice in ['Last 30 days', 'Last 90 days', 'Everything']) {
        await tester.tap(find.byTooltip('Export reminder history'));
        await settle(tester);
        await tester.tap(find.text(choice));
        await settle(tester);
      }

      expect(shared, hasLength(3));
      expect(shared[0], contains('2026-03-12'));
      expect(shared[0], isNot(contains('2025-08-26')), reason: '30 days');
      expect(shared[1], isNot(contains('2025-08-26')), reason: '90 days');
      expect(shared[2], contains('2025-08-26'), reason: 'everything');
      await finish(tester);
    });
  });

  testWidgets('closing the sheet shares nothing', (tester) async {
    var shared = false;
    ReminderHistoryExport.shareOverride = (_, _) async => shared = true;
    await withClock(Clock.fixed(now), () async {
      await seed();
      await mount(tester);

      await tester.tap(find.byTooltip('Export reminder history'));
      await settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);

      expect(shared, isFalse);
      expect(find.text('Last 30 days'), findsNothing);
      await finish(tester);
    });
  });

  testWidgets('nothing to share says so instead of sharing an empty file', (tester) async {
    var shared = false;
    ReminderHistoryExport.shareOverride = (_, _) async => shared = true;
    await withClock(Clock.fixed(now), () async {
      await seed();
      await mount(tester);
      // The card is up, and then the history is gone — as it would be if it were
      // cleared on another screen while this one was open.
      await db.delete(db.reminderOccurrences).go();

      await tester.tap(find.byTooltip('Export reminder history'));
      await settle(tester);
      await tester.tap(find.text('Last 30 days'));
      await settle(tester);

      expect(shared, isFalse);
      expect(find.text('No reminder history in that time.'), findsOneWidget);
      await finish(tester);
    });
  });

  testWidgets('and when sharing fails it says so', (tester) async {
    ReminderHistoryExport.shareOverride = (_, _) async => throw StateError('no share sheet');
    await withClock(Clock.fixed(now), () async {
      await seed();
      await mount(tester);

      await tester.tap(find.byTooltip('Export reminder history'));
      await settle(tester);
      await tester.tap(find.text('Everything'));
      await settle(tester);

      expect(find.textContaining("Couldn't create the file"), findsOneWidget);
      await finish(tester);
    });
  });
}
