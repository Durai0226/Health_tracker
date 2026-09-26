import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/medication_tables.dart';
import '../../utils/calendar_day.dart';

part 'medication_dao.g.dart';

@DriftAccessor(tables: [
  EnhancedMedicines,
  MedicineLogs,
  MedicineSchedules,
  Doctors,
  Pharmacies,
  Appointments,
  DependentProfiles,
  TreatmentCourses,
])
class MedicationDao extends DatabaseAccessor<AppDatabase> with _$MedicationDaoMixin {
  MedicationDao(AppDatabase db) : super(db);

  // ============ MEDICINES ============

  Future<List<EnhancedMedicine>> getAllMedicines({bool includeArchived = false}) async {
    if (includeArchived) {
      return await (select(enhancedMedicines)
            ..where((t) => t.deletedAt.isNull()))
          .get();
    }
    return await (select(enhancedMedicines)
      ..where((t) =>
          t.isArchived.equals(false) &
          t.isActive.equals(true) &
          t.deletedAt.isNull()))
      .get();
  }

  /// Every medicine INCLUDING tombstoned ones — the shape cloud sync needs.
  ///
  /// `getAllMedicines` filters `deletedAt IS NULL`, and a syncer that cannot
  /// see a tombstone reads the row as "missing on this device" and downloads
  /// the deleted medicine straight back, alarms and all.
  Future<List<EnhancedMedicine>> getAllMedicinesIncludingDeleted() =>
      select(enhancedMedicines).get();

  Future<EnhancedMedicine?> getMedicine(String id) async {
    return await (select(enhancedMedicines)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
      .getSingleOrNull();
  }

  /// Insert, clearing any tombstone.
  ///
  /// Re-adding a medicine that was previously deleted reuses nothing by
  /// default, but a cloud download can carry an id that is tombstoned here.
  /// Without the explicit clear the row would stay invisible forever — the
  /// same trap `PeriodDao.upsertDay` documents.
  Future<void> addMedicine(EnhancedMedicinesCompanion medicine) async {
    await into(enhancedMedicines).insertOnConflictUpdate(
        medicine.copyWith(deletedAt: const Value(null)));
  }

  Future<void> updateMedicine(EnhancedMedicinesCompanion medicine) async {
    await (update(enhancedMedicines)
      ..where((t) => t.id.equals(medicine.id.value)))
      .write(medicine.copyWith(deletedAt: const Value(null)));
  }

  /// Soft delete: stamp a tombstone instead of dropping the row.
  ///
  /// A hard DELETE left nothing to say "the user removed this", so once
  /// medicines are cloud-synced the next sync sees the id present in Firestore
  /// and absent locally, reads that as "not downloaded yet", and writes the
  /// medicine back — reinstating its schedule and its alarms.
  ///
  /// `updatedAt` is bumped so the deletion wins the LWW comparison.
  ///
  /// The logs are still hard-deleted: they are the medicine's own history, a
  /// tombstoned medicine appears nowhere, and orphaned taken logs would inflate
  /// adherence (numerator) against a denominator that no longer includes it.
  Future<void> deleteMedicine(String id) async {
    await (delete(medicineLogs)..where((t) => t.medicineId.equals(id))).go();
    final now = DateTime.now();
    await (update(enhancedMedicines)..where((t) => t.id.equals(id))).write(
      EnhancedMedicinesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Stream<List<EnhancedMedicine>> watchMedicines() {
    return (select(enhancedMedicines)
      ..where((t) => t.isArchived.equals(false) & t.isActive.equals(true)))
      .watch();
  }

  // ============ MEDICINE LOGS ============

  Future<List<MedicineLog>> getAllLogs() async {
    return await (select(medicineLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.scheduledTime)]))
      .get();
  }

  Future<MedicineLog?> getLogById(String id) async {
    return await (select(medicineLogs)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<MedicineLog>> getLogsForMedicine(String medicineId) async {
    return await (select(medicineLogs)
      ..where((t) => t.medicineId.equals(medicineId))
      ..orderBy([(t) => OrderingTerm.desc(t.scheduledTime)]))
      .get();
  }

  Future<List<MedicineLog>> getLogsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = dayOffset(startOfDay, 1);
    return await (select(medicineLogs)
      ..where((t) => t.scheduledTime.isBiggerOrEqualValue(startOfDay) & 
                     t.scheduledTime.isSmallerThanValue(endOfDay))
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledTime)]))
      .get();
  }

  Future<List<MedicineLog>> getLogsForDateRange(DateTime start, DateTime end) async {
    return await (select(medicineLogs)
      ..where((t) => t.scheduledTime.isBiggerOrEqualValue(start) & 
                     t.scheduledTime.isSmallerThanValue(end))
      ..orderBy([(t) => OrderingTerm.desc(t.scheduledTime)]))
      .get();
  }

  /// Record a dose outcome.
  ///
  /// Upsert, not insert: a log id is now deterministic per medicine + scheduled
  /// slot (see `MedicineCleanStorageService.doseLogId`), and one slot has exactly
  /// one outcome. Re-taking or re-skipping the same dose must therefore REPLACE
  /// the previous row. With a plain `insert` it appended instead, so skipping a
  /// dose twice counted as two skips and the Today hero could show "3/2".
  Future<void> addLog(MedicineLogsCompanion log) async {
    await into(medicineLogs).insertOnConflictUpdate(log);
  }

  Future<void> updateLog(MedicineLogsCompanion log) async {
    await (update(medicineLogs)
      ..where((t) => t.id.equals(log.id.value)))
      .write(log);
  }

  Future<void> deleteLog(String id) async {
    await (delete(medicineLogs)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<MedicineLog>> watchLogs() {
    return (select(medicineLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.scheduledTime)]))
      .watch();
  }

  // ============ DOCTORS ============

  Future<List<Doctor>> getAllDoctors() async {
    return await select(doctors).get();
  }

  Future<Doctor?> getDoctor(String id) async {
    return await (select(doctors)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> addDoctor(DoctorsCompanion doctor) async {
    await into(doctors).insert(doctor);
  }

  Future<void> updateDoctor(DoctorsCompanion doctor) async {
    await (update(doctors)..where((t) => t.id.equals(doctor.id.value))).write(doctor);
  }

  Future<void> deleteDoctor(String id) async {
    await (delete(doctors)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Doctor>> watchDoctors() => select(doctors).watch();

  // ============ PHARMACIES ============

  Future<List<Pharmacy>> getAllPharmacies() async {
    return await select(pharmacies).get();
  }

  Future<void> addPharmacy(PharmaciesCompanion pharmacy) async {
    await into(pharmacies).insert(pharmacy);
  }

  Future<void> updatePharmacy(PharmaciesCompanion pharmacy) async {
    await (update(pharmacies)..where((t) => t.id.equals(pharmacy.id.value))).write(pharmacy);
  }

  Future<void> deletePharmacy(String id) async {
    await (delete(pharmacies)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Pharmacy>> watchPharmacies() => select(pharmacies).watch();

  // ============ APPOINTMENTS ============

  Future<List<Appointment>> getAllAppointments() async {
    return await (select(appointments)
      ..orderBy([(t) => OrderingTerm.asc(t.appointmentDateTime)]))
      .get();
  }

  Future<List<Appointment>> getUpcomingAppointments() async {
    return await (select(appointments)
      ..where((t) => t.appointmentDateTime.isBiggerOrEqualValue(DateTime.now()))
      ..orderBy([(t) => OrderingTerm.asc(t.appointmentDateTime)]))
      .get();
  }

  Future<void> addAppointment(AppointmentsCompanion appointment) async {
    await into(appointments).insert(appointment);
  }

  Future<void> updateAppointment(AppointmentsCompanion appointment) async {
    await (update(appointments)..where((t) => t.id.equals(appointment.id.value))).write(appointment);
  }

  Future<void> deleteAppointment(String id) async {
    await (delete(appointments)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Appointment>> watchAppointments() {
    return (select(appointments)
      ..orderBy([(t) => OrderingTerm.asc(t.appointmentDateTime)]))
      .watch();
  }

  // ============ DEPENDENTS ============

  Future<List<DependentProfile>> getAllDependents() async {
    return await (select(dependentProfiles)
      ..where((t) => t.isActive.equals(true)))
      .get();
  }

  Future<void> addDependent(DependentProfilesCompanion dependent) async {
    await into(dependentProfiles).insert(dependent);
  }

  Future<void> updateDependent(DependentProfilesCompanion dependent) async {
    await (update(dependentProfiles)..where((t) => t.id.equals(dependent.id.value))).write(dependent);
  }

  Future<void> deleteDependent(String id) async {
    await (delete(dependentProfiles)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<DependentProfile>> watchDependents() {
    return (select(dependentProfiles)..where((t) => t.isActive.equals(true))).watch();
  }

  // ============ TREATMENTS ============

  Future<List<TreatmentCourse>> getAllTreatments() async {
    return await select(treatmentCourses).get();
  }

  Future<List<TreatmentCourse>> getActiveTreatments() async {
    return await (select(treatmentCourses)
      ..where((t) => t.isActive.equals(true)))
      .get();
  }

  Future<void> addTreatment(TreatmentCoursesCompanion treatment) async {
    await into(treatmentCourses).insert(treatment);
  }

  Future<void> updateTreatment(TreatmentCoursesCompanion treatment) async {
    await (update(treatmentCourses)..where((t) => t.id.equals(treatment.id.value))).write(treatment);
  }

  Future<void> deleteTreatment(String id) async {
    await (delete(treatmentCourses)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<TreatmentCourse>> watchTreatments() => select(treatmentCourses).watch();
}
