// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinanceAccountAdapter extends TypeAdapter<FinanceAccount> {
  @override
  final int typeId = 85;

  @override
  FinanceAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinanceAccount(
      id: fields[0] as String?,
      name: fields[1] as String,
      type: fields[2] as AccountType,
      balance: fields[3] as double,
      colorValue: fields[4] as int?,
      iconCodePoint: fields[5] as int?,
      currency: fields[6] as String,
      includeInTotal: fields[7] as bool,
      isArchived: fields[8] as bool,
      sortOrder: fields[9] as int,
      createdAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FinanceAccount obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.balance)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.iconCodePoint)
      ..writeByte(6)
      ..write(obj.currency)
      ..writeByte(7)
      ..write(obj.includeInTotal)
      ..writeByte(8)
      ..write(obj.isArchived)
      ..writeByte(9)
      ..write(obj.sortOrder)
      ..writeByte(10)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
