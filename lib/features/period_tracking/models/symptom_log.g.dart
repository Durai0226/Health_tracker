// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'symptom_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SymptomLogAdapter extends TypeAdapter<SymptomLog> {
  @override
  final int typeId = 39;

  @override
  SymptomLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SymptomLog(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      symptoms: (fields[2] as List).cast<SymptomEntry>(),
      moods: (fields[3] as List).cast<MoodType>(),
      energyLevel: fields[4] as EnergyLevel?,
      sleepQuality: fields[5] as SleepQuality?,
      sleepHours: fields[6] as double?,
      notes: fields[7] as String?,
      stressLevel: fields[8] as int?,
      hadIntimacy: fields[9] as bool?,
      usedProtection: fields[10] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, SymptomLog obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.symptoms)
      ..writeByte(3)
      ..write(obj.moods)
      ..writeByte(4)
      ..write(obj.energyLevel)
      ..writeByte(5)
      ..write(obj.sleepQuality)
      ..writeByte(6)
      ..write(obj.sleepHours)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.stressLevel)
      ..writeByte(9)
      ..write(obj.hadIntimacy)
      ..writeByte(10)
      ..write(obj.usedProtection);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymptomLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SymptomEntryAdapter extends TypeAdapter<SymptomEntry> {
  @override
  final int typeId = 40;

  @override
  SymptomEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SymptomEntry(
      type: fields[0] as SymptomType,
      severity: fields[1] as SymptomSeverity,
      notes: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SymptomEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.severity)
      ..writeByte(2)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymptomEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SymptomTypeAdapter extends TypeAdapter<SymptomType> {
  @override
  final int typeId = 34;

  @override
  SymptomType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SymptomType.cramps;
      case 1:
        return SymptomType.headache;
      case 2:
        return SymptomType.backPain;
      case 3:
        return SymptomType.bloating;
      case 4:
        return SymptomType.breastTenderness;
      case 5:
        return SymptomType.fatigue;
      case 6:
        return SymptomType.acne;
      case 7:
        return SymptomType.nausea;
      case 8:
        return SymptomType.insomnia;
      case 9:
        return SymptomType.hotFlashes;
      case 10:
        return SymptomType.dizziness;
      case 11:
        return SymptomType.cravings;
      case 12:
        return SymptomType.constipation;
      case 13:
        return SymptomType.diarrhea;
      case 14:
        return SymptomType.jointPain;
      default:
        return SymptomType.cramps;
    }
  }

  @override
  void write(BinaryWriter writer, SymptomType obj) {
    switch (obj) {
      case SymptomType.cramps:
        writer.writeByte(0);
        break;
      case SymptomType.headache:
        writer.writeByte(1);
        break;
      case SymptomType.backPain:
        writer.writeByte(2);
        break;
      case SymptomType.bloating:
        writer.writeByte(3);
        break;
      case SymptomType.breastTenderness:
        writer.writeByte(4);
        break;
      case SymptomType.fatigue:
        writer.writeByte(5);
        break;
      case SymptomType.acne:
        writer.writeByte(6);
        break;
      case SymptomType.nausea:
        writer.writeByte(7);
        break;
      case SymptomType.insomnia:
        writer.writeByte(8);
        break;
      case SymptomType.hotFlashes:
        writer.writeByte(9);
        break;
      case SymptomType.dizziness:
        writer.writeByte(10);
        break;
      case SymptomType.cravings:
        writer.writeByte(11);
        break;
      case SymptomType.constipation:
        writer.writeByte(12);
        break;
      case SymptomType.diarrhea:
        writer.writeByte(13);
        break;
      case SymptomType.jointPain:
        writer.writeByte(14);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymptomTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SymptomSeverityAdapter extends TypeAdapter<SymptomSeverity> {
  @override
  final int typeId = 35;

  @override
  SymptomSeverity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SymptomSeverity.mild;
      case 1:
        return SymptomSeverity.moderate;
      case 2:
        return SymptomSeverity.severe;
      default:
        return SymptomSeverity.mild;
    }
  }

  @override
  void write(BinaryWriter writer, SymptomSeverity obj) {
    switch (obj) {
      case SymptomSeverity.mild:
        writer.writeByte(0);
        break;
      case SymptomSeverity.moderate:
        writer.writeByte(1);
        break;
      case SymptomSeverity.severe:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymptomSeverityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MoodTypeAdapter extends TypeAdapter<MoodType> {
  @override
  final int typeId = 36;

  @override
  MoodType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MoodType.happy;
      case 1:
        return MoodType.calm;
      case 2:
        return MoodType.energetic;
      case 3:
        return MoodType.sensitive;
      case 4:
        return MoodType.anxious;
      case 5:
        return MoodType.irritable;
      case 6:
        return MoodType.sad;
      case 7:
        return MoodType.moodSwings;
      case 8:
        return MoodType.stressed;
      case 9:
        return MoodType.tired;
      case 10:
        return MoodType.focused;
      case 11:
        return MoodType.confused;
      default:
        return MoodType.happy;
    }
  }

  @override
  void write(BinaryWriter writer, MoodType obj) {
    switch (obj) {
      case MoodType.happy:
        writer.writeByte(0);
        break;
      case MoodType.calm:
        writer.writeByte(1);
        break;
      case MoodType.energetic:
        writer.writeByte(2);
        break;
      case MoodType.sensitive:
        writer.writeByte(3);
        break;
      case MoodType.anxious:
        writer.writeByte(4);
        break;
      case MoodType.irritable:
        writer.writeByte(5);
        break;
      case MoodType.sad:
        writer.writeByte(6);
        break;
      case MoodType.moodSwings:
        writer.writeByte(7);
        break;
      case MoodType.stressed:
        writer.writeByte(8);
        break;
      case MoodType.tired:
        writer.writeByte(9);
        break;
      case MoodType.focused:
        writer.writeByte(10);
        break;
      case MoodType.confused:
        writer.writeByte(11);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EnergyLevelAdapter extends TypeAdapter<EnergyLevel> {
  @override
  final int typeId = 37;

  @override
  EnergyLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EnergyLevel.veryLow;
      case 1:
        return EnergyLevel.low;
      case 2:
        return EnergyLevel.medium;
      case 3:
        return EnergyLevel.high;
      case 4:
        return EnergyLevel.veryHigh;
      default:
        return EnergyLevel.veryLow;
    }
  }

  @override
  void write(BinaryWriter writer, EnergyLevel obj) {
    switch (obj) {
      case EnergyLevel.veryLow:
        writer.writeByte(0);
        break;
      case EnergyLevel.low:
        writer.writeByte(1);
        break;
      case EnergyLevel.medium:
        writer.writeByte(2);
        break;
      case EnergyLevel.high:
        writer.writeByte(3);
        break;
      case EnergyLevel.veryHigh:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnergyLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SleepQualityAdapter extends TypeAdapter<SleepQuality> {
  @override
  final int typeId = 38;

  @override
  SleepQuality read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SleepQuality.poor;
      case 1:
        return SleepQuality.fair;
      case 2:
        return SleepQuality.good;
      case 3:
        return SleepQuality.excellent;
      default:
        return SleepQuality.poor;
    }
  }

  @override
  void write(BinaryWriter writer, SleepQuality obj) {
    switch (obj) {
      case SleepQuality.poor:
        writer.writeByte(0);
        break;
      case SleepQuality.fair:
        writer.writeByte(1);
        break;
      case SleepQuality.good:
        writer.writeByte(2);
        break;
      case SleepQuality.excellent:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepQualityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
