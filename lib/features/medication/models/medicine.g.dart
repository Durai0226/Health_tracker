// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicineAdapter extends TypeAdapter<Medicine> {
  @override
  final int typeId = 0;

  @override
  Medicine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medicine(
      id: fields[0] as String,
      name: fields[1] as String,
      dosageAmount: fields[2] as int,
      dosageType: fields[3] as String,
      time: fields[4] as DateTime,
      frequency: fields[5] as String,
      durationDays: fields[6] as int?,
      enableReminder: fields[7] as bool,
      enableBuyReminder: fields[8] as bool,
      stockRemaining: fields[9] as int?,
      lowStockThreshold: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Medicine obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dosageAmount)
      ..writeByte(3)
      ..write(obj.dosageType)
      ..writeByte(4)
      ..write(obj.time)
      ..writeByte(5)
      ..write(obj.frequency)
      ..writeByte(6)
      ..write(obj.durationDays)
      ..writeByte(7)
      ..write(obj.enableReminder)
      ..writeByte(8)
      ..write(obj.enableBuyReminder)
      ..writeByte(9)
      ..write(obj.stockRemaining)
      ..writeByte(10)
      ..write(obj.lowStockThreshold);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
