import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/intake_streak.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';

void main() {
  group('Intake Streak Logic Tests', () {
    test('Recording a take increments consecutive takes', () {
      var streak = IntakeStreak(
        id: 'test_1',
        medicineId: 'med_1',
      );

      streak = streak.recordTake(DateTime.now());
      expect(streak.consecutiveTakes, 1);
      expect(streak.totalTaken, 1);
      expect(streak.currentStreak, 1);

      streak = streak.recordTake(DateTime.now().add(const Duration(days: 1)));
      expect(streak.consecutiveTakes, 2);
      expect(streak.totalTaken, 2);
      expect(streak.currentStreak, 2);

      streak = streak.recordTake(DateTime.now().add(const Duration(days: 2)));
      expect(streak.consecutiveTakes, 3);
      expect(streak.totalTaken, 3);
      expect(streak.currentStreak, 3);
    });

    test('Skip prevention logic - cannot skip after 3 consecutive takes', () {
      var streak = IntakeStreak(
        id: 'test_2',
        medicineId: 'med_2',
      );

      expect(streak.canSkip, true);

      streak = streak.recordTake(DateTime.now());
      expect(streak.canSkip, true);

      streak = streak.recordTake(DateTime.now().add(const Duration(days: 1)));
      expect(streak.canSkip, true);

      streak = streak.recordTake(DateTime.now().add(const Duration(days: 2)));
      expect(streak.canSkip, false, reason: 'Should not be able to skip after 3 consecutive takes');
      expect(streak.consecutiveTakes, 3);
    });

    test('Recording a skip resets streak and consecutive takes', () {
      var streak = IntakeStreak(
        id: 'test_3',
        medicineId: 'med_3',
      );

      streak = streak.recordTake(DateTime.now().subtract(const Duration(days: 2)));
      streak = streak.recordTake(DateTime.now().subtract(const Duration(days: 1)));
      streak = streak.recordTake(DateTime.now());

      expect(streak.currentStreak, 3);
      expect(streak.consecutiveTakes, 3);
      expect(streak.canSkip, false);

      streak = streak.recordSkip(DateTime.now().add(const Duration(days: 1)));

      expect(streak.currentStreak, 0, reason: 'Streak should reset after skip');
      expect(streak.consecutiveTakes, 0, reason: 'Consecutive takes should reset');
      expect(streak.canSkip, true, reason: 'Should be able to skip again after reset');
      expect(streak.totalSkipped, 1);
    });

    test('Longest streak is maintained even after reset', () {
      var streak = IntakeStreak(
        id: 'test_4',
        medicineId: 'med_4',
      );

      for (int i = 0; i < 7; i++) {
        streak = streak.recordTake(DateTime.now().add(Duration(days: i)));
      }

      expect(streak.currentStreak, 7);
      expect(streak.longestStreak, 7);

      streak = streak.recordSkip(DateTime.now().add(const Duration(days: 8)));

      expect(streak.currentStreak, 0);
      expect(streak.longestStreak, 7, reason: 'Longest streak should be preserved');

      for (int i = 0; i < 3; i++) {
        streak = streak.recordTake(DateTime.now().add(Duration(days: 9 + i)));
      }

      expect(streak.currentStreak, 3);
      expect(streak.longestStreak, 7, reason: 'Longest streak should still be 7');
    });

    test('Adherence rate is calculated correctly', () {
      var streak = IntakeStreak(
        id: 'test_5',
        medicineId: 'med_5',
      );

      for (int i = 0; i < 7; i++) {
        streak = streak.recordTake(DateTime.now().add(Duration(days: i)));
      }

      for (int i = 0; i < 3; i++) {
        streak = streak.recordSkip(DateTime.now().add(Duration(days: 7 + i)));
      }

      expect(streak.totalTaken, 7);
      expect(streak.totalSkipped, 3);
      expect(streak.adherenceRate, 70.0);
    });

    test('Streak breaks when days are not consecutive', () {
      var streak = IntakeStreak(
        id: 'test_6',
        medicineId: 'med_6',
      );

      final baseDate = DateTime(2024, 1, 1);
      
      streak = streak.recordTake(baseDate);
      expect(streak.currentStreak, 1);

      streak = streak.recordTake(baseDate.add(const Duration(days: 1)));
      expect(streak.currentStreak, 2);

      streak = streak.recordTake(baseDate.add(const Duration(days: 3)));
      expect(streak.currentStreak, 1, reason: 'Streak should reset when days are not consecutive');
    });

    test('Active streak detection works correctly', () {
      final now = DateTime.now();
      
      var streak = IntakeStreak(
        id: 'test_7',
        medicineId: 'med_7',
        lastTakenDate: now,
      );

      expect(streak.isActiveStreak, true);

      streak = IntakeStreak(
        id: 'test_7',
        medicineId: 'med_7',
        lastTakenDate: now.subtract(const Duration(days: 1)),
      );

      expect(streak.isActiveStreak, true);

      streak = IntakeStreak(
        id: 'test_7',
        medicineId: 'med_7',
        lastTakenDate: now.subtract(const Duration(days: 3)),
      );

      expect(streak.isActiveStreak, false);
    });
  });

  group('Patient Medicine Profile Tests', () {
    test('Patient profile can add health categories', () {
      var profile = PatientMedicineProfile(
        id: 'patient_1',
        patientId: 'patient_1',
        patientName: 'John Doe',
      );

      expect(profile.healthCategories.length, 0);

      profile = profile.addCategory(HealthCategory.heart);
      expect(profile.healthCategories.length, 1);
      expect(profile.healthCategories.contains(HealthCategory.heart), true);

      profile = profile.addCategory(HealthCategory.diabetes);
      expect(profile.healthCategories.length, 2);
      expect(profile.healthCategories.contains(HealthCategory.diabetes), true);
    });

    test('Patient profile prevents duplicate categories', () {
      var profile = PatientMedicineProfile(
        id: 'patient_2',
        patientId: 'patient_2',
        patientName: 'Jane Smith',
      );

      profile = profile.addCategory(HealthCategory.heart);
      expect(profile.healthCategories.length, 1);

      profile = profile.addCategory(HealthCategory.heart);
      expect(profile.healthCategories.length, 1, reason: 'Should not add duplicate categories');
    });

    test('Patient profile can add custom categories', () {
      var profile = PatientMedicineProfile(
        id: 'patient_3',
        patientId: 'patient_3',
        patientName: 'Bob Johnson',
      );

      profile = profile.addCustomCategory('Post-Surgery Recovery');
      expect(profile.customCategories.length, 1);
      expect(profile.customCategories.contains('Post-Surgery Recovery'), true);

      profile = profile.addCustomCategory('Chronic Pain Management');
      expect(profile.customCategories.length, 2);
    });

    test('Patient profile can link medicines to categories', () {
      var profile = PatientMedicineProfile(
        id: 'patient_4',
        patientId: 'patient_4',
        patientName: 'Alice Williams',
      );

      profile = profile.addCategory(HealthCategory.heart);
      profile = profile.addMedicineToCategory(HealthCategory.heart.displayName, 'med_1');
      profile = profile.addMedicineToCategory(HealthCategory.heart.displayName, 'med_2');

      final medicines = profile.getMedicinesForCategory(HealthCategory.heart.displayName);
      expect(medicines.length, 2);
      expect(medicines.contains('med_1'), true);
      expect(medicines.contains('med_2'), true);
    });

    test('Patient profile calculates total categories and medicines correctly', () {
      var profile = PatientMedicineProfile(
        id: 'patient_5',
        patientId: 'patient_5',
        patientName: 'Charlie Brown',
      );

      profile = profile.addCategory(HealthCategory.heart);
      profile = profile.addCategory(HealthCategory.diabetes);
      profile = profile.addCustomCategory('Custom Category 1');

      expect(profile.totalCategories, 3);

      profile = profile.addMedicineToCategory(HealthCategory.heart.displayName, 'med_1');
      profile = profile.addMedicineToCategory(HealthCategory.heart.displayName, 'med_2');
      profile = profile.addMedicineToCategory(HealthCategory.diabetes.displayName, 'med_3');

      expect(profile.totalMedicines, 3);
    });
  });

  group('Health Category Enum Tests', () {
    test('All health categories have display names', () {
      for (final category in HealthCategory.values) {
        expect(category.displayName, isNotEmpty);
      }
    });

    test('All health categories have icons', () {
      for (final category in HealthCategory.values) {
        expect(category.icon, isNotEmpty);
      }
    });

    test('Health categories cover major health systems', () {
      expect(HealthCategory.values.contains(HealthCategory.heart), true);
      expect(HealthCategory.values.contains(HealthCategory.kidney), true);
      expect(HealthCategory.values.contains(HealthCategory.lungs), true);
      expect(HealthCategory.values.contains(HealthCategory.liver), true);
      expect(HealthCategory.values.contains(HealthCategory.brain), true);
      expect(HealthCategory.values.contains(HealthCategory.diabetes), true);
      expect(HealthCategory.values.contains(HealthCategory.cancer), true);
      expect(HealthCategory.values.contains(HealthCategory.mentalHealth), true);
    });
  });
}
