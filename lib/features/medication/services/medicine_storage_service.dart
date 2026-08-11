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
import '../../../core/health/streak_engine.dart';
import '../../../core/services/active_profile_service.dart';
import '../../../core/services/dose_action_queue.dart';
import '../../../core/services/notification_service.dart';
import 'appointment_reminder_service.dart';
import 'reminder_window_nudges.dart';
import 'vitals_storage_service.dart';

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
      route: data.routeIndex != null
          ? AdministrationRoute.values[data.routeIndex!]
          : null,
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
      routeIndex: drift.Value(medicine.route?.index),
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
      // isPreLogged checked BEFORE isTaken: a pre-logged row derived from an
      // older schema doesn't exist, but as a defensive ordering choice this
      // stays correct regardless of which flags a future write sets.
      status: data.isPreLogged ? MedicineStatus.preLogged
          : data.isTaken ? MedicineStatus.taken
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
      isPreLogged: drift.Value(log.status == MedicineStatus.preLogged),
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

  /// Whether [dependentId] belongs to the currently active profile
  /// ([ActiveProfileService]). Active == self (`null`) matches only records
  /// that ALSO carry a null `dependentId` — the read-side half of the
  /// "null means self" contract documented on [ActiveProfileService].
  static bool _inActiveProfile(String? dependentId) {
    final active = ActiveProfileService().activeDependentId;
    return active == null ? dependentId == null : dependentId == active;
  }

  /// [scopeToActiveProfile] defaults to true (every screen that lists "my
  /// medicines" wants only the active profile's) but MUST be passed false
  /// for global maintenance sweeps that have to see every profile regardless
  /// of which one is active — reminder (re)scheduling and missed-dose
  /// reconciliation both need this, since a caregiver's dependent's alarms
  /// must keep firing even while a different profile happens to be selected
  /// in the UI.
  static Future<List<EnhancedMedicine>> getAllMedicines({
    bool includeArchived = false,
    bool scopeToActiveProfile = true,
  }) async {
    final meds = await _dao.getAllMedicines(includeArchived: includeArchived);
    final domain = meds.map(_mapToDomainMedicine).toList();
    return scopeToActiveProfile
        ? domain.where((m) => _inActiveProfile(m.dependentId)).toList()
        : domain;
  }

  /// Every medicine belonging to [dependentId], regardless of which profile
  /// is currently active — this is an explicit cross-profile lookup (e.g. the
  /// dependent list previewing each member's medicine count), not a "my
  /// medicines" view, so it bypasses active-profile scoping entirely.
  static Future<List<EnhancedMedicine>> getMedicinesForDependent(String dependentId) async {
    final meds = await getAllMedicines(includeArchived: true, scopeToActiveProfile: false);
    return meds.where((m) => m.dependentId == dependentId).toList();
  }

  static Future<List<EnhancedMedicine>> getMedicinesForDependentAsync(String dependentId) =>
      getMedicinesForDependent(dependentId);

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

  static Future<List<EnhancedMedicine>> getExpiringMedicinesAsync({
    int daysAhead = 30,
    bool scopeToActiveProfile = true,
  }) async {
    final cutoff = DateTime.now().add(Duration(days: daysAhead));
    final meds =
        await getAllMedicines(scopeToActiveProfile: scopeToActiveProfile);
    return meds.where((m) {
      if (m.expiryDate == null) return false;
      return m.expiryDate!.isBefore(cutoff);
    }).toList();
  }

  static Future<EnhancedMedicine?> getMedicine(String id) async {
    final med = await _dao.getMedicine(id);
    return med != null ? _mapToDomainMedicine(med) : null;
  }

  /// [stampActiveProfile] must be false when restoring a backup: an imported
  /// medicine's `dependentId` is already authoritative (it came from the
  /// backup file itself, including a legitimate null for a self-owned
  /// medicine), and stamping it here would misattribute a self-owned
  /// medicine to whichever profile merely happens to be active during the
  /// restore. See [importMedicinesJson].
  static Future<void> saveMedicine(
    EnhancedMedicine medicine, {
    bool stampActiveProfile = true,
  }) async {
    final existing = await getMedicine(medicine.id);
    if (existing != null) {
      await updateMedicine(medicine);
    } else {
      await addMedicine(medicine, stampActiveProfile: stampActiveProfile);
    }
  }

  static Future<void> addMedicine(
    EnhancedMedicine medicine, {
    bool stampActiveProfile = true,
  }) async {
    final toSave =
        stampActiveProfile ? _stampActiveProfile(medicine) : medicine;
    await _dao.addMedicine(_mapToMedicineCompanion(toSave));
    _bumpRevision();
  }

  /// A brand-new medicine with no explicit owner is created for whoever is
  /// currently active. Self stays null (nothing to stamp — see
  /// [ActiveProfileService]'s "null means self" contract); a medicine that
  /// already carries a `dependentId` (e.g. an edit) is left untouched so
  /// switching profiles can never silently reassign an existing medicine's
  /// owner.
  static EnhancedMedicine _stampActiveProfile(EnhancedMedicine medicine) {
    if (medicine.dependentId != null) return medicine;
    final active = ActiveProfileService().activeDependentId;
    return active == null ? medicine : medicine.copyWith(dependentId: active);
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

  /// Put back the units a dose removed — used by Undo so undoing a "taken" dose
  /// also reverses its stock decrement (previously only the log was deleted).
  static Future<void> restoreStock(String medicineId, double amount) async {
    final med = await getMedicine(medicineId);
    if (med != null && med.currentStock != null) {
      await updateMedicine(med.restoreStock(amount));
    }
  }

  // ============ MEDICINE LOG METHODS ============

  static Future<List<MedicineLog>> getAllLogs({bool scopeToActiveProfile = true}) async {
    final logs = await _dao.getAllLogs();
    final domain = logs.map(_mapToDomainLog).toList();
    return scopeToActiveProfile
        ? domain.where((l) => _inActiveProfile(l.dependentId)).toList()
        : domain;
  }

  /// Single log by id (for Undo, which must know the medicine + dose amount to
  /// reverse a stock decrement before deleting the log).
  static Future<MedicineLog?> getLog(String id) async {
    final row = await _dao.getLogById(id);
    return row == null ? null : _mapToDomainLog(row);
  }

  /// [scopeToActiveProfile] only matters when this medicine's OWNER differs
  /// from the currently active profile — true by default, matching every
  /// other MedicineLog read path (getAllLogs, getLogsForDate,
  /// getLogsForDateRange). Callers that intentionally process medicines
  /// across every profile at once (e.g. MedicationReminderService's
  /// _adaptiveSuggestionMinutes, recomputing reminders for the full
  /// cross-profile medicine list) MUST pass false, or every log for a
  /// non-active profile's medicine is silently filtered out — exactly the
  /// bug that forced that specific call site to override the default.
  static Future<List<MedicineLog>> getLogsForMedicine(
    String medicineId, {
    bool scopeToActiveProfile = true,
  }) async {
    final logs = await _dao.getLogsForMedicine(medicineId);
    final domain = logs.map(_mapToDomainLog).toList();
    return scopeToActiveProfile
        ? domain.where((l) => _inActiveProfile(l.dependentId)).toList()
        : domain;
  }

  static Future<List<MedicineLog>> getLogsForDate(
    DateTime date, {
    bool scopeToActiveProfile = true,
  }) async {
    final logs = await _dao.getLogsForDate(date);
    final domain = logs.map(_mapToDomainLog).toList();
    return scopeToActiveProfile
        ? domain.where((l) => _inActiveProfile(l.dependentId)).toList()
        : domain;
  }

  static Future<List<MedicineLog>> getLogsForDateRange(
    DateTime start,
    DateTime end, {
    bool scopeToActiveProfile = true,
  }) async {
    final logs = await _dao.getLogsForDateRange(start, end);
    final domain = logs.map(_mapToDomainLog).toList();
    return scopeToActiveProfile
        ? domain.where((l) => _inActiveProfile(l.dependentId)).toList()
        : domain;
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

  /// The canonical log id for one scheduled dose.
  ///
  /// A slot has exactly ONE outcome — taken, skipped, or missed — so the id is
  /// derived from (medicine, slot) and never from `DateTime.now()`. That makes
  /// `addLog` idempotent per slot: re-skipping a dose, or taking one that was
  /// previously skipped, replaces the row instead of adding another.
  ///
  /// Both id schemes used to be timestamp-based, so every tap appended a row.
  /// `getDailySummaryAsync` counts rows, so two skips of one dose read as two
  /// skipped doses; the Today hero computes `taken + skipped + missed` against
  /// the scheduled total and could exceed it, showing e.g. "3/2".
  ///
  /// PRN ("as needed") doses are unaffected: they pass a distinct
  /// `scheduledTime` for each intake, so their ids stay unique.
  static String doseLogId(String medicineId, DateTime scheduledTime) =>
      '${medicineId}_${scheduledTime.millisecondsSinceEpoch}';

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
    // A log inherits its medicine's owner — not necessarily whatever profile
    // happens to be active right now — so it stays correctly scoped even if
    // this fires from a background path (e.g. a notification "Take all")
    // while a different profile is open in the UI.
    final medicine = await getMedicine(medicineId);
    final log = MedicineLog.taken(
      id: doseLogId(medicineId, scheduledTime),
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      dosageTaken: dosageTaken,
      notes: notes,
      sideEffects: sideEffects,
      moodRating: moodRating,
      effectivenessRating: effectivenessRating,
      dependentId: medicine?.dependentId,
      vitals: vitals,
    );
    await addLog(log);
    await _markDoseResolved(medicineId, scheduledTime);

    // Update stock if tracked
    await reduceStock(medicineId, dosageTaken);

    return log;
  }

  /// Logs a dose taken NOW, ahead of its real future [scheduledTime] slot —
  /// travel/timezone, or a pre-filled pillbox. Mirrors [markMedicineTaken]
  /// exactly (same stock decrement, same resolved-flag, same owner
  /// inheritance) except the persisted status and that [scheduledTime] is
  /// expected to be in the future rather than defaulted to "now".
  static Future<MedicineLog> markMedicinePreLogged({
    required String medicineId,
    required DateTime scheduledTime,
    double dosageTaken = 1,
    String? notes,
    String? sideEffects,
    int? moodRating,
    int? effectivenessRating,
    Map<String, dynamic>? vitals,
  }) async {
    final medicine = await getMedicine(medicineId);
    final log = MedicineLog.preLogged(
      id: doseLogId(medicineId, scheduledTime),
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      dosageTaken: dosageTaken,
      notes: notes,
      sideEffects: sideEffects,
      moodRating: moodRating,
      effectivenessRating: effectivenessRating,
      dependentId: medicine?.dependentId,
      vitals: vitals,
    );
    await addLog(log);
    // Suppresses follow-up window nudges for this slot. The PRIMARY alarm at
    // the original scheduled time is NOT suppressed by this flag (no gate
    // exists for it today — a pre-existing gap shared with "took it early",
    // not something this feature introduces or can fix here).
    await _markDoseResolved(medicineId, scheduledTime);

    await reduceStock(medicineId, dosageTaken);

    return log;
  }

  /// Marks (medicineId, scheduledTime) as resolved for Phase 4's reminder
  /// windows — checked by every nudge in that window before firing, so
  /// taking or skipping a dose (via ANY path: in-app, a notification action,
  /// or a "Take all") stops the rest of that window's nudges. A no-op,
  /// never-read flag for a medicine that was never windowed.
  static Future<void> _markDoseResolved(
      String medicineId, DateTime scheduledTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(nudgeResolvedKey(medicineId, scheduledTime), true);
    } catch (e) {
      debugPrint('⚠️ Failed to mark dose resolved: $e');
    }
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
  ///
  /// A global sweep, deliberately unscoped: every profile's missed doses get
  /// reconciled every time this runs, regardless of which one is active, so
  /// switching profiles later immediately shows correct historical data
  /// instead of only whatever was active at the moment a dose went missed.
  static Future<void> reconcileMissedDoses({int lookbackDays = 14}) async {
    const graceHours = 3;
    final now = DateTime.now();
    final graceCutoff = now.subtract(const Duration(hours: graceHours));
    final startDate = now.subtract(Duration(days: lookbackDays));
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final today = DateTime(now.year, now.month, now.day);

    final medicines = await getAllMedicines(scopeToActiveProfile: false);
    // Fetch from the midnight of the first day so every slot we iterate over is
    // covered by the idempotency check below (slots can precede `startDate`).
    final existingLogs =
        await getLogsForDateRange(startDay, now, scopeToActiveProfile: false);

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
          // Idempotency: skip only if a TERMINAL log (taken/skipped/missed/
          // preLogged) already exists for this exact slot. A non-terminal
          // (pending) log must not suppress the missed insert, or a
          // deferred-then-forgotten dose would never be counted as missed.
          // preLogged MUST be included here: addLog upserts on doseLogId, so
          // without this a pre-logged future slot that ages past the grace
          // window would get a `missed` row silently written over it.
          final exists = medLogs.any((l) =>
              (l.isTaken || l.isSkipped || l.isMissed || l.isPreLogged) &&
              l.scheduledTime.year == slot.year &&
              l.scheduledTime.month == slot.month &&
              l.scheduledTime.day == slot.day &&
              l.scheduledTime.hour == slot.hour &&
              l.scheduledTime.minute == slot.minute);
          if (exists) continue;

          // Must use the canonical [doseLogId] — the SAME id the take/skip paths
          // use. It previously carried a `_missed_` infix, which gave a missed
          // row a different primary key from a later taken row for the same
          // slot. `addLog` upserts on the primary key, so it could not collapse
          // them: the slot ended up with two rows, `getTodaysDoses` picked the
          // older `missed` one, and Home showed a dose you had just taken as
          // "OVERDUE" — while re-decrementing stock on every further tap.
          toInsert.add(MedicineLog.missed(
            id: doseLogId(med.id, slot),
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

    await _alertCaregiversOfMissedDoses(toInsert, now);
    await _alertExpiringMedicines(now);
    await _pruneStaleResolvedFlags(now);
    await _pruneStaleExpiryFlags(now);
  }

  /// Fires a one-time "expiring soon"/"expired" notification per medicine,
  /// piggybacking on this sweep the same way [_alertCaregiversOfMissedDoses]
  /// does. Deduped like [reduceStock]'s low-stock alert (fire once when a
  /// threshold is crossed, not on every sweep) — but since a medicine has no
  /// wasLow-style prior-state to compare against here, the "already alerted"
  /// flag is a SharedPreferences entry instead, keyed by expiryDate so
  /// changing it (e.g. after a refill) naturally re-arms the alert.
  /// Best-effort — a notification failure must never surface as a
  /// reconciliation failure.
  static Future<void> _alertExpiringMedicines(DateTime now) async {
    try {
      // Unscoped, matching reconcileMissedDoses' own contract — a caregiver's
      // dependent must keep getting expiry alerts while a different profile
      // is active, exactly like _alertCaregiversOfMissedDoses above.
      final expiring =
          await getExpiringMedicinesAsync(scopeToActiveProfile: false);
      if (expiring.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      for (final med in expiring) {
        final expiry = med.expiryDate!;
        final key = 'expiry_notified_${med.id}_${expiry.millisecondsSinceEpoch}';
        if (prefs.getBool(key) ?? false) continue;

        final daysLeft = expiry.difference(now).inDays;
        final body = med.isExpired
            ? '${med.name} has expired — check before your next dose.'
            : '${med.name} expires in $daysLeft day${daysLeft == 1 ? '' : 's'}.';
        final ok = await NotificationService().showImmediateNotification(
          title: med.isExpired ? 'Medicine expired' : 'Medicine expiring soon',
          body: body,
          channelId: 'medicine_channel',
        );
        if (ok) await prefs.setBool(key, true);
      }
    } catch (e) {
      debugPrint('⚠️ Expiry alert failed: $e');
    }
  }

  /// Removes `expiry_notified_` flags whose embedded expiry date is more than
  /// 90 days in the past — a medicine still tracked that long past its
  /// stated expiry is unlikely to need the SAME alert again, and this stops
  /// one key accumulating forever per medicine per expiry-date change (a
  /// refill mints a new key; the old one otherwise never gets removed). Piggy
  /// backs on this sweep like [_pruneStaleResolvedFlags].
  static Future<void> _pruneStaleExpiryFlags(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cutoff = now.subtract(const Duration(days: 90)).millisecondsSinceEpoch;
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('expiry_notified_')) continue;
        final millisStr = key.split('_').last;
        final millis = int.tryParse(millisStr);
        if (millis != null && millis < cutoff) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Pruning stale expiry flags failed: $e');
    }
  }

  /// Removes `nudge_resolved_` flags (Phase 4's reminder windows) more than
  /// 48h old. Each flag is a one-off, per-dose SharedPreferences entry (see
  /// `_markDoseResolved`) that's never explicitly deleted when written —
  /// without this, they'd accumulate forever, one per dose ever taken/
  /// skipped. Piggybacks on this existing periodic sweep rather than
  /// inventing a new one; best-effort like the rest of reconciliation.
  static Future<void> _pruneStaleResolvedFlags(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cutoff = now.subtract(const Duration(hours: 48)).millisecondsSinceEpoch;
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('nudge_resolved_')) continue;
        final millisStr = key.split('_').last;
        final millis = int.tryParse(millisStr);
        if (millis != null && millis < cutoff) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Pruning stale resolved flags failed: $e');
    }
  }

  /// One local notification per non-self dependent with a RECENT newly-missed
  /// dose — matching Medisafe's "even know when they miss a dose." Self never
  /// alerts (there's no one else to notify). Deliberately scoped to the last
  /// 24h, not the full lookback window: a first-ever reconciliation (or one
  /// after days offline) can backfill many old misses at once, and alerting
  /// on all of them would read as spam rather than a timely heads-up.
  /// Best-effort — a notification failure must never surface as a
  /// reconciliation failure.
  static Future<void> _alertCaregiversOfMissedDoses(
      List<MedicineLog> newlyMissed, DateTime now) async {
    try {
      final recentCutoff = now.subtract(const Duration(hours: 24));
      final recent = newlyMissed
          .where((l) => l.scheduledTime.isAfter(recentCutoff))
          .toList();
      final dependentIds = recent.map((l) => l.dependentId).whereType<String>().toSet();
      if (dependentIds.isEmpty) return;

      final dependents = await getAllDependents();
      for (final id in dependentIds) {
        final profile = dependents.where((d) => d.id == id).firstOrNull;
        if (profile == null) continue;
        final count = recent.where((l) => l.dependentId == id).length;
        await NotificationService().showCaregiverAlert(
          title: 'Missed dose',
          body: '${profile.name} missed $count dose${count == 1 ? '' : 's'}.',
          // Varies per dependent — the title above doesn't, so keying the
          // notification id on it would collide and silently overwrite one
          // dependent's alert with another's in the same sweep.
          dedupeKey: id,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Caregiver missed-dose alert failed: $e');
    }
  }

  static Future<MedicineLog> markMedicineSkipped({
    required String medicineId,
    required DateTime scheduledTime,
    required SkipReason reason,
    String? skipNote,
  }) async {
    // See markMedicineTaken — a log inherits its medicine's owner.
    final medicine = await getMedicine(medicineId);
    final log = MedicineLog.skipped(
      id: doseLogId(medicineId, scheduledTime),
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      reason: reason,
      skipNote: skipNote,
      dependentId: medicine?.dependentId,
    );
    await addLog(log);
    await _markDoseResolved(medicineId, scheduledTime);
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
                medicineId: a.medicineId,
                scheduledTime: a.scheduledTime,
                // The queue carries no dose amount (it's written from the alarm
                // isolate, which can't read Drift), so resolve it here exactly
                // the way the in-app take path does — including titration.
                // Defaulting to 1 under-decremented stock for every medicine
                // whose dose isn't a single unit (e.g. "2 tablets"), which
                // drifts refill predictions and runs the patient out early.
                dosageTaken: med.schedule
                    .effectiveDosageAmount(a.scheduledTime, med.dosageAmount),
              )
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

  static Future<List<Appointment>> getAllAppointments({
    bool scopeToActiveProfile = true,
  }) async {
    final apps = await _dao.getAllAppointments();
    final domain = apps.map(_mapToDomainAppointment).toList();
    return scopeToActiveProfile
        ? domain.where((a) => _inActiveProfile(a.dependentId)).toList()
        : domain;
  }

  static Future<List<Appointment>> getUpcomingAppointments({
    bool scopeToActiveProfile = true,
  }) async {
    final apps = await _dao.getUpcomingAppointments();
    final domain = apps.map(_mapToDomainAppointment).toList();
    return scopeToActiveProfile
        ? domain.where((a) => _inActiveProfile(a.dependentId)).toList()
        : domain;
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

  static db.AppointmentsCompanion _appointmentToCompanion(Appointment appointment) {
    return db.AppointmentsCompanion(
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
    );
  }

  /// A brand-new appointment with no explicit owner is created for whoever is
  /// currently active — see [_stampActiveProfile]'s doc (same "null means
  /// self, never overwrite an existing owner" contract as medicines).
  /// [stampActiveProfile] must be false when restoring a backup — see
  /// [saveMedicine]'s doc for why.
  static Future<void> addAppointment(
    Appointment appointment, {
    bool stampActiveProfile = true,
  }) async {
    Appointment toSave = appointment;
    if (stampActiveProfile && appointment.dependentId == null) {
      final active = ActiveProfileService().activeDependentId;
      if (active != null) toSave = appointment.copyWith(dependentId: active);
    }
    await _dao.addAppointment(_appointmentToCompanion(toSave));
    await AppointmentReminderService.schedule(toSave);
  }

  static Future<void> updateAppointment(Appointment appointment) async {
    await _dao.updateAppointment(_appointmentToCompanion(appointment));
    await AppointmentReminderService.schedule(appointment);
  }

  static Future<void> deleteAppointment(String id) async {
    await _dao.deleteAppointment(id);
    await AppointmentReminderService.cancelById(id);
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

  /// Deletes a dependent's PROFILE row, but reassigns everything they owned
  /// back to self first — deleting a profile must not orphan its medicines,
  /// logs or vitals under an id that can never be selected again. This is
  /// what the delete confirmation's "their medicines and history stay on
  /// device" promise actually depends on.
  static Future<void> deleteDependent(String id) async {
    final medicines = await getMedicinesForDependent(id);
    for (final m in medicines) {
      await updateMedicine(m.copyWith(clearDependentId: true));
    }

    final logs = (await getAllLogs(scopeToActiveProfile: false))
        .where((l) => l.dependentId == id);
    for (final l in logs) {
      await updateLog(l.copyWith(clearDependentId: true));
    }

    // syncToHealthConnect: false for the same reason importJson uses it — a
    // dependent can accumulate readings from before sync was enabled (or
    // while write permission was denied), all with unset synced flags;
    // without this guard, reassigning them here would bulk-push that
    // dependent's entire unsynced history to Health Connect/HealthKit as a
    // side effect of deleting their profile.
    final bpReadings = (await VitalsStorageService.getAllBp(scopeToActiveProfile: false))
        .where((r) => r.dependentId == id);
    for (final r in bpReadings) {
      await VitalsStorageService.saveBp(r.copyWith(clearDependentId: true),
          stampActiveProfile: false, syncToHealthConnect: false);
    }
    final glucoseReadings =
        (await VitalsStorageService.getAllGlucose(scopeToActiveProfile: false))
            .where((r) => r.dependentId == id);
    for (final r in glucoseReadings) {
      await VitalsStorageService.saveGlucose(r.copyWith(clearDependentId: true),
          stampActiveProfile: false, syncToHealthConnect: false);
    }

    final appointments = (await getAllAppointments(scopeToActiveProfile: false))
        .where((a) => a.dependentId == id);
    for (final a in appointments) {
      await updateAppointment(a.copyWith(clearDependentId: true));
    }

    await _dao.deleteDependent(id);
  }

  // ============ BACKUP HELPERS ============

  /// Key under which a medicine's dose history (its MedicineLogs rows) rides
  /// along inside that medicine's own exported JSON map.
  ///
  /// MedicineLogs were in NO backup and NO cloud sync, so a restore brought
  /// back every medicine but ZERO adherence history — every dose ever taken,
  /// skipped or missed was gone, and with it every streak, adherence
  /// percentage and doctor-facing report. Carrying the logs inside the
  /// medicines section (rather than as a new top-level section) keeps the
  /// backup format compatible in BOTH directions: an older app reading a new
  /// backup ignores the extra key, and a newer app reading an old backup just
  /// finds no history to restore.
  static const String doseLogsBackupKey = 'doseLogs';

  /// Every dose log across every profile, as JSON. Unscoped for the same
  /// reason as [exportMedicinesJson].
  static Future<List<Map<String, dynamic>>> exportDoseLogsJson() async {
    final logs = await getAllLogs(scopeToActiveProfile: false);
    return logs.map((l) => l.toJson()).toList();
  }

  /// Restore dose logs. Non-destructive and idempotent: [addLog] upserts on
  /// the log's own id (see [doseLogId]), so restoring the same backup twice
  /// can never duplicate a dose, and a malformed entry is skipped instead of
  /// failing the whole restore.
  ///
  /// Merge semantics match [importMedicinesJson]'s: where a slot exists both
  /// locally and in the backup, the BACKUP's row wins.
  static Future<void> importDoseLogsJson(List<dynamic> data) async {
    for (final raw in data) {
      try {
        final log =
            MedicineLog.fromJson(Map<String, dynamic>.from(raw as Map));
        if (log.id.isEmpty || log.medicineId.isEmpty) continue;
        await addLog(log);
      } catch (e) {
        debugPrint('Import dose log failed: $e');
      }
    }
  }

  /// Export all medicines (domain models) as JSON for inclusion in the full
  /// app backup. Uses the DOMAIN [EnhancedMedicine] (with toJson) this service
  /// imports, so it avoids the generated-Drift naming clash in clean_storage.
  ///
  /// Each medicine carries its own dose history under [doseLogsBackupKey] —
  /// see that constant for why the logs live here instead of in a new
  /// top-level section. Logs are grouped by `medicineId`; `deleteMedicine`
  /// cascade-deletes a medicine's logs, so an orphaned log (one whose medicine
  /// no longer exists) is not a state the app can normally reach.
  ///
  /// Unscoped (`scopeToActiveProfile: false`): a backup taken while, say,
  /// "Kid A" is the active profile must still capture every OTHER profile's
  /// medicines too, or restoring it would silently lose them.
  static Future<List<Map<String, dynamic>>> exportMedicinesJson() async {
    final medicines =
        await getAllMedicines(includeArchived: true, scopeToActiveProfile: false);
    final logsByMedicine = <String, List<Map<String, dynamic>>>{};
    for (final log in await exportDoseLogsJson()) {
      final medicineId = log['medicineId']?.toString();
      if (medicineId == null || medicineId.isEmpty) continue;
      (logsByMedicine[medicineId] ??= <Map<String, dynamic>>[]).add(log);
    }
    return medicines.map((m) {
      final json = m.toJson();
      final logs = logsByMedicine[m.id];
      if (logs != null && logs.isNotEmpty) json[doseLogsBackupKey] = logs;
      return json;
    }).toList();
  }

  /// Restore medicines from a full-app backup. Non-destructive: each medicine
  /// is upserted by id via [saveMedicine], so restoring over existing data
  /// merges rather than duplicating or clobbering. Malformed entries are
  /// skipped so a single bad record can't fail the whole restore.
  ///
  /// The medicine's dose history ([doseLogsBackupKey]) is restored right after
  /// the medicine itself, so the logs never reference a medicine that hasn't
  /// been written yet. An old backup without that key restores the medicine
  /// exactly as before.
  static Future<void> importMedicinesJson(List<dynamic> data) async {
    for (final raw in data) {
      try {
        final json = Map<String, dynamic>.from(raw as Map);
        final medicine = EnhancedMedicine.fromJson(json);
        await saveMedicine(medicine, stampActiveProfile: false);
        final logs = json[doseLogsBackupKey];
        if (logs is List) await importDoseLogsJson(logs);
      } catch (e) {
        debugPrint('Import medicine failed: $e');
      }
    }
  }

  // ============ EXPORT METHODS ============

  static Future<Map<String, dynamic>> exportAllMedicineData() async {
    // Unscoped — a full-data export must cover every profile, not just
    // whichever one happens to be active (see exportMedicinesJson).
    final medicines =
        await getAllMedicines(includeArchived: true, scopeToActiveProfile: false);
    final logs = await getAllLogs(scopeToActiveProfile: false);
    final doctors = await getAllDoctors();
    final pharmacies = await getAllPharmacies();
    final appointments = await getAllAppointments(scopeToActiveProfile: false);
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

    // Scope counts to the same population as the scheduled denominator so the
    // rate can't exceed 100% from archived/PRN/orphaned taken logs.
    final eligibleIds = medicines
        .where((m) => m.isActive && !m.isArchived && !m.schedule.isPRN)
        .map((m) => m.id)
        .toSet();
    // ONE outcome per slot. Deterministic log ids (see [doseLogId]) keep this
    // true for anything written from now on, but installs created before that
    // fix can already hold several rows for the same dose — and these counts feed
    // the Today hero's `taken + skipped + missed` against `scheduled`, so a
    // duplicate showed up as "3/2 taken". Collapsing at read time heals that
    // existing data without a migration.
    final scopedLogs =
        dedupeByDose(logs.where((l) => eligibleIds.contains(l.medicineId)));
    // countsAsTaken folds in preLogged — a pre-logged dose was physically
    // taken, just ahead of its scheduled slot.
    final taken = scopedLogs.where((l) => l.countsAsTaken).length;
    final skipped = scopedLogs.where((l) => l.isSkipped).length;
    final missed = scopedLogs.where((l) => l.isMissed).length;

    return DailyMedicineSummary(
      date: date,
      totalScheduled: scheduled,
      taken: taken,
      skipped: skipped,
      missed: missed,
      adherenceRate: scheduled > 0 ? (taken / scheduled).clamp(0.0, 1.0) : 1.0,
      medicinesTaken: scopedLogs
          .where((l) => l.countsAsTaken)
          .map((l) => l.medicineId)
          .toList(),
      medicinesMissed:
          scopedLogs.where((l) => l.isMissed).map((l) => l.medicineId).toList(),
    );
  }

  /// Collapse [logs] to one entry per (medicine, scheduled slot).
  ///
  /// When a slot has several rows, the winner is the one that reflects what the
  /// user actually did: an explicit **taken** beats an explicit **skipped**,
  /// and both beat **missed** — which is written automatically by the
  /// missed-dose reconciler and must never override a real action.
  ///
  /// Pure, and part of the public surface: every path that derives counts from
  /// logs must go through this, or a slot with more than one row is counted
  /// twice. Mirrors the ranking in `TodayScheduleService.mostAuthoritative` so
  /// the schedule view and the adherence numbers agree.
  static List<MedicineLog> dedupeByDose(Iterable<MedicineLog> logs) {
    int rank(MedicineLog l) {
      if (l.isTaken) return 4;
      if (l.isPreLogged) return 3;
      if (l.isSkipped) return 2;
      if (l.isMissed) return 1;
      return 0;
    }

    final best = <String, MedicineLog>{};
    for (final l in logs) {
      final key = doseLogId(l.medicineId, l.scheduledTime);
      final current = best[key];
      if (current == null || rank(l) > rank(current)) best[key] = l;
    }
    return best.values.toList();
  }

  // ============ ANALYTICS METHODS ============

  /// Identity of ONE medicine's dose slot, at minute granularity.
  ///
  /// The medicine id is part of the key: several medicines routinely share the
  /// same minute (see `groupRemindersBySlot`), so a time-only key makes one
  /// medicine's "taken" satisfy every other medicine due at that minute.
  ///
  /// Deliberately minute-granular rather than [doseLogId]'s exact epoch
  /// millis: a log's `scheduledTime` can carry seconds when it came from a
  /// path that falls back to `DateTime.now()` (e.g. the alarm screen), while a
  /// slot from `getScheduledTimesForDate` never does, and an exact-millis
  /// comparison would then read a genuinely taken dose as untaken.
  static String _slotKey(String medicineId, DateTime slot) =>
      '$medicineId@${slot.year}-${slot.month}-${slot.day}-${slot.hour}-${slot.minute}';

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
    //
    // The key MUST carry the medicine id. Keyed on clock time alone, two
    // medicines sharing an 08:00 slot (the normal case — `groupRemindersBySlot`
    // exists precisely to collapse same-minute medicines into one reminder)
    // both resolved as taken when only ONE was, so the day counted as complete
    // and the patient was shown a perfect streak while never taking the second
    // drug.
    //
    // The log set is scoped to the same eligible population as the `due`
    // denominator below (active, non-archived, non-PRN) — see
    // [getAdherenceStats], which already does this. Without it a PRN or
    // ARCHIVED medicine logged at 08:00 marked the 08:00 statin as taken.
    final eligibleIds = active.map((m) => m.id).toSet();
    final logs = await getLogsForDateRange(earliest, now);
    final takenKeys = <String>{};
    for (final l in logs.where(
        (l) => l.countsAsTaken && eligibleIds.contains(l.medicineId))) {
      takenKeys.add(_slotKey(l.medicineId, l.scheduledTime));
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
          if (takenKeys.contains(_slotKey(m.id, slot))) taken++;
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

    // Scope the numerator to the same population as the scheduled denominator
    // (active, non-archived, non-PRN). Counting taken logs from archived / PRN /
    // orphaned medicines against a denominator that excludes them let adherence
    // exceed 100% ("12 of 7 doses").
    final eligibleIds = medicines
        .where((m) => m.isActive && !m.isArchived && !m.schedule.isPRN)
        .map((m) => m.id)
        .toSet();
    // Collapse to one row per slot first. Installs written before the
    // missed-dose id fix can hold both a `missed` and a `taken` row for the
    // same slot, which double-counted here and could push `total` past the
    // scheduled denominator.
    final scoped =
        dedupeByDose(logs.where((l) => eligibleIds.contains(l.medicineId)));
    final taken = scoped.where((l) => l.countsAsTaken).length;
    final skipped = scoped.where((l) => l.isSkipped).length;
    final missed = scoped.where((l) => l.isMissed).length;
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
      'adherenceRate':
          scheduled > 0 ? (taken / scheduled * 100).round().clamp(0, 100) : 100,
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

    // Deduped per slot — see getAdherenceStats.
    final logs = dedupeByDose((await getLogsForMedicine(medicineId)).where((l) =>
        !l.scheduledTime.isBefore(startDate) &&
        !l.scheduledTime.isAfter(now)));

    final taken = logs.where((l) => l.countsAsTaken).length;
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
      'adherenceRate':
          scheduled > 0 ? (taken / scheduled * 100).round().clamp(0, 100) : 100,
      'days': days,
    };
  }
}
