// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fitness_reminder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FitnessReminderAdapter extends TypeAdapter<FitnessReminder> {
  @override
  final int typeId = 5;

  @override
  FitnessReminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FitnessReminder(
      id: fields[0] as String,
      type: fields[1] as String,
      title: fields[2] as String,
      reminderTime: fields[3] as DateTime,
      frequency: fields[4] as String,
      durationMinutes: fields[5] as int,
      isEnabled: fields[6] as bool,
      customDays: (fields[7] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, FitnessReminder obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.durationMinutes)
      ..writeByte(6)
      ..write(obj.isEnabled)
      ..writeByte(7)
      ..write(obj.customDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitnessReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
