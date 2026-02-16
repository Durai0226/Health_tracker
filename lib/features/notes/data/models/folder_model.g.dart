// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FolderModelAdapter extends TypeAdapter<FolderModel> {
  @override
  final int typeId = 101;

  @override
  FolderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FolderModel(
      id: fields[0] as String,
      name: fields[1] as String,
      parentId: fields[2] as String?,
      createdAt: fields[3] as DateTime,
      color: fields[4] as String?,
      icon: fields[5] as String?,
      isSynced: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, FolderModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.parentId)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.color)
      ..writeByte(5)
      ..write(obj.icon)
      ..writeByte(6)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
