/// Cycle privacy: private reminder wording, leaving cycle data out of backups,
/// and deleting all of it.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show SettingsTile;
import 'package:tablet_remainder/features/backup/services/health_backup_serializer.dart';
import 'package:tablet_remainder/features/period/models/cycle_prediction.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/models/period_reminder_config.dart';
import 'package:tablet_remainder/features/period/models/period_settings.dart';
import 'package:tablet_remainder/features/period/screens/cycle_privacy_screen.dart';
import 'package:tablet_remainder/features/period/services/cycle_privacy.dart';
import 'package:tablet_remainder/features/period/services/period_reminder_service.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
    PeriodService.clearInMemory();
    await PeriodService.resetForTesting();
    await PeriodService.init();
  });

  tearDown(() async => db.close());

  /// A period started [daysAgo] days ago and the three cycles before it, so a
  /// prediction exists and its reminders land in the future.
  Future<void> seedCycles({int daysAgo = 5}) async {
    final today = DateTime.now();
    for (var i = 0; i < 4; i++) {
      final d = DateTime(today.year, today.month, today.day - daysAgo - 28 * i);
      await PeriodService.logDay(PeriodDay(
          id: PeriodDay.keyFor(d), date: d, flowIndex: 2));
    }
  }

  group('private reminders', () {
    const config = PeriodReminderConfig(
      periodSoonEnabled: true,
      pmsEnabled: true,
      logReminderEnabled: true,
      fertileEnabled: true,
    );
    final prediction = CyclePrediction(
      predictedStart: DateTime(2026, 6, 20),
      fertileStart: DateTime(2026, 6, 5),
      state: CycleState.ready,
      completedCycles: 6,
    );
    final now = DateTime(2026, 5, 1);

    List<PlannedReminder> plan({required bool private}) =>
        PeriodReminderPlanner.plan(
          prediction: prediction,
          mode: TrackingMode.ttc,
          config: config,
          now: now,
          private: private,
        );

    test('say only "Reminder", whichever reminder it is', () {
      final p = plan(private: true);
      expect(p, hasLength(4));
      for (final r in p) {
        expect(r.title, 'Reminder');
        expect(r.body, 'Open the app to see it.');
      }
    });

    test('and nothing in them gives it away', () {
      for (final r in plan(private: true)) {
        final text = '${r.title} ${r.body}'.toLowerCase();
        for (final word in ['cycle', 'period', 'pms', 'fertile', 'log']) {
          expect(text, isNot(contains(word)));
        }
      }
    });

    test('off, the wording is what it always was', () {
      final titles = plan(private: false).map((r) => r.title);
      expect(titles, containsAll(['Cycle check-in', 'Fertile window']));
    });

    test('the same four reminders arm either way: only the words change', () {
      expect(plan(private: true).map((r) => (r.id, r.date)),
          plan(private: false).map((r) => (r.id, r.date)));
    });

    test('switching it on re-arms what is already set, in the new words',
        () async {
      await seedCycles();
      await PeriodReminderService.saveConfig(
          const PeriodReminderConfig(periodSoonEnabled: true));
      final before = scheduler.scheduled.lastWhere((s) => s.id == 990001);
      expect(before.title, 'Cycle check-in');

      await CyclePrivacy.setPrivateNotifications(true);

      final after = scheduler.scheduled.lastWhere((s) => s.id == 990001);
      expect(after.title, 'Reminder');
      expect(after.body, 'Open the app to see it.');

      await CyclePrivacy.setPrivateNotifications(false);
      expect(scheduler.scheduled.lastWhere((s) => s.id == 990001).title,
          'Cycle check-in');
    });
  });

  group('backups', () {
    test('include cycle data by default', () async {
      await seedCycles();
      final json = await HealthBackupSerializer.exportJson();
      expect(json.containsKey(HealthBackupSerializer.periodKey), isTrue);
      final days = (json[HealthBackupSerializer.periodKey] as Map)['days'] as List;
      expect(days, hasLength(4));
    });

    test('leave it out entirely when asked, and keep the rest', () async {
      await seedCycles();
      await CyclePrivacy.setExcludeFromBackups(true);

      final json = await HealthBackupSerializer.exportJson();

      expect(json.containsKey(HealthBackupSerializer.periodKey), isFalse,
          reason: 'absent, not empty: a restore of this file then leaves any '
              'cycle data on the device as it is');
      expect(json.containsKey(HealthBackupSerializer.sleepKey), isTrue);
      expect(json.containsKey(HealthBackupSerializer.stepsKey), isTrue);
    });

    test('and switching it off puts it back', () async {
      await seedCycles();
      await CyclePrivacy.setExcludeFromBackups(true);
      await CyclePrivacy.setExcludeFromBackups(false);
      final json = await HealthBackupSerializer.exportJson();
      expect(json.containsKey(HealthBackupSerializer.periodKey), isTrue);
    });
  });

  group('delete all cycle data', () {
    test('removes the days, the cycles and the settings, from disk and memory',
        () async {
      await seedCycles();
      await PeriodService.saveSettings(PeriodService.getSettings()
          .copyWith(typicalCycleLength: 33, trackingMode: TrackingMode.ttc));
      expect(PeriodService.days, isNotEmpty);
      expect(PeriodService.getCycles(), isNotEmpty);

      await PeriodService.deleteAllCycleData();

      expect(PeriodService.days, isEmpty);
      expect(PeriodService.getCycles(), isEmpty);
      expect(PeriodService.getSettings().typicalCycleLength, 28);
      expect(PeriodService.getSettings().trackingMode, TrackingMode.tracking);
      expect(PeriodService.getPrediction().state, CycleState.onboarding);

      // On disk, and not as tombstones: a soft-deleted row keeps the date and
      // the flow.
      expect(await db.select(db.periodDays).get(), isEmpty);
      expect(await db.select(db.menstrualCycles).get(), isEmpty);
      expect(await db.select(db.periodSettingsTable).get(), isEmpty);
    });

    test('takes the reminders down with it', () async {
      await seedCycles();
      await PeriodReminderService.saveConfig(
          const PeriodReminderConfig(periodSoonEnabled: true));
      expect(scheduler.armedIds, contains(990001));
      scheduler.clear();

      await PeriodService.deleteAllCycleData();

      expect(scheduler.armedIds, isEmpty,
          reason: 'there is nothing left to predict from');
      expect(scheduler.cancelled, contains(990001));
    });

    test('is a no-op, not an error, when there is nothing', () async {
      await PeriodService.deleteAllCycleData();
      expect(PeriodService.days, isEmpty);
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 1800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const CyclePrivacyScreen()));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpFor(WidgetTester tester, [int n = 6]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    bool on(WidgetTester tester, String title) => tester
        .widget<SettingsTile>(find.widgetWithText(SettingsTile, title))
        .switchValue!;

    testWidgets('says what is stored and where', (tester) async {
      await seedCycles();
      await open(tester);
      // Four period starts: three completed cycles and the one now open.
      expect(find.textContaining('4 logged days and 4 cycles, on this device.'),
          findsOneWidget);
      expect(find.textContaining('goes into a backup file'), findsOneWidget);
    });

    testWidgets('with nothing logged it says so, and offers nothing to delete',
        (tester) async {
      await open(tester);
      expect(find.text('Nothing logged.'), findsOneWidget);
      final tile = tester.widget<SettingsTile>(
          find.widgetWithText(SettingsTile, 'Delete all cycle data'));
      expect(tile.onTap, isNull);
    });

    testWidgets('both switches start off, and each does what it says',
        (tester) async {
      await open(tester);
      expect(on(tester, 'Private reminders'), isFalse);
      expect(on(tester, 'Leave out of backups'), isFalse);

      await tester.tap(find.widgetWithText(SettingsTile, 'Private reminders'));
      await pumpFor(tester);
      expect(CyclePrivacy.privateNotifications, isTrue);
      expect(on(tester, 'Private reminders'), isTrue);

      await tester.tap(find.widgetWithText(SettingsTile, 'Leave out of backups'));
      await pumpFor(tester);
      expect(CyclePrivacy.excludeFromBackups, isTrue);
      expect(find.textContaining('left out of backup files'), findsOneWidget);
    });

    testWidgets('deleting asks first, and Cancel keeps everything',
        (tester) async {
      await seedCycles();
      await open(tester);

      await tester.tap(find.text('Delete all cycle data'));
      await pumpFor(tester);
      expect(find.text('Delete all cycle data?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await pumpFor(tester);
      expect(PeriodService.days, isNotEmpty);
    });

    testWidgets('and confirming removes it', (tester) async {
      await seedCycles();
      await open(tester);

      await tester.tap(find.text('Delete all cycle data'));
      await pumpFor(tester);
      // The section is called "Delete" too; the confirm button is the last.
      await tester.tap(find.text('Delete').last);
      await pumpFor(tester, 10);

      expect(PeriodService.days, isEmpty);
      expect(find.text('Nothing logged.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
