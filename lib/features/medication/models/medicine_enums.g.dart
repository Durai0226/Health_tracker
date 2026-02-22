// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_enums.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DosageFormAdapter extends TypeAdapter<DosageForm> {
  @override
  final int typeId = 50;

  @override
  DosageForm read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DosageForm.tablet;
      case 1:
        return DosageForm.capsule;
      case 2:
        return DosageForm.syrup;
      case 3:
        return DosageForm.injection;
      case 4:
        return DosageForm.drops;
      case 5:
        return DosageForm.cream;
      case 6:
        return DosageForm.ointment;
      case 7:
        return DosageForm.patch;
      case 8:
        return DosageForm.inhaler;
      case 9:
        return DosageForm.spray;
      case 10:
        return DosageForm.powder;
      case 11:
        return DosageForm.gel;
      case 12:
        return DosageForm.suppository;
      case 13:
        return DosageForm.lozenge;
      case 14:
        return DosageForm.solution;
      case 15:
        return DosageForm.suspension;
      case 16:
        return DosageForm.other;
      default:
        return DosageForm.tablet;
    }
  }

  @override
  void write(BinaryWriter writer, DosageForm obj) {
    switch (obj) {
      case DosageForm.tablet:
        writer.writeByte(0);
        break;
      case DosageForm.capsule:
        writer.writeByte(1);
        break;
      case DosageForm.syrup:
        writer.writeByte(2);
        break;
      case DosageForm.injection:
        writer.writeByte(3);
        break;
      case DosageForm.drops:
        writer.writeByte(4);
        break;
      case DosageForm.cream:
        writer.writeByte(5);
        break;
      case DosageForm.ointment:
        writer.writeByte(6);
        break;
      case DosageForm.patch:
        writer.writeByte(7);
        break;
      case DosageForm.inhaler:
        writer.writeByte(8);
        break;
      case DosageForm.spray:
        writer.writeByte(9);
        break;
      case DosageForm.powder:
        writer.writeByte(10);
        break;
      case DosageForm.gel:
        writer.writeByte(11);
        break;
      case DosageForm.suppository:
        writer.writeByte(12);
        break;
      case DosageForm.lozenge:
        writer.writeByte(13);
        break;
      case DosageForm.solution:
        writer.writeByte(14);
        break;
      case DosageForm.suspension:
        writer.writeByte(15);
        break;
      case DosageForm.other:
        writer.writeByte(16);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DosageFormAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FrequencyTypeAdapter extends TypeAdapter<FrequencyType> {
  @override
  final int typeId = 51;

  @override
  FrequencyType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FrequencyType.onceDaily;
      case 1:
        return FrequencyType.twiceDaily;
      case 2:
        return FrequencyType.thriceDaily;
      case 3:
        return FrequencyType.fourTimesDaily;
      case 4:
        return FrequencyType.everyXHours;
      case 5:
        return FrequencyType.everyXDays;
      case 6:
        return FrequencyType.specificDays;
      case 7:
        return FrequencyType.asNeeded;
      case 8:
        return FrequencyType.cyclical;
      default:
        return FrequencyType.onceDaily;
    }
  }

  @override
  void write(BinaryWriter writer, FrequencyType obj) {
    switch (obj) {
      case FrequencyType.onceDaily:
        writer.writeByte(0);
        break;
      case FrequencyType.twiceDaily:
        writer.writeByte(1);
        break;
      case FrequencyType.thriceDaily:
        writer.writeByte(2);
        break;
      case FrequencyType.fourTimesDaily:
        writer.writeByte(3);
        break;
      case FrequencyType.everyXHours:
        writer.writeByte(4);
        break;
      case FrequencyType.everyXDays:
        writer.writeByte(5);
        break;
      case FrequencyType.specificDays:
        writer.writeByte(6);
        break;
      case FrequencyType.asNeeded:
        writer.writeByte(7);
        break;
      case FrequencyType.cyclical:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrequencyTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealTimingAdapter extends TypeAdapter<MealTiming> {
  @override
  final int typeId = 52;

  @override
  MealTiming read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MealTiming.anytime;
      case 1:
        return MealTiming.beforeMeal;
      case 2:
        return MealTiming.withMeal;
      case 3:
        return MealTiming.afterMeal;
      case 4:
        return MealTiming.emptyStomach;
      case 5:
        return MealTiming.beforeBed;
      case 6:
        return MealTiming.wakeUp;
      default:
        return MealTiming.anytime;
    }
  }

  @override
  void write(BinaryWriter writer, MealTiming obj) {
    switch (obj) {
      case MealTiming.anytime:
        writer.writeByte(0);
        break;
      case MealTiming.beforeMeal:
        writer.writeByte(1);
        break;
      case MealTiming.withMeal:
        writer.writeByte(2);
        break;
      case MealTiming.afterMeal:
        writer.writeByte(3);
        break;
      case MealTiming.emptyStomach:
        writer.writeByte(4);
        break;
      case MealTiming.beforeBed:
        writer.writeByte(5);
        break;
      case MealTiming.wakeUp:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealTimingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicineStatusAdapter extends TypeAdapter<MedicineStatus> {
  @override
  final int typeId = 53;

  @override
  MedicineStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MedicineStatus.taken;
      case 1:
        return MedicineStatus.skipped;
      case 2:
        return MedicineStatus.missed;
      case 3:
        return MedicineStatus.snoozed;
      case 4:
        return MedicineStatus.pending;
      default:
        return MedicineStatus.taken;
    }
  }

  @override
  void write(BinaryWriter writer, MedicineStatus obj) {
    switch (obj) {
      case MedicineStatus.taken:
        writer.writeByte(0);
        break;
      case MedicineStatus.skipped:
        writer.writeByte(1);
        break;
      case MedicineStatus.missed:
        writer.writeByte(2);
        break;
      case MedicineStatus.snoozed:
        writer.writeByte(3);
        break;
      case MedicineStatus.pending:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SkipReasonAdapter extends TypeAdapter<SkipReason> {
  @override
  final int typeId = 54;

  @override
  SkipReason read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SkipReason.sideEffects;
      case 1:
        return SkipReason.forgotToTake;
      case 2:
        return SkipReason.ranOut;
      case 3:
        return SkipReason.feelingBetter;
      case 4:
        return SkipReason.doctorAdvised;
      case 5:
        return SkipReason.tooExpensive;
      case 6:
        return SkipReason.notNeeded;
      case 7:
        return SkipReason.other;
      default:
        return SkipReason.sideEffects;
    }
  }

  @override
  void write(BinaryWriter writer, SkipReason obj) {
    switch (obj) {
      case SkipReason.sideEffects:
        writer.writeByte(0);
        break;
      case SkipReason.forgotToTake:
        writer.writeByte(1);
        break;
      case SkipReason.ranOut:
        writer.writeByte(2);
        break;
      case SkipReason.feelingBetter:
        writer.writeByte(3);
        break;
      case SkipReason.doctorAdvised:
        writer.writeByte(4);
        break;
      case SkipReason.tooExpensive:
        writer.writeByte(5);
        break;
      case SkipReason.notNeeded:
        writer.writeByte(6);
        break;
      case SkipReason.other:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkipReasonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InteractionSeverityAdapter extends TypeAdapter<InteractionSeverity> {
  @override
  final int typeId = 55;

  @override
  InteractionSeverity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return InteractionSeverity.mild;
      case 1:
        return InteractionSeverity.moderate;
      case 2:
        return InteractionSeverity.severe;
      case 3:
        return InteractionSeverity.contraindicated;
      default:
        return InteractionSeverity.mild;
    }
  }

  @override
  void write(BinaryWriter writer, InteractionSeverity obj) {
    switch (obj) {
      case InteractionSeverity.mild:
        writer.writeByte(0);
        break;
      case InteractionSeverity.moderate:
        writer.writeByte(1);
        break;
      case InteractionSeverity.severe:
        writer.writeByte(2);
        break;
      case InteractionSeverity.contraindicated:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InteractionSeverityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicineColorAdapter extends TypeAdapter<MedicineColor> {
  @override
  final int typeId = 56;

  @override
  MedicineColor read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MedicineColor.white;
      case 1:
        return MedicineColor.yellow;
      case 2:
        return MedicineColor.orange;
      case 3:
        return MedicineColor.pink;
      case 4:
        return MedicineColor.red;
      case 5:
        return MedicineColor.purple;
      case 6:
        return MedicineColor.blue;
      case 7:
        return MedicineColor.green;
      case 8:
        return MedicineColor.brown;
      case 9:
        return MedicineColor.black;
      case 10:
        return MedicineColor.gray;
      case 11:
        return MedicineColor.multicolor;
      default:
        return MedicineColor.white;
    }
  }

  @override
  void write(BinaryWriter writer, MedicineColor obj) {
    switch (obj) {
      case MedicineColor.white:
        writer.writeByte(0);
        break;
      case MedicineColor.yellow:
        writer.writeByte(1);
        break;
      case MedicineColor.orange:
        writer.writeByte(2);
        break;
      case MedicineColor.pink:
        writer.writeByte(3);
        break;
      case MedicineColor.red:
        writer.writeByte(4);
        break;
      case MedicineColor.purple:
        writer.writeByte(5);
        break;
      case MedicineColor.blue:
        writer.writeByte(6);
        break;
      case MedicineColor.green:
        writer.writeByte(7);
        break;
      case MedicineColor.brown:
        writer.writeByte(8);
        break;
      case MedicineColor.black:
        writer.writeByte(9);
        break;
      case MedicineColor.gray:
        writer.writeByte(10);
        break;
      case MedicineColor.multicolor:
        writer.writeByte(11);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineColorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicineShapeAdapter extends TypeAdapter<MedicineShape> {
  @override
  final int typeId = 57;

  @override
  MedicineShape read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MedicineShape.round;
      case 1:
        return MedicineShape.oval;
      case 2:
        return MedicineShape.capsule;
      case 3:
        return MedicineShape.rectangle;
      case 4:
        return MedicineShape.square;
      case 5:
        return MedicineShape.diamond;
      case 6:
        return MedicineShape.triangle;
      case 7:
        return MedicineShape.heart;
      case 8:
        return MedicineShape.other;
      default:
        return MedicineShape.round;
    }
  }

  @override
  void write(BinaryWriter writer, MedicineShape obj) {
    switch (obj) {
      case MedicineShape.round:
        writer.writeByte(0);
        break;
      case MedicineShape.oval:
        writer.writeByte(1);
        break;
      case MedicineShape.capsule:
        writer.writeByte(2);
        break;
      case MedicineShape.rectangle:
        writer.writeByte(3);
        break;
      case MedicineShape.square:
        writer.writeByte(4);
        break;
      case MedicineShape.diamond:
        writer.writeByte(5);
        break;
      case MedicineShape.triangle:
        writer.writeByte(6);
        break;
      case MedicineShape.heart:
        writer.writeByte(7);
        break;
      case MedicineShape.other:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineShapeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HealthCategoryAdapter extends TypeAdapter<HealthCategory> {
  @override
  final int typeId = 158;

  @override
  HealthCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HealthCategory.heart;
      case 1:
        return HealthCategory.kidney;
      case 2:
        return HealthCategory.lungs;
      case 3:
        return HealthCategory.liver;
      case 4:
        return HealthCategory.brain;
      case 5:
        return HealthCategory.stomach;
      case 6:
        return HealthCategory.skin;
      case 7:
        return HealthCategory.eye;
      case 8:
        return HealthCategory.ear;
      case 9:
        return HealthCategory.bone;
      case 10:
        return HealthCategory.blood;
      case 11:
        return HealthCategory.diabetes;
      case 12:
        return HealthCategory.thyroid;
      case 13:
        return HealthCategory.mentalHealth;
      case 14:
        return HealthCategory.reproductive;
      case 15:
        return HealthCategory.immune;
      case 16:
        return HealthCategory.cancer;
      case 17:
        return HealthCategory.pain;
      case 18:
        return HealthCategory.infection;
      case 19:
        return HealthCategory.allergy;
      case 20:
        return HealthCategory.vitamin;
      case 21:
        return HealthCategory.custom;
      default:
        return HealthCategory.heart;
    }
  }

  @override
  void write(BinaryWriter writer, HealthCategory obj) {
    switch (obj) {
      case HealthCategory.heart:
        writer.writeByte(0);
        break;
      case HealthCategory.kidney:
        writer.writeByte(1);
        break;
      case HealthCategory.lungs:
        writer.writeByte(2);
        break;
      case HealthCategory.liver:
        writer.writeByte(3);
        break;
      case HealthCategory.brain:
        writer.writeByte(4);
        break;
      case HealthCategory.stomach:
        writer.writeByte(5);
        break;
      case HealthCategory.skin:
        writer.writeByte(6);
        break;
      case HealthCategory.eye:
        writer.writeByte(7);
        break;
      case HealthCategory.ear:
        writer.writeByte(8);
        break;
      case HealthCategory.bone:
        writer.writeByte(9);
        break;
      case HealthCategory.blood:
        writer.writeByte(10);
        break;
      case HealthCategory.diabetes:
        writer.writeByte(11);
        break;
      case HealthCategory.thyroid:
        writer.writeByte(12);
        break;
      case HealthCategory.mentalHealth:
        writer.writeByte(13);
        break;
      case HealthCategory.reproductive:
        writer.writeByte(14);
        break;
      case HealthCategory.immune:
        writer.writeByte(15);
        break;
      case HealthCategory.cancer:
        writer.writeByte(16);
        break;
      case HealthCategory.pain:
        writer.writeByte(17);
        break;
      case HealthCategory.infection:
        writer.writeByte(18);
        break;
      case HealthCategory.allergy:
        writer.writeByte(19);
        break;
      case HealthCategory.vitamin:
        writer.writeByte(20);
        break;
      case HealthCategory.custom:
        writer.writeByte(21);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
