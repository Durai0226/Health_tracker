// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'water_achievement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WaterAchievementAdapter extends TypeAdapter<WaterAchievement> {
  @override
  final int typeId = 26;

  @override
  WaterAchievement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaterAchievement(
      id: fields[0] as String,
      type: fields[1] as AchievementType,
      title: fields[2] as String,
      description: fields[3] as String,
      emoji: fields[4] as String,
      targetValue: fields[5] as int,
      currentValue: fields[6] as int,
      isUnlocked: fields[7] as bool,
      unlockedAt: fields[8] as DateTime?,
      tier: fields[9] as int,
      points: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WaterAchievement obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.emoji)
      ..writeByte(5)
      ..write(obj.targetValue)
      ..writeByte(6)
      ..write(obj.currentValue)
      ..writeByte(7)
      ..write(obj.isUnlocked)
      ..writeByte(8)
      ..write(obj.unlockedAt)
      ..writeByte(9)
      ..write(obj.tier)
      ..writeByte(10)
      ..write(obj.points);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterAchievementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserAchievementsAdapter extends TypeAdapter<UserAchievements> {
  @override
  final int typeId = 27;

  @override
  UserAchievements read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserAchievements(
      id: fields[0] as String,
      achievements: (fields[1] as List?)?.cast<WaterAchievement>(),
      totalPoints: fields[2] as int,
      currentStreak: fields[3] as int,
      longestStreak: fields[4] as int,
      totalDrinks: fields[5] as int,
      totalMl: fields[6] as int,
      beverageTypesUsed: (fields[7] as List?)?.cast<String>(),
      daysGoalMet: fields[8] as int,
      lastGoalMetDate: fields[9] as DateTime?,
      caffeineFreeDays: fields[10] as int,
      alcoholFreeDays: fields[11] as int,
      earlyMorningDrinks: fields[12] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserAchievements obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.achievements)
      ..writeByte(2)
      ..write(obj.totalPoints)
      ..writeByte(3)
      ..write(obj.currentStreak)
      ..writeByte(4)
      ..write(obj.longestStreak)
      ..writeByte(5)
      ..write(obj.totalDrinks)
      ..writeByte(6)
      ..write(obj.totalMl)
      ..writeByte(7)
      ..write(obj.beverageTypesUsed)
      ..writeByte(8)
      ..write(obj.daysGoalMet)
      ..writeByte(9)
      ..write(obj.lastGoalMetDate)
      ..writeByte(10)
      ..write(obj.caffeineFreeDays)
      ..writeByte(11)
      ..write(obj.alcoholFreeDays)
      ..writeByte(12)
      ..write(obj.earlyMorningDrinks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAchievementsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AchievementTypeAdapter extends TypeAdapter<AchievementType> {
  @override
  final int typeId = 25;

  @override
  AchievementType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AchievementType.streak;
      case 1:
        return AchievementType.totalVolume;
      case 2:
        return AchievementType.consistency;
      case 3:
        return AchievementType.variety;
      case 4:
        return AchievementType.earlyBird;
      case 5:
        return AchievementType.nightOwl;
      case 6:
        return AchievementType.perfectWeek;
      case 7:
        return AchievementType.perfectMonth;
      case 8:
        return AchievementType.overachiever;
      case 9:
        return AchievementType.socialDrinker;
      case 10:
        return AchievementType.caffeineControl;
      default:
        return AchievementType.streak;
    }
  }

  @override
  void write(BinaryWriter writer, AchievementType obj) {
    switch (obj) {
      case AchievementType.streak:
        writer.writeByte(0);
        break;
      case AchievementType.totalVolume:
        writer.writeByte(1);
        break;
      case AchievementType.consistency:
        writer.writeByte(2);
        break;
      case AchievementType.variety:
        writer.writeByte(3);
        break;
      case AchievementType.earlyBird:
        writer.writeByte(4);
        break;
      case AchievementType.nightOwl:
        writer.writeByte(5);
        break;
      case AchievementType.perfectWeek:
        writer.writeByte(6);
        break;
      case AchievementType.perfectMonth:
        writer.writeByte(7);
        break;
      case AchievementType.overachiever:
        writer.writeByte(8);
        break;
      case AchievementType.socialDrinker:
        writer.writeByte(9);
        break;
      case AchievementType.caffeineControl:
        writer.writeByte(10);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AchievementTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
