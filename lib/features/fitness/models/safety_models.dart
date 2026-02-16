import 'package:hive/hive.dart';

part 'safety_models.g.dart';

/// Beacon Session - Live location sharing during workouts
@HiveType(typeId: 80)
class BeaconSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String activityId;

  @HiveField(2)
  final DateTime startTime;

  @HiveField(3)
  final DateTime? endTime;

  @HiveField(4)
  final bool isActive;

  @HiveField(5)
  final List<BeaconContact> contacts;

  @HiveField(6)
  final String shareLink;

  @HiveField(7)
  final int updateIntervalSeconds;

  @HiveField(8)
  final List<LocationUpdate> locationHistory;

  @HiveField(9)
  final bool autoEndOnActivityComplete;

  BeaconSession({
    required this.id,
    required this.activityId,
    required this.startTime,
    this.endTime,
    this.isActive = true,
    required this.contacts,
    required this.shareLink,
    this.updateIntervalSeconds = 30,
    this.locationHistory = const [],
    this.autoEndOnActivityComplete = true,
  });

  Duration get activeDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  LocationUpdate? get lastLocation {
    return locationHistory.isNotEmpty ? locationHistory.last : null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityId': activityId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'isActive': isActive,
    'contacts': contacts.map((c) => c.toJson()).toList(),
    'shareLink': shareLink,
    'updateIntervalSeconds': updateIntervalSeconds,
    'locationHistory': locationHistory.map((l) => l.toJson()).toList(),
    'autoEndOnActivityComplete': autoEndOnActivityComplete,
  };

  factory BeaconSession.fromJson(Map<String, dynamic> json) => BeaconSession(
    id: json['id'] ?? '',
    activityId: json['activityId'] ?? '',
    startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    isActive: json['isActive'] ?? true,
    contacts: (json['contacts'] as List<dynamic>?)
        ?.map((c) => BeaconContact.fromJson(c))
        .toList() ?? [],
    shareLink: json['shareLink'] ?? '',
    updateIntervalSeconds: json['updateIntervalSeconds'] ?? 30,
    locationHistory: (json['locationHistory'] as List<dynamic>?)
        ?.map((l) => LocationUpdate.fromJson(l))
        .toList() ?? [],
    autoEndOnActivityComplete: json['autoEndOnActivityComplete'] ?? true,
  );
}

@HiveType(typeId: 81)
class BeaconContact extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? email;

  @HiveField(3)
  final String? phone;

  @HiveField(4)
  final bool notifyOnStart;

  @HiveField(5)
  final bool notifyOnEnd;

  @HiveField(6)
  final bool notifyOnEmergency;

  BeaconContact({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.notifyOnStart = true,
    this.notifyOnEnd = true,
    this.notifyOnEmergency = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'notifyOnStart': notifyOnStart,
    'notifyOnEnd': notifyOnEnd,
    'notifyOnEmergency': notifyOnEmergency,
  };

  factory BeaconContact.fromJson(Map<String, dynamic> json) => BeaconContact(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    email: json['email'],
    phone: json['phone'],
    notifyOnStart: json['notifyOnStart'] ?? true,
    notifyOnEnd: json['notifyOnEnd'] ?? true,
    notifyOnEmergency: json['notifyOnEmergency'] ?? true,
  );
}

@HiveType(typeId: 82)
class LocationUpdate extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final double? altitude;

  @HiveField(3)
  final double? speed; // m/s

  @HiveField(4)
  final double? heading; // degrees

  @HiveField(5)
  final double? accuracy; // meters

  @HiveField(6)
  final DateTime timestamp;

  LocationUpdate({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.heading,
    this.accuracy,
    required this.timestamp,
  });

  String get formattedSpeed {
    if (speed == null) return '-';
    final kmh = speed! * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'speed': speed,
    'heading': heading,
    'accuracy': accuracy,
    'timestamp': timestamp.toIso8601String(),
  };

  factory LocationUpdate.fromJson(Map<String, dynamic> json) => LocationUpdate(
    latitude: (json['latitude'] ?? 0).toDouble(),
    longitude: (json['longitude'] ?? 0).toDouble(),
    altitude: json['altitude']?.toDouble(),
    speed: json['speed']?.toDouble(),
    heading: json['heading']?.toDouble(),
    accuracy: json['accuracy']?.toDouble(),
    timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
  );
}

/// Live Performance Data - Real-time workout metrics
@HiveType(typeId: 83)
class LivePerformanceData extends HiveObject {
  @HiveField(0)
  final String activityId;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final int? currentHeartRate;

  @HiveField(3)
  final double? currentPace; // min/km

  @HiveField(4)
  final double? currentSpeed; // km/h

  @HiveField(5)
  final int? currentPower; // watts

  @HiveField(6)
  final int? currentCadence;

  @HiveField(7)
  final double currentDistanceKm;

  @HiveField(8)
  final int elapsedSeconds;

  @HiveField(9)
  final int? currentCalories;

  @HiveField(10)
  final double? currentElevation;

  @HiveField(11)
  final String? currentHeartRateZone;

  @HiveField(12)
  final int? currentLapNumber;

  @HiveField(13)
  final double? lapDistanceKm;

  @HiveField(14)
  final int? lapTimeSeconds;

  LivePerformanceData({
    required this.activityId,
    required this.timestamp,
    this.currentHeartRate,
    this.currentPace,
    this.currentSpeed,
    this.currentPower,
    this.currentCadence,
    required this.currentDistanceKm,
    required this.elapsedSeconds,
    this.currentCalories,
    this.currentElevation,
    this.currentHeartRateZone,
    this.currentLapNumber,
    this.lapDistanceKm,
    this.lapTimeSeconds,
  });

  String get formattedPace {
    if (currentPace == null) return '-';
    final minutes = currentPace!.floor();
    final seconds = ((currentPace! - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  String get formattedDuration {
    final hours = elapsedSeconds ~/ 3600;
    final minutes = (elapsedSeconds % 3600) ~/ 60;
    final seconds = elapsedSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'activityId': activityId,
    'timestamp': timestamp.toIso8601String(),
    'currentHeartRate': currentHeartRate,
    'currentPace': currentPace,
    'currentSpeed': currentSpeed,
    'currentPower': currentPower,
    'currentCadence': currentCadence,
    'currentDistanceKm': currentDistanceKm,
    'elapsedSeconds': elapsedSeconds,
    'currentCalories': currentCalories,
    'currentElevation': currentElevation,
    'currentHeartRateZone': currentHeartRateZone,
    'currentLapNumber': currentLapNumber,
    'lapDistanceKm': lapDistanceKm,
    'lapTimeSeconds': lapTimeSeconds,
  };

  factory LivePerformanceData.fromJson(Map<String, dynamic> json) => LivePerformanceData(
    activityId: json['activityId'] ?? '',
    timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    currentHeartRate: json['currentHeartRate'],
    currentPace: json['currentPace']?.toDouble(),
    currentSpeed: json['currentSpeed']?.toDouble(),
    currentPower: json['currentPower'],
    currentCadence: json['currentCadence'],
    currentDistanceKm: (json['currentDistanceKm'] ?? 0).toDouble(),
    elapsedSeconds: json['elapsedSeconds'] ?? 0,
    currentCalories: json['currentCalories'],
    currentElevation: json['currentElevation']?.toDouble(),
    currentHeartRateZone: json['currentHeartRateZone'],
    currentLapNumber: json['currentLapNumber'],
    lapDistanceKm: json['lapDistanceKm']?.toDouble(),
    lapTimeSeconds: json['lapTimeSeconds'],
  );
}

/// Weather Data - Conditions during/for workout
@HiveType(typeId: 84)
class WorkoutWeather extends HiveObject {
  @HiveField(0)
  final String activityId;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final double temperature; // Celsius

  @HiveField(3)
  final double feelsLike;

  @HiveField(4)
  final int humidity; // percentage

  @HiveField(5)
  final double windSpeed; // km/h

  @HiveField(6)
  final int windDirection; // degrees

  @HiveField(7)
  final String condition; // sunny, cloudy, rain, etc.

  @HiveField(8)
  final String conditionIcon;

  @HiveField(9)
  final int? uvIndex;

  @HiveField(10)
  final double? visibility; // km

  @HiveField(11)
  final int? airQualityIndex;

  @HiveField(12)
  final String? sunrise;

  @HiveField(13)
  final String? sunset;

  WorkoutWeather({
    required this.activityId,
    required this.timestamp,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.condition,
    required this.conditionIcon,
    this.uvIndex,
    this.visibility,
    this.airQualityIndex,
    this.sunrise,
    this.sunset,
  });

  String get temperatureFormatted => '${temperature.round()}°C';
  String get feelsLikeFormatted => '${feelsLike.round()}°C';
  String get windFormatted => '${windSpeed.round()} km/h';

  String get conditionEmoji {
    switch (condition.toLowerCase()) {
      case 'sunny':
      case 'clear': return '☀️';
      case 'partly cloudy': return '⛅';
      case 'cloudy': return '☁️';
      case 'rain':
      case 'light rain': return '🌧️';
      case 'heavy rain': return '⛈️';
      case 'snow': return '❄️';
      case 'fog': return '🌫️';
      case 'wind': return '💨';
      default: return '🌤️';
    }
  }

  String get runningAdvice {
    if (temperature > 30) return 'Hot conditions - stay hydrated!';
    if (temperature < 5) return 'Cold conditions - dress in layers';
    if (humidity > 80) return 'High humidity - pace yourself';
    if (windSpeed > 30) return 'Strong winds - consider indoor workout';
    if (uvIndex != null && uvIndex! > 7) return 'High UV - wear sunscreen';
    if (airQualityIndex != null && airQualityIndex! > 100) return 'Poor air quality - consider indoor workout';
    return 'Good conditions for outdoor activity';
  }

  Map<String, dynamic> toJson() => {
    'activityId': activityId,
    'timestamp': timestamp.toIso8601String(),
    'temperature': temperature,
    'feelsLike': feelsLike,
    'humidity': humidity,
    'windSpeed': windSpeed,
    'windDirection': windDirection,
    'condition': condition,
    'conditionIcon': conditionIcon,
    'uvIndex': uvIndex,
    'visibility': visibility,
    'airQualityIndex': airQualityIndex,
    'sunrise': sunrise,
    'sunset': sunset,
  };

  factory WorkoutWeather.fromJson(Map<String, dynamic> json) => WorkoutWeather(
    activityId: json['activityId'] ?? '',
    timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    temperature: (json['temperature'] ?? 20).toDouble(),
    feelsLike: (json['feelsLike'] ?? 20).toDouble(),
    humidity: json['humidity'] ?? 50,
    windSpeed: (json['windSpeed'] ?? 0).toDouble(),
    windDirection: json['windDirection'] ?? 0,
    condition: json['condition'] ?? 'clear',
    conditionIcon: json['conditionIcon'] ?? '01d',
    uvIndex: json['uvIndex'],
    visibility: json['visibility']?.toDouble(),
    airQualityIndex: json['airQualityIndex'],
    sunrise: json['sunrise'],
    sunset: json['sunset'],
  );
}

/// Emergency Contact for safety features
@HiveType(typeId: 85)
class EmergencyContact extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phone;

  @HiveField(3)
  final String? email;

  @HiveField(4)
  final String relationship;

  @HiveField(5)
  final bool isPrimary;

  @HiveField(6)
  final bool autoAlertOnCrash;

  @HiveField(7)
  final bool includeInBeacon;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.relationship,
    this.isPrimary = false,
    this.autoAlertOnCrash = true,
    this.includeInBeacon = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'relationship': relationship,
    'isPrimary': isPrimary,
    'autoAlertOnCrash': autoAlertOnCrash,
    'includeInBeacon': includeInBeacon,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    email: json['email'],
    relationship: json['relationship'] ?? '',
    isPrimary: json['isPrimary'] ?? false,
    autoAlertOnCrash: json['autoAlertOnCrash'] ?? true,
    includeInBeacon: json['includeInBeacon'] ?? true,
  );
}

/// Crash Detection Event
@HiveType(typeId: 86)
class CrashDetectionEvent extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String activityId;

  @HiveField(2)
  final DateTime detectedAt;

  @HiveField(3)
  final double latitude;

  @HiveField(4)
  final double longitude;

  @HiveField(5)
  final String severity; // potential, moderate, severe

  @HiveField(6)
  final bool wasDismissed;

  @HiveField(7)
  final bool emergencyServicesContacted;

  @HiveField(8)
  final List<String> contactsNotified;

  @HiveField(9)
  final DateTime? resolvedAt;

  CrashDetectionEvent({
    required this.id,
    required this.activityId,
    required this.detectedAt,
    required this.latitude,
    required this.longitude,
    required this.severity,
    this.wasDismissed = false,
    this.emergencyServicesContacted = false,
    this.contactsNotified = const [],
    this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityId': activityId,
    'detectedAt': detectedAt.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'severity': severity,
    'wasDismissed': wasDismissed,
    'emergencyServicesContacted': emergencyServicesContacted,
    'contactsNotified': contactsNotified,
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  factory CrashDetectionEvent.fromJson(Map<String, dynamic> json) => CrashDetectionEvent(
    id: json['id'] ?? '',
    activityId: json['activityId'] ?? '',
    detectedAt: DateTime.parse(json['detectedAt'] ?? DateTime.now().toIso8601String()),
    latitude: (json['latitude'] ?? 0).toDouble(),
    longitude: (json['longitude'] ?? 0).toDouble(),
    severity: json['severity'] ?? 'potential',
    wasDismissed: json['wasDismissed'] ?? false,
    emergencyServicesContacted: json['emergencyServicesContacted'] ?? false,
    contactsNotified: List<String>.from(json['contactsNotified'] ?? []),
    resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt']) : null,
  );
}
