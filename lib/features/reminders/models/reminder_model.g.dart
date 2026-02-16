// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderAdapter extends TypeAdapter<Reminder> {
  @override
  final int typeId = 201;

  @override
  Reminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Reminder(
      id: fields[0] as String,
      title: fields[1] as String,
      body: fields[2] as String,
      scheduledTime: fields[3] as DateTime,
      isCompleted: fields[4] as bool,
      createdAt: fields[5] as DateTime?,
      updatedAt: fields[6] as DateTime?,
      isSynced: fields[7] as bool,
      repeatType: fields[8] as RepeatType,
      customDays: (fields[9] as List?)?.cast<int>(),
      snoozeDuration: fields[10] as int?,
      sound: fields[11] as String?,
      priority: fields[12] as ReminderPriority,
      categoryId: fields[13] as String?,
      note: fields[14] as String?,
      imagePath: fields[15] as String?,
      noteId: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Reminder obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.scheduledTime)
      ..writeByte(4)
      ..write(obj.isCompleted)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.isSynced)
      ..writeByte(8)
      ..write(obj.repeatType)
      ..writeByte(9)
      ..write(obj.customDays)
      ..writeByte(10)
      ..write(obj.snoozeDuration)
      ..writeByte(11)
      ..write(obj.sound)
      ..writeByte(12)
      ..write(obj.priority)
      ..writeByte(13)
      ..write(obj.categoryId)
      ..writeByte(14)
      ..write(obj.note)
      ..writeByte(15)
      ..write(obj.imagePath)
      ..writeByte(16)
      ..write(obj.noteId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RepeatTypeAdapter extends TypeAdapter<RepeatType> {
  @override
  final int typeId = 202;

  @override
  RepeatType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepeatType.none;
      case 1:
        return RepeatType.daily;
      case 2:
        return RepeatType.weekly;
      case 3:
        return RepeatType.weekdays;
      case 4:
        return RepeatType.weekends;
      case 5:
        return RepeatType.custom;
      default:
        return RepeatType.none;
    }
  }

  @override
  void write(BinaryWriter writer, RepeatType obj) {
    switch (obj) {
      case RepeatType.none:
        writer.writeByte(0);
        break;
      case RepeatType.daily:
        writer.writeByte(1);
        break;
      case RepeatType.weekly:
        writer.writeByte(2);
        break;
      case RepeatType.weekdays:
        writer.writeByte(3);
        break;
      case RepeatType.weekends:
        writer.writeByte(4);
        break;
      case RepeatType.custom:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReminderPriorityAdapter extends TypeAdapter<ReminderPriority> {
  @override
  final int typeId = 203;

  @override
  ReminderPriority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReminderPriority.low;
      case 1:
        return ReminderPriority.medium;
      case 2:
        return ReminderPriority.high;
      default:
        return ReminderPriority.low;
    }
  }

  @override
  void write(BinaryWriter writer, ReminderPriority obj) {
    switch (obj) {
      case ReminderPriority.low:
        writer.writeByte(0);
        break;
      case ReminderPriority.medium:
        writer.writeByte(1);
        break;
      case ReminderPriority.high:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderPriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
