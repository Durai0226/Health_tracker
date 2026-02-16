// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drug_interaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DrugInteractionAdapter extends TypeAdapter<DrugInteraction> {
  @override
  final int typeId = 65;

  @override
  DrugInteraction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DrugInteraction(
      id: fields[0] as String,
      drug1Name: fields[1] as String,
      drug2Name: fields[2] as String,
      severity: fields[3] as InteractionSeverity,
      description: fields[4] as String,
      recommendation: fields[5] as String?,
      mechanism: fields[6] as String?,
      references: (fields[7] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DrugInteraction obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.drug1Name)
      ..writeByte(2)
      ..write(obj.drug2Name)
      ..writeByte(3)
      ..write(obj.severity)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.recommendation)
      ..writeByte(6)
      ..write(obj.mechanism)
      ..writeByte(7)
      ..write(obj.references);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrugInteractionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SideEffectAdapter extends TypeAdapter<SideEffect> {
  @override
  final int typeId = 66;

  @override
  SideEffect read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SideEffect(
      name: fields[0] as String,
      frequency: fields[1] as String,
      description: fields[2] as String?,
      isSerious: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SideEffect obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.frequency)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isSerious);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SideEffectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DrugInfoAdapter extends TypeAdapter<DrugInfo> {
  @override
  final int typeId = 67;

  @override
  DrugInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DrugInfo(
      genericName: fields[0] as String,
      brandNames: (fields[1] as List).cast<String>(),
      drugClass: fields[2] as String,
      description: fields[3] as String?,
      uses: (fields[4] as List?)?.cast<String>(),
      warnings: (fields[5] as List?)?.cast<String>(),
      sideEffects: (fields[6] as List?)?.cast<SideEffect>(),
      contraindications: (fields[7] as List?)?.cast<String>(),
      pregnancyCategory: fields[8] as String?,
      requiresPrescription: fields[9] as bool?,
      storage: fields[10] as String?,
      halfLife: fields[11] as String?,
      foodInteractions: (fields[12] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DrugInfo obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.genericName)
      ..writeByte(1)
      ..write(obj.brandNames)
      ..writeByte(2)
      ..write(obj.drugClass)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.uses)
      ..writeByte(5)
      ..write(obj.warnings)
      ..writeByte(6)
      ..write(obj.sideEffects)
      ..writeByte(7)
      ..write(obj.contraindications)
      ..writeByte(8)
      ..write(obj.pregnancyCategory)
      ..writeByte(9)
      ..write(obj.requiresPrescription)
      ..writeByte(10)
      ..write(obj.storage)
      ..writeByte(11)
      ..write(obj.halfLife)
      ..writeByte(12)
      ..write(obj.foodInteractions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrugInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
