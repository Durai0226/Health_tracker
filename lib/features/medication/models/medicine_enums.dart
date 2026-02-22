import 'package:hive/hive.dart';

part 'medicine_enums.g.dart';

/// Dosage form types - comprehensive list like Medisafe
@HiveType(typeId: 50)
enum DosageForm {
  @HiveField(0)
  tablet,
  @HiveField(1)
  capsule,
  @HiveField(2)
  syrup,
  @HiveField(3)
  injection,
  @HiveField(4)
  drops,
  @HiveField(5)
  cream,
  @HiveField(6)
  ointment,
  @HiveField(7)
  patch,
  @HiveField(8)
  inhaler,
  @HiveField(9)
  spray,
  @HiveField(10)
  powder,
  @HiveField(11)
  gel,
  @HiveField(12)
  suppository,
  @HiveField(13)
  lozenge,
  @HiveField(14)
  solution,
  @HiveField(15)
  suspension,
  @HiveField(16)
  other;

  String get displayName {
    switch (this) {
      case DosageForm.tablet:
        return 'Tablet';
      case DosageForm.capsule:
        return 'Capsule';
      case DosageForm.syrup:
        return 'Syrup';
      case DosageForm.injection:
        return 'Injection';
      case DosageForm.drops:
        return 'Drops';
      case DosageForm.cream:
        return 'Cream';
      case DosageForm.ointment:
        return 'Ointment';
      case DosageForm.patch:
        return 'Patch';
      case DosageForm.inhaler:
        return 'Inhaler';
      case DosageForm.spray:
        return 'Spray';
      case DosageForm.powder:
        return 'Powder';
      case DosageForm.gel:
        return 'Gel';
      case DosageForm.suppository:
        return 'Suppository';
      case DosageForm.lozenge:
        return 'Lozenge';
      case DosageForm.solution:
        return 'Solution';
      case DosageForm.suspension:
        return 'Suspension';
      case DosageForm.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case DosageForm.tablet:
        return '💊';
      case DosageForm.capsule:
        return '💊';
      case DosageForm.syrup:
        return '🧴';
      case DosageForm.injection:
        return '💉';
      case DosageForm.drops:
        return '💧';
      case DosageForm.cream:
      case DosageForm.ointment:
      case DosageForm.gel:
        return '🧴';
      case DosageForm.patch:
        return '🩹';
      case DosageForm.inhaler:
        return '🌬️';
      case DosageForm.spray:
        return '💨';
      case DosageForm.powder:
        return '🧂';
      case DosageForm.suppository:
        return '💊';
      case DosageForm.lozenge:
        return '🍬';
      case DosageForm.solution:
      case DosageForm.suspension:
        return '🧪';
      case DosageForm.other:
        return '💊';
    }
  }

  String get unit {
    switch (this) {
      case DosageForm.tablet:
      case DosageForm.capsule:
      case DosageForm.lozenge:
        return 'pill(s)';
      case DosageForm.syrup:
      case DosageForm.solution:
      case DosageForm.suspension:
        return 'ml';
      case DosageForm.injection:
        return 'unit(s)';
      case DosageForm.drops:
        return 'drop(s)';
      case DosageForm.cream:
      case DosageForm.ointment:
      case DosageForm.gel:
        return 'application(s)';
      case DosageForm.patch:
        return 'patch(es)';
      case DosageForm.inhaler:
        return 'puff(s)';
      case DosageForm.spray:
        return 'spray(s)';
      case DosageForm.powder:
        return 'sachet(s)';
      case DosageForm.suppository:
        return 'unit(s)';
      case DosageForm.other:
        return 'dose(s)';
    }
  }
}

/// Frequency types for medication scheduling
@HiveType(typeId: 51)
enum FrequencyType {
  @HiveField(0)
  onceDaily,
  @HiveField(1)
  twiceDaily,
  @HiveField(2)
  thriceDaily,
  @HiveField(3)
  fourTimesDaily,
  @HiveField(4)
  everyXHours,
  @HiveField(5)
  everyXDays,
  @HiveField(6)
  specificDays,
  @HiveField(7)
  asNeeded,
  @HiveField(8)
  cyclical;

  String get displayName {
    switch (this) {
      case FrequencyType.onceDaily:
        return 'Once a day';
      case FrequencyType.twiceDaily:
        return 'Twice a day';
      case FrequencyType.thriceDaily:
        return '3 times a day';
      case FrequencyType.fourTimesDaily:
        return '4 times a day';
      case FrequencyType.everyXHours:
        return 'Every X hours';
      case FrequencyType.everyXDays:
        return 'Every X days';
      case FrequencyType.specificDays:
        return 'Specific days';
      case FrequencyType.asNeeded:
        return 'As needed (PRN)';
      case FrequencyType.cyclical:
        return 'Cyclical';
    }
  }
}

/// Meal timing instructions
@HiveType(typeId: 52)
enum MealTiming {
  @HiveField(0)
  anytime,
  @HiveField(1)
  beforeMeal,
  @HiveField(2)
  withMeal,
  @HiveField(3)
  afterMeal,
  @HiveField(4)
  emptyStomach,
  @HiveField(5)
  beforeBed,
  @HiveField(6)
  wakeUp;

  String get displayName {
    switch (this) {
      case MealTiming.anytime:
        return 'Anytime';
      case MealTiming.beforeMeal:
        return 'Before meals';
      case MealTiming.withMeal:
        return 'With meals';
      case MealTiming.afterMeal:
        return 'After meals';
      case MealTiming.emptyStomach:
        return 'Empty stomach';
      case MealTiming.beforeBed:
        return 'Before bed';
      case MealTiming.wakeUp:
        return 'When waking up';
    }
  }

  String get icon {
    switch (this) {
      case MealTiming.anytime:
        return '⏰';
      case MealTiming.beforeMeal:
        return '🍽️';
      case MealTiming.withMeal:
        return '🍴';
      case MealTiming.afterMeal:
        return '✅';
      case MealTiming.emptyStomach:
        return '💨';
      case MealTiming.beforeBed:
        return '🌙';
      case MealTiming.wakeUp:
        return '☀️';
    }
  }
}

/// Medicine status for log entries
@HiveType(typeId: 53)
enum MedicineStatus {
  @HiveField(0)
  taken,
  @HiveField(1)
  skipped,
  @HiveField(2)
  missed,
  @HiveField(3)
  snoozed,
  @HiveField(4)
  pending;

  String get displayName {
    switch (this) {
      case MedicineStatus.taken:
        return 'Taken';
      case MedicineStatus.skipped:
        return 'Skipped';
      case MedicineStatus.missed:
        return 'Missed';
      case MedicineStatus.snoozed:
        return 'Snoozed';
      case MedicineStatus.pending:
        return 'Pending';
    }
  }
}

/// Skip reasons for tracking missed doses
@HiveType(typeId: 54)
enum SkipReason {
  @HiveField(0)
  sideEffects,
  @HiveField(1)
  forgotToTake,
  @HiveField(2)
  ranOut,
  @HiveField(3)
  feelingBetter,
  @HiveField(4)
  doctorAdvised,
  @HiveField(5)
  tooExpensive,
  @HiveField(6)
  notNeeded,
  @HiveField(7)
  other;

  String get displayName {
    switch (this) {
      case SkipReason.sideEffects:
        return 'Side effects';
      case SkipReason.forgotToTake:
        return 'Forgot to take';
      case SkipReason.ranOut:
        return 'Ran out of medicine';
      case SkipReason.feelingBetter:
        return 'Feeling better';
      case SkipReason.doctorAdvised:
        return 'Doctor advised';
      case SkipReason.tooExpensive:
        return 'Too expensive';
      case SkipReason.notNeeded:
        return 'Didn\'t need it';
      case SkipReason.other:
        return 'Other reason';
    }
  }
}

/// Drug interaction severity levels
@HiveType(typeId: 55)
enum InteractionSeverity {
  @HiveField(0)
  mild,
  @HiveField(1)
  moderate,
  @HiveField(2)
  severe,
  @HiveField(3)
  contraindicated;

  String get displayName {
    switch (this) {
      case InteractionSeverity.mild:
        return 'Mild';
      case InteractionSeverity.moderate:
        return 'Moderate';
      case InteractionSeverity.severe:
        return 'Severe';
      case InteractionSeverity.contraindicated:
        return 'Contraindicated';
    }
  }

  String get description {
    switch (this) {
      case InteractionSeverity.mild:
        return 'Minor interaction, usually safe';
      case InteractionSeverity.moderate:
        return 'May cause problems, consult doctor';
      case InteractionSeverity.severe:
        return 'Significant risk, avoid combination';
      case InteractionSeverity.contraindicated:
        return 'Do not take together';
    }
  }
}

/// Medicine color for pill identification
@HiveType(typeId: 56)
enum MedicineColor {
  @HiveField(0)
  white,
  @HiveField(1)
  yellow,
  @HiveField(2)
  orange,
  @HiveField(3)
  pink,
  @HiveField(4)
  red,
  @HiveField(5)
  purple,
  @HiveField(6)
  blue,
  @HiveField(7)
  green,
  @HiveField(8)
  brown,
  @HiveField(9)
  black,
  @HiveField(10)
  gray,
  @HiveField(11)
  multicolor;

  String get displayName {
    switch (this) {
      case MedicineColor.white:
        return 'White';
      case MedicineColor.yellow:
        return 'Yellow';
      case MedicineColor.orange:
        return 'Orange';
      case MedicineColor.pink:
        return 'Pink';
      case MedicineColor.red:
        return 'Red';
      case MedicineColor.purple:
        return 'Purple';
      case MedicineColor.blue:
        return 'Blue';
      case MedicineColor.green:
        return 'Green';
      case MedicineColor.brown:
        return 'Brown';
      case MedicineColor.black:
        return 'Black';
      case MedicineColor.gray:
        return 'Gray';
      case MedicineColor.multicolor:
        return 'Multicolor';
    }
  }

  int get colorValue {
    switch (this) {
      case MedicineColor.white:
        return 0xFFFFFFFF;
      case MedicineColor.yellow:
        return 0xFFFFEB3B;
      case MedicineColor.orange:
        return 0xFFFF9800;
      case MedicineColor.pink:
        return 0xFFE91E63;
      case MedicineColor.red:
        return 0xFFF44336;
      case MedicineColor.purple:
        return 0xFF9C27B0;
      case MedicineColor.blue:
        return 0xFF2196F3;
      case MedicineColor.green:
        return 0xFF4CAF50;
      case MedicineColor.brown:
        return 0xFF795548;
      case MedicineColor.black:
        return 0xFF212121;
      case MedicineColor.gray:
        return 0xFF9E9E9E;
      case MedicineColor.multicolor:
        return 0xFFE0E0E0;
    }
  }
}

/// Medicine shape for pill identification
@HiveType(typeId: 57)
enum MedicineShape {
  @HiveField(0)
  round,
  @HiveField(1)
  oval,
  @HiveField(2)
  capsule,
  @HiveField(3)
  rectangle,
  @HiveField(4)
  square,
  @HiveField(5)
  diamond,
  @HiveField(6)
  triangle,
  @HiveField(7)
  heart,
  @HiveField(8)
  other;

  String get displayName {
    switch (this) {
      case MedicineShape.round:
        return 'Round';
      case MedicineShape.oval:
        return 'Oval';
      case MedicineShape.capsule:
        return 'Capsule';
      case MedicineShape.rectangle:
        return 'Rectangle';
      case MedicineShape.square:
        return 'Square';
      case MedicineShape.diamond:
        return 'Diamond';
      case MedicineShape.triangle:
        return 'Triangle';
      case MedicineShape.heart:
        return 'Heart';
      case MedicineShape.other:
        return 'Other';
    }
  }
}

@HiveType(typeId: 158)
enum HealthCategory {
  @HiveField(0)
  heart,
  @HiveField(1)
  kidney,
  @HiveField(2)
  lungs,
  @HiveField(3)
  liver,
  @HiveField(4)
  brain,
  @HiveField(5)
  stomach,
  @HiveField(6)
  skin,
  @HiveField(7)
  eye,
  @HiveField(8)
  ear,
  @HiveField(9)
  bone,
  @HiveField(10)
  blood,
  @HiveField(11)
  diabetes,
  @HiveField(12)
  thyroid,
  @HiveField(13)
  mentalHealth,
  @HiveField(14)
  reproductive,
  @HiveField(15)
  immune,
  @HiveField(16)
  cancer,
  @HiveField(17)
  pain,
  @HiveField(18)
  infection,
  @HiveField(19)
  allergy,
  @HiveField(20)
  vitamin,
  @HiveField(21)
  custom;

  String get displayName {
    switch (this) {
      case HealthCategory.heart:
        return 'Heart & Cardiovascular';
      case HealthCategory.kidney:
        return 'Kidney & Urinary';
      case HealthCategory.lungs:
        return 'Lungs & Respiratory';
      case HealthCategory.liver:
        return 'Liver & Digestive';
      case HealthCategory.brain:
        return 'Brain & Neurological';
      case HealthCategory.stomach:
        return 'Stomach & Gastrointestinal';
      case HealthCategory.skin:
        return 'Skin & Dermatology';
      case HealthCategory.eye:
        return 'Eye & Vision';
      case HealthCategory.ear:
        return 'Ear & Hearing';
      case HealthCategory.bone:
        return 'Bone & Joints';
      case HealthCategory.blood:
        return 'Blood & Circulation';
      case HealthCategory.diabetes:
        return 'Diabetes';
      case HealthCategory.thyroid:
        return 'Thyroid & Endocrine';
      case HealthCategory.mentalHealth:
        return 'Mental Health';
      case HealthCategory.reproductive:
        return 'Reproductive Health';
      case HealthCategory.immune:
        return 'Immune System';
      case HealthCategory.cancer:
        return 'Cancer Treatment';
      case HealthCategory.pain:
        return 'Pain Management';
      case HealthCategory.infection:
        return 'Infection & Antibiotics';
      case HealthCategory.allergy:
        return 'Allergy';
      case HealthCategory.vitamin:
        return 'Vitamins & Supplements';
      case HealthCategory.custom:
        return 'Custom Category';
    }
  }

  String get icon {
    switch (this) {
      case HealthCategory.heart:
        return '❤️';
      case HealthCategory.kidney:
        return '🫘';
      case HealthCategory.lungs:
        return '🫁';
      case HealthCategory.liver:
        return '🫀';
      case HealthCategory.brain:
        return '🧠';
      case HealthCategory.stomach:
        return '🫃';
      case HealthCategory.skin:
        return '🧴';
      case HealthCategory.eye:
        return '👁️';
      case HealthCategory.ear:
        return '👂';
      case HealthCategory.bone:
        return '🦴';
      case HealthCategory.blood:
        return '🩸';
      case HealthCategory.diabetes:
        return '💉';
      case HealthCategory.thyroid:
        return '🦋';
      case HealthCategory.mentalHealth:
        return '🧘';
      case HealthCategory.reproductive:
        return '🌸';
      case HealthCategory.immune:
        return '🛡️';
      case HealthCategory.cancer:
        return '🎗️';
      case HealthCategory.pain:
        return '💊';
      case HealthCategory.infection:
        return '🦠';
      case HealthCategory.allergy:
        return '🤧';
      case HealthCategory.vitamin:
        return '💪';
      case HealthCategory.custom:
        return '📋';
    }
  }
}
