// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SegmentAdapter extends TypeAdapter<Segment> {
  @override
  final int typeId = 70;

  @override
  Segment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Segment(
      id: fields[0] as String,
      name: fields[1] as String,
      distanceKm: fields[2] as double,
      elevationGainM: fields[3] as int,
      activityType: fields[4] as String,
      points: (fields[5] as List).cast<RoutePointSimple>(),
      difficulty: fields[6] as String,
      totalAttempts: fields[7] as int,
      creatorId: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      isStarred: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Segment obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.distanceKm)
      ..writeByte(3)
      ..write(obj.elevationGainM)
      ..writeByte(4)
      ..write(obj.activityType)
      ..writeByte(5)
      ..write(obj.points)
      ..writeByte(6)
      ..write(obj.difficulty)
      ..writeByte(7)
      ..write(obj.totalAttempts)
      ..writeByte(8)
      ..write(obj.creatorId)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.isStarred);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SegmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RoutePointSimpleAdapter extends TypeAdapter<RoutePointSimple> {
  @override
  final int typeId = 71;

  @override
  RoutePointSimple read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutePointSimple(
      lat: fields[0] as double,
      lng: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, RoutePointSimple obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.lat)
      ..writeByte(1)
      ..write(obj.lng);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePointSimpleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SegmentEffortAdapter extends TypeAdapter<SegmentEffort> {
  @override
  final int typeId = 72;

  @override
  SegmentEffort read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SegmentEffort(
      id: fields[0] as String,
      segmentId: fields[1] as String,
      activityId: fields[2] as String,
      usreId: fields[3] as String,
      elapsedTimeSeconds: fields[4] as int,
      startTime: fields[5] as DateTime,
      avgHeartRate: fields[6] as int?,
      avgPower: fields[7] as double?,
      rank: fields[8] as int,
      isPR: fields[9] as bool,
      previousBestSeconds: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, SegmentEffort obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.segmentId)
      ..writeByte(2)
      ..write(obj.activityId)
      ..writeByte(3)
      ..write(obj.usreId)
      ..writeByte(4)
      ..write(obj.elapsedTimeSeconds)
      ..writeByte(5)
      ..write(obj.startTime)
      ..writeByte(6)
      ..write(obj.avgHeartRate)
      ..writeByte(7)
      ..write(obj.avgPower)
      ..writeByte(8)
      ..write(obj.rank)
      ..writeByte(9)
      ..write(obj.isPR)
      ..writeByte(10)
      ..write(obj.previousBestSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SegmentEffortAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LeaderboardEntryAdapter extends TypeAdapter<LeaderboardEntry> {
  @override
  final int typeId = 73;

  @override
  LeaderboardEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LeaderboardEntry(
      rank: fields[0] as int,
      usreId: fields[1] as String,
      userName: fields[2] as String,
      userAvatarUrl: fields[3] as String?,
      elapsedTimeSeconds: fields[4] as int,
      achievedAt: fields[5] as DateTime,
      isCurrentUser: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LeaderboardEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.rank)
      ..writeByte(1)
      ..write(obj.usreId)
      ..writeByte(2)
      ..write(obj.userName)
      ..writeByte(3)
      ..write(obj.userAvatarUrl)
      ..writeByte(4)
      ..write(obj.elapsedTimeSeconds)
      ..writeByte(5)
      ..write(obj.achievedAt)
      ..writeByte(6)
      ..write(obj.isCurrentUser);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FitnessChallengeAdapter extends TypeAdapter<FitnessChallenge> {
  @override
  final int typeId = 74;

  @override
  FitnessChallenge read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FitnessChallenge(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      challengeType: fields[3] as String,
      activityType: fields[4] as String,
      targetValue: fields[5] as double,
      targetUnit: fields[6] as String,
      startDate: fields[7] as DateTime,
      endDate: fields[8] as DateTime,
      participants: (fields[9] as List).cast<ChallengeParticipant>(),
      imageUrl: fields[10] as String?,
      isJoined: fields[11] as bool,
      currentProgress: fields[12] as double,
      privacy: fields[13] as String,
      creatorId: fields[14] as String?,
      prizes: (fields[15] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, FitnessChallenge obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.challengeType)
      ..writeByte(4)
      ..write(obj.activityType)
      ..writeByte(5)
      ..write(obj.targetValue)
      ..writeByte(6)
      ..write(obj.targetUnit)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.endDate)
      ..writeByte(9)
      ..write(obj.participants)
      ..writeByte(10)
      ..write(obj.imageUrl)
      ..writeByte(11)
      ..write(obj.isJoined)
      ..writeByte(12)
      ..write(obj.currentProgress)
      ..writeByte(13)
      ..write(obj.privacy)
      ..writeByte(14)
      ..write(obj.creatorId)
      ..writeByte(15)
      ..write(obj.prizes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitnessChallengeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChallengeParticipantAdapter extends TypeAdapter<ChallengeParticipant> {
  @override
  final int typeId = 75;

  @override
  ChallengeParticipant read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChallengeParticipant(
      userId: fields[0] as String,
      userName: fields[1] as String,
      avatarUrl: fields[2] as String?,
      progress: fields[3] as double,
      rank: fields[4] as int,
      joinedAt: fields[5] as DateTime,
      isCurrentUser: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChallengeParticipant obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.userName)
      ..writeByte(2)
      ..write(obj.avatarUrl)
      ..writeByte(3)
      ..write(obj.progress)
      ..writeByte(4)
      ..write(obj.rank)
      ..writeByte(5)
      ..write(obj.joinedAt)
      ..writeByte(6)
      ..write(obj.isCurrentUser);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeParticipantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SocialActivityItemAdapter extends TypeAdapter<SocialActivityItem> {
  @override
  final int typeId = 76;

  @override
  SocialActivityItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SocialActivityItem(
      id: fields[0] as String,
      userId: fields[1] as String,
      userName: fields[2] as String,
      userAvatarUrl: fields[3] as String?,
      activityType: fields[4] as String,
      title: fields[5] as String,
      description: fields[6] as String?,
      timestamp: fields[7] as DateTime,
      activityData: (fields[8] as Map?)?.cast<String, dynamic>(),
      kudosCount: fields[9] as int,
      commentIds: (fields[10] as List?)?.cast<String>(),
      hasGivenKudos: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SocialActivityItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.userName)
      ..writeByte(3)
      ..write(obj.userAvatarUrl)
      ..writeByte(4)
      ..write(obj.activityType)
      ..writeByte(5)
      ..write(obj.title)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.timestamp)
      ..writeByte(8)
      ..write(obj.activityData)
      ..writeByte(9)
      ..write(obj.kudosCount)
      ..writeByte(10)
      ..write(obj.commentIds)
      ..writeByte(11)
      ..write(obj.hasGivenKudos);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialActivityItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
