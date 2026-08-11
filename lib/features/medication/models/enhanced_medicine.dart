import 'medicine_enums.dart';
import 'medicine_schedule.dart';
import 'drug_interaction.dart';

/// Enhanced Medicine model with all premium features like Medisafe/Apple Health
class EnhancedMedicine {
  // Basic Information
  final String id;
  final String name;
  final String? genericName;
  final String? brandName;
  final DosageForm dosageForm;
  final AdministrationRoute? route;
  final double dosageAmount;
  final String? dosageUnit; // mg, ml, mcg, etc.
  final String? strength; // e.g., "500mg", "10mg/5ml"
  // Schedule
  final MedicineSchedule schedule;
  // Pill Identification
  final MedicineColor? color;
  final MedicineShape? shape;
  final String? imprint; // Text/numbers on pill
  final String? imagePath; // Photo of medicine
  // Instructions
  final String? instructions; // Special instructions
  final String? purpose; // What is it for
  final String? condition; // Medical condition being treated
  // Stock Management
  final int? currentStock;
  final int? lowStockThreshold;
  final bool refillReminderEnabled;
  final DateTime? lastRefillDate;
  final double? costPerUnit;
  // Prescription Details
  final String? prescriptionNumber;
  final String? doctorId;
  final String? pharmacyId;
  final DateTime? prescribedDate;
  final DateTime? expiryDate;
  final int? refillsRemaining;
  // Reminders
  final bool reminderEnabled;
  final String? reminderSound;
  final bool criticalAlert; // For critical medications
  final int snoozeMinutes;
  // Drug Information
  final DrugInfo? drugInfo;
  final List<String>? warnings;
  final List<String>? sideEffects;
  // Family/Dependent
  final String? dependentId; // Who takes this medicine
  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final bool isArchived;
  final String? notes;
  final Map<String, dynamic>? customFields;
  final List<HealthCategory>? healthCategories;
  final String? customHealthCategory;
  final String? patientProfileId;
  final bool requiresContinuousIntake;
  final int? minimumConsecutiveDays;

  EnhancedMedicine({
    required this.id,
    required this.name,
    this.genericName,
    this.brandName,
    required this.dosageForm,
    this.route,
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
    this.healthCategories,
    this.customHealthCategory,
    this.patientProfileId,
    this.requiresContinuousIntake = false,
    this.minimumConsecutiveDays,
  }) : createdAt = createdAt ?? DateTime.now();

  // Computed properties
  bool get isLowStock {
    // Refill/stock tracking is opt-in (refillReminderEnabled, default off). An
    // untracked medicine's stock is persisted as 0, so without this gate every
    // medicine added without a quantity would read as a false "low stock".
    if (!refillReminderEnabled) return false;
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

  /// Returns the primary health category (first in list) or defaults to custom
  HealthCategory get healthCategory => 
      healthCategories?.isNotEmpty == true 
          ? healthCategories!.first 
          : HealthCategory.custom;

  int get estimatedDaysRemaining {
    // Only meaningful when stock is actually tracked (see [isLowStock]).
    if (!refillReminderEnabled || currentStock == null) return -1;
    // Average units consumed per day over a representative window, using the
    // schedule's real per-day slots. `schedule.times.length` alone was wrong for
    // everyXHours (interval fan-out) and for specificDays / everyXDays / cyclical
    // (off-days), over- or under-estimating the runway.
    const window = 28;
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    var slotCount = 0;
    for (var i = 0; i < window; i++) {
      slotCount += schedule.getScheduledTimesForDate(base.add(Duration(days: i))).length;
    }
    if (slotCount == 0) return -1;
    final unitsPerDay = (slotCount * dosageAmount) / window;
    if (unitsPerDay <= 0) return -1;
    return (currentStock! / unitsPerDay).floor();
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
    'route': route?.index,
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
    'healthCategories': healthCategories?.map((c) => c.index).toList(),
    'customHealthCategory': customHealthCategory,
    'patientProfileId': patientProfileId,
    'requiresContinuousIntake': requiresContinuousIntake,
    'minimumConsecutiveDays': minimumConsecutiveDays,
  };

  factory EnhancedMedicine.fromJson(Map<String, dynamic> json) => EnhancedMedicine(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    genericName: json['genericName'],
    brandName: json['brandName'],
    dosageForm: DosageForm.values[json['dosageForm'] ?? 0],
    route: json['route'] != null ? AdministrationRoute.values[json['route']] : null,
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
    healthCategories: (json['healthCategories'] as List?)?.map((i) => HealthCategory.values[i as int]).toList(),
    customHealthCategory: json['customHealthCategory'],
    patientProfileId: json['patientProfileId'],
    requiresContinuousIntake: json['requiresContinuousIntake'] ?? false,
    minimumConsecutiveDays: json['minimumConsecutiveDays'],
  );

  EnhancedMedicine copyWith({
    String? id,
    String? name,
    String? genericName,
    String? brandName,
    DosageForm? dosageForm,
    AdministrationRoute? route,
    // See clearDependentId's doc below — same reason: clearing an
    // already-set route back to "unset" needs a real clear, not a no-op.
    bool clearRoute = false,
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
    // The ordinary `dependentId` param above can only ever SET a non-null
    // owner (copyWith's usual `param ?? this.field` can't distinguish "not
    // passed" from "explicitly clear to null"). Reassigning a medicine back
    // to self after its dependent profile is deleted needs a real clear.
    bool clearDependentId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isArchived,
    String? notes,
    Map<String, dynamic>? customFields,
    List<HealthCategory>? healthCategories,
    String? customHealthCategory,
    String? patientProfileId,
    bool? requiresContinuousIntake,
    int? minimumConsecutiveDays,
  }) {
    return EnhancedMedicine(
      id: id ?? this.id,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      brandName: brandName ?? this.brandName,
      dosageForm: dosageForm ?? this.dosageForm,
      route: clearRoute ? null : (route ?? this.route),
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
      dependentId: clearDependentId ? null : (dependentId ?? this.dependentId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      notes: notes ?? this.notes,
      customFields: customFields ?? this.customFields,
      healthCategories: healthCategories ?? this.healthCategories,
      customHealthCategory: customHealthCategory ?? this.customHealthCategory,
      patientProfileId: patientProfileId ?? this.patientProfileId,
      requiresContinuousIntake: requiresContinuousIntake ?? this.requiresContinuousIntake,
      minimumConsecutiveDays: minimumConsecutiveDays ?? this.minimumConsecutiveDays,
    );
  }

  /// Reduce stock by the given amount. Uses ceil() so a fractional dose (e.g.
  /// half a tablet) still decrements the integer stock instead of truncating to
  /// 0 and never depleting.
  EnhancedMedicine reduceStock(double amount) {
    if (currentStock == null) return this;
    return copyWith(currentStock: (currentStock! - amount.ceil()).clamp(0, 999999));
  }

  /// Add stock (refill)
  EnhancedMedicine addStock(int amount) {
    final newStock = (currentStock ?? 0) + amount;
    return copyWith(
      currentStock: newStock,
      lastRefillDate: DateTime.now(),
    );
  }

  /// Puts back the units a dose removed (for Undo). Mirrors [reduceStock]'s
  /// `ceil()` so a taken-then-undone dose leaves stock unchanged. Not a refill,
  /// so it does not touch lastRefillDate.
  EnhancedMedicine restoreStock(double amount) {
    if (currentStock == null) return this;
    return copyWith(currentStock: (currentStock! + amount.ceil()).clamp(0, 999999));
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
class TreatmentCourse {
  final String id;
  final String name;
  final String? condition;
  final String? description;
  final List<String> medicineIds;
  final DateTime startDate;
  final DateTime? endDate;
  final String? doctorId;
  final String? notes;
  final bool isActive;
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
