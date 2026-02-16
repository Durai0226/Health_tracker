// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'water_container.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WaterContainerAdapter extends TypeAdapter<WaterContainer> {
  @override
  final int typeId = 21;

  @override
  WaterContainer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaterContainer(
      id: fields[0] as String,
      name: fields[1] as String,
      emoji: fields[2] as String,
      capacityMl: fields[3] as int,
      isDefault: fields[4] as bool,
      colorHex: fields[5] as String?,
      usageCount: fields[6] as int,
      lastUsed: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WaterContainer obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.emoji)
      ..writeByte(3)
      ..write(obj.capacityMl)
      ..writeByte(4)
      ..write(obj.isDefault)
      ..writeByte(5)
      ..write(obj.colorHex)
      ..writeByte(6)
      ..write(obj.usageCount)
      ..writeByte(7)
      ..write(obj.lastUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterContainerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
