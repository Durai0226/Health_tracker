// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetAdapter extends TypeAdapter<Budget> {
  @override
  final int typeId = 87;

  @override
  Budget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Budget(
      id: fields[0] as String?,
      name: fields[1] as String,
      limit: fields[2] as double,
      spent: fields[3] as double,
      period: fields[4] as BudgetPeriod,
      categoryIds: (fields[5] as List).cast<String>(),
      colorValue: fields[6] as int?,
      startDate: fields[7] as DateTime?,
      isArchived: fields[8] as bool,
      notifyAtPercent: fields[9] as bool,
      notifyPercent: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Budget obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.limit)
      ..writeByte(3)
      ..write(obj.spent)
      ..writeByte(4)
      ..write(obj.period)
      ..writeByte(5)
      ..write(obj.categoryIds)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.isArchived)
      ..writeByte(9)
      ..write(obj.notifyAtPercent)
      ..writeByte(10)
      ..write(obj.notifyPercent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
