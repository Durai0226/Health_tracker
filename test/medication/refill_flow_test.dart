import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/home/screens/app_shell.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/refill_loop.dart';
import 'package:tablet_remainder/features/medication/widgets/refill_request_sheet.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
    RefillLoop.pendingOpen.value = null;
    await MedicineCleanStorageService.saveMedicine(EnhancedMedicine(
      id: 'm1',
      name: 'Metformin',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      currentStock: 30,
      refillReminderEnabled: true,
      createdAt: DateTime(2026, 2, 1),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
        startDate: DateTime(2026, 2, 1),
      ),
    ));
  });

  tearDown(() async {
    RefillLoop.pendingOpen.value = null;
    await db.close();
  });

  Future<void> openFlow(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => RefillRequestFlow.run(context, 'm1'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('ask, then come back and say picked up', (tester) async {
    await openFlow(tester);
    expect(find.text('Refill Metformin'), findsOneWidget);

    await tester.tap(find.text("I've asked for it"));
    await tester.pumpAndSettle();
    expect(RefillRequestState.requestedAt('m1'), isNotNull);
    expect(scheduler.scheduled.single.payload, 'refill:m1');

    // The follow-up (or the overview row) brings the person back.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Picked up'), findsOneWidget);
    expect(find.text("I've asked for it"), findsNothing);

    await tester.tap(find.text('Picked up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+30'));
    await tester.pumpAndSettle();

    expect(
        (await MedicineCleanStorageService.getMedicine('m1'))!.currentStock,
        60);
    expect(RefillRequestState.requestedAt('m1'), isNull);
    expect(scheduler.cancelled, contains(RefillLoop.followUpIdFor('m1')));
  });

  testWidgets('closing the sheet changes nothing', (tester) async {
    await openFlow(tester);
    await tester.tapAt(const Offset(10, 10)); // the scrim
    await tester.pumpAndSettle();
    expect(RefillRequestState.requestedAt('m1'), isNull);
    expect(scheduler.scheduled, isEmpty);
  });

  group('AppShell', () {
    /// Fixed frames, not `pumpAndSettle`. The seeded 08:00 medicine reads as
    /// OVERDUE on Today once the real clock passes eight, and the overdue state
    /// pulses forever — so a test that settled passed before 8am and timed out
    /// after it.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AppShell(),
        ));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 300));
      } finally {
        FlutterError.onError = prev;
      }
    }

    testWidgets('a refill reminder that cold-started the app opens the sheet',
        (tester) async {
      RefillLoop.pendingOpen.value = 'm1';
      await pumpShell(tester);
      await settle(tester);
      expect(find.text('Refill Metformin'), findsOneWidget);
      expect(RefillLoop.pendingOpen.value, isNull);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('while the app lock is engaged it waits for the unlock',
        (tester) async {
      final lock = AppLockService().isLockedNotifier;
      lock.value = true;
      addTearDown(() => lock.value = false);
      await pumpShell(tester);

      RefillLoop.pendingOpen.value = 'm1';
      await settle(tester);
      expect(find.text('Refill Metformin'), findsNothing,
          reason: 'health data must not open behind the PIN screen');

      lock.value = false;
      await settle(tester);
      expect(find.text('Refill Metformin'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('and one tapped while the app is open does too, every time',
        (tester) async {
      await pumpShell(tester);
      expect(find.text('Refill Metformin'), findsNothing);

      for (var i = 0; i < 2; i++) {
        RefillLoop.pendingOpen.value = 'm1';
        await settle(tester);
        expect(find.text('Refill Metformin'), findsOneWidget, reason: 'tap $i');
        await tester.tapAt(const Offset(10, 10));
        await settle(tester);
        expect(find.text('Refill Metformin'), findsNothing);
      }
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
