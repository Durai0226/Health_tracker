// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_check.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HealthCheckAdapter extends TypeAdapter<HealthCheck> {
  @override
  final int typeId = 2;

  @override
  HealthCheck read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HealthCheck(
      id: fields[0] as String,
      type: fields[1] as String,
      title: fields[2] as String,
      reminderTime: fields[3] as DateTime,
      frequency: fields[4] as String,
      enableReminder: fields[5] as bool,
      readings: (fields[6] as List?)?.cast<DateTime>(),
    );
  }

  @override
  void write(BinaryWriter writer, HealthCheck obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.reminderTime)
      ..writeByte(4)
      ..write(obj.frequency)
      ..writeByte(5)
      ..write(obj.enableReminder)
      ..writeByte(6)
      ..write(obj.readings);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthCheckAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
