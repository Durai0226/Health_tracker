// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_version_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NoteVersionModelAdapter extends TypeAdapter<NoteVersionModel> {
  @override
  final int typeId = 103;

  @override
  NoteVersionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NoteVersionModel(
      id: fields[0] as String,
      noteId: fields[1] as String,
      content: fields[2] as String,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, NoteVersionModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.noteId)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteVersionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
