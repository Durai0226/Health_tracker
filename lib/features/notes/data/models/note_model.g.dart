// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NoteModelAdapter extends TypeAdapter<NoteModel> {
  @override
  final int typeId = 100;

  @override
  NoteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NoteModel(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      folderId: fields[5] as String?,
      tagIds: (fields[6] as List).cast<String>(),
      isPinned: fields[7] as bool,
      isArchived: fields[8] as bool,
      isDeleted: fields[9] as bool,
      mediaUrls: (fields[10] as List).cast<String>(),
      color: fields[11] as String?,
      isLocked: fields[12] as bool,
      isSynced: fields[13] as bool,
      reminderId: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NoteModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.folderId)
      ..writeByte(6)
      ..write(obj.tagIds)
      ..writeByte(7)
      ..write(obj.isPinned)
      ..writeByte(8)
      ..write(obj.isArchived)
      ..writeByte(9)
      ..write(obj.isDeleted)
      ..writeByte(10)
      ..write(obj.mediaUrls)
      ..writeByte(11)
      ..write(obj.color)
      ..writeByte(12)
      ..write(obj.isLocked)
      ..writeByte(13)
      ..write(obj.isSynced)
      ..writeByte(14)
      ..write(obj.reminderId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
