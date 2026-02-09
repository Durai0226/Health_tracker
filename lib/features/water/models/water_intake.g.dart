// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'water_intake.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WaterIntakeAdapter extends TypeAdapter<WaterIntake> {
  @override
  final int typeId = 3;

  @override
  WaterIntake read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaterIntake(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      dailyGoalMl: fields[2] as int,
      currentIntakeMl: fields[3] as int,
      logs: (fields[4] as List?)?.cast<WaterLog>(),
    );
  }

  @override
  void write(BinaryWriter writer, WaterIntake obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.dailyGoalMl)
      ..writeByte(3)
      ..write(obj.currentIntakeMl)
      ..writeByte(4)
      ..write(obj.logs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterIntakeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WaterLogAdapter extends TypeAdapter<WaterLog> {
  @override
  final int typeId = 4;

  @override
  WaterLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaterLog(
      time: fields[0] as DateTime,
      amountMl: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WaterLog obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.time)
      ..writeByte(1)
      ..write(obj.amountMl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
