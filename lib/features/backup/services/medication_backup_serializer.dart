import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart' as db;
import '../../medication/models/clinic.dart';
import '../../medication/services/medicine_storage_service.dart';

/// The doctors / appointments / household-profiles half of the app backup.
///
/// `exportAllData()` covered the medicines themselves (with their dose logs)
/// and nothing else from the medication feature. Everything the user typed
/// into the Doctors, Appointments and Household screens — a consultant's name
/// and phone number, the date and place of a hospital appointment, a child's
/// blood type, allergies and insurance details — was in no backup at all, and
/// none of it can be re-derived from anywhere: unlike sensor steps or the
/// menstrual cycles the app recomputes, this is data that exists only because
/// someone typed it in.
///
/// **`exportAllMedicineData` is not the seam for this.** It serialises the
/// same six things through the DOMAIN models, its `medicines`/`logs` sections
/// duplicate what `exportMedicinesJson` already puts in the backup, it carries
/// `pharmacies` (a table with a DAO and service methods but no screen that
/// writes it), and it has no import counterpart. It has had no callers since
/// it was written. Reusing it would have meant two different serialisations of
/// medicines inside one backup file.
///
/// **Why Drift rows and not the domain models** — the same reason
/// `HealthBackupSerializer` gives: `Doctor`, `Appointment` and
/// `DependentProfile` are domain names in `CleanStorageService` and generated
/// table names here, so a `db.`-prefixed import in a file of its own is what
/// keeps the two apart. The row classes also serialize every column, where the
/// domain mappers drop some — the domain `Doctor` has no `createdAt` and the
/// domain `DependentProfile` has no `photoPath`, and both are real columns.
///
/// **Export, import and clear live in one file on purpose** — see the same
/// warning on [HealthBackupSerializer]: a table this clears but cannot put
/// back is data destroyed by a restore.
class MedicationBackupSerializer {
  MedicationBackupSerializer._();

  /// Top-level keys this serializer owns inside the backup map.
  static const String doctorsKey = 'doctors';
  static const String appointmentsKey = 'appointments';
  static const String dependentsKey = 'dependents';

  /// Clinics and hospitals. Unlike the rest of this file they are not Drift
  /// rows — they live in SharedPreferences — so they were in no backup and
  /// survived "Delete all data". They ride the same section rules as the other
  /// three: exported always, restored by id, cleared only when the file has them.
  static const String clinicsKey = 'clinics';

  static db.AppDatabase get _db => db.AppDatabase.instance;

  /// Every profile's records, not the active one's.
  ///
  /// `MedicineCleanStorageService.getAllAppointments` scopes to the active
  /// household profile, which is right for a screen and wrong for a backup:
  /// exporting while "Me" is selected would silently leave a dependent's
  /// appointments out of the file. Reading the tables directly is what makes
  /// the export independent of who happens to be selected.
  ///
  /// `pharmacies` and `treatment_courses` are deliberately absent. Both have
  /// tables and DAO methods, but nothing in the app writes either — there is
  /// no pharmacy screen and no caller of `addTreatment` — so they hold no
  /// user data to lose. If a screen for one ever lands, it joins this file,
  /// [importJson] and [clearRestorableRows] in the same change.
  static Future<Map<String, dynamic>> exportJson() async {
    final d = _db;

    final doctors = await (d.select(d.doctors)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    final appointments = await (d.select(d.appointments)
          ..orderBy([(t) => OrderingTerm.asc(t.appointmentDateTime)]))
        .get();
    final dependents = await (d.select(d.dependentProfiles)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final clinics = await MedicineCleanStorageService.getAllClinics();

    return <String, dynamic>{
      doctorsKey: doctors.map((r) => r.toJson()).toList(),
      appointmentsKey: appointments.map((r) => r.toJson()).toList(),
      dependentsKey: dependents.map((r) => r.toJson()).toList(),
      clinicsKey: clinics.map((c) => c.toJson()).toList(),
    };
  }

  /// Restore whatever of [data] this serializer owns. Non-destructive and
  /// idempotent, matching the rest of `importData`: every row is upserted on
  /// its own primary key, a section that is ABSENT is left untouched, and a
  /// malformed row is skipped rather than failing the whole restore.
  static Future<void> importJson(Map<String, dynamic> data) async {
    final d = _db;

    // Doctors and dependents before appointments: an appointment carries a
    // `doctorId` and a `dependentId`, and restoring it first would leave both
    // dangling for the length of the restore.
    for (final raw in (data[doctorsKey] as List? ?? const [])) {
      try {
        await d.into(d.doctors).insertOnConflictUpdate(
            db.Doctor.fromJson(Map<String, dynamic>.from(raw as Map))
                .toCompanion(false));
      } catch (e) {
        debugPrint('Import doctor failed: $e');
      }
    }

    for (final raw in (data[dependentsKey] as List? ?? const [])) {
      try {
        await d.into(d.dependentProfiles).insertOnConflictUpdate(
            db.DependentProfile.fromJson(Map<String, dynamic>.from(raw as Map))
                .toCompanion(false));
      } catch (e) {
        debugPrint('Import dependent profile failed: $e');
      }
    }

    for (final raw in (data[clinicsKey] as List? ?? const [])) {
      try {
        await MedicineCleanStorageService.saveClinic(
            Clinic.fromJson(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        debugPrint('Import clinic failed: $e');
      }
    }

    for (final raw in (data[appointmentsKey] as List? ?? const [])) {
      try {
        await d.into(d.appointments).insertOnConflictUpdate(
            db.Appointment.fromJson(Map<String, dynamic>.from(raw as Map))
                .toCompanion(false));
      } catch (e) {
        debugPrint('Import appointment failed: $e');
      }
    }
  }

  /// The tables an OVERWRITE restore may wipe first, and no others.
  ///
  /// `dependent_profiles` is deliberately absent, for the reason
  /// [HealthBackupSerializer.clearRestorableRows] keeps `health_profiles`:
  /// it is partly app scaffolding. `ActiveProfileService.init()` creates the
  /// well-known "self" row exactly once per install and every profile screen
  /// assumes it is there, so wiping the table mid-session — restoring a file
  /// written before this section existed, say — would leave the app with no
  /// profile at all until the next cold start. [importJson] upserts each
  /// dependent on its own id, so an overwrite restore still replaces the rows
  /// the file carries without that risk.
  ///
  /// [forBackup] applies the same rule per FILE rather than per format — see
  /// `CleanStorageService.clearRestorableData`. Every backup written before
  /// this serializer existed carries neither key, and wiping a consultant's
  /// phone number and every appointment for a file that cannot put them back
  /// is exactly the loss this class was added to prevent. Null means "a
  /// current export", where both keys are always present.
  static Future<void> clearRestorableRows({
    Map<String, dynamic>? forBackup,
  }) async {
    final d = _db;
    bool carries(String key) => forBackup == null || forBackup.containsKey(key);
    // Appointments first: they reference the doctors below.
    if (carries(appointmentsKey)) await d.delete(d.appointments).go();
    if (carries(doctorsKey)) await d.delete(d.doctors).go();
    if (carries(clinicsKey)) await MedicineCleanStorageService.clearClinics();
  }
}
