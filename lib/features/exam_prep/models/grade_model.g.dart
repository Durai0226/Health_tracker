// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grade_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GradeAdapter extends TypeAdapter<Grade> {
  @override
  final int typeId = 262;

  @override
  Grade read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Grade(
      id: fields[0] as String,
      examId: fields[1] as String,
      subjectId: fields[2] as String,
      obtainedMarks: fields[3] as double,
      totalMarks: fields[4] as double,
      passingMarks: fields[5] as double?,
      letterGrade: fields[6] as String?,
      gradePoints: fields[7] as double?,
      gradeScale: fields[8] as GradeScale,
      weightPercentage: fields[9] as double?,
      feedback: fields[10] as String?,
      teacherRemarks: fields[11] as String?,
      rank: fields[12] as int?,
      totalStudents: fields[13] as int?,
      classAverage: fields[14] as double?,
      highestScore: fields[15] as double?,
      lowestScore: fields[16] as double?,
      isPublished: fields[17] as bool,
      publishedAt: fields[18] as DateTime?,
      createdAt: fields[19] as DateTime?,
      updatedAt: fields[20] as DateTime?,
      isSynced: fields[21] as bool,
      semesterId: fields[22] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Grade obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.examId)
      ..writeByte(2)
      ..write(obj.subjectId)
      ..writeByte(3)
      ..write(obj.obtainedMarks)
      ..writeByte(4)
      ..write(obj.totalMarks)
      ..writeByte(5)
      ..write(obj.passingMarks)
      ..writeByte(6)
      ..write(obj.letterGrade)
      ..writeByte(7)
      ..write(obj.gradePoints)
      ..writeByte(8)
      ..write(obj.gradeScale)
      ..writeByte(9)
      ..write(obj.weightPercentage)
      ..writeByte(10)
      ..write(obj.feedback)
      ..writeByte(11)
      ..write(obj.teacherRemarks)
      ..writeByte(12)
      ..write(obj.rank)
      ..writeByte(13)
      ..write(obj.totalStudents)
      ..writeByte(14)
      ..write(obj.classAverage)
      ..writeByte(15)
      ..write(obj.highestScore)
      ..writeByte(16)
      ..write(obj.lowestScore)
      ..writeByte(17)
      ..write(obj.isPublished)
      ..writeByte(18)
      ..write(obj.publishedAt)
      ..writeByte(19)
      ..write(obj.createdAt)
      ..writeByte(20)
      ..write(obj.updatedAt)
      ..writeByte(21)
      ..write(obj.isSynced)
      ..writeByte(22)
      ..write(obj.semesterId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SemesterGPAAdapter extends TypeAdapter<SemesterGPA> {
  @override
  final int typeId = 263;

  @override
  SemesterGPA read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SemesterGPA(
      id: fields[0] as String,
      semesterId: fields[1] as String,
      semesterName: fields[2] as String,
      gpa: fields[3] as double,
      totalCredits: fields[4] as int,
      completedCredits: fields[5] as int,
      gradeIds: (fields[6] as List).cast<String>(),
      startDate: fields[7] as DateTime,
      endDate: fields[8] as DateTime,
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
      isSynced: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SemesterGPA obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.semesterId)
      ..writeByte(2)
      ..write(obj.semesterName)
      ..writeByte(3)
      ..write(obj.gpa)
      ..writeByte(4)
      ..write(obj.totalCredits)
      ..writeByte(5)
      ..write(obj.completedCredits)
      ..writeByte(6)
      ..write(obj.gradeIds)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.endDate)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemesterGPAAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GradeScaleAdapter extends TypeAdapter<GradeScale> {
  @override
  final int typeId = 261;

  @override
  GradeScale read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GradeScale.percentage;
      case 1:
        return GradeScale.letter;
      case 2:
        return GradeScale.gpa_4;
      case 3:
        return GradeScale.gpa_10;
      case 4:
        return GradeScale.points;
      case 5:
        return GradeScale.custom;
      default:
        return GradeScale.percentage;
    }
  }

  @override
  void write(BinaryWriter writer, GradeScale obj) {
    switch (obj) {
      case GradeScale.percentage:
        writer.writeByte(0);
        break;
      case GradeScale.letter:
        writer.writeByte(1);
        break;
      case GradeScale.gpa_4:
        writer.writeByte(2);
        break;
      case GradeScale.gpa_10:
        writer.writeByte(3);
        break;
      case GradeScale.points:
        writer.writeByte(4);
        break;
      case GradeScale.custom:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradeScaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
