import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/intake_streak.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/intake_tracking_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  setUpAll(() async {
    await Hive.initFlutter();
    
    Hive.registerAdapter(EnhancedMedicineAdapter());
    Hive.registerAdapter(IntakeStreakAdapter());
    Hive.registerAdapter(PatientMedicineProfileAdapter());
    Hive.registerAdapter(DosageFormAdapter());
    Hive.registerAdapter(FrequencyTypeAdapter());
    Hive.registerAdapter(MealTimingAdapter());
    Hive.registerAdapter(MedicineStatusAdapter());
    Hive.registerAdapter(SkipReasonAdapter());
    Hive.registerAdapter(HealthCategoryAdapter());
    Hive.registerAdapter(MedicineScheduleAdapter());
    Hive.registerAdapter(ScheduledTimeAdapter());
    
    await MedicineStorageService.init();
    await IntakeTrackingService.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('Continuous Intake Tracking Tests', () {
    test('Medicine with continuous intake requirement prevents skip after consecutive takes', () async {
      final medicine = EnhancedMedicine(
        id: 'test_med_1',
        name: 'Heart Medicine',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 9, minute: 0)],
          mealTiming: MealTiming.afterMeal,
        ),
        requiresContinuousIntake: true,
        minimumConsecutiveDays: 3,
        healthCategories: [HealthCategory.heart],
      );

      await MedicineStorageService.addMedicine(medicine);

      await IntakeTrackingService.recordMedicineTaken(
        medicineId: medicine.id,
        takenDate: DateTime.now().subtract(const Duration(days: 2)),
      );
      await IntakeTrackingService.recordMedicineTaken(
        medicineId: medicine.id,
        takenDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      await IntakeTrackingService.recordMedicineTaken(
        medicineId: medicine.id,
        takenDate: DateTime.now(),
      );

      final canSkip = await IntakeTrackingService.canSkipMedicine(medicine.id);
      expect(canSkip, false, reason: 'Should not be able to skip after 3 consecutive takes');

      final stats = IntakeTrackingService.getStreakStats(medicine.id);
      expect(stats['consecutiveTakes'], 3);
      expect(stats['canSkip'], false);

      await MedicineStorageService.deleteMedicine(medicine.id);
    });

    test('Medicine allows skip before reaching minimum consecutive days', () async {
      final medicine = EnhancedMedicine(
        id: 'test_med_2',
        name: 'Diabetes Medicine',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.twiceDaily,
          times: [
            ScheduledTime(hour: 8, minute: 0),
            ScheduledTime(hour: 20, minute: 0),
          ],
          mealTiming: MealTiming.beforeMeal,
        ),
        requiresContinuousIntake: true,
        minimumConsecutiveDays: 5,
        healthCategories: [HealthCategory.diabetes],
      );

      await MedicineStorageService.addMedicine(medicine);

      await IntakeTrackingService.recordMedicineTaken(
        medicineId: medicine.id,
        takenDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      await IntakeTrackingService.recordMedicineTaken(
        medicineId: medicine.id,
        takenDate: DateTime.now(),
      );

      final canSkip = await IntakeTrackingService.canSkipMedicine(medicine.id);
      expect(canSkip, true, reason: 'Should be able to skip before reaching 5 consecutive takes');

      final stats = IntakeTrackingService.getStreakStats(medicine.id);
      expect(stats['consecutiveTakes'], 2);
      expect(stats['canSkip'], true);

      await MedicineStorageService.deleteMedicine(medicine.id);
    });

    test('Skip resets streak and allows future skips', () async {
      final medicine = EnhancedMedicine(
        id: 'test_med_3',
        name: 'Blood Pressure Medicine',
        dosageForm: DosageForm.capsule,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 10, minute: 0)],
          mealTiming: MealTiming.anytime,
        ),
        healthCategories: [HealthCategory.heart, HealthCategory.blood],
      );

      await MedicineStorageService.addMedicine(medicine);

      await IntakeTrackingService.recordMedicineTaken(
        medicineId: medicine.id,
        takenDate: DateTime.now().subtract(const Duration(days: 2)),
      );
      await IntakeTrackingService.recordMedicineTaken(
        medicineId: medicine.id,
        takenDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      var stats = IntakeTrackingService.getStreakStats(medicine.id);
      expect(stats['currentStreak'], 2);

      await IntakeTrackingService.recordMedicineSkipped(
        medicineId: medicine.id,
        skipDate: DateTime.now(),
        reason: SkipReason.forgotToTake,
      );

      stats = IntakeTrackingService.getStreakStats(medicine.id);
      expect(stats['currentStreak'], 0, reason: 'Streak should reset after skip');
      expect(stats['canSkip'], true);

      await MedicineStorageService.deleteMedicine(medicine.id);
    });

    test('Streak tracking maintains longest streak', () async {
      final medicine = EnhancedMedicine(
        id: 'test_med_4',
        name: 'Vitamin D',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 9, minute: 0)],
          mealTiming: MealTiming.withMeal,
        ),
        healthCategories: [HealthCategory.vitamin],
      );

      await MedicineStorageService.addMedicine(medicine);

      for (int i = 7; i >= 1; i--) {
        await IntakeTrackingService.recordMedicineTaken(
          medicineId: medicine.id,
          takenDate: DateTime.now().subtract(Duration(days: i)),
        );
      }

      var stats = IntakeTrackingService.getStreakStats(medicine.id);
      expect(stats['currentStreak'], 7);
      expect(stats['longestStreak'], 7);

      await IntakeTrackingService.recordMedicineSkipped(
        medicineId: medicine.id,
        skipDate: DateTime.now(),
        reason: SkipReason.forgotToTake,
      );

      for (int i = 3; i >= 1; i--) {
        await IntakeTrackingService.recordMedicineTaken(
          medicineId: medicine.id,
          takenDate: DateTime.now().add(Duration(days: i)),
        );
      }

      stats = IntakeTrackingService.getStreakStats(medicine.id);
      expect(stats['currentStreak'], 3);
      expect(stats['longestStreak'], 7, reason: 'Longest streak should be maintained');

      await MedicineStorageService.deleteMedicine(medicine.id);
    });
  });

  group('Health Category Management Tests', () {
    test('Patient profile can have multiple health categories', () async {
      final profile = IntakeTrackingService.getOrCreatePatientProfile(
        patientId: 'patient_1',
        patientName: 'John Doe',
      );

      await IntakeTrackingService.addHealthCategoryToProfile(
        patientId: profile.patientId,
        category: HealthCategory.heart,
      );
      await IntakeTrackingService.addHealthCategoryToProfile(
        patientId: profile.patientId,
        category: HealthCategory.diabetes,
      );
      await IntakeTrackingService.addHealthCategoryToProfile(
        patientId: profile.patientId,
        category: HealthCategory.kidney,
      );

      final updatedProfile = IntakeTrackingService.getPatientProfile('patient_1');
      expect(updatedProfile!.healthCategories.length, 3);
      expect(updatedProfile.healthCategories.contains(HealthCategory.heart), true);
      expect(updatedProfile.healthCategories.contains(HealthCategory.diabetes), true);
      expect(updatedProfile.healthCategories.contains(HealthCategory.kidney), true);
    });

    test('Patient profile can have custom categories', () async {
      final profile = IntakeTrackingService.getOrCreatePatientProfile(
        patientId: 'patient_2',
        patientName: 'Jane Smith',
      );

      await IntakeTrackingService.addCustomCategoryToProfile(
        patientId: profile.patientId,
        categoryName: 'Post-Surgery Recovery',
      );
      await IntakeTrackingService.addCustomCategoryToProfile(
        patientId: profile.patientId,
        categoryName: 'Chronic Pain Management',
      );

      final updatedProfile = IntakeTrackingService.getPatientProfile('patient_2');
      expect(updatedProfile!.customCategories.length, 2);
      expect(updatedProfile.customCategories.contains('Post-Surgery Recovery'), true);
      expect(updatedProfile.customCategories.contains('Chronic Pain Management'), true);
    });

    test('Medicines can be linked to patient health categories', () async {
      final profile = IntakeTrackingService.getOrCreatePatientProfile(
        patientId: 'patient_3',
        patientName: 'Bob Johnson',
      );

      await IntakeTrackingService.addHealthCategoryToProfile(
        patientId: profile.patientId,
        category: HealthCategory.heart,
      );

      final medicine1 = EnhancedMedicine(
        id: 'heart_med_1',
        name: 'Aspirin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 9, minute: 0)],
          mealTiming: MealTiming.afterMeal,
        ),
        healthCategories: [HealthCategory.heart],
        patientProfileId: 'patient_3',
      );

      final medicine2 = EnhancedMedicine(
        id: 'heart_med_2',
        name: 'Beta Blocker',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.twiceDaily,
          times: [
            ScheduledTime(hour: 8, minute: 0),
            ScheduledTime(hour: 20, minute: 0),
          ],
          mealTiming: MealTiming.beforeMeal,
        ),
        healthCategories: [HealthCategory.heart],
        patientProfileId: 'patient_3',
      );

      await MedicineStorageService.addMedicine(medicine1);
      await MedicineStorageService.addMedicine(medicine2);

      await IntakeTrackingService.linkMedicineToCategory(
        patientId: 'patient_3',
        categoryName: HealthCategory.heart.displayName,
        medicineId: medicine1.id,
      );
      await IntakeTrackingService.linkMedicineToCategory(
        patientId: 'patient_3',
        categoryName: HealthCategory.heart.displayName,
        medicineId: medicine2.id,
      );

      final medicines = IntakeTrackingService.getMedicinesByHealthCategory(
        patientId: 'patient_3',
        categoryName: HealthCategory.heart.displayName,
      );

      expect(medicines.length, 2);
      expect(medicines.any((m) => m.id == 'heart_med_1'), true);
      expect(medicines.any((m) => m.id == 'heart_med_2'), true);

      await MedicineStorageService.deleteMedicine(medicine1.id);
      await MedicineStorageService.deleteMedicine(medicine2.id);
    });

    test('Comprehensive health report provides category-wise analytics', () async {
      final profile = IntakeTrackingService.getOrCreatePatientProfile(
        patientId: 'patient_4',
        patientName: 'Alice Williams',
      );

      await IntakeTrackingService.addHealthCategoryToProfile(
        patientId: profile.patientId,
        category: HealthCategory.diabetes,
      );
      await IntakeTrackingService.addHealthCategoryToProfile(
        patientId: profile.patientId,
        category: HealthCategory.heart,
      );

      final diabetesMed = EnhancedMedicine(
        id: 'diabetes_med_1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 500,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.twiceDaily,
          times: [
            ScheduledTime(hour: 8, minute: 0),
            ScheduledTime(hour: 20, minute: 0),
          ],
          mealTiming: MealTiming.withMeal,
        ),
        healthCategories: [HealthCategory.diabetes],
        patientProfileId: 'patient_4',
      );

      await MedicineStorageService.addMedicine(diabetesMed);

      await IntakeTrackingService.recordMedicineTaken(
        medicineId: diabetesMed.id,
        takenDate: DateTime.now().subtract(const Duration(days: 2)),
      );
      await IntakeTrackingService.recordMedicineTaken(
        medicineId: diabetesMed.id,
        takenDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      await IntakeTrackingService.recordMedicineTaken(
        medicineId: diabetesMed.id,
        takenDate: DateTime.now(),
      );

      final report = IntakeTrackingService.getComprehensiveHealthReport('patient_4');

      expect(report['patientName'], 'Alice Williams');
      expect(report['totalCategories'], 2);
      expect(report['totalMedicines'], 1);
      expect(report['categoryStats'], isNotNull);
      expect(report['overallAdherence'], greaterThan(0));

      await MedicineStorageService.deleteMedicine(diabetesMed.id);
    });
  });

  group('Adherence Rate Calculation Tests', () {
    test('Adherence rate is calculated correctly', () async {
      final medicine = EnhancedMedicine(
        id: 'adherence_test_1',
        name: 'Test Medicine',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 9, minute: 0)],
          mealTiming: MealTiming.anytime,
        ),
      );

      await MedicineStorageService.addMedicine(medicine);

      for (int i = 0; i < 7; i++) {
        await IntakeTrackingService.recordMedicineTaken(
          medicineId: medicine.id,
          takenDate: DateTime.now().subtract(Duration(days: i)),
        );
      }

      for (int i = 0; i < 3; i++) {
        await IntakeTrackingService.recordMedicineSkipped(
          medicineId: medicine.id,
          skipDate: DateTime.now().add(Duration(days: i + 1)),
          reason: SkipReason.forgotToTake,
        );
      }

      final stats = IntakeTrackingService.getStreakStats(medicine.id);
      expect(stats['totalTaken'], 7);
      expect(stats['totalSkipped'], 3);
      expect(stats['adherenceRate'], 70.0);

      await MedicineStorageService.deleteMedicine(medicine.id);
    });
  });
}
