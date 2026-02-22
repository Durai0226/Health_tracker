
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../features/medication/models/medicine.dart';
import '../../features/period_tracking/models/period_data.dart';
import '../../features/water/services/water_service.dart';
import '../../features/water/models/enhanced_water_log.dart';
import '../../features/fitness/models/fitness_reminder.dart';
import 'storage_service.dart';

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  Future<void> syncUserData(String userId) async {
    if (_isSyncing) {
      debugPrint('Sync already in progress, skipping...');
      return;
    }

    try {
      _isSyncing = true;
      debugPrint('Starting cloud sync for user: $userId');

      await Future.wait([
        _syncMedicines(userId),
        _syncPeriodData(userId),
        _syncWaterIntake(userId),
        _syncFitnessReminders(userId),
      ]);

      debugPrint('Cloud sync completed successfully');
    } catch (e) {
      debugPrint('Cloud sync error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncMedicines(String userId) async {
    try {
      final localMedicines = StorageService.getAllMedicines();
      final cloudRef = _firestore.collection('users').doc(userId).collection('medicines');

      // Use limit for initial sync to avoid loading too much data
      final cloudSnapshot = await cloudRef.limit(500).get();
      final cloudMedicines = cloudSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Medicine.fromJson(data);
      }).toList();

      if (cloudMedicines.isEmpty && localMedicines.isNotEmpty) {
        debugPrint('Uploading ${localMedicines.length} medicines to cloud');
        for (final medicine in localMedicines) {
          await cloudRef.doc(medicine.id).set(medicine.toJson());
        }
      } else if (cloudMedicines.isNotEmpty) {
        debugPrint('Downloading ${cloudMedicines.length} medicines from cloud');
        for (final medicine in cloudMedicines) {
          await StorageService.addMedicine(medicine);
        }
      }
    } catch (e) {
      debugPrint('Medicine sync error: $e');
    }
  }

  Future<void> _syncPeriodData(String userId) async {
    try {
      final localPeriod = StorageService.getPeriodData();
      final cloudRef = _firestore.collection('users').doc(userId).collection('period').doc('current');

      final cloudDoc = await cloudRef.get();
      
      if (!cloudDoc.exists && localPeriod != null) {
        debugPrint('Uploading period data to cloud');
        await cloudRef.set(localPeriod.toJson());
      } else if (cloudDoc.exists && cloudDoc.data() != null) {
        debugPrint('Downloading period data from cloud');
        final cloudPeriod = PeriodData.fromJson(cloudDoc.data()!);
        await StorageService.savePeriodData(cloudPeriod);
      }
    } catch (e) {
      debugPrint('Period data sync error: $e');
    }
  }

  Future<void> _syncWaterIntake(String userId) async {
    try {
      final localWater = WaterService.getTodayData();
      final today = DateTime.now();
      final key = '${today.year}-${today.month}-${today.day}';
      final cloudRef = _firestore.collection('users').doc(userId).collection('water_intake').doc(key);

      final cloudDoc = await cloudRef.get();

      if (!cloudDoc.exists && (localWater.totalIntakeMl > 0 || localWater.logs.isNotEmpty)) {
        debugPrint('Uploading today\'s water intake to cloud');
        await cloudRef.set(localWater.toJson());
      } else if (cloudDoc.exists && cloudDoc.data() != null) {
        debugPrint('Downloading today\'s water intake from cloud');
        final data = cloudDoc.data()!;
        try {
          // Try parsing as DailyWaterData
          final cloudWater = DailyWaterData.fromJson(data);
          await WaterService.saveDailyData(cloudWater);
        } catch (e) {
          // Fallback for legacy WaterIntake data
          debugPrint('Migrating legacy water data: $e');
          final date = DateTime.parse(data['date']);
          final goal = data['dailyGoalMl'] ?? 2500;
          final amount = data['currentIntakeMl'] ?? 0;
          
          final migratedWater = DailyWaterData(
            id: data['id'] ?? key,
            date: date,
            dailyGoalMl: goal,
            totalIntakeMl: amount,
            effectiveHydrationMl: amount,
          );
          await WaterService.saveDailyData(migratedWater);
        }
      }
    } catch (e) {
      debugPrint('Water intake sync error: $e');
    }
  }

  Future<void> _syncFitnessReminders(String userId) async {
    try {
      final localReminders = StorageService.getAllFitnessReminders();
      final cloudRef = _firestore.collection('users').doc(userId).collection('fitness_reminders');

      // Use limit to prevent large data loads
      final cloudSnapshot = await cloudRef.limit(200).get();
      final cloudReminders = cloudSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FitnessReminder.fromJson(data);
      }).toList();

      if (cloudReminders.isEmpty && localReminders.isNotEmpty) {
        debugPrint('Uploading ${localReminders.length} fitness reminders to cloud');
        for (final reminder in localReminders) {
          await cloudRef.doc(reminder.id).set(reminder.toJson());
        }
      } else if (cloudReminders.isNotEmpty) {
        debugPrint('Downloading ${cloudReminders.length} fitness reminders from cloud');
        for (final reminder in cloudReminders) {
          await StorageService.addFitnessReminder(reminder);
        }
      }
    } catch (e) {
      debugPrint('Fitness reminder sync error: $e');
    }
  }

  Future<void> uploadDataToCloud(String userId) async {
    try {
      debugPrint('Uploading all local data to cloud for user: $userId');

      final localMedicines = StorageService.getAllMedicines();
      final localPeriod = StorageService.getPeriodData();
      final localWater = WaterService.getTodayData();
      final localReminders = StorageService.getAllFitnessReminders();

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);

      for (final medicine in localMedicines) {
        batch.set(userRef.collection('medicines').doc(medicine.id), medicine.toJson());
      }

      if (localPeriod != null) {
        batch.set(userRef.collection('period').doc('current'), localPeriod.toJson());
      }

      if (localWater.totalIntakeMl > 0 || localWater.logs.isNotEmpty) {
        final today = DateTime.now();
        final key = '${today.year}-${today.month}-${today.day}';
        batch.set(userRef.collection('water_intake').doc(key), localWater.toJson());
      }

      for (final reminder in localReminders) {
        batch.set(userRef.collection('fitness_reminders').doc(reminder.id), reminder.toJson());
      }

      await batch.commit();
      debugPrint('Successfully uploaded all data to cloud');
    } catch (e) {
      debugPrint('Upload to cloud error: $e');
      rethrow;
    }
  }

  Future<void> downloadDataFromCloud(String userId) async {
    try {
      debugPrint('Downloading all data from cloud for user: $userId');

      final userRef = _firestore.collection('users').doc(userId);

      // Use pagination to avoid loading too much data at once
      final medicinesSnapshot = await userRef.collection('medicines').limit(500).get();
      for (final doc in medicinesSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        await StorageService.addMedicine(Medicine.fromJson(data));
      }

      final periodDoc = await userRef.collection('period').doc('current').get();
      if (periodDoc.exists && periodDoc.data() != null) {
        await StorageService.savePeriodData(PeriodData.fromJson(periodDoc.data()!));
      }

      // Limit water intake to recent entries (last 30 days worth)
      final waterSnapshot = await userRef.collection('water_intake').limit(30).get();
      for (final doc in waterSnapshot.docs) {
        final data = doc.data();
        try {
          final cloudWater = DailyWaterData.fromJson(data);
          await WaterService.saveDailyData(cloudWater);
        } catch (e) {
          // Fallback legacy data
          final date = DateTime.parse(data['date']);
          final goal = data['dailyGoalMl'] ?? 2500;
          final amount = data['currentIntakeMl'] ?? 0;
          
          final migratedWater = DailyWaterData(
            id: doc.id,
            date: date,
            dailyGoalMl: goal,
            totalIntakeMl: amount,
            effectiveHydrationMl: amount,
          );
          await WaterService.saveDailyData(migratedWater);
        }
      }

      final remindersSnapshot = await userRef.collection('fitness_reminders').limit(200).get();
      for (final doc in remindersSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        await StorageService.addFitnessReminder(FitnessReminder.fromJson(data));
      }

      debugPrint('Successfully downloaded all data from cloud');
    } catch (e) {
      debugPrint('Download from cloud error: $e');
      rethrow;
    }
  }

  Future<bool> hasCloudData(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      final medicinesSnapshot = await userRef.collection('medicines').limit(1).get();
      if (medicinesSnapshot.docs.isNotEmpty) return true;

      final periodDoc = await userRef.collection('period').doc('current').get();
      if (periodDoc.exists) return true;

      final waterSnapshot = await userRef.collection('water_intake').limit(1).get();
      if (waterSnapshot.docs.isNotEmpty) return true;

      final remindersSnapshot = await userRef.collection('fitness_reminders').limit(1).get();
      if (remindersSnapshot.docs.isNotEmpty) return true;

      return false;
    } catch (e) {
      debugPrint('Error checking cloud data: $e');
      return false;
    }
  }
}
