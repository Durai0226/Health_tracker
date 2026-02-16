// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_reminder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PeriodReminderAdapter extends TypeAdapter<PeriodReminder> {
  @override
  final int typeId = 7;

  @override
  PeriodReminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PeriodReminder(
      id: fields[0] as String,
      daysBefore: fields[1] as int,
      reminderTime: fields[2] as DateTime,
      isEnabled: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PeriodReminder obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.daysBefore)
      ..writeByte(2)
      ..write(obj.reminderTime)
      ..writeByte(3)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
