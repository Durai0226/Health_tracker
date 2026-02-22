// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intake_streak.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IntakeStreakAdapter extends TypeAdapter<IntakeStreak> {
  @override
  final int typeId = 92;

  @override
  IntakeStreak read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IntakeStreak(
      id: fields[0] as String,
      medicineId: fields[1] as String,
      currentStreak: fields[2] as int,
      longestStreak: fields[3] as int,
      lastTakenDate: fields[4] as DateTime?,
      consecutiveTakeDates: (fields[5] as List?)?.cast<DateTime>(),
      canSkip: fields[6] as bool,
      consecutiveTakes: fields[7] as int,
      lastSkipDate: fields[8] as DateTime?,
      totalTaken: fields[9] as int,
      totalSkipped: fields[10] as int,
      createdAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, IntakeStreak obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.medicineId)
      ..writeByte(2)
      ..write(obj.currentStreak)
      ..writeByte(3)
      ..write(obj.longestStreak)
      ..writeByte(4)
      ..write(obj.lastTakenDate)
      ..writeByte(5)
      ..write(obj.consecutiveTakeDates)
      ..writeByte(6)
      ..write(obj.canSkip)
      ..writeByte(7)
      ..write(obj.consecutiveTakes)
      ..writeByte(8)
      ..write(obj.lastSkipDate)
      ..writeByte(9)
      ..write(obj.totalTaken)
      ..writeByte(10)
      ..write(obj.totalSkipped)
      ..writeByte(11)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntakeStreakAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PatientMedicineProfileAdapter
    extends TypeAdapter<PatientMedicineProfile> {
  @override
  final int typeId = 93;

  @override
  PatientMedicineProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PatientMedicineProfile(
      id: fields[0] as String,
      patientId: fields[1] as String,
      patientName: fields[2] as String,
      healthCategories: (fields[3] as List?)?.cast<HealthCategory>(),
      customCategories: (fields[4] as List?)?.cast<String>(),
      categoryMedicines: (fields[5] as Map?)?.map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<String>())),
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
      healthMetrics: (fields[8] as Map?)?.cast<String, dynamic>(),
      notes: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PatientMedicineProfile obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.patientName)
      ..writeByte(3)
      ..write(obj.healthCategories)
      ..writeByte(4)
      ..write(obj.customCategories)
      ..writeByte(5)
      ..write(obj.categoryMedicines)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.healthMetrics)
      ..writeByte(9)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientMedicineProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
