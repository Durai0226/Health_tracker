// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_template_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TopicTemplateAdapter extends TypeAdapter<TopicTemplate> {
  @override
  final int typeId = 268;

  @override
  TopicTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TopicTemplate(
      name: fields[0] as String,
      estimatedMinutes: fields[1] as int,
      difficulty: fields[2] as int,
      weightPercentage: fields[3] as double,
      subtopics: (fields[4] as List).cast<TopicTemplate>(),
      isImportant: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TopicTemplate obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.estimatedMinutes)
      ..writeByte(2)
      ..write(obj.difficulty)
      ..writeByte(3)
      ..write(obj.weightPercentage)
      ..writeByte(4)
      ..write(obj.subtopics)
      ..writeByte(5)
      ..write(obj.isImportant);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExamTemplateAdapter extends TypeAdapter<ExamTemplate> {
  @override
  final int typeId = 269;

  @override
  ExamTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExamTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      category: fields[3] as TemplateCategory,
      examType: fields[4] as ExamType,
      topics: (fields[5] as List).cast<TopicTemplate>(),
      recommendedStudyDays: fields[6] as int,
      dailyStudyMinutes: fields[7] as int,
      totalMarks: fields[8] as double?,
      passingMarks: fields[9] as double?,
      defaultReminderDays: (fields[10] as List).cast<int>(),
      iconName: fields[11] as String?,
      colorHex: fields[12] as String?,
      isBuiltIn: fields[13] as bool,
      isPublic: fields[14] as bool,
      usageCount: fields[15] as int,
      averageRating: fields[16] as double?,
      createdBy: fields[17] as String?,
      createdAt: fields[18] as DateTime?,
      updatedAt: fields[19] as DateTime?,
      isSynced: fields[20] as bool,
      metadata: (fields[21] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, ExamTemplate obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.examType)
      ..writeByte(5)
      ..write(obj.topics)
      ..writeByte(6)
      ..write(obj.recommendedStudyDays)
      ..writeByte(7)
      ..write(obj.dailyStudyMinutes)
      ..writeByte(8)
      ..write(obj.totalMarks)
      ..writeByte(9)
      ..write(obj.passingMarks)
      ..writeByte(10)
      ..write(obj.defaultReminderDays)
      ..writeByte(11)
      ..write(obj.iconName)
      ..writeByte(12)
      ..write(obj.colorHex)
      ..writeByte(13)
      ..write(obj.isBuiltIn)
      ..writeByte(14)
      ..write(obj.isPublic)
      ..writeByte(15)
      ..write(obj.usageCount)
      ..writeByte(16)
      ..write(obj.averageRating)
      ..writeByte(17)
      ..write(obj.createdBy)
      ..writeByte(18)
      ..write(obj.createdAt)
      ..writeByte(19)
      ..write(obj.updatedAt)
      ..writeByte(20)
      ..write(obj.isSynced)
      ..writeByte(21)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TemplateCategoryAdapter extends TypeAdapter<TemplateCategory> {
  @override
  final int typeId = 267;

  @override
  TemplateCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TemplateCategory.school;
      case 1:
        return TemplateCategory.college;
      case 2:
        return TemplateCategory.university;
      case 3:
        return TemplateCategory.competitive;
      case 4:
        return TemplateCategory.certification;
      case 5:
        return TemplateCategory.language;
      case 6:
        return TemplateCategory.professional;
      case 7:
        return TemplateCategory.custom;
      default:
        return TemplateCategory.school;
    }
  }

  @override
  void write(BinaryWriter writer, TemplateCategory obj) {
    switch (obj) {
      case TemplateCategory.school:
        writer.writeByte(0);
        break;
      case TemplateCategory.college:
        writer.writeByte(1);
        break;
      case TemplateCategory.university:
        writer.writeByte(2);
        break;
      case TemplateCategory.competitive:
        writer.writeByte(3);
        break;
      case TemplateCategory.certification:
        writer.writeByte(4);
        break;
      case TemplateCategory.language:
        writer.writeByte(5);
        break;
      case TemplateCategory.professional:
        writer.writeByte(6);
        break;
      case TemplateCategory.custom:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
