// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduledTimeAdapter extends TypeAdapter<ScheduledTime> {
  @override
  final int typeId = 58;

  @override
  ScheduledTime read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduledTime(
      hour: fields[0] as int,
      minute: fields[1] as int,
      label: fields[2] as String?,
      dosageAmount: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduledTime obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.hour)
      ..writeByte(1)
      ..write(obj.minute)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.dosageAmount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledTimeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicineScheduleAdapter extends TypeAdapter<MedicineSchedule> {
  @override
  final int typeId = 59;

  @override
  MedicineSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicineSchedule(
      frequencyType: fields[0] as FrequencyType,
      times: (fields[1] as List).cast<ScheduledTime>(),
      intervalHours: fields[2] as int?,
      intervalDays: fields[3] as int?,
      specificDays: (fields[4] as List?)?.cast<int>(),
      startDate: fields[5] as DateTime?,
      endDate: fields[6] as DateTime?,
      durationDays: fields[7] as int?,
      cycleDaysOn: fields[8] as int?,
      cycleDaysOff: fields[9] as int?,
      mealTiming: fields[10] as MealTiming,
      isPRN: fields[11] as bool,
      maxDailyDoses: fields[12] as int?,
      minHoursBetweenDoses: fields[13] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, MedicineSchedule obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.frequencyType)
      ..writeByte(1)
      ..write(obj.times)
      ..writeByte(2)
      ..write(obj.intervalHours)
      ..writeByte(3)
      ..write(obj.intervalDays)
      ..writeByte(4)
      ..write(obj.specificDays)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.endDate)
      ..writeByte(7)
      ..write(obj.durationDays)
      ..writeByte(8)
      ..write(obj.cycleDaysOn)
      ..writeByte(9)
      ..write(obj.cycleDaysOff)
      ..writeByte(10)
      ..write(obj.mealTiming)
      ..writeByte(11)
      ..write(obj.isPRN)
      ..writeByte(12)
      ..write(obj.maxDailyDoses)
      ..writeByte(13)
      ..write(obj.minHoursBetweenDoses);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
