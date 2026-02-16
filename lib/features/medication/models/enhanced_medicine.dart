import 'package:hive/hive.dart';
import 'medicine_enums.dart';
import 'medicine_schedule.dart';
import 'drug_interaction.dart';

part 'enhanced_medicine.g.dart';

/// Enhanced Medicine model with all premium features like Medisafe/Apple Health
@HiveType(typeId: 90)
class EnhancedMedicine extends HiveObject {
  // Basic Information
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? genericName;

  @HiveField(3)
  final String? brandName;

  @HiveField(4)
  final DosageForm dosageForm;

  @HiveField(5)
  final double dosageAmount;

  @HiveField(6)
  final String? dosageUnit; // mg, ml, mcg, etc.

  @HiveField(7)
  final String? strength; // e.g., "500mg", "10mg/5ml"

  // Schedule
  @HiveField(8)
  final MedicineSchedule schedule;

  // Pill Identification
  @HiveField(9)
  final MedicineColor? color;

  @HiveField(10)
  final MedicineShape? shape;

  @HiveField(11)
  final String? imprint; // Text/numbers on pill

  @HiveField(12)
  final String? imagePath; // Photo of medicine

  // Instructions
  @HiveField(13)
  final String? instructions; // Special instructions

  @HiveField(14)
  final String? purpose; // What is it for

  @HiveField(15)
  final String? condition; // Medical condition being treated

  // Stock Management
  @HiveField(16)
  final int? currentStock;

  @HiveField(17)
  final int? lowStockThreshold;

  @HiveField(18)
  final bool refillReminderEnabled;

  @HiveField(19)
  final DateTime? lastRefillDate;

  @HiveField(20)
  final double? costPerUnit;

  // Prescription Details
  @HiveField(21)
  final String? prescriptionNumber;

  @HiveField(22)
  final String? doctorId;

  @HiveField(23)
  final String? pharmacyId;

  @HiveField(24)
  final DateTime? prescribedDate;

  @HiveField(25)
  final DateTime? expiryDate;

  @HiveField(26)
  final int? refillsRemaining;

  // Reminders
  @HiveField(27)
  final bool reminderEnabled;

  @HiveField(28)
  final String? reminderSound;

  @HiveField(29)
  final bool criticalAlert; // For critical medications

  @HiveField(30)
  final int snoozeMinutes;

  // Drug Information
  @HiveField(31)
  final DrugInfo? drugInfo;

  @HiveField(32)
  final List<String>? warnings;

  @HiveField(33)
  final List<String>? sideEffects;

  // Family/Dependent
  @HiveField(34)
  final String? dependentId; // Who takes this medicine

  // Metadata
  @HiveField(35)
  final DateTime createdAt;

  @HiveField(36)
  final DateTime? updatedAt;

  @HiveField(37)
  final bool isActive;

  @HiveField(38)
  final bool isArchived;

  @HiveField(39)
  final String? notes;

  @HiveField(40)
  final Map<String, dynamic>? customFields;

  EnhancedMedicine({
    required this.id,
    required this.name,
    this.genericName,
    this.brandName,
    required this.dosageForm,
    required this.dosageAmount,
    this.dosageUnit,
    this.strength,
    required this.schedule,
    this.color,
    this.shape,
    this.imprint,
    this.imagePath,
    this.instructions,
    this.purpose,
    this.condition,
    this.currentStock,
    this.lowStockThreshold,
    this.refillReminderEnabled = false,
    this.lastRefillDate,
    this.costPerUnit,
    this.prescriptionNumber,
    this.doctorId,
    this.pharmacyId,
    this.prescribedDate,
    this.expiryDate,
    this.refillsRemaining,
    this.reminderEnabled = true,
    this.reminderSound,
    this.criticalAlert = false,
    this.snoozeMinutes = 10,
    this.drugInfo,
    this.warnings,
    this.sideEffects,
    this.dependentId,
    DateTime? createdAt,
    this.updatedAt,
    this.isActive = true,
    this.isArchived = false,
    this.notes,
    this.customFields,
  }) : createdAt = createdAt ?? DateTime.now();

  // Computed properties
  bool get isLowStock {
    if (currentStock == null || lowStockThreshold == null) return false;
    return currentStock! <= lowStockThreshold!;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
  }

  bool get isPRN => schedule.isPRN;

  int get estimatedDaysRemaining {
    if (currentStock == null) return -1;
    final dailyDoses = schedule.times.length;
    if (dailyDoses == 0) return -1;
    return (currentStock! / (dailyDoses * dosageAmount)).floor();
  }

  String get displayDosage {
    final amount = dosageAmount % 1 == 0 
        ? dosageAmount.toInt().toString() 
        : dosageAmount.toString();
    final unit = dosageUnit ?? dosageForm.unit;
    return '$amount $unit';
  }

  String get fullDisplayName {
    if (strength != null) {
      return '$name $strength';
    }
    return name;
  }

  List<DateTime> getTodaySchedule() {
    return schedule.getScheduledTimesForDate(DateTime.now());
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'genericName': genericName,
    'brandName': brandName,
    'dosageForm': dosageForm.index,
    'dosageAmount': dosageAmount,
    'dosageUnit': dosageUnit,
    'strength': strength,
    'schedule': schedule.toJson(),
    'color': color?.index,
    'shape': shape?.index,
    'imprint': imprint,
    'imagePath': imagePath,
    'instructions': instructions,
    'purpose': purpose,
    'condition': condition,
    'currentStock': currentStock,
    'lowStockThreshold': lowStockThreshold,
    'refillReminderEnabled': refillReminderEnabled,
    'lastRefillDate': lastRefillDate?.toIso8601String(),
    'costPerUnit': costPerUnit,
    'prescriptionNumber': prescriptionNumber,
    'doctorId': doctorId,
    'pharmacyId': pharmacyId,
    'prescribedDate': prescribedDate?.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'refillsRemaining': refillsRemaining,
    'reminderEnabled': reminderEnabled,
    'reminderSound': reminderSound,
    'criticalAlert': criticalAlert,
    'snoozeMinutes': snoozeMinutes,
    'drugInfo': drugInfo?.toJson(),
    'warnings': warnings,
    'sideEffects': sideEffects,
    'dependentId': dependentId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isActive': isActive,
    'isArchived': isArchived,
    'notes': notes,
    'customFields': customFields,
  };

  factory EnhancedMedicine.fromJson(Map<String, dynamic> json) => EnhancedMedicine(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    genericName: json['genericName'],
    brandName: json['brandName'],
    dosageForm: DosageForm.values[json['dosageForm'] ?? 0],
    dosageAmount: (json['dosageAmount'] ?? 1).toDouble(),
    dosageUnit: json['dosageUnit'],
    strength: json['strength'],
    schedule: MedicineSchedule.fromJson(json['schedule'] ?? {}),
    color: json['color'] != null ? MedicineColor.values[json['color']] : null,
    shape: json['shape'] != null ? MedicineShape.values[json['shape']] : null,
    imprint: json['imprint'],
    imagePath: json['imagePath'],
    instructions: json['instructions'],
    purpose: json['purpose'],
    condition: json['condition'],
    currentStock: json['currentStock'],
    lowStockThreshold: json['lowStockThreshold'],
    refillReminderEnabled: json['refillReminderEnabled'] ?? false,
    lastRefillDate: json['lastRefillDate'] != null ? DateTime.parse(json['lastRefillDate']) : null,
    costPerUnit: json['costPerUnit']?.toDouble(),
    prescriptionNumber: json['prescriptionNumber'],
    doctorId: json['doctorId'],
    pharmacyId: json['pharmacyId'],
    prescribedDate: json['prescribedDate'] != null ? DateTime.parse(json['prescribedDate']) : null,
    expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : null,
    refillsRemaining: json['refillsRemaining'],
    reminderEnabled: json['reminderEnabled'] ?? true,
    reminderSound: json['reminderSound'],
    criticalAlert: json['criticalAlert'] ?? false,
    snoozeMinutes: json['snoozeMinutes'] ?? 10,
    drugInfo: json['drugInfo'] != null ? DrugInfo.fromJson(json['drugInfo']) : null,
    warnings: (json['warnings'] as List?)?.cast<String>(),
    sideEffects: (json['sideEffects'] as List?)?.cast<String>(),
    dependentId: json['dependentId'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    isActive: json['isActive'] ?? true,
    isArchived: json['isArchived'] ?? false,
    notes: json['notes'],
    customFields: json['customFields'],
  );

  EnhancedMedicine copyWith({
    String? id,
    String? name,
    String? genericName,
    String? brandName,
    DosageForm? dosageForm,
    double? dosageAmount,
    String? dosageUnit,
    String? strength,
    MedicineSchedule? schedule,
    MedicineColor? color,
    MedicineShape? shape,
    String? imprint,
    String? imagePath,
    String? instructions,
    String? purpose,
    String? condition,
    int? currentStock,
    int? lowStockThreshold,
    bool? refillReminderEnabled,
    DateTime? lastRefillDate,
    double? costPerUnit,
    String? prescriptionNumber,
    String? doctorId,
    String? pharmacyId,
    DateTime? prescribedDate,
    DateTime? expiryDate,
    int? refillsRemaining,
    bool? reminderEnabled,
    String? reminderSound,
    bool? criticalAlert,
    int? snoozeMinutes,
    DrugInfo? drugInfo,
    List<String>? warnings,
    List<String>? sideEffects,
    String? dependentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isArchived,
    String? notes,
    Map<String, dynamic>? customFields,
  }) {
    return EnhancedMedicine(
      id: id ?? this.id,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      brandName: brandName ?? this.brandName,
      dosageForm: dosageForm ?? this.dosageForm,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      strength: strength ?? this.strength,
      schedule: schedule ?? this.schedule,
      color: color ?? this.color,
      shape: shape ?? this.shape,
      imprint: imprint ?? this.imprint,
      imagePath: imagePath ?? this.imagePath,
      instructions: instructions ?? this.instructions,
      purpose: purpose ?? this.purpose,
      condition: condition ?? this.condition,
      currentStock: currentStock ?? this.currentStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      refillReminderEnabled: refillReminderEnabled ?? this.refillReminderEnabled,
      lastRefillDate: lastRefillDate ?? this.lastRefillDate,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      prescriptionNumber: prescriptionNumber ?? this.prescriptionNumber,
      doctorId: doctorId ?? this.doctorId,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      prescribedDate: prescribedDate ?? this.prescribedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      refillsRemaining: refillsRemaining ?? this.refillsRemaining,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderSound: reminderSound ?? this.reminderSound,
      criticalAlert: criticalAlert ?? this.criticalAlert,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      drugInfo: drugInfo ?? this.drugInfo,
      warnings: warnings ?? this.warnings,
      sideEffects: sideEffects ?? this.sideEffects,
      dependentId: dependentId ?? this.dependentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      notes: notes ?? this.notes,
      customFields: customFields ?? this.customFields,
    );
  }

  /// Reduce stock by the given amount
  EnhancedMedicine reduceStock(double amount) {
    if (currentStock == null) return this;
    return copyWith(currentStock: (currentStock! - amount.toInt()).clamp(0, 999999));
  }

  /// Add stock (refill)
  EnhancedMedicine addStock(int amount) {
    final newStock = (currentStock ?? 0) + amount;
    return copyWith(
      currentStock: newStock,
      lastRefillDate: DateTime.now(),
    );
  }

  /// Archive the medicine
  EnhancedMedicine archive() {
    return copyWith(isArchived: true, isActive: false);
  }

  /// Unarchive the medicine
  EnhancedMedicine unarchive() {
    return copyWith(isArchived: false, isActive: true);
  }
}

/// Treatment course grouping medicines by condition
@HiveType(typeId: 91)
class TreatmentCourse extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? condition;

  @HiveField(3)
  final String? description;

  @HiveField(4)
  final List<String> medicineIds;

  @HiveField(5)
  final DateTime startDate;

  @HiveField(6)
  final DateTime? endDate;

  @HiveField(7)
  final String? doctorId;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final bool isActive;

  @HiveField(10)
  final String? dependentId;

  TreatmentCourse({
    required this.id,
    required this.name,
    this.condition,
    this.description,
    required this.medicineIds,
    required this.startDate,
    this.endDate,
    this.doctorId,
    this.notes,
    this.isActive = true,
    this.dependentId,
  });

  bool get isOngoing => endDate == null || endDate!.isAfter(DateTime.now());

  int get durationDays {
    final end = endDate ?? DateTime.now();
    return end.difference(startDate).inDays;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'condition': condition,
    'description': description,
    'medicineIds': medicineIds,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'doctorId': doctorId,
    'notes': notes,
    'isActive': isActive,
    'dependentId': dependentId,
  };

  factory TreatmentCourse.fromJson(Map<String, dynamic> json) => TreatmentCourse(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    condition: json['condition'],
    description: json['description'],
    medicineIds: (json['medicineIds'] as List?)?.cast<String>() ?? [],
    startDate: DateTime.parse(json['startDate']),
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    doctorId: json['doctorId'],
    notes: json['notes'],
    isActive: json['isActive'] ?? true,
    dependentId: json['dependentId'],
  );

  TreatmentCourse copyWith({
    String? id,
    String? name,
    String? condition,
    String? description,
    List<String>? medicineIds,
    DateTime? startDate,
    DateTime? endDate,
    String? doctorId,
    String? notes,
    bool? isActive,
    String? dependentId,
  }) {
    return TreatmentCourse(
      id: id ?? this.id,
      name: name ?? this.name,
      condition: condition ?? this.condition,
      description: description ?? this.description,
      medicineIds: medicineIds ?? this.medicineIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      doctorId: doctorId ?? this.doctorId,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      dependentId: dependentId ?? this.dependentId,
    );
  }
}
