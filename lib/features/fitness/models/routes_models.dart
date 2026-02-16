import 'package:hive/hive.dart';

part 'routes_models.g.dart';

/// Route - Custom workout route
@HiveType(typeId: 60)
class WorkoutRoute extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final double distanceKm;

  @HiveField(4)
  final int elevationGainM;

  @HiveField(5)
  final String activityType; // run, cycling, walk

  @HiveField(6)
  final List<RoutePoint> points;

  @HiveField(7)
  final String? mapImageUrl;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final bool isFavorite;

  @HiveField(10)
  final int timesCompleted;

  @HiveField(11)
  final String difficulty; // easy, moderate, hard

  @HiveField(12)
  final String? surfaceType; // road, trail, mixed

  @HiveField(13)
  final bool isPublic;

  @HiveField(14)
  final double? avgPace; // Best pace on this route

  @HiveField(15)
  final String? startAddress;

  @HiveField(16)
  final String? endAddress;

  WorkoutRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.distanceKm,
    required this.elevationGainM,
    required this.activityType,
    required this.points,
    this.mapImageUrl,
    required this.createdAt,
    this.isFavorite = false,
    this.timesCompleted = 0,
    required this.difficulty,
    this.surfaceType,
    this.isPublic = false,
    this.avgPace,
    this.startAddress,
    this.endAddress,
  });

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get difficultyEmoji {
    switch (difficulty) {
      case 'easy': return '🟢';
      case 'moderate': return '🟡';
      case 'hard': return '🔴';
      default: return '⚪';
    }
  }

  String get activityEmoji {
    switch (activityType) {
      case 'run': return '🏃';
      case 'cycling': return '🚴';
      case 'walk': return '🚶';
      default: return '🏃';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'distanceKm': distanceKm,
    'elevationGainM': elevationGainM,
    'activityType': activityType,
    'points': points.map((p) => p.toJson()).toList(),
    'mapImageUrl': mapImageUrl,
    'createdAt': createdAt.toIso8601String(),
    'isFavorite': isFavorite,
    'timesCompleted': timesCompleted,
    'difficulty': difficulty,
    'surfaceType': surfaceType,
    'isPublic': isPublic,
    'avgPace': avgPace,
    'startAddress': startAddress,
    'endAddress': endAddress,
  };

  factory WorkoutRoute.fromJson(Map<String, dynamic> json) => WorkoutRoute(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    distanceKm: (json['distanceKm'] ?? 0).toDouble(),
    elevationGainM: json['elevationGainM'] ?? 0,
    activityType: json['activityType'] ?? 'run',
    points: (json['points'] as List<dynamic>?)
        ?.map((p) => RoutePoint.fromJson(p))
        .toList() ?? [],
    mapImageUrl: json['mapImageUrl'],
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    isFavorite: json['isFavorite'] ?? false,
    timesCompleted: json['timesCompleted'] ?? 0,
    difficulty: json['difficulty'] ?? 'moderate',
    surfaceType: json['surfaceType'],
    isPublic: json['isPublic'] ?? false,
    avgPace: json['avgPace']?.toDouble(),
    startAddress: json['startAddress'],
    endAddress: json['endAddress'],
  );
}

@HiveType(typeId: 61)
class RoutePoint extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final double? elevation;

  @HiveField(3)
  final int order;

  RoutePoint({
    required this.latitude,
    required this.longitude,
    this.elevation,
    required this.order,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'elevation': elevation,
    'order': order,
  };

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
    latitude: (json['latitude'] ?? 0).toDouble(),
    longitude: (json['longitude'] ?? 0).toDouble(),
    elevation: json['elevation']?.toDouble(),
    order: json['order'] ?? 0,
  );
}

/// Suggested Route - AI-generated route suggestions
@HiveType(typeId: 62)
class SuggestedRoute extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double distanceKm;

  @HiveField(3)
  final int elevationGainM;

  @HiveField(4)
  final String activityType;

  @HiveField(5)
  final String difficulty;

  @HiveField(6)
  final double popularity; // 0-100

  @HiveField(7)
  final String? previewImageUrl;

  @HiveField(8)
  final String reason; // Why it was suggested

  @HiveField(9)
  final List<RoutePoint> points;

  @HiveField(10)
  final double distanceFromUser; // km

  SuggestedRoute({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.elevationGainM,
    required this.activityType,
    required this.difficulty,
    required this.popularity,
    this.previewImageUrl,
    required this.reason,
    required this.points,
    required this.distanceFromUser,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'distanceKm': distanceKm,
    'elevationGainM': elevationGainM,
    'activityType': activityType,
    'difficulty': difficulty,
    'popularity': popularity,
    'previewImageUrl': previewImageUrl,
    'reason': reason,
    'points': points.map((p) => p.toJson()).toList(),
    'distanceFromUser': distanceFromUser,
  };

  factory SuggestedRoute.fromJson(Map<String, dynamic> json) => SuggestedRoute(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    distanceKm: (json['distanceKm'] ?? 0).toDouble(),
    elevationGainM: json['elevationGainM'] ?? 0,
    activityType: json['activityType'] ?? 'run',
    difficulty: json['difficulty'] ?? 'moderate',
    popularity: (json['popularity'] ?? 0).toDouble(),
    previewImageUrl: json['previewImageUrl'],
    reason: json['reason'] ?? '',
    points: (json['points'] as List<dynamic>?)
        ?.map((p) => RoutePoint.fromJson(p))
        .toList() ?? [],
    distanceFromUser: (json['distanceFromUser'] ?? 0).toDouble(),
  );
}

/// Heatmap Data - Activity location aggregation
@HiveType(typeId: 63)
class HeatmapData extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String activityType;

  @HiveField(2)
  final List<HeatmapPoint> points;

  @HiveField(3)
  final DateTime lastUpdated;

  @HiveField(4)
  final int totalActivities;

  @HiveField(5)
  final double totalDistanceKm;

  HeatmapData({
    required this.id,
    required this.activityType,
    required this.points,
    required this.lastUpdated,
    required this.totalActivities,
    required this.totalDistanceKm,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityType': activityType,
    'points': points.map((p) => p.toJson()).toList(),
    'lastUpdated': lastUpdated.toIso8601String(),
    'totalActivities': totalActivities,
    'totalDistanceKm': totalDistanceKm,
  };

  factory HeatmapData.fromJson(Map<String, dynamic> json) => HeatmapData(
    id: json['id'] ?? '',
    activityType: json['activityType'] ?? '',
    points: (json['points'] as List<dynamic>?)
        ?.map((p) => HeatmapPoint.fromJson(p))
        .toList() ?? [],
    lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    totalActivities: json['totalActivities'] ?? 0,
    totalDistanceKm: (json['totalDistanceKm'] ?? 0).toDouble(),
  );
}

@HiveType(typeId: 64)
class HeatmapPoint extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final int intensity; // Number of times visited

  HeatmapPoint({
    required this.latitude,
    required this.longitude,
    required this.intensity,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'intensity': intensity,
  };

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) => HeatmapPoint(
    latitude: (json['latitude'] ?? 0).toDouble(),
    longitude: (json['longitude'] ?? 0).toDouble(),
    intensity: json['intensity'] ?? 1,
  );
}

/// Offline Map Region - Downloaded map areas
@HiveType(typeId: 65)
class OfflineMapRegion extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double centerLat;

  @HiveField(3)
  final double centerLng;

  @HiveField(4)
  final double radiusKm;

  @HiveField(5)
  final int zoomLevel;

  @HiveField(6)
  final DateTime downloadedAt;

  @HiveField(7)
  final int sizeBytes;

  @HiveField(8)
  final bool isComplete;

  OfflineMapRegion({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    required this.zoomLevel,
    required this.downloadedAt,
    required this.sizeBytes,
    this.isComplete = false,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'centerLat': centerLat,
    'centerLng': centerLng,
    'radiusKm': radiusKm,
    'zoomLevel': zoomLevel,
    'downloadedAt': downloadedAt.toIso8601String(),
    'sizeBytes': sizeBytes,
    'isComplete': isComplete,
  };

  factory OfflineMapRegion.fromJson(Map<String, dynamic> json) => OfflineMapRegion(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    centerLat: (json['centerLat'] ?? 0).toDouble(),
    centerLng: (json['centerLng'] ?? 0).toDouble(),
    radiusKm: (json['radiusKm'] ?? 0).toDouble(),
    zoomLevel: json['zoomLevel'] ?? 15,
    downloadedAt: DateTime.parse(json['downloadedAt'] ?? DateTime.now().toIso8601String()),
    sizeBytes: json['sizeBytes'] ?? 0,
    isComplete: json['isComplete'] ?? false,
  );
}
