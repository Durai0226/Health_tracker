import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../models/doctor_pharmacy.dart';
import '../models/dependent_profile.dart';
import '../models/medicine_enums.dart';

/// Enhanced Medicine Storage Service with all premium features
class MedicineStorageService {
  static const String _medicinesBoxName = 'enhanced_medicines';
  static const String _logsBoxName = 'medicine_logs';
  static const String _doctorsBoxName = 'doctors';
  static const String _pharmaciesBoxName = 'pharmacies';
  static const String _appointmentsBoxName = 'appointments';
  static const String _dependentsBoxName = 'dependents';
  static const String _treatmentsBoxName = 'treatments';

  static bool _isInitialized = false;

  static String? get _currentUserId {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.uid;
    }
    return null;
  }

  static Future<void> _syncToCloud(String collection, String docId, Map<String, dynamic> data) async {
    final userId = _currentUserId;
    if (userId == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .set(data);
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');
    }
  }

  static Future<void> _deleteFromCloud(String collection, String docId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting from cloud: $e');
    }
  }

  static Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Try to get encryption key, fallback to no encryption on web
      HiveAesCipher? cipher;
      try {
        final encryptionKey = await SecureStorageHelper.getEncryptionKey();
        cipher = HiveAesCipher(encryptionKey);
      } catch (e) {
        debugPrint('Secure storage not available, using unencrypted storage: $e');
      }
      
      // Open boxes - adapters are registered in main StorageService
      if (!Hive.isBoxOpen(_medicinesBoxName)) {
        await Hive.openBox<EnhancedMedicine>(_medicinesBoxName, encryptionCipher: cipher);
      }
      if (!Hive.isBoxOpen(_logsBoxName)) {
        await Hive.openBox<MedicineLog>(_logsBoxName, encryptionCipher: cipher);
      }
      if (!Hive.isBoxOpen(_doctorsBoxName)) {
        await Hive.openBox<Doctor>(_doctorsBoxName, encryptionCipher: cipher);
      }
      if (!Hive.isBoxOpen(_pharmaciesBoxName)) {
        await Hive.openBox<Pharmacy>(_pharmaciesBoxName, encryptionCipher: cipher);
      }
      if (!Hive.isBoxOpen(_appointmentsBoxName)) {
        await Hive.openBox<Appointment>(_appointmentsBoxName, encryptionCipher: cipher);
      }
      if (!Hive.isBoxOpen(_dependentsBoxName)) {
        await Hive.openBox<DependentProfile>(_dependentsBoxName, encryptionCipher: cipher);
      }
      if (!Hive.isBoxOpen(_treatmentsBoxName)) {
        await Hive.openBox<TreatmentCourse>(_treatmentsBoxName, encryptionCipher: cipher);
      }
      
      _isInitialized = true;
      debugPrint('✓ MedicineStorageService initialized');
    } catch (e) {
      debugPrint('Error initializing MedicineStorageService: $e');
      rethrow;
    }
  }

  // ============ ENHANCED MEDICINE METHODS ============
  static Box<EnhancedMedicine> get _medicinesBox => Hive.box<EnhancedMedicine>(_medicinesBoxName);

  static List<EnhancedMedicine> getAllMedicines({bool includeArchived = false}) {
    final medicines = _medicinesBox.values.toList();
    if (includeArchived) return medicines;
    return medicines.where((m) => !m.isArchived && m.isActive).toList();
  }

  static List<EnhancedMedicine> getMedicinesForDependent(String dependentId) {
    return getAllMedicines().where((m) => m.dependentId == dependentId).toList();
  }

  static List<EnhancedMedicine> getActiveMedicinesForToday() {
    final today = DateTime.now();
    return getAllMedicines().where((m) {
      return m.schedule.isActiveOnDate(today);
    }).toList();
  }

  static List<EnhancedMedicine> getLowStockMedicines() {
    return getAllMedicines().where((m) => m.isLowStock).toList();
  }

  static List<EnhancedMedicine> getExpiringMedicines({int daysAhead = 30}) {
    final cutoff = DateTime.now().add(Duration(days: daysAhead));
    return getAllMedicines().where((m) {
      if (m.expiryDate == null) return false;
      return m.expiryDate!.isBefore(cutoff);
    }).toList();
  }

  static EnhancedMedicine? getMedicine(String id) {
    return _medicinesBox.get(id);
  }

  static Future<void> addMedicine(EnhancedMedicine medicine) async {
    await _medicinesBox.put(medicine.id, medicine);
    await _syncToCloud('enhanced_medicines', medicine.id, medicine.toJson());
  }

  static Future<void> updateMedicine(EnhancedMedicine medicine) async {
    final updated = medicine.copyWith(updatedAt: DateTime.now());
    await _medicinesBox.put(updated.id, updated);
    await _syncToCloud('enhanced_medicines', updated.id, updated.toJson());
  }

  static Future<void> deleteMedicine(String id) async {
    await _medicinesBox.delete(id);
    await _deleteFromCloud('enhanced_medicines', id);
  }

  static Future<void> archiveMedicine(String id) async {
    final medicine = getMedicine(id);
    if (medicine != null) {
      await updateMedicine(medicine.archive());
    }
  }

  static Future<void> reduceStock(String medicineId, double amount) async {
    final medicine = getMedicine(medicineId);
    if (medicine != null) {
      await updateMedicine(medicine.reduceStock(amount));
    }
  }

  static Future<void> refillStock(String medicineId, int amount) async {
    final medicine = getMedicine(medicineId);
    if (medicine != null) {
      await updateMedicine(medicine.addStock(amount));
    }
  }

  static ValueListenable<Box<EnhancedMedicine>> get medicinesListenable => _medicinesBox.listenable();

  // ============ MEDICINE LOG METHODS ============
  static Box<MedicineLog> get _logsBox => Hive.box<MedicineLog>(_logsBoxName);

  static List<MedicineLog> getAllLogs() {
    return _logsBox.values.toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  static List<MedicineLog> getLogsForMedicine(String medicineId) {
    return _logsBox.values
        .where((log) => log.medicineId == medicineId)
        .toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  static List<MedicineLog> getLogsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _logsBox.values
        .where((log) => 
            log.scheduledTime.isAfter(startOfDay) && 
            log.scheduledTime.isBefore(endOfDay))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  static List<MedicineLog> getLogsForDateRange(DateTime start, DateTime end) {
    return _logsBox.values
        .where((log) => 
            log.scheduledTime.isAfter(start) && 
            log.scheduledTime.isBefore(end))
        .toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  static Future<void> addLog(MedicineLog log) async {
    await _logsBox.put(log.id, log);
    await _syncToCloud('medicine_logs', log.id, log.toJson());
    
    // Reduce stock if medicine was taken
    if (log.isTaken) {
      await reduceStock(log.medicineId, log.dosageTaken);
    }
  }

  static Future<void> updateLog(MedicineLog log) async {
    await _logsBox.put(log.id, log);
    await _syncToCloud('medicine_logs', log.id, log.toJson());
  }

  static Future<void> deleteLog(String id) async {
    await _logsBox.delete(id);
    await _deleteFromCloud('medicine_logs', id);
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
    return log;
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

  static ValueListenable<Box<MedicineLog>> get logsListenable => _logsBox.listenable();

  // ============ DOCTOR METHODS ============
  static Box<Doctor> get _doctorsBox => Hive.box<Doctor>(_doctorsBoxName);

  static List<Doctor> getAllDoctors() {
    return _doctorsBox.values.toList();
  }

  static Doctor? getDoctor(String id) {
    return _doctorsBox.get(id);
  }

  static Doctor? getPrimaryDoctor() {
    return _doctorsBox.values.firstWhere(
      (d) => d.isPrimary,
      orElse: () => _doctorsBox.values.isNotEmpty ? _doctorsBox.values.first : Doctor(id: '', name: ''),
    );
  }

  static Future<void> addDoctor(Doctor doctor) async {
    await _doctorsBox.put(doctor.id, doctor);
    await _syncToCloud('doctors', doctor.id, doctor.toJson());
  }

  static Future<void> updateDoctor(Doctor doctor) async {
    await _doctorsBox.put(doctor.id, doctor);
    await _syncToCloud('doctors', doctor.id, doctor.toJson());
  }

  static Future<void> deleteDoctor(String id) async {
    await _doctorsBox.delete(id);
    await _deleteFromCloud('doctors', id);
  }

  static ValueListenable<Box<Doctor>> get doctorsListenable => _doctorsBox.listenable();

  // ============ PHARMACY METHODS ============
  static Box<Pharmacy> get _pharmaciesBox => Hive.box<Pharmacy>(_pharmaciesBoxName);

  static List<Pharmacy> getAllPharmacies() {
    return _pharmaciesBox.values.toList();
  }

  static Pharmacy? getPharmacy(String id) {
    return _pharmaciesBox.get(id);
  }

  static Future<void> addPharmacy(Pharmacy pharmacy) async {
    await _pharmaciesBox.put(pharmacy.id, pharmacy);
    await _syncToCloud('pharmacies', pharmacy.id, pharmacy.toJson());
  }

  static Future<void> updatePharmacy(Pharmacy pharmacy) async {
    await _pharmaciesBox.put(pharmacy.id, pharmacy);
    await _syncToCloud('pharmacies', pharmacy.id, pharmacy.toJson());
  }

  static Future<void> deletePharmacy(String id) async {
    await _pharmaciesBox.delete(id);
    await _deleteFromCloud('pharmacies', id);
  }

  static ValueListenable<Box<Pharmacy>> get pharmaciesListenable => _pharmaciesBox.listenable();

  // ============ APPOINTMENT METHODS ============
  static Box<Appointment> get _appointmentsBox => Hive.box<Appointment>(_appointmentsBoxName);

  static List<Appointment> getAllAppointments() {
    return _appointmentsBox.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  static List<Appointment> getUpcomingAppointments() {
    final now = DateTime.now();
    return getAllAppointments().where((a) => a.dateTime.isAfter(now)).toList();
  }

  static List<Appointment> getTodayAppointments() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getAllAppointments().where((a) => 
        a.dateTime.isAfter(startOfDay) && a.dateTime.isBefore(endOfDay)).toList();
  }

  static Future<void> addAppointment(Appointment appointment) async {
    await _appointmentsBox.put(appointment.id, appointment);
    await _syncToCloud('appointments', appointment.id, appointment.toJson());
  }

  static Future<void> updateAppointment(Appointment appointment) async {
    await _appointmentsBox.put(appointment.id, appointment);
    await _syncToCloud('appointments', appointment.id, appointment.toJson());
  }

  static Future<void> deleteAppointment(String id) async {
    await _appointmentsBox.delete(id);
    await _deleteFromCloud('appointments', id);
  }

  static ValueListenable<Box<Appointment>> get appointmentsListenable => _appointmentsBox.listenable();

  // ============ DEPENDENT PROFILE METHODS ============
  static Box<DependentProfile> get _dependentsBox => Hive.box<DependentProfile>(_dependentsBoxName);

  static List<DependentProfile> getAllDependents() {
    return _dependentsBox.values.where((d) => d.isActive).toList();
  }

  static DependentProfile? getDependent(String id) {
    return _dependentsBox.get(id);
  }

  static DependentProfile? getSelfProfile() {
    return _dependentsBox.values.firstWhere(
      (d) => d.isSelf,
      orElse: () => DependentProfile.self(name: 'Me'),
    );
  }

  static Future<void> addDependent(DependentProfile dependent) async {
    await _dependentsBox.put(dependent.id, dependent);
    await _syncToCloud('dependents', dependent.id, dependent.toJson());
  }

  static Future<void> updateDependent(DependentProfile dependent) async {
    await _dependentsBox.put(dependent.id, dependent);
    await _syncToCloud('dependents', dependent.id, dependent.toJson());
  }

  static Future<void> deleteDependent(String id) async {
    await _dependentsBox.delete(id);
    await _deleteFromCloud('dependents', id);
  }

  static ValueListenable<Box<DependentProfile>> get dependentsListenable => _dependentsBox.listenable();

  // ============ TREATMENT COURSE METHODS ============
  static Box<TreatmentCourse> get _treatmentsBox => Hive.box<TreatmentCourse>(_treatmentsBoxName);

  static List<TreatmentCourse> getAllTreatments() {
    return _treatmentsBox.values.toList();
  }

  static List<TreatmentCourse> getActiveTreatments() {
    return getAllTreatments().where((t) => t.isActive && t.isOngoing).toList();
  }

  static Future<void> addTreatment(TreatmentCourse treatment) async {
    await _treatmentsBox.put(treatment.id, treatment);
    await _syncToCloud('treatments', treatment.id, treatment.toJson());
  }

  static Future<void> updateTreatment(TreatmentCourse treatment) async {
    await _treatmentsBox.put(treatment.id, treatment);
    await _syncToCloud('treatments', treatment.id, treatment.toJson());
  }

  static Future<void> deleteTreatment(String id) async {
    await _treatmentsBox.delete(id);
    await _deleteFromCloud('treatments', id);
  }

  static ValueListenable<Box<TreatmentCourse>> get treatmentsListenable => _treatmentsBox.listenable();

  // ============ ANALYTICS METHODS ============
  static Map<String, dynamic> getAdherenceStats({int days = 30}) {
    final startDate = DateTime.now().subtract(Duration(days: days));
    final logs = getLogsForDateRange(startDate, DateTime.now());
    
    final taken = logs.where((l) => l.isTaken).length;
    final skipped = logs.where((l) => l.isSkipped).length;
    final missed = logs.where((l) => l.isMissed).length;
    final total = taken + skipped + missed;
    
    return {
      'taken': taken,
      'skipped': skipped,
      'missed': missed,
      'total': total,
      'adherenceRate': total > 0 ? (taken / total * 100).round() : 100,
      'days': days,
      'onTimeRate': _calculateOnTimeRate(logs),
    };
  }

  static double _calculateOnTimeRate(List<MedicineLog> logs) {
    final takenLogs = logs.where((l) => l.isTaken).toList();
    if (takenLogs.isEmpty) return 100;
    
    final onTime = takenLogs.where((l) => l.wasTakenOnTime).length;
    return (onTime / takenLogs.length * 100);
  }

  static int getCurrentStreak() {
    int streak = 0;
    DateTime checkDate = DateTime.now();
    
    while (true) {
      final logs = getLogsForDate(checkDate);
      if (logs.isEmpty) break;
      
      final allTaken = logs.every((l) => l.isTaken);
      if (!allTaken) break;
      
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }

  static Map<String, int> getSkipReasonStats({int days = 30}) {
    final startDate = DateTime.now().subtract(Duration(days: days));
    final logs = getLogsForDateRange(startDate, DateTime.now())
        .where((l) => l.isSkipped && l.skipReason != null);
    
    final stats = <String, int>{};
    for (final log in logs) {
      final reason = log.skipReason!.displayName;
      stats[reason] = (stats[reason] ?? 0) + 1;
    }
    
    return stats;
  }

  static DailyMedicineSummary getDailySummary(DateTime date) {
    final logs = getLogsForDate(date);
    final medicines = getActiveMedicinesForToday();
    
    final taken = logs.where((l) => l.isTaken).length;
    final skipped = logs.where((l) => l.isSkipped).length;
    final missed = logs.where((l) => l.isMissed).length;
    final total = medicines.fold<int>(0, (sum, m) => sum + m.schedule.times.length);
    
    return DailyMedicineSummary(
      date: date,
      totalScheduled: total,
      taken: taken,
      skipped: skipped,
      missed: missed,
      adherenceRate: total > 0 ? taken / total : 1.0,
      medicinesTaken: logs.where((l) => l.isTaken).map((l) => l.medicineId).toList(),
      medicinesMissed: logs.where((l) => l.isMissed).map((l) => l.medicineId).toList(),
    );
  }

  // ============ EXPORT METHODS ============
  static Map<String, dynamic> exportAllMedicineData() {
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'medicines': getAllMedicines(includeArchived: true).map((m) => m.toJson()).toList(),
      'logs': getAllLogs().map((l) => l.toJson()).toList(),
      'doctors': getAllDoctors().map((d) => d.toJson()).toList(),
      'pharmacies': getAllPharmacies().map((p) => p.toJson()).toList(),
      'appointments': getAllAppointments().map((a) => a.toJson()).toList(),
      'dependents': getAllDependents().map((d) => d.toJson()).toList(),
      'treatments': getAllTreatments().map((t) => t.toJson()).toList(),
    };
  }
}
