// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enhanced_medicine.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EnhancedMedicineAdapter extends TypeAdapter<EnhancedMedicine> {
  @override
  final int typeId = 90;

  @override
  EnhancedMedicine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EnhancedMedicine(
      id: fields[0] as String,
      name: fields[1] as String,
      genericName: fields[2] as String?,
      brandName: fields[3] as String?,
      dosageForm: fields[4] as DosageForm,
      dosageAmount: fields[5] as double,
      dosageUnit: fields[6] as String?,
      strength: fields[7] as String?,
      schedule: fields[8] as MedicineSchedule,
      color: fields[9] as MedicineColor?,
      shape: fields[10] as MedicineShape?,
      imprint: fields[11] as String?,
      imagePath: fields[12] as String?,
      instructions: fields[13] as String?,
      purpose: fields[14] as String?,
      condition: fields[15] as String?,
      currentStock: fields[16] as int?,
      lowStockThreshold: fields[17] as int?,
      refillReminderEnabled: fields[18] as bool,
      lastRefillDate: fields[19] as DateTime?,
      costPerUnit: fields[20] as double?,
      prescriptionNumber: fields[21] as String?,
      doctorId: fields[22] as String?,
      pharmacyId: fields[23] as String?,
      prescribedDate: fields[24] as DateTime?,
      expiryDate: fields[25] as DateTime?,
      refillsRemaining: fields[26] as int?,
      reminderEnabled: fields[27] as bool,
      reminderSound: fields[28] as String?,
      criticalAlert: fields[29] as bool,
      snoozeMinutes: fields[30] as int,
      drugInfo: fields[31] as DrugInfo?,
      warnings: (fields[32] as List?)?.cast<String>(),
      sideEffects: (fields[33] as List?)?.cast<String>(),
      dependentId: fields[34] as String?,
      createdAt: fields[35] as DateTime?,
      updatedAt: fields[36] as DateTime?,
      isActive: fields[37] as bool,
      isArchived: fields[38] as bool,
      notes: fields[39] as String?,
      customFields: (fields[40] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, EnhancedMedicine obj) {
    writer
      ..writeByte(41)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.genericName)
      ..writeByte(3)
      ..write(obj.brandName)
      ..writeByte(4)
      ..write(obj.dosageForm)
      ..writeByte(5)
      ..write(obj.dosageAmount)
      ..writeByte(6)
      ..write(obj.dosageUnit)
      ..writeByte(7)
      ..write(obj.strength)
      ..writeByte(8)
      ..write(obj.schedule)
      ..writeByte(9)
      ..write(obj.color)
      ..writeByte(10)
      ..write(obj.shape)
      ..writeByte(11)
      ..write(obj.imprint)
      ..writeByte(12)
      ..write(obj.imagePath)
      ..writeByte(13)
      ..write(obj.instructions)
      ..writeByte(14)
      ..write(obj.purpose)
      ..writeByte(15)
      ..write(obj.condition)
      ..writeByte(16)
      ..write(obj.currentStock)
      ..writeByte(17)
      ..write(obj.lowStockThreshold)
      ..writeByte(18)
      ..write(obj.refillReminderEnabled)
      ..writeByte(19)
      ..write(obj.lastRefillDate)
      ..writeByte(20)
      ..write(obj.costPerUnit)
      ..writeByte(21)
      ..write(obj.prescriptionNumber)
      ..writeByte(22)
      ..write(obj.doctorId)
      ..writeByte(23)
      ..write(obj.pharmacyId)
      ..writeByte(24)
      ..write(obj.prescribedDate)
      ..writeByte(25)
      ..write(obj.expiryDate)
      ..writeByte(26)
      ..write(obj.refillsRemaining)
      ..writeByte(27)
      ..write(obj.reminderEnabled)
      ..writeByte(28)
      ..write(obj.reminderSound)
      ..writeByte(29)
      ..write(obj.criticalAlert)
      ..writeByte(30)
      ..write(obj.snoozeMinutes)
      ..writeByte(31)
      ..write(obj.drugInfo)
      ..writeByte(32)
      ..write(obj.warnings)
      ..writeByte(33)
      ..write(obj.sideEffects)
      ..writeByte(34)
      ..write(obj.dependentId)
      ..writeByte(35)
      ..write(obj.createdAt)
      ..writeByte(36)
      ..write(obj.updatedAt)
      ..writeByte(37)
      ..write(obj.isActive)
      ..writeByte(38)
      ..write(obj.isArchived)
      ..writeByte(39)
      ..write(obj.notes)
      ..writeByte(40)
      ..write(obj.customFields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnhancedMedicineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TreatmentCourseAdapter extends TypeAdapter<TreatmentCourse> {
  @override
  final int typeId = 91;

  @override
  TreatmentCourse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TreatmentCourse(
      id: fields[0] as String,
      name: fields[1] as String,
      condition: fields[2] as String?,
      description: fields[3] as String?,
      medicineIds: (fields[4] as List).cast<String>(),
      startDate: fields[5] as DateTime,
      endDate: fields[6] as DateTime?,
      doctorId: fields[7] as String?,
      notes: fields[8] as String?,
      isActive: fields[9] as bool,
      dependentId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TreatmentCourse obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.condition)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.medicineIds)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.endDate)
      ..writeByte(7)
      ..write(obj.doctorId)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.dependentId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TreatmentCourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
