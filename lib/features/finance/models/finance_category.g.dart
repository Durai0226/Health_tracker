// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinanceCategoryAdapter extends TypeAdapter<FinanceCategory> {
  @override
  final int typeId = 84;

  @override
  FinanceCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinanceCategory(
      id: fields[0] as String?,
      name: fields[1] as String,
      iconCodePoint: fields[2] as int,
      colorValue: fields[3] as int,
      isIncome: fields[4] as bool,
      isDefault: fields[5] as bool,
      sortOrder: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, FinanceCategory obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconCodePoint)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.isIncome)
      ..writeByte(5)
      ..write(obj.isDefault)
      ..writeByte(6)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
