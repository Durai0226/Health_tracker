// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cycle_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CycleLogAdapter extends TypeAdapter<CycleLog> {
  @override
  final int typeId = 32;

  @override
  CycleLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CycleLog(
      id: fields[0] as String,
      startDate: fields[1] as DateTime,
      endDate: fields[2] as DateTime?,
      cycleLength: fields[3] as int,
      periodDuration: fields[4] as int,
      isComplete: fields[5] as bool,
      dailyLogs: (fields[6] as List).cast<DailyLog>(),
      ovulationDate: fields[7] as DateTime?,
      fertileWindowStart: fields[8] as DateTime?,
      fertileWindowEnd: fields[9] as DateTime?,
      notes: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CycleLog obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.endDate)
      ..writeByte(3)
      ..write(obj.cycleLength)
      ..writeByte(4)
      ..write(obj.periodDuration)
      ..writeByte(5)
      ..write(obj.isComplete)
      ..writeByte(6)
      ..write(obj.dailyLogs)
      ..writeByte(7)
      ..write(obj.ovulationDate)
      ..writeByte(8)
      ..write(obj.fertileWindowStart)
      ..writeByte(9)
      ..write(obj.fertileWindowEnd)
      ..writeByte(10)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyLogAdapter extends TypeAdapter<DailyLog> {
  @override
  final int typeId = 33;

  @override
  DailyLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyLog(
      date: fields[0] as DateTime,
      flow: fields[1] as FlowIntensity?,
      hasSpotting: fields[2] as bool,
      notes: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.flow)
      ..writeByte(2)
      ..write(obj.hasSpotting)
      ..writeByte(3)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FlowIntensityAdapter extends TypeAdapter<FlowIntensity> {
  @override
  final int typeId = 30;

  @override
  FlowIntensity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FlowIntensity.spotting;
      case 1:
        return FlowIntensity.light;
      case 2:
        return FlowIntensity.medium;
      case 3:
        return FlowIntensity.heavy;
      case 4:
        return FlowIntensity.veryHeavy;
      default:
        return FlowIntensity.spotting;
    }
  }

  @override
  void write(BinaryWriter writer, FlowIntensity obj) {
    switch (obj) {
      case FlowIntensity.spotting:
        writer.writeByte(0);
        break;
      case FlowIntensity.light:
        writer.writeByte(1);
        break;
      case FlowIntensity.medium:
        writer.writeByte(2);
        break;
      case FlowIntensity.heavy:
        writer.writeByte(3);
        break;
      case FlowIntensity.veryHeavy:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlowIntensityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CyclePhaseAdapter extends TypeAdapter<CyclePhase> {
  @override
  final int typeId = 31;

  @override
  CyclePhase read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CyclePhase.menstrual;
      case 1:
        return CyclePhase.follicular;
      case 2:
        return CyclePhase.ovulation;
      case 3:
        return CyclePhase.luteal;
      case 4:
        return CyclePhase.pms;
      default:
        return CyclePhase.menstrual;
    }
  }

  @override
  void write(BinaryWriter writer, CyclePhase obj) {
    switch (obj) {
      case CyclePhase.menstrual:
        writer.writeByte(0);
        break;
      case CyclePhase.follicular:
        writer.writeByte(1);
        break;
      case CyclePhase.ovulation:
        writer.writeByte(2);
        break;
      case CyclePhase.luteal:
        writer.writeByte(3);
        break;
      case CyclePhase.pms:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CyclePhaseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
