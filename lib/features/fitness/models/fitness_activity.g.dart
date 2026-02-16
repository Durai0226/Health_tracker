// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fitness_activity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FitnessActivityAdapter extends TypeAdapter<FitnessActivity> {
  @override
  final int typeId = 25;

  @override
  FitnessActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FitnessActivity(
      id: fields[0] as String,
      type: fields[1] as String,
      title: fields[2] as String,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime?,
      durationMinutes: fields[5] as int,
      caloriesBurned: fields[6] as int?,
      distanceKm: fields[7] as double?,
      steps: fields[8] as int?,
      heartRateAvg: fields[9] as int?,
      notes: fields[10] as String?,
      isCompleted: fields[11] as bool,
      reminderId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FitnessActivity obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.durationMinutes)
      ..writeByte(6)
      ..write(obj.caloriesBurned)
      ..writeByte(7)
      ..write(obj.distanceKm)
      ..writeByte(8)
      ..write(obj.steps)
      ..writeByte(9)
      ..write(obj.heartRateAvg)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.isCompleted)
      ..writeByte(12)
      ..write(obj.reminderId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitnessActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FitnessGoalAdapter extends TypeAdapter<FitnessGoal> {
  @override
  final int typeId = 26;

  @override
  FitnessGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FitnessGoal(
      weeklyWorkoutTarget: fields[0] as int,
      weeklyMinutesTarget: fields[1] as int,
      weeklyCaloriesTarget: fields[2] as int,
      dailyStepsTarget: fields[3] as int,
      preferredActivities: (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, FitnessGoal obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.weeklyWorkoutTarget)
      ..writeByte(1)
      ..write(obj.weeklyMinutesTarget)
      ..writeByte(2)
      ..write(obj.weeklyCaloriesTarget)
      ..writeByte(3)
      ..write(obj.dailyStepsTarget)
      ..writeByte(4)
      ..write(obj.preferredActivities);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitnessGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
