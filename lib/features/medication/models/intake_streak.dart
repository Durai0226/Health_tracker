import 'package:hive/hive.dart';
import 'medicine_enums.dart';

part 'intake_streak.g.dart';

/// Tracks continuous intake streaks and prevents skipping after consecutive takes
@HiveType(typeId: 92)
class IntakeStreak extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String medicineId;

  @HiveField(2)
  final int currentStreak;

  @HiveField(3)
  final int longestStreak;

  @HiveField(4)
  final DateTime? lastTakenDate;

  @HiveField(5)
  final List<DateTime> consecutiveTakeDates;

  @HiveField(6)
  final bool canSkip;

  @HiveField(7)
  final int consecutiveTakes;

  @HiveField(8)
  final DateTime? lastSkipDate;

  @HiveField(9)
  final int totalTaken;

  @HiveField(10)
  final int totalSkipped;

  @HiveField(11)
  final DateTime createdAt;

  IntakeStreak({
    required this.id,
    required this.medicineId,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastTakenDate,
    List<DateTime>? consecutiveTakeDates,
    this.canSkip = true,
    this.consecutiveTakes = 0,
    this.lastSkipDate,
    this.totalTaken = 0,
    this.totalSkipped = 0,
    DateTime? createdAt,
  })  : consecutiveTakeDates = consecutiveTakeDates ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isActiveStreak {
    if (lastTakenDate == null) return false;
    final daysSinceLastTake = DateTime.now().difference(lastTakenDate!).inDays;
    return daysSinceLastTake <= 1;
  }

  double get adherenceRate {
    final total = totalTaken + totalSkipped;
    if (total == 0) return 100.0;
    return (totalTaken / total) * 100;
  }

  IntakeStreak recordTake(DateTime takenDate) {
    final newConsecutiveTakeDates = List<DateTime>.from(consecutiveTakeDates)..add(takenDate);
    final newConsecutiveTakes = consecutiveTakes + 1;
    
    int newStreak = currentStreak;
    if (lastTakenDate != null) {
      final daysDiff = takenDate.difference(lastTakenDate!).inDays;
      if (daysDiff == 1) {
        newStreak = currentStreak + 1;
      } else if (daysDiff == 0) {
        newStreak = currentStreak;
      } else {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    final newLongestStreak = newStreak > longestStreak ? newStreak : longestStreak;
    
    final newCanSkip = newConsecutiveTakes < 3;

    return IntakeStreak(
      id: id,
      medicineId: medicineId,
      currentStreak: newStreak,
      longestStreak: newLongestStreak,
      lastTakenDate: takenDate,
      consecutiveTakeDates: newConsecutiveTakeDates,
      canSkip: newCanSkip,
      consecutiveTakes: newConsecutiveTakes,
      lastSkipDate: lastSkipDate,
      totalTaken: totalTaken + 1,
      totalSkipped: totalSkipped,
      createdAt: createdAt,
    );
  }

  IntakeStreak recordSkip(DateTime skipDate) {
    return IntakeStreak(
      id: id,
      medicineId: medicineId,
      currentStreak: 0,
      longestStreak: longestStreak,
      lastTakenDate: lastTakenDate,
      consecutiveTakeDates: [],
      canSkip: true,
      consecutiveTakes: 0,
      lastSkipDate: skipDate,
      totalTaken: totalTaken,
      totalSkipped: totalSkipped + 1,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineId': medicineId,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastTakenDate': lastTakenDate?.toIso8601String(),
        'consecutiveTakeDates': consecutiveTakeDates.map((d) => d.toIso8601String()).toList(),
        'canSkip': canSkip,
        'consecutiveTakes': consecutiveTakes,
        'lastSkipDate': lastSkipDate?.toIso8601String(),
        'totalTaken': totalTaken,
        'totalSkipped': totalSkipped,
        'createdAt': createdAt.toIso8601String(),
      };

  factory IntakeStreak.fromJson(Map<String, dynamic> json) => IntakeStreak(
        id: json['id'] ?? '',
        medicineId: json['medicineId'] ?? '',
        currentStreak: json['currentStreak'] ?? 0,
        longestStreak: json['longestStreak'] ?? 0,
        lastTakenDate: json['lastTakenDate'] != null ? DateTime.parse(json['lastTakenDate']) : null,
        consecutiveTakeDates: (json['consecutiveTakeDates'] as List?)
                ?.map((d) => DateTime.parse(d as String))
                .toList() ??
            [],
        canSkip: json['canSkip'] ?? true,
        consecutiveTakes: json['consecutiveTakes'] ?? 0,
        lastSkipDate: json['lastSkipDate'] != null ? DateTime.parse(json['lastSkipDate']) : null,
        totalTaken: json['totalTaken'] ?? 0,
        totalSkipped: json['totalSkipped'] ?? 0,
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      );

  IntakeStreak copyWith({
    String? id,
    String? medicineId,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastTakenDate,
    List<DateTime>? consecutiveTakeDates,
    bool? canSkip,
    int? consecutiveTakes,
    DateTime? lastSkipDate,
    int? totalTaken,
    int? totalSkipped,
    DateTime? createdAt,
  }) {
    return IntakeStreak(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastTakenDate: lastTakenDate ?? this.lastTakenDate,
      consecutiveTakeDates: consecutiveTakeDates ?? this.consecutiveTakeDates,
      canSkip: canSkip ?? this.canSkip,
      consecutiveTakes: consecutiveTakes ?? this.consecutiveTakes,
      lastSkipDate: lastSkipDate ?? this.lastSkipDate,
      totalTaken: totalTaken ?? this.totalTaken,
      totalSkipped: totalSkipped ?? this.totalSkipped,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

@HiveType(typeId: 93)
class PatientMedicineProfile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String patientId;

  @HiveField(2)
  final String patientName;

  @HiveField(3)
  final List<HealthCategory> healthCategories;

  @HiveField(4)
  final List<String> customCategories;

  @HiveField(5)
  final Map<String, List<String>> categoryMedicines;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime? updatedAt;

  @HiveField(8)
  final Map<String, dynamic>? healthMetrics;

  @HiveField(9)
  final String? notes;

  PatientMedicineProfile({
    required this.id,
    required this.patientId,
    required this.patientName,
    List<HealthCategory>? healthCategories,
    List<String>? customCategories,
    Map<String, List<String>>? categoryMedicines,
    DateTime? createdAt,
    this.updatedAt,
    this.healthMetrics,
    this.notes,
  })  : healthCategories = healthCategories ?? [],
        customCategories = customCategories ?? [],
        categoryMedicines = categoryMedicines ?? {},
        createdAt = createdAt ?? DateTime.now();

  int get totalCategories => healthCategories.length + customCategories.length;

  int get totalMedicines {
    return categoryMedicines.values.fold(0, (sum, meds) => sum + meds.length);
  }

  List<String> getMedicinesForCategory(String category) {
    return categoryMedicines[category] ?? [];
  }

  PatientMedicineProfile addCategory(HealthCategory category) {
    if (healthCategories.contains(category)) return this;
    return copyWith(
      healthCategories: [...healthCategories, category],
      updatedAt: DateTime.now(),
    );
  }

  PatientMedicineProfile addCustomCategory(String category) {
    if (customCategories.contains(category)) return this;
    return copyWith(
      customCategories: [...customCategories, category],
      updatedAt: DateTime.now(),
    );
  }

  PatientMedicineProfile addMedicineToCategory(String category, String medicineId) {
    final newCategoryMedicines = Map<String, List<String>>.from(categoryMedicines);
    if (!newCategoryMedicines.containsKey(category)) {
      newCategoryMedicines[category] = [];
    }
    if (!newCategoryMedicines[category]!.contains(medicineId)) {
      newCategoryMedicines[category] = [...newCategoryMedicines[category]!, medicineId];
    }
    return copyWith(
      categoryMedicines: newCategoryMedicines,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'patientName': patientName,
        'healthCategories': healthCategories.map((c) => c.index).toList(),
        'customCategories': customCategories,
        'categoryMedicines': categoryMedicines,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'healthMetrics': healthMetrics,
        'notes': notes,
      };

  factory PatientMedicineProfile.fromJson(Map<String, dynamic> json) => PatientMedicineProfile(
        id: json['id'] ?? '',
        patientId: json['patientId'] ?? '',
        patientName: json['patientName'] ?? '',
        healthCategories: (json['healthCategories'] as List?)
                ?.map((i) => HealthCategory.values[i as int])
                .toList() ??
            [],
        customCategories: (json['customCategories'] as List?)?.cast<String>() ?? [],
        categoryMedicines: (json['categoryMedicines'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as List).cast<String>()),
            ) ??
            {},
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        healthMetrics: json['healthMetrics'] as Map<String, dynamic>?,
        notes: json['notes'],
      );

  PatientMedicineProfile copyWith({
    String? id,
    String? patientId,
    String? patientName,
    List<HealthCategory>? healthCategories,
    List<String>? customCategories,
    Map<String, List<String>>? categoryMedicines,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? healthMetrics,
    String? notes,
  }) {
    return PatientMedicineProfile(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      healthCategories: healthCategories ?? this.healthCategories,
      customCategories: customCategories ?? this.customCategories,
      categoryMedicines: categoryMedicines ?? this.categoryMedicines,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      healthMetrics: healthMetrics ?? this.healthMetrics,
      notes: notes ?? this.notes,
    );
  }
}
