/// "Your visit brief is ready": the notice two days before a visit, and the tap
/// that opens the brief.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/home/screens/app_shell.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/visit_brief_screen.dart';
import 'package:tablet_remainder/features/medication/services/appointment_reminder_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/visit_brief_link.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/font_free_theme.dart';
import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;
  final now = DateTime(2026, 6, 20, 15, 30);
  final visit = DateTime(2026, 6, 25, 10, 30);

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
    VisitBriefLink.pendingOpen.value = null;
  });

  tearDown(() async {
    VisitBriefLink.pendingOpen.value = null;
    await db.close();
  });

  Appointment appt({
    String id = 'a1',
    DateTime? at,
    bool reminder = true,
    bool done = false,
    String doctor = 'Dr Anand',
  }) =>
      Appointment(
        id: id,
        doctorName: doctor,
        dateTime: at ?? visit,
        reminderEnabled: reminder,
        isCompleted: done,
      );

  Future<void> arm(Appointment a) => withClock(Clock.fixed(now), () => AppointmentReminderService.schedule(a));

  RecordedSchedule? notice(String id) =>
      scheduler.lastFor(AppointmentReminderService.briefNotificationIdFor(id));

  group('the link', () {
    test('a payload names the appointment, and only a payload of ours does', () {
      expect(VisitBriefLink.payloadFor('a1'), 'visit:a1');
      expect(VisitBriefLink.appointmentIdFromPayload('visit:a1'), 'a1');
      expect(VisitBriefLink.appointmentIdFromPayload('refill:m1'), isNull);
      expect(VisitBriefLink.appointmentIdFromPayload('alarm:{}'), isNull);
      expect(VisitBriefLink.appointmentIdFromPayload(null), isNull);
      expect(VisitBriefLink.appointmentIdFromPayload('visit:'), isNull);
      expect(VisitBriefLink.appointmentIdFromPayload(''), isNull);
    });

    test('an id with a colon in it comes back whole', () {
      expect(VisitBriefLink.appointmentIdFromPayload('visit:a:b'), 'a:b');
    });
  });

  group('the notice', () {
    test('9:00 two days before, saying whose and when, and opening the brief', () async {
      await arm(appt());
      final n = notice('a1')!;
      expect(n.when.isAtSameMomentAs(DateTime(2026, 6, 23, 9)), isTrue,
          reason: '9:00 on the 23rd, two days before the 25th');
      expect(n.title, 'Your visit brief is ready');
      expect(n.body, 'Dr Anand, Thu, Jun 25. A summary to read before you go.');
      expect(n.payload, 'visit:a1');
    });

    test('and says nothing about health', () async {
      await arm(appt());
      final n = notice('a1')!;
      for (final word in ['dose', 'blood', 'glucose', 'adherence', 'medicine', 'missed']) {
        expect('${n.title} ${n.body}'.toLowerCase(), isNot(contains(word)));
      }
    });

    test('its own id, not the reminder\'s', () {
      expect(AppointmentReminderService.briefNotificationIdFor('a1'),
          isNot(AppointmentReminderService.notificationIdFor('a1')));
      expect(AppointmentReminderService.briefNotificationIdFor('a1'),
          isNot(AppointmentReminderService.briefNotificationIdFor('a2')));
      expect(AppointmentReminderService.briefNotificationIdFor('a1'), isNonNegative);
    });

    test('not with the appointment\'s reminder switched off', () async {
      await arm(appt(reminder: false));
      expect(notice('a1'), isNull);
    });

    test('not for a visit marked done', () async {
      await arm(appt(done: true));
      expect(notice('a1'), isNull);
    });

    test('not when two days before has already passed', () async {
      await arm(appt(at: DateTime(2026, 6, 21, 10, 30)));
      expect(notice('a1'), isNull);
    });

    test('and not for a visit in the past', () async {
      await arm(appt(at: DateTime(2026, 6, 1, 10, 30)));
      expect(notice('a1'), isNull);
    });

    test('saving again re-arms it, after cancelling the old one', () async {
      await arm(appt());
      scheduler.clear();
      await arm(appt(at: DateTime(2026, 6, 27, 10, 30)));
      final id = AppointmentReminderService.briefNotificationIdFor('a1');
      final cancel = scheduler.sequence.indexOf('cancel:$id');
      final armed = scheduler.sequence.indexWhere((e) => e.startsWith('arm:$id@'));
      expect(cancel, isNonNegative);
      expect(armed, greaterThan(cancel), reason: 'the old one goes before the new one comes');
      expect(notice('a1')!.when.isAtSameMomentAs(DateTime(2026, 6, 25, 9)), isTrue);
    });

    test('turning the reminder off takes the notice away', () async {
      await arm(appt());
      scheduler.clear();
      await arm(appt(reminder: false));
      expect(scheduler.cancelled,
          contains(AppointmentReminderService.briefNotificationIdFor('a1')));
      expect(notice('a1'), isNull);
    });

    test('deleting the appointment takes both away', () async {
      await AppointmentReminderService.cancelById('a1');
      expect(
          scheduler.cancelled,
          containsAll([
            AppointmentReminderService.notificationIdFor('a1'),
            AppointmentReminderService.briefNotificationIdFor('a1'),
          ]));
    });

    test('and saving an appointment through the store arms it', () async {
      await withClock(Clock.fixed(now), () async {
        await MedicineCleanStorageService.addAppointment(appt(),
            stampActiveProfile: false);
      });
      expect(notice('a1'), isNotNull);
    });
  });

  group('the tap, as the notification plugin reports it', () {
    NotificationResponse tap(String? payload) => NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload);

    test('on the notice sets what to open', () {
      NotificationService().onNotificationResponseForTesting(tap('visit:a1'));
      expect(VisitBriefLink.pendingOpen.value, 'a1');
    });

    test('and leaves other payloads alone', () {
      NotificationService().onNotificationResponseForTesting(tap('refill:m1'));
      expect(VisitBriefLink.pendingOpen.value, isNull);
      NotificationService().onNotificationResponseForTesting(tap(null));
      expect(VisitBriefLink.pendingOpen.value, isNull);
    });
  });

  group('the tap', () {
    Future<void> frames(WidgetTester tester, [int n = 12]) async {
      for (var i = 0; i < n; i++) {
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
        await tester.pumpWidget(MaterialApp(theme: fontFreeTheme(), home: const AppShell()));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 300));
      } finally {
        FlutterError.onError = prev;
      }
    }

    Future<void> saveVisit() => MedicineCleanStorageService.addAppointment(
        appt(reminder: false), stampActiveProfile: false);

    testWidgets('a notice that started the app opens the brief', (tester) async {
      await tester.runAsync(saveVisit);
      VisitBriefLink.pendingOpen.value = 'a1';
      await pumpShell(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await frames(tester);
      expect(find.byType(VisitBriefScreen), findsOneWidget);
      expect(VisitBriefLink.pendingOpen.value, isNull);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('one tapped while the app is open does too', (tester) async {
      await tester.runAsync(saveVisit);
      await pumpShell(tester);
      expect(find.byType(VisitBriefScreen), findsNothing);
      VisitBriefLink.pendingOpen.value = 'a1';
      await frames(tester, 4);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await frames(tester);
      expect(find.byType(VisitBriefScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('while the app lock is engaged it waits for the unlock', (tester) async {
      await tester.runAsync(saveVisit);
      final lock = AppLockService().isLockedNotifier;
      lock.value = true;
      addTearDown(() => lock.value = false);
      await pumpShell(tester);

      VisitBriefLink.pendingOpen.value = 'a1';
      await frames(tester, 4);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await frames(tester);
      expect(find.byType(VisitBriefScreen), findsNothing,
          reason: 'health data must not open behind the PIN screen');

      lock.value = false;
      await frames(tester, 4);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await frames(tester);
      expect(find.byType(VisitBriefScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('for a visit deleted since, nothing opens', (tester) async {
      await pumpShell(tester);
      VisitBriefLink.pendingOpen.value = 'gone';
      await frames(tester, 4);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await frames(tester);
      expect(find.byType(VisitBriefScreen), findsNothing);
      expect(VisitBriefLink.pendingOpen.value, isNull);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
