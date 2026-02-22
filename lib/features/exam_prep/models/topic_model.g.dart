// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TopicAdapter extends TypeAdapter<Topic> {
  @override
  final int typeId = 257;

  @override
  Topic read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Topic(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      subjectId: fields[3] as String,
      parentTopicId: fields[4] as String?,
      status: fields[5] as TopicStatus,
      difficulty: fields[6] as TopicDifficulty,
      estimatedMinutes: fields[7] as int,
      actualStudyMinutes: fields[8] as int,
      confidenceLevel: fields[9] as double,
      timesRevised: fields[10] as int,
      lastStudiedAt: fields[11] as DateTime?,
      nextRevisionDate: fields[12] as DateTime?,
      childTopicIds: (fields[13] as List).cast<String>(),
      noteIds: (fields[14] as List).cast<String>(),
      resourceUrls: (fields[15] as List).cast<String>(),
      orderIndex: fields[16] as int,
      weightPercentage: fields[17] as double,
      isImportantForExam: fields[18] as bool,
      createdAt: fields[19] as DateTime?,
      updatedAt: fields[20] as DateTime?,
      isSynced: fields[21] as bool,
      tags: (fields[22] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Topic obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.subjectId)
      ..writeByte(4)
      ..write(obj.parentTopicId)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.difficulty)
      ..writeByte(7)
      ..write(obj.estimatedMinutes)
      ..writeByte(8)
      ..write(obj.actualStudyMinutes)
      ..writeByte(9)
      ..write(obj.confidenceLevel)
      ..writeByte(10)
      ..write(obj.timesRevised)
      ..writeByte(11)
      ..write(obj.lastStudiedAt)
      ..writeByte(12)
      ..write(obj.nextRevisionDate)
      ..writeByte(13)
      ..write(obj.childTopicIds)
      ..writeByte(14)
      ..write(obj.noteIds)
      ..writeByte(15)
      ..write(obj.resourceUrls)
      ..writeByte(16)
      ..write(obj.orderIndex)
      ..writeByte(17)
      ..write(obj.weightPercentage)
      ..writeByte(18)
      ..write(obj.isImportantForExam)
      ..writeByte(19)
      ..write(obj.createdAt)
      ..writeByte(20)
      ..write(obj.updatedAt)
      ..writeByte(21)
      ..write(obj.isSynced)
      ..writeByte(22)
      ..write(obj.tags);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TopicStatusAdapter extends TypeAdapter<TopicStatus> {
  @override
  final int typeId = 255;

  @override
  TopicStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TopicStatus.not_started;
      case 1:
        return TopicStatus.in_progress;
      case 2:
        return TopicStatus.completed;
      case 3:
        return TopicStatus.revision_needed;
      case 4:
        return TopicStatus.mastered;
      default:
        return TopicStatus.not_started;
    }
  }

  @override
  void write(BinaryWriter writer, TopicStatus obj) {
    switch (obj) {
      case TopicStatus.not_started:
        writer.writeByte(0);
        break;
      case TopicStatus.in_progress:
        writer.writeByte(1);
        break;
      case TopicStatus.completed:
        writer.writeByte(2);
        break;
      case TopicStatus.revision_needed:
        writer.writeByte(3);
        break;
      case TopicStatus.mastered:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TopicDifficultyAdapter extends TypeAdapter<TopicDifficulty> {
  @override
  final int typeId = 256;

  @override
  TopicDifficulty read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TopicDifficulty.easy;
      case 1:
        return TopicDifficulty.medium;
      case 2:
        return TopicDifficulty.hard;
      case 3:
        return TopicDifficulty.very_hard;
      default:
        return TopicDifficulty.easy;
    }
  }

  @override
  void write(BinaryWriter writer, TopicDifficulty obj) {
    switch (obj) {
      case TopicDifficulty.easy:
        writer.writeByte(0);
        break;
      case TopicDifficulty.medium:
        writer.writeByte(1);
        break;
      case TopicDifficulty.hard:
        writer.writeByte(2);
        break;
      case TopicDifficulty.very_hard:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicDifficultyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
