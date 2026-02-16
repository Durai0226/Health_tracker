// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hydration_challenge.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HydrationChallengeAdapter extends TypeAdapter<HydrationChallenge> {
  @override
  final int typeId = 37;

  @override
  HydrationChallenge read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HydrationChallenge(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      emoji: fields[3] as String,
      difficulty: fields[4] as ChallengeDifficulty,
      duration: fields[5] as ChallengeDuration,
      durationDays: fields[6] as int,
      targetValue: fields[7] as int,
      targetUnit: fields[8] as String,
      rewardPoints: fields[9] as int,
      isActive: fields[10] as bool,
      startDate: fields[11] as DateTime?,
      endDate: fields[12] as DateTime?,
      currentProgress: fields[13] as int,
      isCompleted: fields[14] as bool,
      completedAt: fields[15] as DateTime?,
      milestones: (fields[16] as List?)?.cast<String>(),
      milestonesCompleted: fields[17] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HydrationChallenge obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.emoji)
      ..writeByte(4)
      ..write(obj.difficulty)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.durationDays)
      ..writeByte(7)
      ..write(obj.targetValue)
      ..writeByte(8)
      ..write(obj.targetUnit)
      ..writeByte(9)
      ..write(obj.rewardPoints)
      ..writeByte(10)
      ..write(obj.isActive)
      ..writeByte(11)
      ..write(obj.startDate)
      ..writeByte(12)
      ..write(obj.endDate)
      ..writeByte(13)
      ..write(obj.currentProgress)
      ..writeByte(14)
      ..write(obj.isCompleted)
      ..writeByte(15)
      ..write(obj.completedAt)
      ..writeByte(16)
      ..write(obj.milestones)
      ..writeByte(17)
      ..write(obj.milestonesCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydrationChallengeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserChallengesAdapter extends TypeAdapter<UserChallenges> {
  @override
  final int typeId = 38;

  @override
  UserChallenges read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserChallenges(
      id: fields[0] as String,
      activeChallenges: (fields[1] as List?)?.cast<HydrationChallenge>(),
      completedChallenges: (fields[2] as List?)?.cast<HydrationChallenge>(),
      totalChallengesCompleted: fields[3] as int,
      totalPointsEarned: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserChallenges obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.activeChallenges)
      ..writeByte(2)
      ..write(obj.completedChallenges)
      ..writeByte(3)
      ..write(obj.totalChallengesCompleted)
      ..writeByte(4)
      ..write(obj.totalPointsEarned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserChallengesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChallengeDifficultyAdapter extends TypeAdapter<ChallengeDifficulty> {
  @override
  final int typeId = 35;

  @override
  ChallengeDifficulty read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ChallengeDifficulty.easy;
      case 1:
        return ChallengeDifficulty.medium;
      case 2:
        return ChallengeDifficulty.hard;
      case 3:
        return ChallengeDifficulty.extreme;
      default:
        return ChallengeDifficulty.easy;
    }
  }

  @override
  void write(BinaryWriter writer, ChallengeDifficulty obj) {
    switch (obj) {
      case ChallengeDifficulty.easy:
        writer.writeByte(0);
        break;
      case ChallengeDifficulty.medium:
        writer.writeByte(1);
        break;
      case ChallengeDifficulty.hard:
        writer.writeByte(2);
        break;
      case ChallengeDifficulty.extreme:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeDifficultyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChallengeDurationAdapter extends TypeAdapter<ChallengeDuration> {
  @override
  final int typeId = 36;

  @override
  ChallengeDuration read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ChallengeDuration.daily;
      case 1:
        return ChallengeDuration.weekly;
      case 2:
        return ChallengeDuration.monthly;
      case 3:
        return ChallengeDuration.custom;
      default:
        return ChallengeDuration.daily;
    }
  }

  @override
  void write(BinaryWriter writer, ChallengeDuration obj) {
    switch (obj) {
      case ChallengeDuration.daily:
        writer.writeByte(0);
        break;
      case ChallengeDuration.weekly:
        writer.writeByte(1);
        break;
      case ChallengeDuration.monthly:
        writer.writeByte(2);
        break;
      case ChallengeDuration.custom:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeDurationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
