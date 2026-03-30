// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication_dao.dart';

// ignore_for_file: type=lint
mixin _$MedicationDaoMixin on DatabaseAccessor<AppDatabase> {
  $EnhancedMedicinesTable get enhancedMedicines =>
      attachedDatabase.enhancedMedicines;
  $MedicineLogsTable get medicineLogs => attachedDatabase.medicineLogs;
  $MedicineSchedulesTable get medicineSchedules =>
      attachedDatabase.medicineSchedules;
  $DoctorsTable get doctors => attachedDatabase.doctors;
  $PharmaciesTable get pharmacies => attachedDatabase.pharmacies;
  $AppointmentsTable get appointments => attachedDatabase.appointments;
  $DependentProfilesTable get dependentProfiles =>
      attachedDatabase.dependentProfiles;
  $TreatmentCoursesTable get treatmentCourses =>
      attachedDatabase.treatmentCourses;
  MedicationDaoManager get managers => MedicationDaoManager(this);
}

class MedicationDaoManager {
  final _$MedicationDaoMixin _db;
  MedicationDaoManager(this._db);
  $$EnhancedMedicinesTableTableManager get enhancedMedicines =>
      $$EnhancedMedicinesTableTableManager(
        _db.attachedDatabase,
        _db.enhancedMedicines,
      );
  $$MedicineLogsTableTableManager get medicineLogs =>
      $$MedicineLogsTableTableManager(_db.attachedDatabase, _db.medicineLogs);
  $$MedicineSchedulesTableTableManager get medicineSchedules =>
      $$MedicineSchedulesTableTableManager(
        _db.attachedDatabase,
        _db.medicineSchedules,
      );
  $$DoctorsTableTableManager get doctors =>
      $$DoctorsTableTableManager(_db.attachedDatabase, _db.doctors);
  $$PharmaciesTableTableManager get pharmacies =>
      $$PharmaciesTableTableManager(_db.attachedDatabase, _db.pharmacies);
  $$AppointmentsTableTableManager get appointments =>
      $$AppointmentsTableTableManager(_db.attachedDatabase, _db.appointments);
  $$DependentProfilesTableTableManager get dependentProfiles =>
      $$DependentProfilesTableTableManager(
        _db.attachedDatabase,
        _db.dependentProfiles,
      );
  $$TreatmentCoursesTableTableManager get treatmentCourses =>
      $$TreatmentCoursesTableTableManager(
        _db.attachedDatabase,
        _db.treatmentCourses,
      );
}
