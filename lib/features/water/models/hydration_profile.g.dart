// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hydration_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HydrationProfileAdapter extends TypeAdapter<HydrationProfile> {
  @override
  final int typeId = 24;

  @override
  HydrationProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HydrationProfile(
      id: fields[0] as String,
      weightKg: fields[1] as double?,
      heightCm: fields[2] as int?,
      age: fields[3] as int?,
      isMale: fields[4] as bool,
      activityLevel: fields[5] as ActivityLevel,
      climate: fields[6] as ClimateType,
      isPregnant: fields[7] as bool,
      isBreastfeeding: fields[8] as bool,
      customGoalMl: fields[9] as int,
      useCustomGoal: fields[10] as bool,
      createdAt: fields[11] as DateTime?,
      updatedAt: fields[12] as DateTime?,
      wakeUpReminderEnabled: fields[13] as bool,
      wakeUpHour: fields[14] as int?,
      bedtimeHour: fields[15] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HydrationProfile obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.weightKg)
      ..writeByte(2)
      ..write(obj.heightCm)
      ..writeByte(3)
      ..write(obj.age)
      ..writeByte(4)
      ..write(obj.isMale)
      ..writeByte(5)
      ..write(obj.activityLevel)
      ..writeByte(6)
      ..write(obj.climate)
      ..writeByte(7)
      ..write(obj.isPregnant)
      ..writeByte(8)
      ..write(obj.isBreastfeeding)
      ..writeByte(9)
      ..write(obj.customGoalMl)
      ..writeByte(10)
      ..write(obj.useCustomGoal)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.wakeUpReminderEnabled)
      ..writeByte(14)
      ..write(obj.wakeUpHour)
      ..writeByte(15)
      ..write(obj.bedtimeHour);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydrationProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ActivityLevelAdapter extends TypeAdapter<ActivityLevel> {
  @override
  final int typeId = 22;

  @override
  ActivityLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ActivityLevel.sedentary;
      case 1:
        return ActivityLevel.light;
      case 2:
        return ActivityLevel.moderate;
      case 3:
        return ActivityLevel.active;
      case 4:
        return ActivityLevel.veryActive;
      default:
        return ActivityLevel.sedentary;
    }
  }

  @override
  void write(BinaryWriter writer, ActivityLevel obj) {
    switch (obj) {
      case ActivityLevel.sedentary:
        writer.writeByte(0);
        break;
      case ActivityLevel.light:
        writer.writeByte(1);
        break;
      case ActivityLevel.moderate:
        writer.writeByte(2);
        break;
      case ActivityLevel.active:
        writer.writeByte(3);
        break;
      case ActivityLevel.veryActive:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ClimateTypeAdapter extends TypeAdapter<ClimateType> {
  @override
  final int typeId = 23;

  @override
  ClimateType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ClimateType.cold;
      case 1:
        return ClimateType.moderate;
      case 2:
        return ClimateType.warm;
      case 3:
        return ClimateType.hot;
      case 4:
        return ClimateType.veryHot;
      default:
        return ClimateType.cold;
    }
  }

  @override
  void write(BinaryWriter writer, ClimateType obj) {
    switch (obj) {
      case ClimateType.cold:
        writer.writeByte(0);
        break;
      case ClimateType.moderate:
        writer.writeByte(1);
        break;
      case ClimateType.warm:
        writer.writeByte(2);
        break;
      case ClimateType.hot:
        writer.writeByte(3);
        break;
      case ClimateType.veryHot:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClimateTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
