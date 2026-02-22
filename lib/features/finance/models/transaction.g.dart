// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinanceTransactionAdapter extends TypeAdapter<FinanceTransaction> {
  @override
  final int typeId = 86;

  @override
  FinanceTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinanceTransaction(
      id: fields[0] as String?,
      amount: fields[1] as double,
      type: fields[2] as TransactionType,
      categoryId: fields[3] as String,
      accountId: fields[4] as String,
      toAccountId: fields[5] as String?,
      date: fields[6] as DateTime?,
      note: fields[7] as String?,
      recurrence: fields[8] as RecurrenceType,
      tags: (fields[9] as List?)?.cast<String>(),
      createdAt: fields[10] as DateTime?,
      attachmentPath: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FinanceTransaction obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.accountId)
      ..writeByte(5)
      ..write(obj.toAccountId)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.recurrence)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.attachmentPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
