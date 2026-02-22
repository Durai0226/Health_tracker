// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_analytics_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyStudyStatsAdapter extends TypeAdapter<DailyStudyStats> {
  @override
  final int typeId = 270;

  @override
  DailyStudyStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyStudyStats(
      date: fields[0] as DateTime,
      totalMinutes: fields[1] as int,
      sessionCount: fields[2] as int,
      pomodoroCount: fields[3] as int,
      minutesBySubject: (fields[4] as Map).cast<String, int>(),
      averageQuality: fields[5] as double,
      goalMinutes: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyStudyStats obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.totalMinutes)
      ..writeByte(2)
      ..write(obj.sessionCount)
      ..writeByte(3)
      ..write(obj.pomodoroCount)
      ..writeByte(4)
      ..write(obj.minutesBySubject)
      ..writeByte(5)
      ..write(obj.averageQuality)
      ..writeByte(6)
      ..write(obj.goalMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyStudyStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WeeklyStudyStatsAdapter extends TypeAdapter<WeeklyStudyStats> {
  @override
  final int typeId = 271;

  @override
  WeeklyStudyStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeeklyStudyStats(
      weekStart: fields[0] as DateTime,
      totalMinutes: fields[1] as int,
      totalSessions: fields[2] as int,
      daysStudied: fields[3] as int,
      goalDays: fields[4] as int,
      minutesBySubject: (fields[5] as Map).cast<String, int>(),
      dailyStats: (fields[6] as List).cast<DailyStudyStats>(),
      topicsCompleted: fields[7] as int,
      averageSessionLength: fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyStudyStats obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.weekStart)
      ..writeByte(1)
      ..write(obj.totalMinutes)
      ..writeByte(2)
      ..write(obj.totalSessions)
      ..writeByte(3)
      ..write(obj.daysStudied)
      ..writeByte(4)
      ..write(obj.goalDays)
      ..writeByte(5)
      ..write(obj.minutesBySubject)
      ..writeByte(6)
      ..write(obj.dailyStats)
      ..writeByte(7)
      ..write(obj.topicsCompleted)
      ..writeByte(8)
      ..write(obj.averageSessionLength);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyStudyStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudyAnalyticsAdapter extends TypeAdapter<StudyAnalytics> {
  @override
  final int typeId = 272;

  @override
  StudyAnalytics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudyAnalytics(
      id: fields[0] as String,
      totalLifetimeMinutes: fields[1] as int,
      totalLifetimeSessions: fields[2] as int,
      currentStreak: fields[3] as int,
      longestStreak: fields[4] as int,
      lastStudyDate: fields[5] as DateTime?,
      totalExamsCompleted: fields[6] as int,
      totalExamsPassed: fields[7] as int,
      averageGrade: fields[8] as double,
      totalTopicsCompleted: fields[9] as int,
      totalTopicsMastered: fields[10] as int,
      minutesBySubject: (fields[11] as Map).cast<String, int>(),
      minutesByHour: (fields[12] as Map).cast<int, int>(),
      minutesByDayOfWeek: (fields[13] as Map).cast<int, int>(),
      dailyGoalMinutes: fields[14] as int,
      weeklyGoalDays: fields[15] as int,
      achievementIds: (fields[16] as List).cast<String>(),
      createdAt: fields[17] as DateTime?,
      updatedAt: fields[18] as DateTime?,
      isSynced: fields[19] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, StudyAnalytics obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.totalLifetimeMinutes)
      ..writeByte(2)
      ..write(obj.totalLifetimeSessions)
      ..writeByte(3)
      ..write(obj.currentStreak)
      ..writeByte(4)
      ..write(obj.longestStreak)
      ..writeByte(5)
      ..write(obj.lastStudyDate)
      ..writeByte(6)
      ..write(obj.totalExamsCompleted)
      ..writeByte(7)
      ..write(obj.totalExamsPassed)
      ..writeByte(8)
      ..write(obj.averageGrade)
      ..writeByte(9)
      ..write(obj.totalTopicsCompleted)
      ..writeByte(10)
      ..write(obj.totalTopicsMastered)
      ..writeByte(11)
      ..write(obj.minutesBySubject)
      ..writeByte(12)
      ..write(obj.minutesByHour)
      ..writeByte(13)
      ..write(obj.minutesByDayOfWeek)
      ..writeByte(14)
      ..write(obj.dailyGoalMinutes)
      ..writeByte(15)
      ..write(obj.weeklyGoalDays)
      ..writeByte(16)
      ..write(obj.achievementIds)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt)
      ..writeByte(19)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyAnalyticsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
