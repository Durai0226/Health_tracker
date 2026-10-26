import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/refill_loop.dart';
import 'package:tablet_remainder/features/medication/services/refill_reminder_service.dart';
import 'package:tablet_remainder/features/medication/widgets/refill_request_sheet.dart';

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RefillLoop (pure)', () {
    test('the follow-up is 10:00, two days after the request', () {
      expect(RefillLoop.followUpAt(DateTime(2026, 3, 7, 15, 42)),
          DateTime(2026, 3, 9, 10));
    });

    test('and rolls over month and year ends', () {
      expect(RefillLoop.followUpAt(DateTime(2026, 2, 27, 9)),
          DateTime(2026, 3, 1, 10));
      expect(RefillLoop.followUpAt(DateTime(2026, 12, 31, 23, 59)),
          DateTime(2027, 1, 2, 10));
    });

    test('follow-up ids stay in their own block, clear of the run-out ids', () {
      for (final id in ['a', 'metformin-1', '0000-1111', 'x' * 200]) {
        final f = RefillLoop.followUpIdFor(id);
        expect(f, inInclusiveRange(851000, 851999), reason: id);
        expect(f, isNot(RefillReminderService.notificationIdFor(id)),
            reason: id);
        expect(RefillReminderService.notificationIdFor(id),
            inInclusiveRange(850000, 850999));
      }
      expect(RefillLoop.followUpIdFor('m1'), RefillLoop.followUpIdFor('m1'));
    });

    test('a refill payload round-trips; others are not refills', () {
      expect(RefillLoop.medicineIdFromPayload(RefillLoop.payloadFor('m-42')),
          'm-42');
      expect(RefillLoop.medicineIdFromPayload('alarm:{"id":1}'), isNull);
      expect(RefillLoop.medicineIdFromPayload('refill:'), isNull);
      expect(RefillLoop.medicineIdFromPayload(null), isNull);
    });
  });

  group('with a database and a recording scheduler', () {
    late AppDatabase db;
    late RecordingNotificationScheduler scheduler;

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
    });

    tearDown(() async => db.close());

    final now = DateTime(2026, 3, 10, 9);

    EnhancedMedicine med({String? pharmacyId, int stock = 30}) => EnhancedMedicine(
          id: 'm1',
          name: 'Metformin',
          strength: '500mg',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          currentStock: stock,
          refillReminderEnabled: true,
          pharmacyId: pharmacyId,
          prescriptionNumber: 'RX-77',
          createdAt: DateTime(2026, 2, 1),
          schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)],
            startDate: DateTime(2026, 2, 1),
          ),
        );

    test('asking arms a follow-up that opens the sheet', () async {
      await RefillLoop.markRequested('m1', 'Metformin', now: now);
      expect(RefillRequestState.requestedAt('m1'), now);
      final s = scheduler.scheduled.single;
      expect(s.id, RefillLoop.followUpIdFor('m1'));
      expect(s.payload, 'refill:m1');
      expect(s.title, 'Picked up Metformin?');
      expect(s.when.isAtSameMomentAs(DateTime(2026, 3, 12, 10)), isTrue,
          reason: '10:00 local, two days after the request');
    });

    test('adding stock — by any route — ends the loop', () async {
      await MedicineCleanStorageService.saveMedicine(med());
      await RefillLoop.markRequested('m1', 'Metformin', now: now);
      scheduler.cancelled.clear();

      await MedicineCleanStorageService.refillStock('m1', 30);

      expect(RefillRequestState.requestedAt('m1'), isNull);
      expect(scheduler.cancelled, contains(RefillLoop.followUpIdFor('m1')),
          reason: 'a "did you pick it up?" after they already did is a lie');
      expect(
          (await MedicineCleanStorageService.getMedicine('m1'))!.currentStock,
          60);
    });

    Future<void> seedHistory() async {
      await MedicineCleanStorageService.saveMedicine(med(stock: 40));
      // 21 days of one dose a day, so the predictor has a rate to work with.
      for (var i = 1; i <= 21; i++) {
        final slot = DateTime(2026, 3, 10 - i, 8);
        await MedicineCleanStorageService.addLog(MedicineLog.taken(
            id: MedicineCleanStorageService.doseLogId('m1', slot),
            medicineId: 'm1',
            scheduledTime: slot,
            actionTime: slot));
      }
    }

    test('the run-out reminder opens the sheet when tapped', () async {
      await withClock(Clock.fixed(now), () async {
        await seedHistory();
        final armed = await RefillReminderService.rescheduleAll();
        expect(armed, 1, reason: 'sanity: this fixture should produce a reminder');
        expect(scheduler.scheduled.single.payload, 'refill:m1');
      });
    });

    group('the run-out reminder follows the stock', () {
      DateTime? armedFor() => scheduler.scheduled.lastWhere(
          (x) => x.id == RefillReminderService.notificationIdFor('m1')).when;

      test('stock added moves it later, without waiting for an app start',
          () async {
        await withClock(Clock.fixed(now), () async {
          await seedHistory();
          await RefillReminderService.rescheduleAll();
          final before = armedFor()!;

          await MedicineCleanStorageService.refillStock('m1', 100);
          await pumpEventQueue(times: 100);

          expect(armedFor()!.isAfter(before), isTrue,
              reason: '100 more tablets push the run-out date out');
        });
      });

      test('a dose taken moves it earlier', () async {
        await withClock(Clock.fixed(now), () async {
          await seedHistory();
          await RefillReminderService.rescheduleAll();
          final before = armedFor()!;

          await MedicineCleanStorageService.reduceStock('m1', 10);
          await pumpEventQueue(times: 100);

          expect(armedFor()!.isBefore(before), isTrue);
        });
      });

      test('undoing a dose puts it back', () async {
        await withClock(Clock.fixed(now), () async {
          await seedHistory();
          await RefillReminderService.rescheduleAll();
          final before = armedFor()!;
          await MedicineCleanStorageService.reduceStock('m1', 10);
          await pumpEventQueue(times: 100);
          await MedicineCleanStorageService.restoreStock('m1', 10);
          await pumpEventQueue(times: 100);
          expect(armedFor()!.isAtSameMomentAs(before), isTrue);
        });
      });

      test('a medicine with a refill already asked for stays quiet', () async {
        await withClock(Clock.fixed(now), () async {
          await seedHistory();
          await RefillLoop.markRequested('m1', 'Metformin', now: now);
          scheduler.scheduled.clear();
          await MedicineCleanStorageService.reduceStock('m1', 5);
          await pumpEventQueue(times: 100);
          expect(
              scheduler.scheduled.where(
                  (x) => x.id == RefillReminderService.notificationIdFor('m1')),
              isEmpty);
        });
      });
    });

    test('once a refill is asked for, the run-out reminder is not re-armed',
        () async {
      await withClock(Clock.fixed(now), () async {
        await seedHistory();
        await RefillLoop.markRequested('m1', 'Metformin', now: now);
        scheduler.scheduled.clear();
        final armed = await RefillReminderService.rescheduleAll();
        expect(armed, 0);
        expect(scheduler.scheduled, isEmpty);
      });
    });
  });

  group('RefillRequestForm', () {
    EnhancedMedicine medicine() => EnhancedMedicine(
          id: 'm1',
          name: 'Metformin',
          strength: '500mg',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          currentStock: 5,
          refillReminderEnabled: true,
          prescriptionNumber: 'RX-77',
          schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)],
          ),
        );

    Pharmacy pharmacy({String? phone = '+91 98765 43210', String? email}) =>
        Pharmacy(id: 'p1', name: 'City Pharmacy', phone: phone, email: email);

    Widget host(Widget child) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );

    Future<(List<Uri>, List<RefillAction?>)> pump(
      WidgetTester tester, {
      Pharmacy? pharmacy,
      DateTime? requestedAt,
      bool launchOk = true,
    }) async {
      final launched = <Uri>[];
      final done = <RefillAction?>[];
      await tester.pumpWidget(host(RefillRequestForm(
        medicine: medicine(),
        pharmacy: pharmacy,
        requestedAt: requestedAt,
        launch: (u) async {
          launched.add(u);
          return launchOk;
        },
        onDone: done.add,
      )));
      return (launched, done);
    }

    test('dialable strips everything a dialler cannot take', () {
      expect(dialable('+91 98765-43210'), '+919876543210');
      expect(dialable('(022) 2345 6789'), '02223456789');
    });

    test('the message names the medicine, strength and prescription', () {
      expect(refillMessageFor(medicine()),
          contains('Metformin 500mg'));
      expect(refillMessageFor(medicine()), contains('Prescription RX-77'));
    });

    testWidgets('Call dials the pharmacy', (tester) async {
      final (launched, _) = await pump(tester, pharmacy: pharmacy());
      await tester.tap(find.text('Call City Pharmacy'));
      await tester.pump();
      expect(launched.single.scheme, 'tel');
      expect(launched.single.path, '+919876543210',
          reason: 'spaces in a saved number must not reach the dialler');
      expect(launched.single.toString(), 'tel:+919876543210');
    });

    testWidgets('Send a message pre-fills the request', (tester) async {
      final (launched, _) = await pump(tester, pharmacy: pharmacy());
      await tester.tap(find.text('Send a message'));
      await tester.pump();
      expect(launched.single.scheme, 'sms');
      expect(launched.single.queryParameters['body'], contains('Metformin'));
    });

    testWidgets('Email only appears when the pharmacy has one', (tester) async {
      await pump(tester, pharmacy: pharmacy());
      expect(find.text('Email'), findsNothing);
      await pump(tester, pharmacy: pharmacy(email: 'rx@city.example'));
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('a refused launch says so', (tester) async {
      await pump(tester, pharmacy: pharmacy(), launchOk: false);
      await tester.tap(find.text('Call City Pharmacy'));
      await tester.pump();
      expect(find.text("Couldn't open that on this phone."), findsOneWidget);
    });

    testWidgets('with no pharmacy it explains, and still lets you proceed',
        (tester) async {
      final (_, done) = await pump(tester);
      expect(find.textContaining('No pharmacy is saved'), findsOneWidget);
      expect(find.textContaining('Call '), findsNothing);
      await tester.tap(find.text("I've asked for it"));
      expect(done, [RefillAction.requested]);
    });

    testWidgets('"Already picked up" skips the asking step', (tester) async {
      final (_, done) = await pump(tester, pharmacy: pharmacy());
      await tester.tap(find.text('Already picked up'));
      expect(done, [RefillAction.pickedUp]);
    });

    testWidgets('once asked, it shows when, and offers Picked up — not '
        '"I\'ve asked" again', (tester) async {
      final (_, done) =
          await pump(tester, pharmacy: pharmacy(), requestedAt: DateTime(2026, 3, 10));
      expect(find.text('You asked on Mar 10.'), findsOneWidget);
      expect(find.text("I've asked for it"), findsNothing);
      await tester.tap(find.text('Picked up'));
      expect(done, [RefillAction.pickedUp]);
    });
  });
}
