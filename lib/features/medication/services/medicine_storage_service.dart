import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/medication_dao.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../models/medicine_schedule.dart';
import '../models/doctor_pharmacy.dart';
import '../models/dependent_profile.dart';
import '../models/medicine_enums.dart';
import '../models/clinic.dart';
import '../../../core/ai/streak_engine.dart';
import '../../../core/services/dose_action_queue.dart';
import '../../../core/services/notification_service.dart';

/// Enhanced Medicine Storage Service with all premium features
/// Migrated to Drift (SQLite) storage
class MedicineCleanStorageService {
  static bool _isInitialized = false;

  static MedicationDao get _dao => db.AppDatabase.instance.medicationDao;

  /// A lightweight change signal, bumped whenever medicine data mutates (logs,
  /// stock, or the medicine list itself). Screens kept alive in an IndexedStack
  /// — notably the Home dashboard — can wrap their medicine views in a
  /// [ValueListenableBuilder] on this notifier so they refresh live instead of
  /// going stale after a dose is taken in another tab.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void _bumpRevision() => revision.value++;

  static Future<void> init() async {
    if (_isInitialized) return;
    
    // Ensure database is initialized
    try {
      final _ = db.AppDatabase.instance;
      debugPrint('✓ MedicineCleanStorageService initialized with Drift');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing MedicineCleanStorageService: $e');
    }
  }

  // ============ HELPER MAPPERS ============

  static EnhancedMedicine _mapToDomainMedicine(db.EnhancedMedicine data) {
    return EnhancedMedicine(
      id: data.id,
      name: data.name,
      genericName: data.genericName,
      brandName: data.brandName,
      dosageForm: DosageForm.values[data.dosageForm],
      dosageAmount: data.strength, // Using strength column as dosage amount storage if needed
      dosageUnit: data.strengthUnit,
      strength: data.strengthText, // The real user-entered strength (nullable)
      schedule: MedicineSchedule.fromJson(jsonDecode(data.scheduleJson)),
      color: MedicineColor.values[data.colorIndex],
      shape: MedicineShape.values[data.shapeIndex],
      imagePath: data.imagePath,
      instructions: data.instructions,
      purpose: data.purpose,
      currentStock: data.currentStock,
      lowStockThreshold: data.lowStockThreshold,
      refillReminderEnabled: data.refillReminder,
      expiryDate: data.expiryDate,
      prescriptionNumber: data.prescriptionNumber,
      doctorId: data.doctorId,
      pharmacyId: data.pharmacyId,
      dependentId: data.dependentId,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      isActive: data.isActive,
      isArchived: data.isArchived,
      notes: data.notes,
      healthCategories: data.healthCategoriesJson != null 
          ? (jsonDecode(data.healthCategoriesJson!) as List).map((e) => HealthCategory.values[e]).toList()
          : null,
      customHealthCategory: data.customHealthCategory,
      patientProfileId: data.patientProfileId,
      requiresContinuousIntake: data.requiresContinuousIntake,
      minimumConsecutiveDays: data.minimumConsecutiveDays,
      customFields: data.customFieldsJson != null ? jsonDecode(data.customFieldsJson!) : null,
      warnings: data.warningsJson != null ? List<String>.from(jsonDecode(data.warningsJson!)) : null,
      sideEffects: data.sideEffectsJson != null ? List<String>.from(jsonDecode(data.sideEffectsJson!)) : null,
    );
  }

  static db.EnhancedMedicinesCompanion _mapToMedicineCompanion(EnhancedMedicine medicine) {
    return db.EnhancedMedicinesCompanion(
      id: drift.Value(medicine.id),
      name: drift.Value(medicine.name),
      genericName: drift.Value(medicine.genericName),
      brandName: drift.Value(medicine.brandName),
      dosageForm: drift.Value(medicine.dosageForm.index),
      strength: drift.Value(medicine.dosageAmount), // Map dosageAmount to strength column
      strengthUnit: drift.Value(medicine.dosageUnit ?? 'mg'),
      strengthText: drift.Value(medicine.strength), // The real strength string

      scheduleJson: drift.Value(jsonEncode(medicine.schedule.toJson())),
      startDate: drift.Value(medicine.schedule.startDate ?? DateTime.now()), // Required field
      endDate: drift.Value(medicine.schedule.endDate),
      colorIndex: drift.Value(medicine.color?.index ?? 0),
      shapeIndex: drift.Value(medicine.shape?.index ?? 0),
      imagePath: drift.Value(medicine.imagePath),
      instructions: drift.Value(medicine.instructions),
      purpose: drift.Value(medicine.purpose),
      currentStock: drift.Value(medicine.currentStock ?? 0),
      lowStockThreshold: drift.Value(medicine.lowStockThreshold ?? 7),
      refillReminder: drift.Value(medicine.refillReminderEnabled),
      expiryDate: drift.Value(medicine.expiryDate),
      prescriptionNumber: drift.Value(medicine.prescriptionNumber),
      doctorId: drift.Value(medicine.doctorId),
      pharmacyId: drift.Value(medicine.pharmacyId),
      dependentId: drift.Value(medicine.dependentId),
      createdAt: drift.Value(medicine.createdAt),
      updatedAt: drift.Value(medicine.updatedAt ?? DateTime.now()),
      isActive: drift.Value(medicine.isActive),
      isArchived: drift.Value(medicine.isArchived),
      notes: drift.Value(medicine.notes),
      healthCategoriesJson: drift.Value(medicine.healthCategories != null 
          ? jsonEncode(medicine.healthCategories!.map((e) => e.index).toList()) 
          : null),
      customHealthCategory: drift.Value(medicine.customHealthCategory),
      patientProfileId: drift.Value(medicine.patientProfileId),
      requiresContinuousIntake: drift.Value(medicine.requiresContinuousIntake),
      minimumConsecutiveDays: drift.Value(medicine.minimumConsecutiveDays),
      customFieldsJson: drift.Value(medicine.customFields != null ? jsonEncode(medicine.customFields) : null),
      warningsJson: drift.Value(medicine.warnings != null ? jsonEncode(medicine.warnings) : null),
      sideEffectsJson: drift.Value(medicine.sideEffects != null ? jsonEncode(medicine.sideEffects) : null),
    );
  }

  static MedicineLog _mapToDomainLog(db.MedicineLog data) {
    return MedicineLog(
      id: data.id,
      medicineId: data.medicineId,
      scheduledTime: data.scheduledTime,
      actionTime: data.actualTime,
      status: data.isTaken ? MedicineStatus.taken 
          : data.isSkipped ? MedicineStatus.skipped 
          : data.isMissed ? MedicineStatus.missed 
          : MedicineStatus.pending,
      dosageTaken: data.dosageTaken,
      skipReason: data.skipReason != null ? SkipReason.values[data.skipReason!] : null,
      skipNote: data.skipNote,
      sideEffects: data.sideEffects,
      moodRating: data.moodRating,
      effectivenessRating: data.effectivenessRating,
      notes: data.notes,
      dependentId: data.dependentId,
      vitals: data.vitalsJson != null ? jsonDecode(data.vitalsJson!) : null,
    );
  }

  static db.MedicineLogsCompanion _mapToLogCompanion(MedicineLog log) {
    return db.MedicineLogsCompanion(
      id: drift.Value(log.id),
      medicineId: drift.Value(log.medicineId),
      scheduledTime: drift.Value(log.scheduledTime),
      actualTime: drift.Value(log.actionTime),
      isTaken: drift.Value(log.status == MedicineStatus.taken),
      isSkipped: drift.Value(log.status == MedicineStatus.skipped),
      isMissed: drift.Value(log.status == MedicineStatus.missed),
      dosageTaken: drift.Value(log.dosageTaken),
      skipReason: drift.Value(log.skipReason?.index),
      skipNote: drift.Value(log.skipNote),
      notes: drift.Value(log.notes),
      sideEffects: drift.Value(log.sideEffects),
      moodRating: drift.Value(log.moodRating),
      effectivenessRating: drift.Value(log.effectivenessRating),
      dependentId: drift.Value(log.dependentId),
      vitalsJson: drift.Value(log.vitals != null ? jsonEncode(log.vitals) : null),
      synced: const drift.Value(false),
    );
  }

  // ============ ENHANCED MEDICINE METHODS ============

  static Future<List<EnhancedMedicine>> getAllMedicines({bool includeArchived = false}) async {
    final meds = await _dao.getAllMedicines(includeArchived: includeArchived);
    return meds.map(_mapToDomainMedicine).toList();
  }

  static Future<List<EnhancedMedicine>> getMedicinesForDependent(String dependentId) async {
    final meds = await getAllMedicines(includeArchived: true);
    return meds.where((m) => m.dependentId == dependentId).toList();
  }

  static Future<List<EnhancedMedicine>> getMedicinesForDependentAsync(String dependentId) async {
    final meds = await getAllMedicines(includeArchived: true);
    return meds.where((m) => m.dependentId == dependentId).toList();
  }

  static Future<List<EnhancedMedicine>> getActiveMedicinesForTodayAsync() async {
    final today = DateTime.now();
    final meds = await getAllMedicines();
    return meds.where((m) => m.schedule.isActiveOnDate(today)).toList();
  }
  
  // Keep sync method for compatibility but warn it returns empty
  static List<EnhancedMedicine> getActiveMedicinesForToday() {
    return [];
  }

  static Future<List<EnhancedMedicine>> getLowStockMedicinesAsync() async {
    final meds = await getAllMedicines();
    return meds.where((m) => m.isLowStock).toList();
  }
  
  static List<EnhancedMedicine> getLowStockMedicines() {
    return [];
  }

  static Future<List<EnhancedMedicine>> getExpiringMedicinesAsync({int daysAhead = 30}) async {
    final cutoff = DateTime.now().add(Duration(days: daysAhead));
    final meds = await getAllMedicines();
    return meds.where((m) {
      if (m.expiryDate == null) return false;
      return m.expiryDate!.isBefore(cutoff);
    }).toList();
  }
  
  static List<EnhancedMedicine> getExpiringMedicines({int daysAhead = 30}) {
    return [];
  }

  static Future<EnhancedMedicine?> getMedicine(String id) async {
    final med = await _dao.getMedicine(id);
    return med != null ? _mapToDomainMedicine(med) : null;
  }

  static Future<void> saveMedicine(EnhancedMedicine medicine) async {
    final existing = await getMedicine(medicine.id);
    if (existing != null) {
      await updateMedicine(medicine);
    } else {
      await addMedicine(medicine);
    }
  }

  static Future<void> addMedicine(EnhancedMedicine medicine) async {
    await _dao.addMedicine(_mapToMedicineCompanion(medicine));
    _bumpRevision();
  }

  static Future<void> updateMedicine(EnhancedMedicine medicine) async {
    await _dao.updateMedicine(_mapToMedicineCompanion(medicine));
    _bumpRevision();
  }

  static Future<void> deleteMedicine(String id) async {
    await _dao.deleteMedicine(id);
    _bumpRevision();
  }

  static Future<void> archiveMedicine(String id) async {
    final med = await getMedicine(id);
    if (med != null) {
      await updateMedicine(med.archive());
    }
  }

  static Future<void> reduceStock(String medicineId, double amount) async {
    final med = await getMedicine(medicineId);
    if (med != null) {
      final wasLow = med.isLowStock;
      final updated = med.reduceStock(amount);
      await updateMedicine(updated);
      // Fire a refill alert the moment stock crosses the low threshold
      // (once, not on every subsequent dose). No-ops gracefully off-device.
      if (updated.refillReminderEnabled && updated.isLowStock && !wasLow) {
        await NotificationService().showImmediateNotification(
          title: 'Refill ${med.name}',
          body: 'Only ${updated.currentStock} left — time to restock.',
          channelId: 'refill',
        );
      }
    }
  }

  static Future<void> refillStock(String medicineId, int amount) async {
    final med = await getMedicine(medicineId);
    if (med != null) {
      await updateMedicine(med.addStock(amount));
    }
  }

  // ============ MEDICINE LOG METHODS ============

  static Future<List<MedicineLog>> getAllLogs() async {
    final logs = await _dao.getAllLogs();
    return logs.map(_mapToDomainLog).toList();
  }

  static Future<List<MedicineLog>> getLogsForMedicine(String medicineId) async {
    final logs = await _dao.getLogsForMedicine(medicineId);
    return logs.map(_mapToDomainLog).toList();
  }

  static Future<List<MedicineLog>> getLogsForDate(DateTime date) async {
    final logs = await _dao.getLogsForDate(date);
    return logs.map(_mapToDomainLog).toList();
  }

  static Future<List<MedicineLog>> getLogsForDateRange(DateTime start, DateTime end) async {
    final logs = await _dao.getLogsForDateRange(start, end);
    return logs.map(_mapToDomainLog).toList();
  }

  static Future<void> addLog(MedicineLog log) async {
    await _dao.addLog(_mapToLogCompanion(log));
    _bumpRevision();
  }

  static Future<void> updateLog(MedicineLog log) async {
    await _dao.updateLog(_mapToLogCompanion(log));
    _bumpRevision();
  }

  static Future<void> deleteLog(String id) async {
    await _dao.deleteLog(id);
    _bumpRevision();
  }

  static Future<MedicineLog> markMedicineTaken({
    required String medicineId,
    required DateTime scheduledTime,
    double dosageTaken = 1,
    String? notes,
    String? sideEffects,
    int? moodRating,
    int? effectivenessRating,
    Map<String, dynamic>? vitals,
  }) async {
    final log = MedicineLog.taken(
      id: '${medicineId}_${DateTime.now().millisecondsSinceEpoch}',
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      dosageTaken: dosageTaken,
      notes: notes,
      sideEffects: sideEffects,
      moodRating: moodRating,
      effectivenessRating: effectivenessRating,
      vitals: vitals,
    );
    await addLog(log);
    
    // Update stock if tracked
    await reduceStock(medicineId, dosageTaken);
    
    return log;
  }

  /// Reconcile missed doses by writing a `missed` MedicineLog for every past
  /// scheduled slot that was neither taken nor skipped. Without this, adherence
  /// stats have no denominator of reality (a user who never opens the app would
  /// otherwise show 100% adherence forever).
  ///
  /// Rules:
  /// - Only ACTIVE (non-archived) medicines are considered.
  /// - PRN / as-needed medicines are skipped (a "missed" dose is meaningless).
  /// - A slot is only marked missed once its scheduled time is older than a
  ///   grace window ([graceHours]); today's future slots are never touched.
  /// - Slots that fall before the medicine was created are ignored.
  /// - Idempotent: a slot that already has ANY log (taken/skipped/missed) is left
  ///   alone, so repeated calls never double-insert.
  static Future<void> reconcileMissedDoses({int lookbackDays = 14}) async {
    const graceHours = 3;
    final now = DateTime.now();
    final graceCutoff = now.subtract(const Duration(hours: graceHours));
    final startDate = now.subtract(Duration(days: lookbackDays));
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final today = DateTime(now.year, now.month, now.day);

    final medicines = await getAllMedicines();
    // Fetch from the midnight of the first day so every slot we iterate over is
    // covered by the idempotency check below (slots can precede `startDate`).
    final existingLogs = await getLogsForDateRange(startDay, now);

    final toInsert = <MedicineLog>[];

    for (final med in medicines) {
      if (!med.isActive || med.isArchived) continue;
      if (med.schedule.isPRN) continue;

      final createdDay = DateTime(
          med.createdAt.year, med.createdAt.month, med.createdAt.day);
      final medLogs =
          existingLogs.where((l) => l.medicineId == med.id).toList();

      for (var day = startDay;
          !day.isAfter(today);
          day = day.add(const Duration(days: 1))) {
        if (day.isBefore(createdDay)) continue;

        final slots = med.schedule.getScheduledTimesForDate(day);
        for (final slot in slots) {
          // Only past slots older than the grace window; never future slots.
          if (!slot.isBefore(graceCutoff)) continue;
          // Ignore slots that predate the medicine's creation.
          if (slot.isBefore(med.createdAt)) continue;
          // Idempotency: skip if a log already exists for this exact slot.
          final exists = medLogs.any((l) =>
              l.scheduledTime.year == slot.year &&
              l.scheduledTime.month == slot.month &&
              l.scheduledTime.day == slot.day &&
              l.scheduledTime.hour == slot.hour &&
              l.scheduledTime.minute == slot.minute);
          if (exists) continue;

          toInsert.add(MedicineLog.missed(
            id: '${med.id}_missed_${slot.millisecondsSinceEpoch}',
            medicineId: med.id,
            scheduledTime: slot,
            dependentId: med.dependentId,
          ));
        }
      }
    }

    for (final log in toInsert) {
      await addLog(log);
    }
  }

  static Future<MedicineLog> markMedicineSkipped({
    required String medicineId,
    required DateTime scheduledTime,
    required SkipReason reason,
    String? skipNote,
  }) async {
    final log = MedicineLog.skipped(
      id: '${medicineId}_skip_${DateTime.now().millisecondsSinceEpoch}',
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      reason: reason,
      skipNote: skipNote,
    );
    await addLog(log);
    return log;
  }

  /// Apply any Take/Skip actions the user tapped on a notification while the app
  /// was closed (queued by the background isolate — Drift is unavailable there).
  /// Returns the ids of the logs created, so the caller can offer a single Undo.
  static Future<List<String>> drainPendingDoseActions() async {
    final actions = await DoseActionQueue.drain();
    final created = <String>[];
    for (final a in actions) {
      final med = await getMedicine(a.medicineId);
      if (med == null) continue;
      try {
        final log = a.isTake
            ? await markMedicineTaken(
                medicineId: a.medicineId, scheduledTime: a.scheduledTime)
            : await markMedicineSkipped(
                medicineId: a.medicineId,
                scheduledTime: a.scheduledTime,
                reason: SkipReason.other);
        created.add(log.id);
      } catch (e) {
        debugPrint('⚠️ Applying queued dose action failed: $e');
      }
    }
    return created;
  }

  // ============ DOCTOR METHODS ============

  static Future<List<Doctor>> getAllDoctors() async {
    final docs = await _dao.getAllDoctors();
    return docs.map((d) => Doctor(
      id: d.id,
      name: d.name,
      specialty: d.specialty,
      phone: d.phone,
      email: d.email,
      address: d.address,
      clinicName: d.hospital,
      notes: d.notes,
      isPrimary: d.isPrimary,
    )).toList();
  }

  static Future<Doctor?> getDoctor(String id) async {
    final d = await _dao.getDoctor(id);
    if (d == null) return null;
    return Doctor(
      id: d.id,
      name: d.name,
      specialty: d.specialty,
      phone: d.phone,
      email: d.email,
      address: d.address,
      clinicName: d.hospital,
      notes: d.notes,
      isPrimary: d.isPrimary,
    );
  }

  static Future<void> saveDoctor(Doctor doctor) async {
    final existing = await getDoctor(doctor.id);
    if (existing != null) {
      await updateDoctor(doctor);
    } else {
      await addDoctor(doctor);
    }
  }

  static Future<void> addDoctor(Doctor doctor) async {
    await _dao.addDoctor(db.DoctorsCompanion(
      id: drift.Value(doctor.id),
      name: drift.Value(doctor.name),
      specialty: drift.Value(doctor.specialty),
      phone: drift.Value(doctor.phone),
      email: drift.Value(doctor.email),
      address: drift.Value(doctor.address),
      hospital: drift.Value(doctor.clinicName),
      notes: drift.Value(doctor.notes),
      isPrimary: drift.Value(doctor.isPrimary),
      createdAt: drift.Value(DateTime.now()),
    ));
  }

  static Future<void> updateDoctor(Doctor doctor) async {
    await _dao.updateDoctor(db.DoctorsCompanion(
      id: drift.Value(doctor.id),
      name: drift.Value(doctor.name),
      specialty: drift.Value(doctor.specialty),
      phone: drift.Value(doctor.phone),
      email: drift.Value(doctor.email),
      address: drift.Value(doctor.address),
      hospital: drift.Value(doctor.clinicName),
      notes: drift.Value(doctor.notes),
      isPrimary: drift.Value(doctor.isPrimary),
    ));
  }

  static Future<void> deleteDoctor(String id) async {
    await _dao.deleteDoctor(id);
  }

  // ============ PHARMACY METHODS ============

  static Future<Pharmacy?> getPharmacy(String id) async {
    final pharms = await _dao.getAllPharmacies();
    try {
      final p = pharms.firstWhere((p) => p.id == id);
      return Pharmacy(
        id: p.id,
        name: p.name,
        phone: p.phone,
        address: p.address,
        hours: p.hours,
        hasDelivery: p.hasDelivery,
        notes: p.notes,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Pharmacy>> getAllPharmacies() async {
    final pharms = await _dao.getAllPharmacies();
    return pharms.map((p) => Pharmacy(
      id: p.id,
      name: p.name,
      phone: p.phone,
      address: p.address,
      hours: p.hours,
      hasDelivery: p.hasDelivery,
      notes: p.notes,
    )).toList();
  }

  static Future<void> addPharmacy(Pharmacy pharmacy) async {
    await _dao.addPharmacy(db.PharmaciesCompanion(
      id: drift.Value(pharmacy.id),
      name: drift.Value(pharmacy.name),
      phone: drift.Value(pharmacy.phone),
      address: drift.Value(pharmacy.address),
      hours: drift.Value(pharmacy.hours),
      hasDelivery: drift.Value(pharmacy.hasDelivery),
      notes: drift.Value(pharmacy.notes),
      createdAt: drift.Value(DateTime.now()),
    ));
  }
  
  static Future<void> updatePharmacy(Pharmacy pharmacy) async {
    await _dao.updatePharmacy(db.PharmaciesCompanion(
      id: drift.Value(pharmacy.id),
      name: drift.Value(pharmacy.name),
      phone: drift.Value(pharmacy.phone),
      address: drift.Value(pharmacy.address),
      hours: drift.Value(pharmacy.hours),
      hasDelivery: drift.Value(pharmacy.hasDelivery),
      notes: drift.Value(pharmacy.notes),
    ));
  }

  static Future<void> deletePharmacy(String id) async {
    await _dao.deletePharmacy(id);
  }

  // ============ CLINIC METHODS (SharedPreferences) ============
  
  static const String _clinicsKey = 'medication_clinics';

  static Future<List<Clinic>> getAllClinics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_clinicsKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => Clinic.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading clinics: $e');
      return [];
    }
  }

  static Future<Clinic?> getClinic(String id) async {
    final clinics = await getAllClinics();
    try {
      return clinics.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveClinic(Clinic clinic) async {
    try {
      final clinics = await getAllClinics();
      final index = clinics.indexWhere((c) => c.id == clinic.id);
      
      if (index >= 0) {
        clinics[index] = clinic;
      } else {
        clinics.add(clinic);
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clinicsKey, jsonEncode(clinics.map((c) => c.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving clinic: $e');
      rethrow;
    }
  }

  static Future<void> deleteClinic(String id) async {
    try {
      final clinics = await getAllClinics();
      clinics.removeWhere((c) => c.id == id);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clinicsKey, jsonEncode(clinics.map((c) => c.toJson()).toList()));
    } catch (e) {
      debugPrint('Error deleting clinic: $e');
      rethrow;
    }
  }

  // ============ APPOINTMENT METHODS ============

  static Future<List<Appointment>> getAllAppointments() async {
    final apps = await _dao.getAllAppointments();
    return apps.map(_mapToDomainAppointment).toList();
  }

  static Appointment _mapToDomainAppointment(db.Appointment a) {
    return Appointment(
      id: a.id,
      doctorId: a.doctorId,
      doctorName: a.title, // Using title as doctorName if doctorId not present
      dateTime: a.appointmentDateTime,
      location: a.location,
      notes: a.notes,
      reminderEnabled: a.reminderEnabled,
      reminderMinutesBefore: a.reminderMinutesBefore,
      isCompleted: a.isCompleted,
      dependentId: a.dependentId,
      medicineIds: a.medicineIdsJson != null ? List<String>.from(jsonDecode(a.medicineIdsJson!)) : null,
    );
  }

  static Future<void> addAppointment(Appointment appointment) async {
    await _dao.addAppointment(db.AppointmentsCompanion(
      id: drift.Value(appointment.id),
      doctorId: drift.Value(appointment.doctorId),
      title: drift.Value(appointment.doctorName),
      appointmentDateTime: drift.Value(appointment.dateTime),
      location: drift.Value(appointment.location),
      notes: drift.Value(appointment.notes),
      reminderEnabled: drift.Value(appointment.reminderEnabled),
      reminderMinutesBefore: drift.Value(appointment.reminderMinutesBefore),
      isCompleted: drift.Value(appointment.isCompleted),
      dependentId: drift.Value(appointment.dependentId),
      medicineIdsJson: drift.Value(appointment.medicineIds != null ? jsonEncode(appointment.medicineIds) : null),
      createdAt: drift.Value(DateTime.now()),
    ));
  }
  
  static Future<void> deleteAppointment(String id) async {
    await _dao.deleteAppointment(id);
  }

  // ============ DEPENDENT PROFILE METHODS ============

  static Future<List<DependentProfile>> getAllDependents() async {
    final deps = await _dao.getAllDependents();
    return deps.map(_mapToDomainDependent).toList();
  }
  
  static DependentProfile _mapToDomainDependent(db.DependentProfile d) {
    return DependentProfile(
      id: d.id,
      name: d.name,
      relationship: RelationshipType.values[d.relationshipType],
      dateOfBirth: d.dateOfBirth,
      bloodType: d.bloodType,
      notes: d.notes,
      avatarPath: d.photoPath,
      isActive: d.isActive,
      gender: d.gender,
      weight: d.weight,
      height: d.height,
      emergencyContact: d.emergencyContact,
      emergencyPhone: d.emergencyPhone,
      primaryDoctorId: d.primaryDoctorId,
      insuranceInfo: d.insuranceInfo,
      allergies: d.allergiesJson != null ? List<String>.from(jsonDecode(d.allergiesJson!)) : null,
      conditions: d.conditionsJson != null ? List<String>.from(jsonDecode(d.conditionsJson!)) : null,
      createdAt: d.createdAt,
    );
  }

  static Future<void> addDependent(DependentProfile dependent) async {
    await _dao.addDependent(db.DependentProfilesCompanion(
      id: drift.Value(dependent.id),
      name: drift.Value(dependent.name),
      relationshipType: drift.Value(dependent.relationship.index),
      dateOfBirth: drift.Value(dependent.dateOfBirth),
      bloodType: drift.Value(dependent.bloodType),
      notes: drift.Value(dependent.notes),
      photoPath: drift.Value(dependent.avatarPath),
      isActive: drift.Value(dependent.isActive),
      gender: drift.Value(dependent.gender),
      weight: drift.Value(dependent.weight),
      height: drift.Value(dependent.height),
      emergencyContact: drift.Value(dependent.emergencyContact),
      emergencyPhone: drift.Value(dependent.emergencyPhone),
      primaryDoctorId: drift.Value(dependent.primaryDoctorId),
      insuranceInfo: drift.Value(dependent.insuranceInfo),
      allergiesJson: drift.Value(dependent.allergies != null ? jsonEncode(dependent.allergies) : null),
      conditionsJson: drift.Value(dependent.conditions != null ? jsonEncode(dependent.conditions) : null),
      createdAt: drift.Value(dependent.createdAt),
      isSelf: drift.Value(dependent.relationship == RelationshipType.self),
    ));
  }
  
  static Future<void> updateDependent(DependentProfile dependent) async {
    await _dao.updateDependent(db.DependentProfilesCompanion(
      id: drift.Value(dependent.id),
      name: drift.Value(dependent.name),
      relationshipType: drift.Value(dependent.relationship.index),
      dateOfBirth: drift.Value(dependent.dateOfBirth),
      bloodType: drift.Value(dependent.bloodType),
      notes: drift.Value(dependent.notes),
      photoPath: drift.Value(dependent.avatarPath),
      isActive: drift.Value(dependent.isActive),
      gender: drift.Value(dependent.gender),
      weight: drift.Value(dependent.weight),
      height: drift.Value(dependent.height),
      emergencyContact: drift.Value(dependent.emergencyContact),
      emergencyPhone: drift.Value(dependent.emergencyPhone),
      primaryDoctorId: drift.Value(dependent.primaryDoctorId),
      insuranceInfo: drift.Value(dependent.insuranceInfo),
      allergiesJson: drift.Value(dependent.allergies != null ? jsonEncode(dependent.allergies) : null),
      conditionsJson: drift.Value(dependent.conditions != null ? jsonEncode(dependent.conditions) : null),
    ));
  }

  static Future<void> deleteDependent(String id) async {
    await _dao.deleteDependent(id);
  }

  // ============ BACKUP HELPERS ============

  /// Export all medicines (domain models) as JSON for inclusion in the full
  /// app backup. Uses the DOMAIN [EnhancedMedicine] (with toJson) this service
  /// imports, so it avoids the generated-Drift naming clash in clean_storage.
  static Future<List<Map<String, dynamic>>> exportMedicinesJson() async {
    final medicines = await getAllMedicines(includeArchived: true);
    return medicines.map((m) => m.toJson()).toList();
  }

  /// Restore medicines from a full-app backup. Non-destructive: each medicine
  /// is upserted by id via [saveMedicine], so restoring over existing data
  /// merges rather than duplicating or clobbering. Malformed entries are
  /// skipped so a single bad record can't fail the whole restore.
  static Future<void> importMedicinesJson(List<dynamic> data) async {
    for (final raw in data) {
      try {
        final medicine =
            EnhancedMedicine.fromJson(Map<String, dynamic>.from(raw as Map));
        await saveMedicine(medicine);
      } catch (e) {
        debugPrint('Import medicine failed: $e');
      }
    }
  }

  // ============ EXPORT METHODS ============

  static Future<Map<String, dynamic>> exportAllMedicineData() async {
    final medicines = await getAllMedicines(includeArchived: true);
    final logs = await getAllLogs();
    final doctors = await getAllDoctors();
    final pharmacies = await getAllPharmacies();
    final appointments = await getAllAppointments();
    final dependents = await getAllDependents();
    
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'medicines': medicines.map((m) => m.toJson()).toList(),
      'logs': logs.map((l) => l.toJson()).toList(),
      'doctors': doctors.map((d) => d.toJson()).toList(),
      'pharmacies': pharmacies.map((p) => p.toJson()).toList(),
      'appointments': appointments.map((a) => a.toJson()).toList(),
      'dependents': dependents.map((d) => d.toJson()).toList(),
    };
  }

  static DailyMedicineSummary getDailySummary(DateTime date) {
    // This needs to be async now. Return empty for sync call.
    return DailyMedicineSummary(
      date: date,
      totalScheduled: 0,
      taken: 0,
      skipped: 0,
      missed: 0,
      adherenceRate: 0,
      medicinesTaken: [],
      medicinesMissed: [],
    );
  }
  
  static Future<DailyMedicineSummary> getDailySummaryAsync(DateTime date) async {
    final logs = await getLogsForDate(date);
    final medicines = await getAllMedicines();
    final now = DateTime.now();

    // Denominator = scheduled (non-PRN) slots for this date that are already
    // due (past slots for prior days, or up to now for today). Future slots are
    // not counted so today's remaining doses don't drag adherence down.
    int scheduled = 0;
    for (final m in medicines) {
      if (!m.isActive || m.isArchived) continue;
      if (m.schedule.isPRN) continue;
      final slots = m.schedule.getScheduledTimesForDate(date);
      for (final slot in slots) {
        if (slot.isBefore(m.createdAt)) continue;
        if (slot.isAfter(now)) continue;
        scheduled++;
      }
    }

    final taken = logs.where((l) => l.isTaken).length;
    final skipped = logs.where((l) => l.isSkipped).length;
    final missed = logs.where((l) => l.isMissed).length;

    return DailyMedicineSummary(
      date: date,
      totalScheduled: scheduled,
      taken: taken,
      skipped: skipped,
      missed: missed,
      adherenceRate: scheduled > 0 ? taken / scheduled : 1.0,
      medicinesTaken: logs.where((l) => l.isTaken).map((l) => l.medicineId).toList(),
      medicinesMissed: logs.where((l) => l.isMissed).map((l) => l.medicineId).toList(),
    );
  }

  // ============ ANALYTICS METHODS ============

  /// Forgiving adherence streak via the shared [StreakEngine].
  ///
  /// A day counts as "completed" when **every due (non-PRN) dose that day was
  /// taken** — days with no scheduled doses (off-days / before any medicine
  /// existed) are vacuously complete so they never break the streak, and the
  /// engine forgives one missed day per rolling week. This replaces the old
  /// naive "any dose taken that day" counter (which overstated adherence and
  /// hard-reset on a single gap). Single source of truth for the whole app.
  static Future<StreakResult> getStreakResult() async {
    final medicines = await getAllMedicines();
    final active = medicines
        .where((m) => m.isActive && !m.isArchived && !m.schedule.isPRN)
        .toList();
    if (active.isEmpty) {
      return const StreakResult(
          current: 0, longest: 0, usedGrace: false, atRisk: false);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Window: from the earliest medicine's creation day, bounded to ~180 days.
    var earliest = today;
    for (final m in active) {
      final c = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (c.isBefore(earliest)) earliest = c;
    }
    final floor = today.subtract(const Duration(days: 180));
    if (earliest.isBefore(floor)) earliest = floor;

    // Keys of slots that were actually taken.
    final logs = await getLogsForDateRange(earliest, now);
    final takenKeys = <String>{};
    for (final l in logs.where((l) => l.isTaken)) {
      final t = l.scheduledTime;
      takenKeys.add('${t.year}-${t.month}-${t.day}-${t.hour}-${t.minute}');
    }

    final completed = <DateTime>{};
    for (var day = earliest;
        !day.isAfter(today);
        day = day.add(const Duration(days: 1))) {
      var due = 0;
      var taken = 0;
      for (final m in active) {
        final createdDay =
            DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
        if (day.isBefore(createdDay)) continue;
        for (final slot in m.schedule.getScheduledTimesForDate(day)) {
          if (slot.isBefore(m.createdAt)) continue;
          if (slot.isAfter(now)) continue; // today's upcoming doses aren't due yet
          due++;
          final k =
              '${slot.year}-${slot.month}-${slot.day}-${slot.hour}-${slot.minute}';
          if (takenKeys.contains(k)) taken++;
        }
      }
      if (due == 0 || taken == due) completed.add(day);
    }

    return StreakEngine.compute(
      completedDays: completed,
      today: today,
      graceDaysPerWeek: 1,
    );
  }

  /// Consecutive (forgiving, all-due) adherence streak. Sourced from
  /// [getStreakResult] so every caller shares one definition.
  static Future<int> getCurrentStreak() async =>
      (await getStreakResult()).current;

  static Future<Map<String, dynamic>> getAdherenceStats({int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final logs = await getLogsForDateRange(startDate, now);
    final medicines = await getAllMedicines();

    final taken = logs.where((l) => l.isTaken).length;
    final skipped = logs.where((l) => l.isSkipped).length;
    final missed = logs.where((l) => l.isMissed).length;
    final total = taken + skipped + missed;

    // The denominator that makes adherence meaningful: the number of scheduled
    // (non-PRN) doses that were actually due within the window, NOT logs.length.
    // Only due slots are counted (past days in full, today up to now), and only
    // from the day each medicine was created.
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final today = DateTime(now.year, now.month, now.day);
    int scheduled = 0;
    for (final med in medicines) {
      if (!med.isActive || med.isArchived) continue;
      if (med.schedule.isPRN) continue;
      final createdDay = DateTime(
          med.createdAt.year, med.createdAt.month, med.createdAt.day);
      for (var day = startDay;
          !day.isAfter(today);
          day = day.add(const Duration(days: 1))) {
        if (day.isBefore(createdDay)) continue;
        final slots = med.schedule.getScheduledTimesForDate(day);
        for (final slot in slots) {
          if (slot.isBefore(startDate)) continue;
          if (slot.isBefore(med.createdAt)) continue;
          if (slot.isAfter(now)) continue;
          scheduled++;
        }
      }
    }

    return {
      'taken': taken,
      'skipped': skipped,
      'missed': missed,
      'total': total,
      'scheduled': scheduled,
      'adherenceRate': scheduled > 0 ? (taken / scheduled * 100).round() : 100,
      'days': days,
    };
  }

  /// Per-medicine adherence over the trailing [days] window, using the same
  /// scheduled-slot denominator logic as [getAdherenceStats] but scoped to a
  /// single medicine. Returns taken/skipped/missed/total/scheduled/adherenceRate
  /// (adherenceRate as a 0-100 int). PRN or archived/inactive medicines yield an
  /// adherenceRate of 100 (nothing was due to miss).
  static Future<Map<String, dynamic>> getAdherenceStatsForMedicine(
    String medicineId, {
    int days = 30,
  }) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final medicine = await getMedicine(medicineId);

    final logs = (await getLogsForMedicine(medicineId))
        .where((l) =>
            !l.scheduledTime.isBefore(startDate) &&
            !l.scheduledTime.isAfter(now))
        .toList();

    final taken = logs.where((l) => l.isTaken).length;
    final skipped = logs.where((l) => l.isSkipped).length;
    final missed = logs.where((l) => l.isMissed).length;
    final total = taken + skipped + missed;

    int scheduled = 0;
    if (medicine != null &&
        medicine.isActive &&
        !medicine.isArchived &&
        !medicine.schedule.isPRN) {
      final startDay = DateTime(startDate.year, startDate.month, startDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final createdDay = DateTime(medicine.createdAt.year,
          medicine.createdAt.month, medicine.createdAt.day);
      for (var day = startDay;
          !day.isAfter(today);
          day = day.add(const Duration(days: 1))) {
        if (day.isBefore(createdDay)) continue;
        final slots = medicine.schedule.getScheduledTimesForDate(day);
        for (final slot in slots) {
          if (slot.isBefore(startDate)) continue;
          if (slot.isBefore(medicine.createdAt)) continue;
          if (slot.isAfter(now)) continue;
          scheduled++;
        }
      }
    }

    return {
      'taken': taken,
      'skipped': skipped,
      'missed': missed,
      'total': total,
      'scheduled': scheduled,
      'adherenceRate': scheduled > 0 ? (taken / scheduled * 100).round() : 100,
      'days': days,
    };
  }
}
