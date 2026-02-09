// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PeriodDataAdapter extends TypeAdapter<PeriodData> {
  @override
  final int typeId = 1;

  @override
  PeriodData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PeriodData(
      lastPeriodDate: fields[0] as DateTime,
      cycleLength: fields[1] as int,
      periodDuration: fields[2] as int,
      isEnabled: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PeriodData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.lastPeriodDate)
      ..writeByte(1)
      ..write(obj.cycleLength)
      ..writeByte(2)
      ..write(obj.periodDuration)
      ..writeByte(3)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
