// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_plan_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudyPlanItemAdapter extends TypeAdapter<StudyPlanItem> {
  @override
  final int typeId = 265;

  @override
  StudyPlanItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudyPlanItem(
      id: fields[0] as String,
      topicId: fields[1] as String,
      topicName: fields[2] as String,
      scheduledDate: fields[3] as DateTime,
      plannedMinutes: fields[4] as int,
      actualMinutes: fields[5] as int,
      isCompleted: fields[6] as bool,
      orderIndex: fields[7] as int,
      notes: fields[8] as String?,
      sessionIds: (fields[9] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, StudyPlanItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topicId)
      ..writeByte(2)
      ..write(obj.topicName)
      ..writeByte(3)
      ..write(obj.scheduledDate)
      ..writeByte(4)
      ..write(obj.plannedMinutes)
      ..writeByte(5)
      ..write(obj.actualMinutes)
      ..writeByte(6)
      ..write(obj.isCompleted)
      ..writeByte(7)
      ..write(obj.orderIndex)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.sessionIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyPlanItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudyPlanAdapter extends TypeAdapter<StudyPlan> {
  @override
  final int typeId = 266;

  @override
  StudyPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudyPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      examId: fields[3] as String?,
      subjectId: fields[4] as String?,
      startDate: fields[5] as DateTime,
      endDate: fields[6] as DateTime,
      status: fields[7] as StudyPlanStatus,
      items: (fields[8] as List).cast<StudyPlanItem>(),
      totalPlannedMinutes: fields[9] as int,
      totalActualMinutes: fields[10] as int,
      dailyTargetMinutes: fields[11] as int,
      studyDays: (fields[12] as List).cast<int>(),
      templateId: fields[13] as String?,
      autoAdjust: fields[14] as bool,
      createdAt: fields[15] as DateTime?,
      updatedAt: fields[16] as DateTime?,
      isSynced: fields[17] as bool,
      colorHex: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StudyPlan obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.examId)
      ..writeByte(4)
      ..write(obj.subjectId)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.endDate)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.items)
      ..writeByte(9)
      ..write(obj.totalPlannedMinutes)
      ..writeByte(10)
      ..write(obj.totalActualMinutes)
      ..writeByte(11)
      ..write(obj.dailyTargetMinutes)
      ..writeByte(12)
      ..write(obj.studyDays)
      ..writeByte(13)
      ..write(obj.templateId)
      ..writeByte(14)
      ..write(obj.autoAdjust)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.updatedAt)
      ..writeByte(17)
      ..write(obj.isSynced)
      ..writeByte(18)
      ..write(obj.colorHex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudyPlanStatusAdapter extends TypeAdapter<StudyPlanStatus> {
  @override
  final int typeId = 264;

  @override
  StudyPlanStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StudyPlanStatus.draft;
      case 1:
        return StudyPlanStatus.active;
      case 2:
        return StudyPlanStatus.paused;
      case 3:
        return StudyPlanStatus.completed;
      case 4:
        return StudyPlanStatus.abandoned;
      default:
        return StudyPlanStatus.draft;
    }
  }

  @override
  void write(BinaryWriter writer, StudyPlanStatus obj) {
    switch (obj) {
      case StudyPlanStatus.draft:
        writer.writeByte(0);
        break;
      case StudyPlanStatus.active:
        writer.writeByte(1);
        break;
      case StudyPlanStatus.paused:
        writer.writeByte(2);
        break;
      case StudyPlanStatus.completed:
        writer.writeByte(3);
        break;
      case StudyPlanStatus.abandoned:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyPlanStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
