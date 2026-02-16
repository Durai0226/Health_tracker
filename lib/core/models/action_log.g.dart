// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'action_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActionLogAdapter extends TypeAdapter<ActionLog> {
  @override
  final int typeId = 21;

  @override
  ActionLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActionLog(
      id: fields[0] as String,
      type: fields[1] as ActionType,
      timestamp: fields[2] as DateTime,
      referenceId: fields[3] as String?,
      title: fields[4] as String?,
      metadata: (fields[5] as Map?)?.cast<String, dynamic>(),
      synced: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ActionLog obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.referenceId)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.metadata)
      ..writeByte(6)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ActionTypeAdapter extends TypeAdapter<ActionType> {
  @override
  final int typeId = 20;

  @override
  ActionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ActionType.medicineTaken;
      case 1:
        return ActionType.medicineSkipped;
      case 2:
        return ActionType.fitnessCompleted;
      case 3:
        return ActionType.fitnessSkipped;
      case 4:
        return ActionType.waterLogged;
      case 5:
        return ActionType.healthCheckDone;
      case 6:
        return ActionType.periodStarted;
      case 7:
        return ActionType.periodEnded;
      default:
        return ActionType.medicineTaken;
    }
  }

  @override
  void write(BinaryWriter writer, ActionType obj) {
    switch (obj) {
      case ActionType.medicineTaken:
        writer.writeByte(0);
        break;
      case ActionType.medicineSkipped:
        writer.writeByte(1);
        break;
      case ActionType.fitnessCompleted:
        writer.writeByte(2);
        break;
      case ActionType.fitnessSkipped:
        writer.writeByte(3);
        break;
      case ActionType.waterLogged:
        writer.writeByte(4);
        break;
      case ActionType.healthCheckDone:
        writer.writeByte(5);
        break;
      case ActionType.periodStarted:
        writer.writeByte(6);
        break;
      case ActionType.periodEnded:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
