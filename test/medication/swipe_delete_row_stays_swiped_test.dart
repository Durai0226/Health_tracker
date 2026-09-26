import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppCard;
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/models/clinic.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/nunito_appointment_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_clinic_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_doctor_list_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

/// QA — the three medication list screens that swipe-to-delete, held to the
/// rule the medicine list was fixed to (MED-UI-16).
///
/// All of them answered `confirmDismiss` with `false` on the same frame and
/// ran the delete unawaited, so the card sprang back to rest while its own
/// confirmation sheet was still open: a delete the user had just started read
/// as one that had failed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Appointment reminders are scheduled on save; without a stand-in they
    // reach the unregistered flutter_local_notifications channel.
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  /// Where the swiped row's card is actually painted. The Dismissible's own
  /// box never moves — the translation lives on its child.
  double cardLeft(WidgetTester tester, String id) => tester
      .getTopLeft(find.descendant(
        of: find.byKey(Key(id)),
        matching: find.byType(AppCard),
      ))
      .dx;

  Future<void> open(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
    await tester.pumpAndSettle();
  }

  /// Swipe the row away and assert it is still held open under its own sheet.
  Future<void> expectStaysSwiped(
      WidgetTester tester, String id, String rowText) async {
    final atRest = cardLeft(tester, id);
    await tester.drag(find.text(rowText), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsWidgets,
        reason: 'the swipe asks before deleting');
    expect(cardLeft(tester, id), lessThan(atRest - 100),
        reason: 'the row must not spring back to rest under its own '
            'confirmation sheet — that reads as a delete that failed');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  }

  testWidgets('a swiped doctor stays swiped while its delete is confirmed',
      (tester) async {
    await MedicineCleanStorageService.saveDoctor(
        Doctor(id: 'doc1', name: 'Rao', specialty: 'Cardiology'));
    await open(tester, const NunitoDoctorListScreen());

    await expectStaysSwiped(tester, 'doc1', 'Dr. Rao');
  });

  testWidgets('a swiped clinic stays swiped while its delete is confirmed',
      (tester) async {
    await MedicineCleanStorageService.saveClinic(
        Clinic(id: 'cl1', name: 'Northside Clinic'));
    await open(tester, const NunitoClinicListScreen());

    await expectStaysSwiped(tester, 'cl1', 'Northside Clinic');
  });

  testWidgets('a swiped appointment stays swiped while its delete is confirmed',
      (tester) async {
    await MedicineCleanStorageService.addAppointment(Appointment(
      id: 'ap1',
      doctorName: 'Dr Patel',
      dateTime: DateTime.now().add(const Duration(days: 3)),
    ));
    await open(tester, const NunitoAppointmentListScreen());

    await expectStaysSwiped(tester, 'ap1', 'Dr Patel');
  });
}
