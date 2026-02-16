// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_category_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderCategoryAdapter extends TypeAdapter<ReminderCategory> {
  @override
  final int typeId = 204;

  @override
  ReminderCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      color: fields[2] as int,
      icon: fields[3] as int,
      isDefault: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderCategory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.color)
      ..writeByte(3)
      ..write(obj.icon)
      ..writeByte(4)
      ..write(obj.isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
