// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enhanced_water_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EnhancedWaterLogAdapter extends TypeAdapter<EnhancedWaterLog> {
  @override
  final int typeId = 28;

  @override
  EnhancedWaterLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EnhancedWaterLog(
      id: fields[0] as String,
      time: fields[1] as DateTime,
      amountMl: fields[2] as int,
      effectiveHydrationMl: fields[3] as int,
      beverageId: fields[4] as String,
      beverageName: fields[5] as String,
      beverageEmoji: fields[6] as String,
      hydrationPercent: fields[7] as int,
      containerId: fields[8] as String?,
      containerName: fields[9] as String?,
      caffeineAmount: fields[10] as int,
      isAlcoholic: fields[11] as bool,
      note: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, EnhancedWaterLog obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.time)
      ..writeByte(2)
      ..write(obj.amountMl)
      ..writeByte(3)
      ..write(obj.effectiveHydrationMl)
      ..writeByte(4)
      ..write(obj.beverageId)
      ..writeByte(5)
      ..write(obj.beverageName)
      ..writeByte(6)
      ..write(obj.beverageEmoji)
      ..writeByte(7)
      ..write(obj.hydrationPercent)
      ..writeByte(8)
      ..write(obj.containerId)
      ..writeByte(9)
      ..write(obj.containerName)
      ..writeByte(10)
      ..write(obj.caffeineAmount)
      ..writeByte(11)
      ..write(obj.isAlcoholic)
      ..writeByte(12)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnhancedWaterLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyWaterDataAdapter extends TypeAdapter<DailyWaterData> {
  @override
  final int typeId = 29;

  @override
  DailyWaterData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyWaterData(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      dailyGoalMl: fields[2] as int,
      totalIntakeMl: fields[3] as int,
      effectiveHydrationMl: fields[4] as int,
      logs: (fields[5] as List?)?.cast<EnhancedWaterLog>(),
      totalCaffeineMg: fields[6] as int,
      alcoholicDrinksCount: fields[7] as int,
      goalReached: fields[8] as bool,
      goalReachedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyWaterData obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.dailyGoalMl)
      ..writeByte(3)
      ..write(obj.totalIntakeMl)
      ..writeByte(4)
      ..write(obj.effectiveHydrationMl)
      ..writeByte(5)
      ..write(obj.logs)
      ..writeByte(6)
      ..write(obj.totalCaffeineMg)
      ..writeByte(7)
      ..write(obj.alcoholicDrinksCount)
      ..writeByte(8)
      ..write(obj.goalReached)
      ..writeByte(9)
      ..write(obj.goalReachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyWaterDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
