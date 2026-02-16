// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HeartRateZoneAdapter extends TypeAdapter<HeartRateZone> {
  @override
  final int typeId = 30;

  @override
  HeartRateZone read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HeartRateZone(
      id: fields[0] as String,
      name: fields[1] as String,
      minBpm: fields[2] as int,
      maxBpm: fields[3] as int,
      color: fields[4] as String,
      description: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HeartRateZone obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.minBpm)
      ..writeByte(3)
      ..write(obj.maxBpm)
      ..writeByte(4)
      ..write(obj.color)
      ..writeByte(5)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeartRateZoneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RelativeEffortAdapter extends TypeAdapter<RelativeEffort> {
  @override
  final int typeId = 31;

  @override
  RelativeEffort read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RelativeEffort(
      activityId: fields[0] as String,
      score: fields[1] as int,
      durationSeconds: fields[2] as int,
      avgHeartRate: fields[3] as int,
      maxHeartRate: fields[4] as int,
      timeInZones: (fields[5] as Map).cast<String, int>(),
      calculatedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RelativeEffort obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.activityId)
      ..writeByte(1)
      ..write(obj.score)
      ..writeByte(2)
      ..write(obj.durationSeconds)
      ..writeByte(3)
      ..write(obj.avgHeartRate)
      ..writeByte(4)
      ..write(obj.maxHeartRate)
      ..writeByte(5)
      ..write(obj.timeInZones)
      ..writeByte(6)
      ..write(obj.calculatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelativeEffortAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PersonalRecordAdapter extends TypeAdapter<PersonalRecord> {
  @override
  final int typeId = 32;

  @override
  PersonalRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersonalRecord(
      id: fields[0] as String,
      activityType: fields[1] as String,
      recordType: fields[2] as String,
      distance: fields[3] as String,
      value: fields[4] as double,
      achievedAt: fields[5] as DateTime,
      activityId: fields[6] as String?,
      previousValue: fields[7] as double?,
      previousDate: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PersonalRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.activityType)
      ..writeByte(2)
      ..write(obj.recordType)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.value)
      ..writeByte(5)
      ..write(obj.achievedAt)
      ..writeByte(6)
      ..write(obj.activityId)
      ..writeByte(7)
      ..write(obj.previousValue)
      ..writeByte(8)
      ..write(obj.previousDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TrainingPlanAdapter extends TypeAdapter<TrainingPlan> {
  @override
  final int typeId = 33;

  @override
  TrainingPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrainingPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      activityType: fields[3] as String,
      goal: fields[4] as String,
      durationWeeks: fields[5] as int,
      weeks: (fields[6] as List).cast<TrainingWeek>(),
      startDate: fields[7] as DateTime,
      endDate: fields[8] as DateTime?,
      isActive: fields[9] as bool,
      currentWeek: fields[10] as int,
      difficulty: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TrainingPlan obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.activityType)
      ..writeByte(4)
      ..write(obj.goal)
      ..writeByte(5)
      ..write(obj.durationWeeks)
      ..writeByte(6)
      ..write(obj.weeks)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.endDate)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.currentWeek)
      ..writeByte(11)
      ..write(obj.difficulty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TrainingWeekAdapter extends TypeAdapter<TrainingWeek> {
  @override
  final int typeId = 34;

  @override
  TrainingWeek read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrainingWeek(
      weekNumber: fields[0] as int,
      focus: fields[1] as String,
      workouts: (fields[2] as List).cast<PlannedWorkout>(),
      notes: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TrainingWeek obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.weekNumber)
      ..writeByte(1)
      ..write(obj.focus)
      ..writeByte(2)
      ..write(obj.workouts)
      ..writeByte(3)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingWeekAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlannedWorkoutAdapter extends TypeAdapter<PlannedWorkout> {
  @override
  final int typeId = 35;

  @override
  PlannedWorkout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedWorkout(
      id: fields[0] as String,
      dayOfWeek: fields[1] as int,
      workoutType: fields[2] as String,
      description: fields[3] as String,
      targetDurationMinutes: fields[4] as int,
      targetDistanceKm: fields[5] as double?,
      targetPace: fields[6] as String?,
      targetHeartRateZone: fields[7] as String?,
      isCompleted: fields[8] as bool,
      completedActivityId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedWorkout obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dayOfWeek)
      ..writeByte(2)
      ..write(obj.workoutType)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.targetDurationMinutes)
      ..writeByte(5)
      ..write(obj.targetDistanceKm)
      ..writeByte(6)
      ..write(obj.targetPace)
      ..writeByte(7)
      ..write(obj.targetHeartRateZone)
      ..writeByte(8)
      ..write(obj.isCompleted)
      ..writeByte(9)
      ..write(obj.completedActivityId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedWorkoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReadinessScoreAdapter extends TypeAdapter<ReadinessScore> {
  @override
  final int typeId = 36;

  @override
  ReadinessScore read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadinessScore(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      overallScore: fields[2] as int,
      sleepScore: fields[3] as int,
      recoveryScore: fields[4] as int,
      activityBalance: fields[5] as int,
      hrvStatus: fields[6] as int,
      restingHr: fields[7] as int,
      recommendation: fields[8] as String,
      suggestedWorkoutIntensity: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ReadinessScore obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.overallScore)
      ..writeByte(3)
      ..write(obj.sleepScore)
      ..writeByte(4)
      ..write(obj.recoveryScore)
      ..writeByte(5)
      ..write(obj.activityBalance)
      ..writeByte(6)
      ..write(obj.hrvStatus)
      ..writeByte(7)
      ..write(obj.restingHr)
      ..writeByte(8)
      ..write(obj.recommendation)
      ..writeByte(9)
      ..write(obj.suggestedWorkoutIntensity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadinessScoreAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutAnalysisAdapter extends TypeAdapter<WorkoutAnalysis> {
  @override
  final int typeId = 37;

  @override
  WorkoutAnalysis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutAnalysis(
      activityId: fields[0] as String,
      splits: (fields[1] as List).cast<Split>(),
      averagePower: fields[2] as double?,
      normalizedPower: fields[3] as double?,
      intensityFactor: fields[4] as double?,
      trainingStressScore: fields[5] as int?,
      gradeAdjustedPace: fields[6] as double?,
      averageCadence: fields[7] as double?,
      verticalOscillation: fields[8] as double?,
      groundContactTime: fields[9] as double?,
      elevationGain: fields[10] as int?,
      elevationLoss: fields[11] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutAnalysis obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.activityId)
      ..writeByte(1)
      ..write(obj.splits)
      ..writeByte(2)
      ..write(obj.averagePower)
      ..writeByte(3)
      ..write(obj.normalizedPower)
      ..writeByte(4)
      ..write(obj.intensityFactor)
      ..writeByte(5)
      ..write(obj.trainingStressScore)
      ..writeByte(6)
      ..write(obj.gradeAdjustedPace)
      ..writeByte(7)
      ..write(obj.averageCadence)
      ..writeByte(8)
      ..write(obj.verticalOscillation)
      ..writeByte(9)
      ..write(obj.groundContactTime)
      ..writeByte(10)
      ..write(obj.elevationGain)
      ..writeByte(11)
      ..write(obj.elevationLoss);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutAnalysisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SplitAdapter extends TypeAdapter<Split> {
  @override
  final int typeId = 38;

  @override
  Split read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Split(
      splitNumber: fields[0] as int,
      distanceKm: fields[1] as double,
      durationSeconds: fields[2] as int,
      pace: fields[3] as double,
      avgHeartRate: fields[4] as int?,
      elevationChange: fields[5] as int?,
      power: fields[6] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Split obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.splitNumber)
      ..writeByte(1)
      ..write(obj.distanceKm)
      ..writeByte(2)
      ..write(obj.durationSeconds)
      ..writeByte(3)
      ..write(obj.pace)
      ..writeByte(4)
      ..write(obj.avgHeartRate)
      ..writeByte(5)
      ..write(obj.elevationChange)
      ..writeByte(6)
      ..write(obj.power);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
