// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SleepSessionAdapter extends TypeAdapter<SleepSession> {
  @override
  final int typeId = 50;

  @override
  SleepSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepSession(
      id: fields[0] as String,
      bedTime: fields[1] as DateTime,
      wakeTime: fields[2] as DateTime,
      totalMinutes: fields[3] as int,
      deepSleepMinutes: fields[4] as int,
      lightSleepMinutes: fields[5] as int,
      remSleepMinutes: fields[6] as int,
      awakeMinutes: fields[7] as int,
      sleepScore: fields[8] as int,
      avgHeartRate: fields[9] as int?,
      lowestHeartRate: fields[10] as int?,
      respiratoryRate: fields[11] as int?,
      oxygenSaturation: fields[12] as double?,
      sleepLatencyMinutes: fields[13] as int?,
      awakenings: fields[14] as int,
      notes: fields[15] as String?,
      factors: (fields[16] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, SleepSession obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bedTime)
      ..writeByte(2)
      ..write(obj.wakeTime)
      ..writeByte(3)
      ..write(obj.totalMinutes)
      ..writeByte(4)
      ..write(obj.deepSleepMinutes)
      ..writeByte(5)
      ..write(obj.lightSleepMinutes)
      ..writeByte(6)
      ..write(obj.remSleepMinutes)
      ..writeByte(7)
      ..write(obj.awakeMinutes)
      ..writeByte(8)
      ..write(obj.sleepScore)
      ..writeByte(9)
      ..write(obj.avgHeartRate)
      ..writeByte(10)
      ..write(obj.lowestHeartRate)
      ..writeByte(11)
      ..write(obj.respiratoryRate)
      ..writeByte(12)
      ..write(obj.oxygenSaturation)
      ..writeByte(13)
      ..write(obj.sleepLatencyMinutes)
      ..writeByte(14)
      ..write(obj.awakenings)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.factors);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SleepGoalAdapter extends TypeAdapter<SleepGoal> {
  @override
  final int typeId = 51;

  @override
  SleepGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepGoal(
      targetHours: fields[0] as int,
      targetMinutes: fields[1] as int,
      targetBedTime: fields[2] as TimeOfDayModel,
      targetWakeTime: fields[3] as TimeOfDayModel,
      smartAlarmEnabled: fields[4] as bool,
      smartAlarmWindowMinutes: fields[5] as int,
      bedtimeReminderEnabled: fields[6] as bool,
      reminderMinutesBefore: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SleepGoal obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.targetHours)
      ..writeByte(1)
      ..write(obj.targetMinutes)
      ..writeByte(2)
      ..write(obj.targetBedTime)
      ..writeByte(3)
      ..write(obj.targetWakeTime)
      ..writeByte(4)
      ..write(obj.smartAlarmEnabled)
      ..writeByte(5)
      ..write(obj.smartAlarmWindowMinutes)
      ..writeByte(6)
      ..write(obj.bedtimeReminderEnabled)
      ..writeByte(7)
      ..write(obj.reminderMinutesBefore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimeOfDayModelAdapter extends TypeAdapter<TimeOfDayModel> {
  @override
  final int typeId = 52;

  @override
  TimeOfDayModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeOfDayModel(
      hour: fields[0] as int,
      minute: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TimeOfDayModel obj) {
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
      other is TimeOfDayModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SleepInsightAdapter extends TypeAdapter<SleepInsight> {
  @override
  final int typeId = 53;

  @override
  SleepInsight read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepInsight(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      category: fields[3] as String,
      priority: fields[4] as String,
      tips: (fields[5] as List).cast<String>(),
      generatedAt: fields[6] as DateTime,
      isRead: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SleepInsight obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.tips)
      ..writeByte(6)
      ..write(obj.generatedAt)
      ..writeByte(7)
      ..write(obj.isRead);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepInsightAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WellnessReportAdapter extends TypeAdapter<WellnessReport> {
  @override
  final int typeId = 54;

  @override
  WellnessReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WellnessReport(
      id: fields[0] as String,
      startDate: fields[1] as DateTime,
      endDate: fields[2] as DateTime,
      reportType: fields[3] as String,
      avgSleepScore: fields[4] as int,
      avgSleepDuration: fields[5] as int,
      avgRestingHr: fields[6] as int,
      avgStressLevel: fields[7] as int,
      avgActivityMinutes: fields[8] as int,
      avgSteps: fields[9] as int,
      avgHydration: fields[10] as double,
      trendsComparedToPrevious: (fields[11] as Map).cast<String, int>(),
      highlights: (fields[12] as List).cast<String>(),
      areasToImprove: (fields[13] as List).cast<String>(),
      overallWellnessScore: fields[14] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WellnessReport obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.endDate)
      ..writeByte(3)
      ..write(obj.reportType)
      ..writeByte(4)
      ..write(obj.avgSleepScore)
      ..writeByte(5)
      ..write(obj.avgSleepDuration)
      ..writeByte(6)
      ..write(obj.avgRestingHr)
      ..writeByte(7)
      ..write(obj.avgStressLevel)
      ..writeByte(8)
      ..write(obj.avgActivityMinutes)
      ..writeByte(9)
      ..write(obj.avgSteps)
      ..writeByte(10)
      ..write(obj.avgHydration)
      ..writeByte(11)
      ..write(obj.trendsComparedToPrevious)
      ..writeByte(12)
      ..write(obj.highlights)
      ..writeByte(13)
      ..write(obj.areasToImprove)
      ..writeByte(14)
      ..write(obj.overallWellnessScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WellnessReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
