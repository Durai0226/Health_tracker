// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudySessionAdapter extends TypeAdapter<StudySession> {
  @override
  final int typeId = 260;

  @override
  StudySession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudySession(
      id: fields[0] as String,
      subjectId: fields[1] as String?,
      topicId: fields[2] as String?,
      examId: fields[3] as String?,
      sessionType: fields[4] as StudySessionType,
      startTime: fields[5] as DateTime,
      endTime: fields[6] as DateTime?,
      plannedMinutes: fields[7] as int,
      actualMinutes: fields[8] as int,
      isCompleted: fields[9] as bool,
      wasInterrupted: fields[10] as bool,
      interruptionCount: fields[11] as int,
      quality: fields[12] as SessionQuality?,
      notes: fields[13] as String?,
      pomodoroCount: fields[14] as int,
      breakMinutes: fields[15] as int,
      focusScore: fields[16] as double?,
      distractions: (fields[17] as List).cast<String>(),
      productivityRating: fields[18] as double?,
      createdAt: fields[19] as DateTime?,
      updatedAt: fields[20] as DateTime?,
      isSynced: fields[21] as bool,
      metadata: (fields[22] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, StudySession obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subjectId)
      ..writeByte(2)
      ..write(obj.topicId)
      ..writeByte(3)
      ..write(obj.examId)
      ..writeByte(4)
      ..write(obj.sessionType)
      ..writeByte(5)
      ..write(obj.startTime)
      ..writeByte(6)
      ..write(obj.endTime)
      ..writeByte(7)
      ..write(obj.plannedMinutes)
      ..writeByte(8)
      ..write(obj.actualMinutes)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.wasInterrupted)
      ..writeByte(11)
      ..write(obj.interruptionCount)
      ..writeByte(12)
      ..write(obj.quality)
      ..writeByte(13)
      ..write(obj.notes)
      ..writeByte(14)
      ..write(obj.pomodoroCount)
      ..writeByte(15)
      ..write(obj.breakMinutes)
      ..writeByte(16)
      ..write(obj.focusScore)
      ..writeByte(17)
      ..write(obj.distractions)
      ..writeByte(18)
      ..write(obj.productivityRating)
      ..writeByte(19)
      ..write(obj.createdAt)
      ..writeByte(20)
      ..write(obj.updatedAt)
      ..writeByte(21)
      ..write(obj.isSynced)
      ..writeByte(22)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudySessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudySessionTypeAdapter extends TypeAdapter<StudySessionType> {
  @override
  final int typeId = 258;

  @override
  StudySessionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StudySessionType.regular;
      case 1:
        return StudySessionType.pomodoro;
      case 2:
        return StudySessionType.revision;
      case 3:
        return StudySessionType.practice;
      case 4:
        return StudySessionType.reading;
      case 5:
        return StudySessionType.notes_making;
      case 6:
        return StudySessionType.problem_solving;
      case 7:
        return StudySessionType.memorization;
      case 8:
        return StudySessionType.group_study;
      default:
        return StudySessionType.regular;
    }
  }

  @override
  void write(BinaryWriter writer, StudySessionType obj) {
    switch (obj) {
      case StudySessionType.regular:
        writer.writeByte(0);
        break;
      case StudySessionType.pomodoro:
        writer.writeByte(1);
        break;
      case StudySessionType.revision:
        writer.writeByte(2);
        break;
      case StudySessionType.practice:
        writer.writeByte(3);
        break;
      case StudySessionType.reading:
        writer.writeByte(4);
        break;
      case StudySessionType.notes_making:
        writer.writeByte(5);
        break;
      case StudySessionType.problem_solving:
        writer.writeByte(6);
        break;
      case StudySessionType.memorization:
        writer.writeByte(7);
        break;
      case StudySessionType.group_study:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudySessionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionQualityAdapter extends TypeAdapter<SessionQuality> {
  @override
  final int typeId = 259;

  @override
  SessionQuality read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SessionQuality.poor;
      case 1:
        return SessionQuality.average;
      case 2:
        return SessionQuality.good;
      case 3:
        return SessionQuality.excellent;
      default:
        return SessionQuality.poor;
    }
  }

  @override
  void write(BinaryWriter writer, SessionQuality obj) {
    switch (obj) {
      case SessionQuality.poor:
        writer.writeByte(0);
        break;
      case SessionQuality.average:
        writer.writeByte(1);
        break;
      case SessionQuality.good:
        writer.writeByte(2);
        break;
      case SessionQuality.excellent:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionQualityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
