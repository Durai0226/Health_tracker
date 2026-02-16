// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'beverage_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BeverageTypeAdapter extends TypeAdapter<BeverageType> {
  @override
  final int typeId = 20;

  @override
  BeverageType read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BeverageType(
      id: fields[0] as String,
      name: fields[1] as String,
      emoji: fields[2] as String,
      hydrationPercent: fields[3] as int,
      colorHex: fields[4] as String,
      isDefault: fields[5] as bool,
      hasCaffeine: fields[6] as bool,
      caffeinePerMl: fields[7] as int,
      isAlcoholic: fields[8] as bool,
      defaultAmountMl: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BeverageType obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.emoji)
      ..writeByte(3)
      ..write(obj.hydrationPercent)
      ..writeByte(4)
      ..write(obj.colorHex)
      ..writeByte(5)
      ..write(obj.isDefault)
      ..writeByte(6)
      ..write(obj.hasCaffeine)
      ..writeByte(7)
      ..write(obj.caffeinePerMl)
      ..writeByte(8)
      ..write(obj.isAlcoholic)
      ..writeByte(9)
      ..write(obj.defaultAmountMl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeverageTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
