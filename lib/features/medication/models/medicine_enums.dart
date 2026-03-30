/// Dosage form types - comprehensive list like Medisafe
enum DosageForm {
  tablet,
  capsule,
  syrup,
  injection,
  drops,
  cream,
  ointment,
  patch,
  inhaler,
  spray,
  powder,
  gel,
  suppository,
  lozenge,
  solution,
  suspension,
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
enum FrequencyType {
  onceDaily,
  twiceDaily,
  thriceDaily,
  fourTimesDaily,
  everyXHours,
  everyXDays,
  specificDays,
  asNeeded,
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
enum MealTiming {
  anytime,
  beforeMeal,
  withMeal,
  afterMeal,
  emptyStomach,
  beforeBed,
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
enum MedicineStatus {
  taken,
  skipped,
  missed,
  snoozed,
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
enum SkipReason {
  sideEffects,
  forgotToTake,
  ranOut,
  feelingBetter,
  doctorAdvised,
  tooExpensive,
  notNeeded,
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
enum InteractionSeverity {
  mild,
  moderate,
  severe,
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
enum MedicineColor {
  white,
  yellow,
  orange,
  pink,
  red,
  purple,
  blue,
  green,
  brown,
  black,
  gray,
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
enum MedicineShape {
  round,
  oval,
  capsule,
  rectangle,
  square,
  diamond,
  triangle,
  heart,
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

enum HealthCategory {
  heart,
  kidney,
  lungs,
  liver,
  brain,
  stomach,
  skin,
  eye,
  ear,
  bone,
  blood,
  diabetes,
  thyroid,
  mentalHealth,
  reproductive,
  immune,
  cancer,
  pain,
  infection,
  allergy,
  vitamin,
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
