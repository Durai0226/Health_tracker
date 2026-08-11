import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/services/appointment_reminder_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Phase 6's appointment reminders gate: the DAO/domain layer was complete
/// but had zero UI or reminder-scheduling code exercising it. These tests
/// cover the service-layer CRUD + profile-reassignment wiring added to close
/// that gap — not the actual notification firing (mobile-only, see AGENTS.md).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Appointment appointment(String id, {DateTime? dateTime, String? dependentId}) =>
      Appointment(
        id: id,
        doctorName: 'Dr. Test',
        dateTime: dateTime ?? DateTime.now().add(const Duration(days: 1)),
        dependentId: dependentId,
      );

  group('AppointmentReminderService.notificationIdFor', () {
    test('deterministic and non-negative', () {
      final id = AppointmentReminderService.notificationIdFor('appt-1');
      expect(id, AppointmentReminderService.notificationIdFor('appt-1'));
      expect(id >= 0, true);
    });

    test('different appointments get different ids (no trivial collision)', () {
      expect(
        AppointmentReminderService.notificationIdFor('appt-1'),
        isNot(AppointmentReminderService.notificationIdFor('appt-2')),
      );
    });
  });

  group('service CRUD', () {
    test('addAppointment persists and getAllAppointments returns it', () async {
      await MedicineCleanStorageService.addAppointment(appointment('a1'));
      final all = await MedicineCleanStorageService.getAllAppointments();
      expect(all.map((a) => a.id), contains('a1'));
    });

    test('addAppointment never throws even though it schedules a reminder',
        () async {
      // Regression: AppointmentReminderService used to let a bare
      // NotificationService plugin call escape uncaught (confirmed via a
      // throwaway probe: cancelNotification throws LateInitializationError
      // headlessly) which would have made this call throw too.
      await expectLater(
          MedicineCleanStorageService.addAppointment(appointment('a-safe')),
          completes);
    });

    test('getUpcomingAppointments excludes past appointments', () async {
      await MedicineCleanStorageService.addAppointment(appointment('future',
          dateTime: DateTime.now().add(const Duration(days: 2))));
      await MedicineCleanStorageService.addAppointment(appointment('past',
          dateTime: DateTime.now().subtract(const Duration(days: 2))));
      final upcoming = await MedicineCleanStorageService.getUpcomingAppointments();
      expect(upcoming.map((a) => a.id), contains('future'));
      expect(upcoming.map((a) => a.id), isNot(contains('past')));
    });

    test('updateAppointment persists changes', () async {
      final a = appointment('a2');
      await MedicineCleanStorageService.addAppointment(a);
      await MedicineCleanStorageService.updateAppointment(
          a.copyWith(isCompleted: true, doctorName: 'Dr. Updated'));
      final all = await MedicineCleanStorageService.getAllAppointments();
      final updated = all.firstWhere((x) => x.id == 'a2');
      expect(updated.isCompleted, true);
      expect(updated.doctorName, 'Dr. Updated');
    });

    test('deleteAppointment removes it', () async {
      await MedicineCleanStorageService.addAppointment(appointment('a3'));
      await MedicineCleanStorageService.deleteAppointment('a3');
      final all = await MedicineCleanStorageService.getAllAppointments();
      expect(all.map((a) => a.id), isNot(contains('a3')));
    });
  });

  group('profile scoping', () {
    test('appointment scoped to a dependent is invisible to self', () async {
      await MedicineCleanStorageService.addAppointment(
          appointment('dep-appt', dependentId: 'dep-1'));
      await MedicineCleanStorageService.addAppointment(appointment('self-appt'));

      final selfView = await MedicineCleanStorageService.getAllAppointments();
      expect(selfView.map((a) => a.id), contains('self-appt'));
      expect(selfView.map((a) => a.id), isNot(contains('dep-appt')));
    });
  });

  group('deleteDependent reassignment', () {
    test('reassigns the dependent\'s appointments to self instead of orphaning them',
        () async {
      await MedicineCleanStorageService.addAppointment(
          appointment('orphan-check', dependentId: 'dep-2'));

      await MedicineCleanStorageService.deleteDependent('dep-2');

      final all = await MedicineCleanStorageService.getAllAppointments();
      final reassigned = all.firstWhere((a) => a.id == 'orphan-check');
      expect(reassigned.dependentId, null);
    });
  });

  group('Appointment.copyWith clearDependentId', () {
    test('clearDependentId explicitly nulls out ownership', () {
      final a = appointment('c1', dependentId: 'dep-3');
      final cleared = a.copyWith(clearDependentId: true);
      expect(cleared.dependentId, null);
    });

    test('without clearDependentId, dependentId is preserved when omitted', () {
      final a = appointment('c2', dependentId: 'dep-4');
      final copy = a.copyWith(doctorName: 'Dr. New');
      expect(copy.dependentId, 'dep-4');
    });
  });
}
