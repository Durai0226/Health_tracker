// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'safety_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BeaconSessionAdapter extends TypeAdapter<BeaconSession> {
  @override
  final int typeId = 80;

  @override
  BeaconSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BeaconSession(
      id: fields[0] as String,
      activityId: fields[1] as String,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime?,
      isActive: fields[4] as bool,
      contacts: (fields[5] as List).cast<BeaconContact>(),
      shareLink: fields[6] as String,
      updateIntervalSeconds: fields[7] as int,
      locationHistory: (fields[8] as List).cast<LocationUpdate>(),
      autoEndOnActivityComplete: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BeaconSession obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.activityId)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.contacts)
      ..writeByte(6)
      ..write(obj.shareLink)
      ..writeByte(7)
      ..write(obj.updateIntervalSeconds)
      ..writeByte(8)
      ..write(obj.locationHistory)
      ..writeByte(9)
      ..write(obj.autoEndOnActivityComplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeaconSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BeaconContactAdapter extends TypeAdapter<BeaconContact> {
  @override
  final int typeId = 81;

  @override
  BeaconContact read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BeaconContact(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String?,
      phone: fields[3] as String?,
      notifyOnStart: fields[4] as bool,
      notifyOnEnd: fields[5] as bool,
      notifyOnEmergency: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BeaconContact obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.notifyOnStart)
      ..writeByte(5)
      ..write(obj.notifyOnEnd)
      ..writeByte(6)
      ..write(obj.notifyOnEmergency);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeaconContactAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocationUpdateAdapter extends TypeAdapter<LocationUpdate> {
  @override
  final int typeId = 82;

  @override
  LocationUpdate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocationUpdate(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      altitude: fields[2] as double?,
      speed: fields[3] as double?,
      heading: fields[4] as double?,
      accuracy: fields[5] as double?,
      timestamp: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LocationUpdate obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.altitude)
      ..writeByte(3)
      ..write(obj.speed)
      ..writeByte(4)
      ..write(obj.heading)
      ..writeByte(5)
      ..write(obj.accuracy)
      ..writeByte(6)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationUpdateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LivePerformanceDataAdapter extends TypeAdapter<LivePerformanceData> {
  @override
  final int typeId = 83;

  @override
  LivePerformanceData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LivePerformanceData(
      activityId: fields[0] as String,
      timestamp: fields[1] as DateTime,
      currentHeartRate: fields[2] as int?,
      currentPace: fields[3] as double?,
      currentSpeed: fields[4] as double?,
      currentPower: fields[5] as int?,
      currentCadence: fields[6] as int?,
      currentDistanceKm: fields[7] as double,
      elapsedSeconds: fields[8] as int,
      currentCalories: fields[9] as int?,
      currentElevation: fields[10] as double?,
      currentHeartRateZone: fields[11] as String?,
      currentLapNumber: fields[12] as int?,
      lapDistanceKm: fields[13] as double?,
      lapTimeSeconds: fields[14] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, LivePerformanceData obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.activityId)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.currentHeartRate)
      ..writeByte(3)
      ..write(obj.currentPace)
      ..writeByte(4)
      ..write(obj.currentSpeed)
      ..writeByte(5)
      ..write(obj.currentPower)
      ..writeByte(6)
      ..write(obj.currentCadence)
      ..writeByte(7)
      ..write(obj.currentDistanceKm)
      ..writeByte(8)
      ..write(obj.elapsedSeconds)
      ..writeByte(9)
      ..write(obj.currentCalories)
      ..writeByte(10)
      ..write(obj.currentElevation)
      ..writeByte(11)
      ..write(obj.currentHeartRateZone)
      ..writeByte(12)
      ..write(obj.currentLapNumber)
      ..writeByte(13)
      ..write(obj.lapDistanceKm)
      ..writeByte(14)
      ..write(obj.lapTimeSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LivePerformanceDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutWeatherAdapter extends TypeAdapter<WorkoutWeather> {
  @override
  final int typeId = 84;

  @override
  WorkoutWeather read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutWeather(
      activityId: fields[0] as String,
      timestamp: fields[1] as DateTime,
      temperature: fields[2] as double,
      feelsLike: fields[3] as double,
      humidity: fields[4] as int,
      windSpeed: fields[5] as double,
      windDirection: fields[6] as int,
      condition: fields[7] as String,
      conditionIcon: fields[8] as String,
      uvIndex: fields[9] as int?,
      visibility: fields[10] as double?,
      airQualityIndex: fields[11] as int?,
      sunrise: fields[12] as String?,
      sunset: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutWeather obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.activityId)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.temperature)
      ..writeByte(3)
      ..write(obj.feelsLike)
      ..writeByte(4)
      ..write(obj.humidity)
      ..writeByte(5)
      ..write(obj.windSpeed)
      ..writeByte(6)
      ..write(obj.windDirection)
      ..writeByte(7)
      ..write(obj.condition)
      ..writeByte(8)
      ..write(obj.conditionIcon)
      ..writeByte(9)
      ..write(obj.uvIndex)
      ..writeByte(10)
      ..write(obj.visibility)
      ..writeByte(11)
      ..write(obj.airQualityIndex)
      ..writeByte(12)
      ..write(obj.sunrise)
      ..writeByte(13)
      ..write(obj.sunset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutWeatherAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EmergencyContactAdapter extends TypeAdapter<EmergencyContact> {
  @override
  final int typeId = 85;

  @override
  EmergencyContact read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmergencyContact(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String,
      email: fields[3] as String?,
      relationship: fields[4] as String,
      isPrimary: fields[5] as bool,
      autoAlertOnCrash: fields[6] as bool,
      includeInBeacon: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, EmergencyContact obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.relationship)
      ..writeByte(5)
      ..write(obj.isPrimary)
      ..writeByte(6)
      ..write(obj.autoAlertOnCrash)
      ..writeByte(7)
      ..write(obj.includeInBeacon);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContactAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CrashDetectionEventAdapter extends TypeAdapter<CrashDetectionEvent> {
  @override
  final int typeId = 86;

  @override
  CrashDetectionEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CrashDetectionEvent(
      id: fields[0] as String,
      activityId: fields[1] as String,
      detectedAt: fields[2] as DateTime,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      severity: fields[5] as String,
      wasDismissed: fields[6] as bool,
      emergencyServicesContacted: fields[7] as bool,
      contactsNotified: (fields[8] as List).cast<String>(),
      resolvedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CrashDetectionEvent obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.activityId)
      ..writeByte(2)
      ..write(obj.detectedAt)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.severity)
      ..writeByte(6)
      ..write(obj.wasDismissed)
      ..writeByte(7)
      ..write(obj.emergencyServicesContacted)
      ..writeByte(8)
      ..write(obj.contactsNotified)
      ..writeByte(9)
      ..write(obj.resolvedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrashDetectionEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
