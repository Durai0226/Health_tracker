// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubjectAdapter extends TypeAdapter<Subject> {
  @override
  final int typeId = 254;

  @override
  Subject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subject(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      teacherName: fields[3] as String?,
      colorHex: fields[4] as String,
      iconName: fields[5] as String,
      creditHours: fields[6] as int,
      targetGrade: fields[7] as double?,
      currentGrade: fields[8] as double?,
      topicIds: (fields[9] as List).cast<String>(),
      examIds: (fields[10] as List).cast<String>(),
      totalStudyMinutes: fields[11] as int,
      weeklyTargetMinutes: fields[12] as int,
      parentId: fields[13] as String?,
      orderIndex: fields[14] as int,
      isArchived: fields[15] as bool,
      createdAt: fields[16] as DateTime?,
      updatedAt: fields[17] as DateTime?,
      isSynced: fields[18] as bool,
      semesterId: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Subject obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.teacherName)
      ..writeByte(4)
      ..write(obj.colorHex)
      ..writeByte(5)
      ..write(obj.iconName)
      ..writeByte(6)
      ..write(obj.creditHours)
      ..writeByte(7)
      ..write(obj.targetGrade)
      ..writeByte(8)
      ..write(obj.currentGrade)
      ..writeByte(9)
      ..write(obj.topicIds)
      ..writeByte(10)
      ..write(obj.examIds)
      ..writeByte(11)
      ..write(obj.totalStudyMinutes)
      ..writeByte(12)
      ..write(obj.weeklyTargetMinutes)
      ..writeByte(13)
      ..write(obj.parentId)
      ..writeByte(14)
      ..write(obj.orderIndex)
      ..writeByte(15)
      ..write(obj.isArchived)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.updatedAt)
      ..writeByte(18)
      ..write(obj.isSynced)
      ..writeByte(19)
      ..write(obj.semesterId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
