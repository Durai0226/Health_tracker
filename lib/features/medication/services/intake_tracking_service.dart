import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/intake_streak.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import 'medicine_storage_service.dart';

class IntakeTrackingService {
  static const String _streaksBoxName = 'intake_streaks';
  static const String _patientProfilesBoxName = 'patient_medicine_profiles';
  
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

  static Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      if (!Hive.isBoxOpen(_streaksBoxName)) {
        await Hive.openBox<IntakeStreak>(_streaksBoxName);
      }
      if (!Hive.isBoxOpen(_patientProfilesBoxName)) {
        await Hive.openBox<PatientMedicineProfile>(_patientProfilesBoxName);
      }
      
      _isInitialized = true;
      debugPrint('✓ IntakeTrackingService initialized');
    } catch (e) {
      debugPrint('Error initializing IntakeTrackingService: $e');
      rethrow;
    }
  }

  static Box<IntakeStreak> get _streaksBox => Hive.box<IntakeStreak>(_streaksBoxName);
  static Box<PatientMedicineProfile> get _profilesBox => Hive.box<PatientMedicineProfile>(_patientProfilesBoxName);

  static IntakeStreak? getStreak(String medicineId) {
    return _streaksBox.get(medicineId);
  }

  static IntakeStreak getOrCreateStreak(String medicineId) {
    var streak = getStreak(medicineId);
    if (streak == null) {
      streak = IntakeStreak(
        id: medicineId,
        medicineId: medicineId,
      );
      _streaksBox.put(medicineId, streak);
    }
    return streak;
  }

  static bool canSkipMedicine(String medicineId) {
    final medicine = MedicineStorageService.getMedicine(medicineId);
    if (medicine == null) return true;

    if (!medicine.requiresContinuousIntake) return true;

    final streak = getOrCreateStreak(medicineId);
    
    if (medicine.minimumConsecutiveDays != null) {
      return streak.consecutiveTakes < medicine.minimumConsecutiveDays!;
    }

    return streak.canSkip;
  }

  static Future<Map<String, dynamic>> recordMedicineTaken({
    required String medicineId,
    required DateTime takenDate,
    double dosageTaken = 1,
    String? notes,
    String? sideEffects,
    int? moodRating,
    int? effectivenessRating,
  }) async {
    final streak = getOrCreateStreak(medicineId);
    final updatedStreak = streak.recordTake(takenDate);
    
    await _streaksBox.put(medicineId, updatedStreak);
    await _syncToCloud('intake_streaks', medicineId, updatedStreak.toJson());

    await MedicineStorageService.markMedicineTaken(
      medicineId: medicineId,
      scheduledTime: takenDate,
      dosageTaken: dosageTaken,
      notes: notes,
      sideEffects: sideEffects,
      moodRating: moodRating,
      effectivenessRating: effectivenessRating,
    );

    return {
      'success': true,
      'streak': updatedStreak.currentStreak,
      'longestStreak': updatedStreak.longestStreak,
      'canSkip': updatedStreak.canSkip,
      'consecutiveTakes': updatedStreak.consecutiveTakes,
      'message': _getStreakMessage(updatedStreak),
    };
  }

  static Future<Map<String, dynamic>> recordMedicineSkipped({
    required String medicineId,
    required DateTime skipDate,
    required SkipReason reason,
    String? skipNote,
  }) async {
    final canSkip = canSkipMedicine(medicineId);
    
    if (!canSkip) {
      return {
        'success': false,
        'canSkip': false,
        'message': 'Cannot skip - continuous intake required. You must take this medicine consecutively.',
      };
    }

    final streak = getOrCreateStreak(medicineId);
    final updatedStreak = streak.recordSkip(skipDate);
    
    await _streaksBox.put(medicineId, updatedStreak);
    await _syncToCloud('intake_streaks', medicineId, updatedStreak.toJson());

    await MedicineStorageService.markMedicineSkipped(
      medicineId: medicineId,
      scheduledTime: skipDate,
      reason: reason,
      skipNote: skipNote,
    );

    return {
      'success': true,
      'canSkip': true,
      'message': 'Medicine skipped. Your streak has been reset.',
    };
  }

  static String _getStreakMessage(IntakeStreak streak) {
    if (streak.currentStreak == 1) {
      return 'Great start! Keep it up!';
    } else if (streak.currentStreak < 7) {
      return '${streak.currentStreak} days streak! Keep going!';
    } else if (streak.currentStreak < 30) {
      return 'Amazing! ${streak.currentStreak} days streak!';
    } else {
      return 'Incredible! ${streak.currentStreak} days streak! 🎉';
    }
  }

  static Map<String, dynamic> getStreakStats(String medicineId) {
    final streak = getOrCreateStreak(medicineId);
    return {
      'currentStreak': streak.currentStreak,
      'longestStreak': streak.longestStreak,
      'totalTaken': streak.totalTaken,
      'totalSkipped': streak.totalSkipped,
      'adherenceRate': streak.adherenceRate,
      'canSkip': canSkipMedicine(medicineId),
      'consecutiveTakes': streak.consecutiveTakes,
      'isActiveStreak': streak.isActiveStreak,
    };
  }

  static PatientMedicineProfile? getPatientProfile(String patientId) {
    return _profilesBox.get(patientId);
  }

  static PatientMedicineProfile getOrCreatePatientProfile({
    required String patientId,
    required String patientName,
  }) {
    var profile = getPatientProfile(patientId);
    if (profile == null) {
      profile = PatientMedicineProfile(
        id: patientId,
        patientId: patientId,
        patientName: patientName,
      );
      _profilesBox.put(patientId, profile);
    }
    return profile;
  }

  static Future<void> addHealthCategoryToProfile({
    required String patientId,
    required HealthCategory category,
  }) async {
    final profile = getPatientProfile(patientId);
    if (profile != null) {
      final updated = profile.addCategory(category);
      await _profilesBox.put(patientId, updated);
      await _syncToCloud('patient_profiles', patientId, updated.toJson());
    }
  }

  static Future<void> addCustomCategoryToProfile({
    required String patientId,
    required String categoryName,
  }) async {
    final profile = getPatientProfile(patientId);
    if (profile != null) {
      final updated = profile.addCustomCategory(categoryName);
      await _profilesBox.put(patientId, updated);
      await _syncToCloud('patient_profiles', patientId, updated.toJson());
    }
  }

  static Future<void> linkMedicineToCategory({
    required String patientId,
    required String categoryName,
    required String medicineId,
  }) async {
    final profile = getPatientProfile(patientId);
    if (profile != null) {
      final updated = profile.addMedicineToCategory(categoryName, medicineId);
      await _profilesBox.put(patientId, updated);
      await _syncToCloud('patient_profiles', patientId, updated.toJson());
    }
  }

  static List<PatientMedicineProfile> getAllPatientProfiles() {
    return _profilesBox.values.toList();
  }

  static Map<String, dynamic> getPatientHealthAnalytics(String patientId) {
    final profile = getPatientProfile(patientId);
    if (profile == null) {
      return {
        'totalCategories': 0,
        'totalMedicines': 0,
        'categoryBreakdown': {},
      };
    }

    final categoryBreakdown = <String, int>{};
    for (final category in profile.healthCategories) {
      final medicines = profile.getMedicinesForCategory(category.displayName);
      categoryBreakdown[category.displayName] = medicines.length;
    }
    for (final category in profile.customCategories) {
      final medicines = profile.getMedicinesForCategory(category);
      categoryBreakdown[category] = medicines.length;
    }

    return {
      'totalCategories': profile.totalCategories,
      'totalMedicines': profile.totalMedicines,
      'categoryBreakdown': categoryBreakdown,
      'healthCategories': profile.healthCategories.map((c) => c.displayName).toList(),
      'customCategories': profile.customCategories,
    };
  }

  static List<EnhancedMedicine> getMedicinesByHealthCategory({
    required String patientId,
    required String categoryName,
  }) {
    final profile = getPatientProfile(patientId);
    if (profile == null) return [];

    final medicineIds = profile.getMedicinesForCategory(categoryName);
    final medicines = <EnhancedMedicine>[];
    
    for (final id in medicineIds) {
      final medicine = MedicineStorageService.getMedicine(id);
      if (medicine != null) {
        medicines.add(medicine);
      }
    }
    
    return medicines;
  }

  static Map<String, dynamic> getComprehensiveHealthReport(String patientId) {
    final profile = getPatientProfile(patientId);
    if (profile == null) {
      return {'error': 'Patient profile not found'};
    }

    final allMedicines = MedicineStorageService.getAllMedicines()
        .where((m) => m.patientProfileId == patientId)
        .toList();

    final categoryStats = <String, Map<String, dynamic>>{};
    
    for (final category in profile.healthCategories) {
      final categoryMeds = allMedicines
          .where((m) => m.healthCategories?.contains(category) ?? false)
          .toList();
      
      int totalTaken = 0;
      int totalSkipped = 0;
      double avgAdherence = 0;
      
      for (final med in categoryMeds) {
        final streak = getStreak(med.id);
        if (streak != null) {
          totalTaken += streak.totalTaken;
          totalSkipped += streak.totalSkipped;
        }
      }
      
      final total = totalTaken + totalSkipped;
      avgAdherence = total > 0 ? (totalTaken / total) * 100 : 100;
      
      categoryStats[category.displayName] = {
        'medicineCount': categoryMeds.length,
        'totalTaken': totalTaken,
        'totalSkipped': totalSkipped,
        'adherenceRate': avgAdherence,
        'medicines': categoryMeds.map((m) => m.name).toList(),
      };
    }

    return {
      'patientName': profile.patientName,
      'totalCategories': profile.totalCategories,
      'totalMedicines': allMedicines.length,
      'categoryStats': categoryStats,
      'overallAdherence': _calculateOverallAdherence(allMedicines),
    };
  }

  static double _calculateOverallAdherence(List<EnhancedMedicine> medicines) {
    int totalTaken = 0;
    int totalSkipped = 0;
    
    for (final med in medicines) {
      final streak = getStreak(med.id);
      if (streak != null) {
        totalTaken += streak.totalTaken;
        totalSkipped += streak.totalSkipped;
      }
    }
    
    final total = totalTaken + totalSkipped;
    return total > 0 ? (totalTaken / total) * 100 : 100;
  }

  static ValueListenable<Box<IntakeStreak>> get streaksListenable => _streaksBox.listenable();
  static ValueListenable<Box<PatientMedicineProfile>> get profilesListenable => _profilesBox.listenable();
}
