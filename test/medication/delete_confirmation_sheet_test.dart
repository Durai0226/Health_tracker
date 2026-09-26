import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/medication/models/clinic.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/nunito_appointment_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_clinic_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_doctor_list_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// DS-13: the medication lists ask for a destructive confirmation through
/// [ConfirmationBottomSheet], not a raw `AlertDialog`.
///
/// The swap is only safe if the ANSWER survives it. `showDialog<bool>` and
/// `showModalBottomSheet<bool>` both resolve to `null` when the user escapes
/// without choosing, and every one of these call sites branches on
/// `confirm == true` — so the two failure modes worth a test are the two the
/// user can never undo: a swipe that quietly deletes a row nobody confirmed,
/// and a confirmed delete that quietly does nothing.
///
/// All three lists reach the sheet through `Dismissible.confirmDismiss`, which
/// returns false and lets the card spring back; the sheet, not the swipe, is
/// what deletes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() {
    // No network in a widget test: without this google_fonts tries to fetch
    // and the pump hangs on an unresolved font future.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  const size = Size(390, 844);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: size),
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Swipe a row end-to-start far enough to pass the dismiss threshold.
  Future<void> swipeToDelete(WidgetTester tester, Finder row) async {
    await tester.drag(row, const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  group('doctors', () {
    setUp(() async {
      await MedicineCleanStorageService.addDoctor(
        Doctor(id: 'doc-1', name: 'Ada Byron', specialty: 'Cardiology'),
      );
    });

    testWidgets('the swipe opens the app sheet, not an AlertDialog',
        (tester) async {
      await pump(tester, const NunitoDoctorListScreen());
      await swipeToDelete(tester, find.text('Dr. Ada Byron'));

      expect(find.byType(AppBottomSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Delete doctor?'), findsOneWidget);
      expect(find.text('Are you sure you want to delete Dr. Ada Byron?'),
          findsOneWidget);
    });

    testWidgets('dismissing the sheet by its barrier deletes nothing',
        (tester) async {
      await pump(tester, const NunitoDoctorListScreen());
      await swipeToDelete(tester, find.text('Dr. Ada Byron'));

      // The dialog this replaced was barrierDismissible, and the sheet must
      // stay escapable the same way — a tap on the scrim answers `null`, and
      // `null` is not a confirmation.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomSheet), findsNothing);
      expect(find.text('Dr. Ada Byron'), findsOneWidget);
      expect(await MedicineCleanStorageService.getAllDoctors(), hasLength(1));
    });

    testWidgets('Cancel deletes nothing', (tester) async {
      await pump(tester, const NunitoDoctorListScreen());
      await swipeToDelete(tester, find.text('Dr. Ada Byron'));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Ada Byron'), findsOneWidget);
      expect(await MedicineCleanStorageService.getAllDoctors(), hasLength(1));
    });

    testWidgets('Delete removes the doctor', (tester) async {
      await pump(tester, const NunitoDoctorListScreen());
      await swipeToDelete(tester, find.text('Dr. Ada Byron'));

      // Exact-text match, so this is the confirm button and not the
      // 'Delete doctor?' title above it.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await MedicineCleanStorageService.getAllDoctors(), isEmpty);
      expect(find.text('Dr. Ada Byron'), findsNothing);
      expect(find.text('No doctors added'), findsOneWidget);
    });
  });

  group('clinics', () {
    setUp(() async {
      await MedicineCleanStorageService.saveClinic(
        Clinic(id: 'clinic-1', name: 'Mercy General'),
      );
    });

    testWidgets('dismissing the sheet by its barrier deletes nothing',
        (tester) async {
      await pump(tester, const NunitoClinicListScreen());
      await swipeToDelete(tester, find.text('Mercy General'));

      expect(find.text('Delete clinic?'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Mercy General'), findsOneWidget);
      expect(await MedicineCleanStorageService.getAllClinics(), hasLength(1));
    });

    testWidgets('Delete removes the clinic', (tester) async {
      await pump(tester, const NunitoClinicListScreen());
      await swipeToDelete(tester, find.text('Mercy General'));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await MedicineCleanStorageService.getAllClinics(), isEmpty);
      expect(find.text('Mercy General'), findsNothing);
      expect(find.text('No clinics added'), findsOneWidget);
    });
  });

  group('appointments', () {
    setUp(() async {
      await MedicineCleanStorageService.addAppointment(Appointment(
        id: 'appt-1',
        doctorName: 'Grace Hopper',
        // Far enough out that `isUpcoming` holds regardless of when the suite
        // runs, so the row lands under "Upcoming" and not "Past".
        dateTime: DateTime.now().add(const Duration(days: 3)),
      ));
    });

    testWidgets('the swipe opens the app sheet, not an AlertDialog',
        (tester) async {
      await pump(tester, const NunitoAppointmentListScreen());
      await swipeToDelete(tester, find.text('Grace Hopper'));

      expect(find.byType(AppBottomSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Delete appointment?'), findsOneWidget);
      expect(
          find.text(
              'Are you sure you want to delete this appointment with Grace Hopper?'),
          findsOneWidget);
    });

    testWidgets('dismissing the sheet by its barrier deletes nothing',
        (tester) async {
      await pump(tester, const NunitoAppointmentListScreen());
      await swipeToDelete(tester, find.text('Grace Hopper'));

      // `null`, not `false` -- the branch the call site must still treat as
      // "no". This is the escape the original dialog allowed, and the one a
      // swipe makes easy to hit by accident.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomSheet), findsNothing);
      expect(find.text('Grace Hopper'), findsOneWidget,
          reason: 'the swiped row springs back when nothing was confirmed');
      expect(
          await MedicineCleanStorageService.getAllAppointments(), hasLength(1));
    });

    testWidgets('Cancel deletes nothing', (tester) async {
      await pump(tester, const NunitoAppointmentListScreen());
      await swipeToDelete(tester, find.text('Grace Hopper'));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(
          await MedicineCleanStorageService.getAllAppointments(), hasLength(1));
    });

    testWidgets('Delete removes the appointment', (tester) async {
      await pump(tester, const NunitoAppointmentListScreen());
      await swipeToDelete(tester, find.text('Grace Hopper'));

      // Exact-text match, so this is the confirm button and not the
      // 'Delete appointment?' title above it.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await MedicineCleanStorageService.getAllAppointments(), isEmpty);
      expect(find.text('Grace Hopper'), findsNothing);
      expect(find.text('No appointments yet'), findsOneWidget);
    });
  });
}
