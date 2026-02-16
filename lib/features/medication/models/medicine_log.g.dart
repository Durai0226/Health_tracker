// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicineLogAdapter extends TypeAdapter<MedicineLog> {
  @override
  final int typeId = 60;

  @override
  MedicineLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicineLog(
      id: fields[0] as String,
      medicineId: fields[1] as String,
      scheduledTime: fields[2] as DateTime,
      actionTime: fields[3] as DateTime?,
      status: fields[4] as MedicineStatus,
      dosageTaken: fields[5] as double,
      skipReason: fields[6] as SkipReason?,
      skipNote: fields[7] as String?,
      sideEffects: fields[8] as String?,
      moodRating: fields[9] as int?,
      effectivenessRating: fields[10] as int?,
      notes: fields[11] as String?,
      dependentId: fields[12] as String?,
      vitals: (fields[13] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, MedicineLog obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.medicineId)
      ..writeByte(2)
      ..write(obj.scheduledTime)
      ..writeByte(3)
      ..write(obj.actionTime)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.dosageTaken)
      ..writeByte(6)
      ..write(obj.skipReason)
      ..writeByte(7)
      ..write(obj.skipNote)
      ..writeByte(8)
      ..write(obj.sideEffects)
      ..writeByte(9)
      ..write(obj.moodRating)
      ..writeByte(10)
      ..write(obj.effectivenessRating)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.dependentId)
      ..writeByte(13)
      ..write(obj.vitals);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyMedicineSummaryAdapter extends TypeAdapter<DailyMedicineSummary> {
  @override
  final int typeId = 61;

  @override
  DailyMedicineSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyMedicineSummary(
      date: fields[0] as DateTime,
      totalScheduled: fields[1] as int,
      taken: fields[2] as int,
      skipped: fields[3] as int,
      missed: fields[4] as int,
      adherenceRate: fields[5] as double,
      medicinesTaken: (fields[6] as List).cast<String>(),
      medicinesMissed: (fields[7] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DailyMedicineSummary obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.totalScheduled)
      ..writeByte(2)
      ..write(obj.taken)
      ..writeByte(3)
      ..write(obj.skipped)
      ..writeByte(4)
      ..write(obj.missed)
      ..writeByte(5)
      ..write(obj.adherenceRate)
      ..writeByte(6)
      ..write(obj.medicinesTaken)
      ..writeByte(7)
      ..write(obj.medicinesMissed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyMedicineSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
