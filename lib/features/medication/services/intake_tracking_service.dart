import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/intake_streak.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/dependent_profile.dart';
import 'medicine_storage_service.dart';

/// Intake tracking service using Drift storage via MedicineCleanStorageService
class IntakeTrackingService {
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
    await MedicineCleanStorageService.init();
    debugPrint('✓ IntakeTrackingService initialized');
    _isInitialized = true;
  }

  static Future<IntakeStreak?> getStreak(String medicineId) async {
    final logs = await MedicineCleanStorageService.getLogsForMedicine(medicineId);
    if (logs.isEmpty) return null;
    
    // Calculate streak from logs
    int currentStreak = 0;
    int longestStreak = 0;
    final sortedLogs = logs.where((l) => l.isTaken).toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    
    if (sortedLogs.isNotEmpty) {
      currentStreak = 1;
      var prevDate = sortedLogs.first.scheduledTime;
      for (int i = 1; i < sortedLogs.length; i++) {
        final diff = prevDate.difference(sortedLogs[i].scheduledTime).inDays;
        if (diff == 1) {
          currentStreak++;
          prevDate = sortedLogs[i].scheduledTime;
        } else {
          break;
        }
      }
      longestStreak = currentStreak;
    }
    
    return IntakeStreak(
      id: medicineId,
      medicineId: medicineId,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastTakenDate: sortedLogs.isNotEmpty ? sortedLogs.first.scheduledTime : null,
    );
  }

  static Future<IntakeStreak> getOrCreateStreak(String medicineId) async {
    var streak = await getStreak(medicineId);
    return streak ?? IntakeStreak(
      id: medicineId,
      medicineId: medicineId,
    );
  }

  static Future<bool> canSkipMedicine(String medicineId) async {
    final streak = await getStreak(medicineId);
    return streak?.canSkip ?? true;
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
    try {
      await MedicineCleanStorageService.markMedicineTaken(
        medicineId: medicineId,
        scheduledTime: takenDate,
        dosageTaken: dosageTaken,
        notes: notes,
        sideEffects: sideEffects,
        moodRating: moodRating,
        effectivenessRating: effectivenessRating,
      );
      
      final streak = await getStreak(medicineId);
      final currentStreak = streak?.currentStreak ?? 1;
      
      return {
        'success': true,
        'streak': currentStreak,
        'longestStreak': streak?.longestStreak ?? currentStreak,
        'canSkip': true,
        'consecutiveTakes': currentStreak,
        'message': _getStreakMessage(streak ?? IntakeStreak(id: medicineId, medicineId: medicineId)),
      };
    } catch (e) {
      debugPrint('Error recording medicine taken: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> recordMedicineSkipped({
    required String medicineId,
    required DateTime skipDate,
    required SkipReason reason,
    String? skipNote,
  }) async {
    try {
      await MedicineCleanStorageService.markMedicineSkipped(
        medicineId: medicineId,
        scheduledTime: skipDate,
        reason: reason,
        skipNote: skipNote,
      );
      
      return {
        'success': true,
        'canSkip': true,
        'message': 'Dose skipped',
      };
    } catch (e) {
      debugPrint('Error recording medicine skipped: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
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

  static Future<Map<String, dynamic>> getStreakStats(String medicineId) async {
    final logs = await MedicineCleanStorageService.getLogsForMedicine(medicineId);
    final totalTaken = logs.where((l) => l.isTaken).length;
    final totalSkipped = logs.where((l) => l.isSkipped).length;
    final total = totalTaken + totalSkipped;
    final adherenceRate = total > 0 ? (totalTaken / total) * 100 : 100.0;
    
    final streak = await getStreak(medicineId);
    
    return {
      'currentStreak': streak?.currentStreak ?? 0,
      'longestStreak': streak?.longestStreak ?? 0,
      'totalTaken': totalTaken,
      'totalSkipped': totalSkipped,
      'adherenceRate': adherenceRate,
      'canSkip': true,
      'consecutiveTakes': streak?.currentStreak ?? 0,
      'isActiveStreak': (streak?.currentStreak ?? 0) > 0,
    };
  }

  /// Get dependent profile by ID
  static Future<DependentProfile?> getDependentProfile(String dependentId) async {
    final dependents = await MedicineCleanStorageService.getAllDependents();
    try {
      return dependents.firstWhere((d) => d.id == dependentId);
    } catch (_) {
      return null;
    }
  }

  /// Get all dependent profiles
  static Future<List<DependentProfile>> getAllDependentProfiles() async {
    return await MedicineCleanStorageService.getAllDependents();
  }

  /// Get health analytics for a dependent
  static Future<Map<String, dynamic>> getDependentHealthAnalytics(String dependentId) async {
    final medicines = await MedicineCleanStorageService.getMedicinesForDependent(dependentId);
    
    // Group medicines by health category
    final categoryBreakdown = <String, int>{};
    final healthCategories = <String>{};
    
    for (final med in medicines) {
      final category = med.healthCategory.displayName;
      categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
      healthCategories.add(category);
    }
    
    return {
      'totalCategories': healthCategories.length,
      'totalMedicines': medicines.length,
      'categoryBreakdown': categoryBreakdown,
      'healthCategories': healthCategories.toList(),
    };
  }

  /// Get medicines by health category for a dependent
  static Future<List<EnhancedMedicine>> getMedicinesByHealthCategory({
    required String dependentId,
    required HealthCategory category,
  }) async {
    final medicines = await MedicineCleanStorageService.getMedicinesForDependent(dependentId);
    return medicines.where((m) => m.healthCategory == category).toList();
  }

  /// Get comprehensive health report for a dependent
  static Future<Map<String, dynamic>> getComprehensiveHealthReport(String dependentId) async {
    final dependent = await getDependentProfile(dependentId);
    final medicines = await MedicineCleanStorageService.getMedicinesForDependent(dependentId);
    
    // Calculate stats per category
    final categoryStats = <String, Map<String, dynamic>>{};
    for (final med in medicines) {
      final category = med.healthCategory.displayName;
      if (!categoryStats.containsKey(category)) {
        categoryStats[category] = {
          'count': 0,
          'medicines': <String>[],
        };
      }
      categoryStats[category]!['count'] = (categoryStats[category]!['count'] as int) + 1;
      (categoryStats[category]!['medicines'] as List<String>).add(med.name);
    }
    
    // Calculate overall adherence
    final adherence = await _calculateOverallAdherence(medicines);
    
    return {
      'dependentName': dependent?.name ?? 'Unknown',
      'totalCategories': categoryStats.length,
      'totalMedicines': medicines.length,
      'categoryStats': categoryStats,
      'overallAdherence': adherence,
    };
  }

  /// Calculate overall adherence rate across all medicines
  static Future<double> _calculateOverallAdherence(List<EnhancedMedicine> medicines) async {
    if (medicines.isEmpty) return 100.0;
    
    double totalAdherence = 0;
    int count = 0;
    
    for (final med in medicines) {
      final stats = await getStreakStats(med.id);
      totalAdherence += stats['adherenceRate'] as double;
      count++;
    }
    
    return count > 0 ? totalAdherence / count : 100.0;
  }

  /// Get all medicines grouped by health category
  static Future<Map<HealthCategory, List<EnhancedMedicine>>> getMedicinesGroupedByCategory() async {
    final medicines = await MedicineCleanStorageService.getAllMedicines();
    final grouped = <HealthCategory, List<EnhancedMedicine>>{};
    
    for (final med in medicines) {
      if (!grouped.containsKey(med.healthCategory)) {
        grouped[med.healthCategory] = [];
      }
      grouped[med.healthCategory]!.add(med);
    }
    
    return grouped;
  }

  /// Get adherence summary for all active medicines
  static Future<Map<String, dynamic>> getOverallAdherenceSummary() async {
    final medicines = await MedicineCleanStorageService.getAllMedicines();
    final activeMedicines = medicines.where((m) => m.isActive).toList();
    
    if (activeMedicines.isEmpty) {
      return {
        'totalMedicines': 0,
        'averageAdherence': 100.0,
        'totalTaken': 0,
        'totalSkipped': 0,
        'activeSteaks': 0,
      };
    }
    
    int totalTaken = 0;
    int totalSkipped = 0;
    int activeStreaks = 0;
    double totalAdherence = 0;
    
    for (final med in activeMedicines) {
      final stats = await getStreakStats(med.id);
      totalTaken += stats['totalTaken'] as int;
      totalSkipped += stats['totalSkipped'] as int;
      totalAdherence += stats['adherenceRate'] as double;
      if (stats['isActiveStreak'] as bool) {
        activeStreaks++;
      }
    }
    
    return {
      'totalMedicines': activeMedicines.length,
      'averageAdherence': totalAdherence / activeMedicines.length,
      'totalTaken': totalTaken,
      'totalSkipped': totalSkipped,
      'activeStreaks': activeStreaks,
    };
  }
}
