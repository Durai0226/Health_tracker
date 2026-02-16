// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'water_reminder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WaterReminderAdapter extends TypeAdapter<WaterReminder> {
  @override
  final int typeId = 6;

  @override
  WaterReminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaterReminder(
      id: fields[0] as String,
      reminderTimes: (fields[1] as List).cast<DateTime>(),
      intervalMinutes: fields[2] as int,
      isEnabled: fields[3] as bool,
      startTime: fields[4] as DateTime?,
      endTime: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WaterReminder obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.reminderTimes)
      ..writeByte(2)
      ..write(obj.intervalMinutes)
      ..writeByte(3)
      ..write(obj.isEnabled)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
