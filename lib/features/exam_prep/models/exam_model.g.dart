// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExamAdapter extends TypeAdapter<Exam> {
  @override
  final int typeId = 253;

  @override
  Exam read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exam(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      subjectId: fields[3] as String,
      examType: fields[4] as ExamType,
      examDate: fields[5] as DateTime,
      examEndDate: fields[6] as DateTime?,
      location: fields[7] as String?,
      status: fields[8] as ExamStatus,
      priority: fields[9] as ExamPriority,
      totalMarks: fields[10] as double?,
      obtainedMarks: fields[11] as double?,
      passingMarks: fields[12] as double?,
      grade: fields[13] as String?,
      topicIds: (fields[14] as List).cast<String>(),
      targetStudyMinutes: fields[15] as int,
      actualStudyMinutes: fields[16] as int,
      attachmentUrls: (fields[17] as List).cast<String>(),
      noteIds: (fields[18] as List).cast<String>(),
      templateId: fields[19] as String?,
      reminderEnabled: fields[20] as bool,
      reminderTimes: (fields[21] as List).cast<DateTime>(),
      createdAt: fields[22] as DateTime?,
      updatedAt: fields[23] as DateTime?,
      isSynced: fields[24] as bool,
      orderIndex: fields[25] as int,
      colorHex: fields[26] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Exam obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.subjectId)
      ..writeByte(4)
      ..write(obj.examType)
      ..writeByte(5)
      ..write(obj.examDate)
      ..writeByte(6)
      ..write(obj.examEndDate)
      ..writeByte(7)
      ..write(obj.location)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.priority)
      ..writeByte(10)
      ..write(obj.totalMarks)
      ..writeByte(11)
      ..write(obj.obtainedMarks)
      ..writeByte(12)
      ..write(obj.passingMarks)
      ..writeByte(13)
      ..write(obj.grade)
      ..writeByte(14)
      ..write(obj.topicIds)
      ..writeByte(15)
      ..write(obj.targetStudyMinutes)
      ..writeByte(16)
      ..write(obj.actualStudyMinutes)
      ..writeByte(17)
      ..write(obj.attachmentUrls)
      ..writeByte(18)
      ..write(obj.noteIds)
      ..writeByte(19)
      ..write(obj.templateId)
      ..writeByte(20)
      ..write(obj.reminderEnabled)
      ..writeByte(21)
      ..write(obj.reminderTimes)
      ..writeByte(22)
      ..write(obj.createdAt)
      ..writeByte(23)
      ..write(obj.updatedAt)
      ..writeByte(24)
      ..write(obj.isSynced)
      ..writeByte(25)
      ..write(obj.orderIndex)
      ..writeByte(26)
      ..write(obj.colorHex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExamTypeAdapter extends TypeAdapter<ExamType> {
  @override
  final int typeId = 250;

  @override
  ExamType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExamType.midterm;
      case 1:
        return ExamType.final_exam;
      case 2:
        return ExamType.quiz;
      case 3:
        return ExamType.test;
      case 4:
        return ExamType.assignment;
      case 5:
        return ExamType.project;
      case 6:
        return ExamType.presentation;
      case 7:
        return ExamType.practical;
      case 8:
        return ExamType.viva;
      case 9:
        return ExamType.other;
      default:
        return ExamType.midterm;
    }
  }

  @override
  void write(BinaryWriter writer, ExamType obj) {
    switch (obj) {
      case ExamType.midterm:
        writer.writeByte(0);
        break;
      case ExamType.final_exam:
        writer.writeByte(1);
        break;
      case ExamType.quiz:
        writer.writeByte(2);
        break;
      case ExamType.test:
        writer.writeByte(3);
        break;
      case ExamType.assignment:
        writer.writeByte(4);
        break;
      case ExamType.project:
        writer.writeByte(5);
        break;
      case ExamType.presentation:
        writer.writeByte(6);
        break;
      case ExamType.practical:
        writer.writeByte(7);
        break;
      case ExamType.viva:
        writer.writeByte(8);
        break;
      case ExamType.other:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExamStatusAdapter extends TypeAdapter<ExamStatus> {
  @override
  final int typeId = 251;

  @override
  ExamStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExamStatus.upcoming;
      case 1:
        return ExamStatus.in_progress;
      case 2:
        return ExamStatus.completed;
      case 3:
        return ExamStatus.missed;
      case 4:
        return ExamStatus.cancelled;
      default:
        return ExamStatus.upcoming;
    }
  }

  @override
  void write(BinaryWriter writer, ExamStatus obj) {
    switch (obj) {
      case ExamStatus.upcoming:
        writer.writeByte(0);
        break;
      case ExamStatus.in_progress:
        writer.writeByte(1);
        break;
      case ExamStatus.completed:
        writer.writeByte(2);
        break;
      case ExamStatus.missed:
        writer.writeByte(3);
        break;
      case ExamStatus.cancelled:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExamPriorityAdapter extends TypeAdapter<ExamPriority> {
  @override
  final int typeId = 252;

  @override
  ExamPriority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExamPriority.low;
      case 1:
        return ExamPriority.medium;
      case 2:
        return ExamPriority.high;
      case 3:
        return ExamPriority.critical;
      default:
        return ExamPriority.low;
    }
  }

  @override
  void write(BinaryWriter writer, ExamPriority obj) {
    switch (obj) {
      case ExamPriority.low:
        writer.writeByte(0);
        break;
      case ExamPriority.medium:
        writer.writeByte(1);
        break;
      case ExamPriority.high:
        writer.writeByte(2);
        break;
      case ExamPriority.critical:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamPriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
