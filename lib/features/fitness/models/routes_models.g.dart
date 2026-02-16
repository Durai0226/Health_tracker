// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutRouteAdapter extends TypeAdapter<WorkoutRoute> {
  @override
  final int typeId = 60;

  @override
  WorkoutRoute read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutRoute(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      distanceKm: fields[3] as double,
      elevationGainM: fields[4] as int,
      activityType: fields[5] as String,
      points: (fields[6] as List).cast<RoutePoint>(),
      mapImageUrl: fields[7] as String?,
      createdAt: fields[8] as DateTime,
      isFavorite: fields[9] as bool,
      timesCompleted: fields[10] as int,
      difficulty: fields[11] as String,
      surfaceType: fields[12] as String?,
      isPublic: fields[13] as bool,
      avgPace: fields[14] as double?,
      startAddress: fields[15] as String?,
      endAddress: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutRoute obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.distanceKm)
      ..writeByte(4)
      ..write(obj.elevationGainM)
      ..writeByte(5)
      ..write(obj.activityType)
      ..writeByte(6)
      ..write(obj.points)
      ..writeByte(7)
      ..write(obj.mapImageUrl)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.isFavorite)
      ..writeByte(10)
      ..write(obj.timesCompleted)
      ..writeByte(11)
      ..write(obj.difficulty)
      ..writeByte(12)
      ..write(obj.surfaceType)
      ..writeByte(13)
      ..write(obj.isPublic)
      ..writeByte(14)
      ..write(obj.avgPace)
      ..writeByte(15)
      ..write(obj.startAddress)
      ..writeByte(16)
      ..write(obj.endAddress);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutRouteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RoutePointAdapter extends TypeAdapter<RoutePoint> {
  @override
  final int typeId = 61;

  @override
  RoutePoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutePoint(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      elevation: fields[2] as double?,
      order: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RoutePoint obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.elevation)
      ..writeByte(3)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SuggestedRouteAdapter extends TypeAdapter<SuggestedRoute> {
  @override
  final int typeId = 62;

  @override
  SuggestedRoute read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SuggestedRoute(
      id: fields[0] as String,
      name: fields[1] as String,
      distanceKm: fields[2] as double,
      elevationGainM: fields[3] as int,
      activityType: fields[4] as String,
      difficulty: fields[5] as String,
      popularity: fields[6] as double,
      previewImageUrl: fields[7] as String?,
      reason: fields[8] as String,
      points: (fields[9] as List).cast<RoutePoint>(),
      distanceFromUser: fields[10] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SuggestedRoute obj) {
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
      ..write(obj.difficulty)
      ..writeByte(6)
      ..write(obj.popularity)
      ..writeByte(7)
      ..write(obj.previewImageUrl)
      ..writeByte(8)
      ..write(obj.reason)
      ..writeByte(9)
      ..write(obj.points)
      ..writeByte(10)
      ..write(obj.distanceFromUser);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuggestedRouteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HeatmapDataAdapter extends TypeAdapter<HeatmapData> {
  @override
  final int typeId = 63;

  @override
  HeatmapData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HeatmapData(
      id: fields[0] as String,
      activityType: fields[1] as String,
      points: (fields[2] as List).cast<HeatmapPoint>(),
      lastUpdated: fields[3] as DateTime,
      totalActivities: fields[4] as int,
      totalDistanceKm: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, HeatmapData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.activityType)
      ..writeByte(2)
      ..write(obj.points)
      ..writeByte(3)
      ..write(obj.lastUpdated)
      ..writeByte(4)
      ..write(obj.totalActivities)
      ..writeByte(5)
      ..write(obj.totalDistanceKm);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeatmapDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HeatmapPointAdapter extends TypeAdapter<HeatmapPoint> {
  @override
  final int typeId = 64;

  @override
  HeatmapPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HeatmapPoint(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      intensity: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HeatmapPoint obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.intensity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeatmapPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineMapRegionAdapter extends TypeAdapter<OfflineMapRegion> {
  @override
  final int typeId = 65;

  @override
  OfflineMapRegion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineMapRegion(
      id: fields[0] as String,
      name: fields[1] as String,
      centerLat: fields[2] as double,
      centerLng: fields[3] as double,
      radiusKm: fields[4] as double,
      zoomLevel: fields[5] as int,
      downloadedAt: fields[6] as DateTime,
      sizeBytes: fields[7] as int,
      isComplete: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineMapRegion obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.centerLat)
      ..writeByte(3)
      ..write(obj.centerLng)
      ..writeByte(4)
      ..write(obj.radiusKm)
      ..writeByte(5)
      ..write(obj.zoomLevel)
      ..writeByte(6)
      ..write(obj.downloadedAt)
      ..writeByte(7)
      ..write(obj.sizeBytes)
      ..writeByte(8)
      ..write(obj.isComplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineMapRegionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
