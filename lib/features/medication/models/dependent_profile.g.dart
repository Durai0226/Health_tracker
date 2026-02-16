// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dependent_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DependentProfileAdapter extends TypeAdapter<DependentProfile> {
  @override
  final int typeId = 69;

  @override
  DependentProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DependentProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      relationship: fields[2] as RelationshipType,
      dateOfBirth: fields[3] as DateTime?,
      gender: fields[4] as String?,
      bloodType: fields[5] as String?,
      weight: fields[6] as double?,
      height: fields[7] as double?,
      allergies: (fields[8] as List?)?.cast<String>(),
      conditions: (fields[9] as List?)?.cast<String>(),
      emergencyContact: fields[10] as String?,
      emergencyPhone: fields[11] as String?,
      primaryDoctorId: fields[12] as String?,
      insuranceInfo: fields[13] as String?,
      notes: fields[14] as String?,
      avatarPath: fields[15] as String?,
      isActive: fields[16] as bool,
      createdAt: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DependentProfile obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.relationship)
      ..writeByte(3)
      ..write(obj.dateOfBirth)
      ..writeByte(4)
      ..write(obj.gender)
      ..writeByte(5)
      ..write(obj.bloodType)
      ..writeByte(6)
      ..write(obj.weight)
      ..writeByte(7)
      ..write(obj.height)
      ..writeByte(8)
      ..write(obj.allergies)
      ..writeByte(9)
      ..write(obj.conditions)
      ..writeByte(10)
      ..write(obj.emergencyContact)
      ..writeByte(11)
      ..write(obj.emergencyPhone)
      ..writeByte(12)
      ..write(obj.primaryDoctorId)
      ..writeByte(13)
      ..write(obj.insuranceInfo)
      ..writeByte(14)
      ..write(obj.notes)
      ..writeByte(15)
      ..write(obj.avatarPath)
      ..writeByte(16)
      ..write(obj.isActive)
      ..writeByte(17)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependentProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RelationshipTypeAdapter extends TypeAdapter<RelationshipType> {
  @override
  final int typeId = 68;

  @override
  RelationshipType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RelationshipType.self;
      case 1:
        return RelationshipType.child;
      case 2:
        return RelationshipType.parent;
      case 3:
        return RelationshipType.spouse;
      case 4:
        return RelationshipType.grandparent;
      case 5:
        return RelationshipType.sibling;
      case 6:
        return RelationshipType.other;
      default:
        return RelationshipType.self;
    }
  }

  @override
  void write(BinaryWriter writer, RelationshipType obj) {
    switch (obj) {
      case RelationshipType.self:
        writer.writeByte(0);
        break;
      case RelationshipType.child:
        writer.writeByte(1);
        break;
      case RelationshipType.parent:
        writer.writeByte(2);
        break;
      case RelationshipType.spouse:
        writer.writeByte(3);
        break;
      case RelationshipType.grandparent:
        writer.writeByte(4);
        break;
      case RelationshipType.sibling:
        writer.writeByte(5);
        break;
      case RelationshipType.other:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationshipTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
