// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advanced_water_reminder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdvancedWaterReminderAdapter extends TypeAdapter<AdvancedWaterReminder> {
  @override
  final int typeId = 37;

  @override
  AdvancedWaterReminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdvancedWaterReminder(
      id: fields[0] as String,
      isEnabled: fields[1] as bool,
      daySchedules: (fields[2] as List?)?.cast<DaySchedule>(),
      sound: fields[3] as ReminderSound,
      vibrationEnabled: fields[4] as bool,
      smartReminders: fields[5] as bool,
      skipIfGoalMet: fields[6] as bool,
      snoozeMinutes: fields[7] as int,
      customMessage: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AdvancedWaterReminder obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.isEnabled)
      ..writeByte(2)
      ..write(obj.daySchedules)
      ..writeByte(3)
      ..write(obj.sound)
      ..writeByte(4)
      ..write(obj.vibrationEnabled)
      ..writeByte(5)
      ..write(obj.smartReminders)
      ..writeByte(6)
      ..write(obj.skipIfGoalMet)
      ..writeByte(7)
      ..write(obj.snoozeMinutes)
      ..writeByte(8)
      ..write(obj.customMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedWaterReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DayScheduleAdapter extends TypeAdapter<DaySchedule> {
  @override
  final int typeId = 38;

  @override
  DaySchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DaySchedule(
      day: fields[0] as DayOfWeek,
      isEnabled: fields[1] as bool,
      startHour: fields[2] as int,
      startMinute: fields[3] as int,
      endHour: fields[4] as int,
      endMinute: fields[5] as int,
      intervalMinutes: fields[6] as int,
      customTimes: (fields[7] as List?)?.cast<TimeSlot>(),
    );
  }

  @override
  void write(BinaryWriter writer, DaySchedule obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.day)
      ..writeByte(1)
      ..write(obj.isEnabled)
      ..writeByte(2)
      ..write(obj.startHour)
      ..writeByte(3)
      ..write(obj.startMinute)
      ..writeByte(4)
      ..write(obj.endHour)
      ..writeByte(5)
      ..write(obj.endMinute)
      ..writeByte(6)
      ..write(obj.intervalMinutes)
      ..writeByte(7)
      ..write(obj.customTimes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimeSlotAdapter extends TypeAdapter<TimeSlot> {
  @override
  final int typeId = 39;

  @override
  TimeSlot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeSlot(
      hour: fields[0] as int,
      minute: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TimeSlot obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.hour)
      ..writeByte(1)
      ..write(obj.minute);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DayOfWeekAdapter extends TypeAdapter<DayOfWeek> {
  @override
  final int typeId = 35;

  @override
  DayOfWeek read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DayOfWeek.monday;
      case 1:
        return DayOfWeek.tuesday;
      case 2:
        return DayOfWeek.wednesday;
      case 3:
        return DayOfWeek.thursday;
      case 4:
        return DayOfWeek.friday;
      case 5:
        return DayOfWeek.saturday;
      case 6:
        return DayOfWeek.sunday;
      default:
        return DayOfWeek.monday;
    }
  }

  @override
  void write(BinaryWriter writer, DayOfWeek obj) {
    switch (obj) {
      case DayOfWeek.monday:
        writer.writeByte(0);
        break;
      case DayOfWeek.tuesday:
        writer.writeByte(1);
        break;
      case DayOfWeek.wednesday:
        writer.writeByte(2);
        break;
      case DayOfWeek.thursday:
        writer.writeByte(3);
        break;
      case DayOfWeek.friday:
        writer.writeByte(4);
        break;
      case DayOfWeek.saturday:
        writer.writeByte(5);
        break;
      case DayOfWeek.sunday:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayOfWeekAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReminderSoundAdapter extends TypeAdapter<ReminderSound> {
  @override
  final int typeId = 36;

  @override
  ReminderSound read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReminderSound.defaultSound;
      case 1:
        return ReminderSound.waterDrop;
      case 2:
        return ReminderSound.gentle;
      case 3:
        return ReminderSound.chime;
      case 4:
        return ReminderSound.none;
      default:
        return ReminderSound.defaultSound;
    }
  }

  @override
  void write(BinaryWriter writer, ReminderSound obj) {
    switch (obj) {
      case ReminderSound.defaultSound:
        writer.writeByte(0);
        break;
      case ReminderSound.waterDrop:
        writer.writeByte(1);
        break;
      case ReminderSound.gentle:
        writer.writeByte(2);
        break;
      case ReminderSound.chime:
        writer.writeByte(3);
        break;
      case ReminderSound.none:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSoundAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
