import 'package:flutter/material.dart';

/// Safety feature models for Luna Cycle
/// Emergency contacts, SOS alerts, location sharing based on Safeline case study

/// Emergency contact
class LunaEmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? relationship;
  final bool isPrimary;
  final bool canReceiveAlerts;
  final bool canSeeLocation;
  final String? photoUrl;
  final DateTime createdAt;

  const LunaEmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.relationship,
    this.isPrimary = false,
    this.canReceiveAlerts = true,
    this.canSeeLocation = false,
    this.photoUrl,
    required this.createdAt,
  });

  LunaEmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? relationship,
    bool? isPrimary,
    bool? canReceiveAlerts,
    bool? canSeeLocation,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return LunaEmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      canReceiveAlerts: canReceiveAlerts ?? this.canReceiveAlerts,
      canSeeLocation: canSeeLocation ?? this.canSeeLocation,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'relationship': relationship,
    'isPrimary': isPrimary,
    'canReceiveAlerts': canReceiveAlerts,
    'canSeeLocation': canSeeLocation,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LunaEmergencyContact.fromJson(Map<String, dynamic> json) {
    return LunaEmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      relationship: json['relationship'] as String?,
      isPrimary: json['isPrimary'] as bool? ?? false,
      canReceiveAlerts: json['canReceiveAlerts'] as bool? ?? true,
      canSeeLocation: json['canSeeLocation'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Safety alert sent to contacts
class LunaSafetyAlert {
  final String id;
  final String userId;
  final LunaAlertType type;
  final LunaAlertStatus status;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? customMessage;
  final DateTime triggeredAt;
  final DateTime? cancelledAt;
  final DateTime? resolvedAt;
  final List<String> notifiedContactIds;
  final String? batteryLevel;
  final bool isTest;

  const LunaSafetyAlert({
    required this.id,
    required this.userId,
    required this.type,
    this.status = LunaAlertStatus.active,
    this.latitude,
    this.longitude,
    this.address,
    this.customMessage,
    required this.triggeredAt,
    this.cancelledAt,
    this.resolvedAt,
    this.notifiedContactIds = const [],
    this.batteryLevel,
    this.isTest = false,
  });

  LunaSafetyAlert copyWith({
    String? id,
    String? userId,
    LunaAlertType? type,
    LunaAlertStatus? status,
    double? latitude,
    double? longitude,
    String? address,
    String? customMessage,
    DateTime? triggeredAt,
    DateTime? cancelledAt,
    DateTime? resolvedAt,
    List<String>? notifiedContactIds,
    String? batteryLevel,
    bool? isTest,
  }) {
    return LunaSafetyAlert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      customMessage: customMessage ?? this.customMessage,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      notifiedContactIds: notifiedContactIds ?? this.notifiedContactIds,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isTest: isTest ?? this.isTest,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.index,
    'status': status.index,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'customMessage': customMessage,
    'triggeredAt': triggeredAt.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'notifiedContactIds': notifiedContactIds,
    'batteryLevel': batteryLevel,
    'isTest': isTest,
  };

  factory LunaSafetyAlert.fromJson(Map<String, dynamic> json) {
    return LunaSafetyAlert(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: LunaAlertType.values[json['type'] as int? ?? 0],
      status: LunaAlertStatus.values[json['status'] as int? ?? 0],
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      address: json['address'] as String?,
      customMessage: json['customMessage'] as String?,
      triggeredAt: DateTime.parse(json['triggeredAt'] as String),
      cancelledAt: json['cancelledAt'] != null 
          ? DateTime.parse(json['cancelledAt'] as String) 
          : null,
      resolvedAt: json['resolvedAt'] != null 
          ? DateTime.parse(json['resolvedAt'] as String) 
          : null,
      notifiedContactIds: (json['notifiedContactIds'] as List<dynamic>?)?.cast<String>() ?? [],
      batteryLevel: json['batteryLevel'] as String?,
      isTest: json['isTest'] as bool? ?? false,
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
  
  String get googleMapsUrl => hasLocation 
      ? 'https://www.google.com/maps?q=$latitude,$longitude' 
      : '';
}

/// Location sharing session
class LunaLocationShare {
  final String id;
  final String userId;
  final String sharedWithId;
  final String sharedWithName;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? currentAddress;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final LunaShareDuration duration;
  final DateTime? lastUpdatedAt;

  const LunaLocationShare({
    required this.id,
    required this.userId,
    required this.sharedWithId,
    required this.sharedWithName,
    this.currentLatitude,
    this.currentLongitude,
    this.currentAddress,
    required this.startedAt,
    this.expiresAt,
    this.isActive = true,
    required this.duration,
    this.lastUpdatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'sharedWithId': sharedWithId,
    'sharedWithName': sharedWithName,
    'currentLatitude': currentLatitude,
    'currentLongitude': currentLongitude,
    'currentAddress': currentAddress,
    'startedAt': startedAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'isActive': isActive,
    'duration': duration.index,
    'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
  };

  factory LunaLocationShare.fromJson(Map<String, dynamic> json) {
    return LunaLocationShare(
      id: json['id'] as String,
      userId: json['userId'] as String,
      sharedWithId: json['sharedWithId'] as String,
      sharedWithName: json['sharedWithName'] as String,
      currentLatitude: json['currentLatitude'] as double?,
      currentLongitude: json['currentLongitude'] as double?,
      currentAddress: json['currentAddress'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt'] as String) 
          : null,
      isActive: json['isActive'] as bool? ?? true,
      duration: LunaShareDuration.values[json['duration'] as int? ?? 0],
      lastUpdatedAt: json['lastUpdatedAt'] != null 
          ? DateTime.parse(json['lastUpdatedAt'] as String) 
          : null,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

/// Safety settings
class LunaSafetySettings {
  final bool sosEnabled;
  final bool shakeToSOS;
  final int shakeSensitivity; // 1-5
  final bool autoShareLocation;
  final bool sendSMS;
  final bool makeCall;
  final String? customSOSMessage;
  final bool countdownEnabled;
  final int countdownSeconds;
  final bool silentMode; // No sound when triggering SOS
  final bool fakeCancelCode; // Require PIN to cancel SOS
  final String? cancelPin;

  const LunaSafetySettings({
    this.sosEnabled = true,
    this.shakeToSOS = false,
    this.shakeSensitivity = 3,
    this.autoShareLocation = true,
    this.sendSMS = true,
    this.makeCall = false,
    this.customSOSMessage,
    this.countdownEnabled = true,
    this.countdownSeconds = 5,
    this.silentMode = false,
    this.fakeCancelCode = false,
    this.cancelPin,
  });

  LunaSafetySettings copyWith({
    bool? sosEnabled,
    bool? shakeToSOS,
    int? shakeSensitivity,
    bool? autoShareLocation,
    bool? sendSMS,
    bool? makeCall,
    String? customSOSMessage,
    bool? countdownEnabled,
    int? countdownSeconds,
    bool? silentMode,
    bool? fakeCancelCode,
    String? cancelPin,
  }) {
    return LunaSafetySettings(
      sosEnabled: sosEnabled ?? this.sosEnabled,
      shakeToSOS: shakeToSOS ?? this.shakeToSOS,
      shakeSensitivity: shakeSensitivity ?? this.shakeSensitivity,
      autoShareLocation: autoShareLocation ?? this.autoShareLocation,
      sendSMS: sendSMS ?? this.sendSMS,
      makeCall: makeCall ?? this.makeCall,
      customSOSMessage: customSOSMessage ?? this.customSOSMessage,
      countdownEnabled: countdownEnabled ?? this.countdownEnabled,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      silentMode: silentMode ?? this.silentMode,
      fakeCancelCode: fakeCancelCode ?? this.fakeCancelCode,
      cancelPin: cancelPin ?? this.cancelPin,
    );
  }

  Map<String, dynamic> toJson() => {
    'sosEnabled': sosEnabled,
    'shakeToSOS': shakeToSOS,
    'shakeSensitivity': shakeSensitivity,
    'autoShareLocation': autoShareLocation,
    'sendSMS': sendSMS,
    'makeCall': makeCall,
    'customSOSMessage': customSOSMessage,
    'countdownEnabled': countdownEnabled,
    'countdownSeconds': countdownSeconds,
    'silentMode': silentMode,
    'fakeCancelCode': fakeCancelCode,
    'cancelPin': cancelPin,
  };

  factory LunaSafetySettings.fromJson(Map<String, dynamic> json) {
    return LunaSafetySettings(
      sosEnabled: json['sosEnabled'] as bool? ?? true,
      shakeToSOS: json['shakeToSOS'] as bool? ?? false,
      shakeSensitivity: json['shakeSensitivity'] as int? ?? 3,
      autoShareLocation: json['autoShareLocation'] as bool? ?? true,
      sendSMS: json['sendSMS'] as bool? ?? true,
      makeCall: json['makeCall'] as bool? ?? false,
      customSOSMessage: json['customSOSMessage'] as String?,
      countdownEnabled: json['countdownEnabled'] as bool? ?? true,
      countdownSeconds: json['countdownSeconds'] as int? ?? 5,
      silentMode: json['silentMode'] as bool? ?? false,
      fakeCancelCode: json['fakeCancelCode'] as bool? ?? false,
      cancelPin: json['cancelPin'] as String?,
    );
  }
}

/// Alert types
enum LunaAlertType {
  sos,
  checkIn,
  journeyStart,
  journeyEnd,
  timer,
  panic,
}

extension LunaAlertTypeExtension on LunaAlertType {
  String get displayName {
    switch (this) {
      case LunaAlertType.sos: return 'SOS Alert';
      case LunaAlertType.checkIn: return 'Check-in Request';
      case LunaAlertType.journeyStart: return 'Journey Started';
      case LunaAlertType.journeyEnd: return 'Journey Ended';
      case LunaAlertType.timer: return 'Timer Alert';
      case LunaAlertType.panic: return 'Panic Alert';
    }
  }

  IconData get icon {
    switch (this) {
      case LunaAlertType.sos: return Icons.sos;
      case LunaAlertType.checkIn: return Icons.check_circle_outline;
      case LunaAlertType.journeyStart: return Icons.directions_walk;
      case LunaAlertType.journeyEnd: return Icons.flag;
      case LunaAlertType.timer: return Icons.timer;
      case LunaAlertType.panic: return Icons.warning_amber;
    }
  }

  Color get color {
    switch (this) {
      case LunaAlertType.sos: return const Color(0xFFFF5252);
      case LunaAlertType.checkIn: return const Color(0xFF4CAF50);
      case LunaAlertType.journeyStart: return const Color(0xFF2196F3);
      case LunaAlertType.journeyEnd: return const Color(0xFF4CAF50);
      case LunaAlertType.timer: return const Color(0xFFFF9800);
      case LunaAlertType.panic: return const Color(0xFFFF5252);
    }
  }

  String get defaultMessage {
    switch (this) {
      case LunaAlertType.sos: 
        return 'I need help! This is an emergency SOS alert from Luna Cycle.';
      case LunaAlertType.checkIn: 
        return 'Please check on me. I haven\'t responded to my safety check-in.';
      case LunaAlertType.journeyStart: 
        return 'I\'ve started a journey and will share my location until I arrive safely.';
      case LunaAlertType.journeyEnd: 
        return 'I\'ve arrived safely at my destination.';
      case LunaAlertType.timer: 
        return 'My safety timer has expired. Please check on me.';
      case LunaAlertType.panic: 
        return 'URGENT: I\'m in danger and need immediate help!';
    }
  }
}

/// Alert status
enum LunaAlertStatus {
  active,
  cancelled,
  resolved,
  expired,
  test,
}

extension LunaAlertStatusExtension on LunaAlertStatus {
  String get displayName {
    switch (this) {
      case LunaAlertStatus.active: return 'Active';
      case LunaAlertStatus.cancelled: return 'Cancelled';
      case LunaAlertStatus.resolved: return 'Resolved';
      case LunaAlertStatus.expired: return 'Expired';
      case LunaAlertStatus.test: return 'Test';
    }
  }

  Color get color {
    switch (this) {
      case LunaAlertStatus.active: return const Color(0xFFFF5252);
      case LunaAlertStatus.cancelled: return const Color(0xFF9E9E9E);
      case LunaAlertStatus.resolved: return const Color(0xFF4CAF50);
      case LunaAlertStatus.expired: return const Color(0xFFFF9800);
      case LunaAlertStatus.test: return const Color(0xFF2196F3);
    }
  }
}

/// Location share duration options
enum LunaShareDuration {
  minutes15,
  minutes30,
  hour1,
  hours2,
  hours4,
  hours8,
  untilArrival,
  indefinite,
}

extension LunaShareDurationExtension on LunaShareDuration {
  String get displayName {
    switch (this) {
      case LunaShareDuration.minutes15: return '15 minutes';
      case LunaShareDuration.minutes30: return '30 minutes';
      case LunaShareDuration.hour1: return '1 hour';
      case LunaShareDuration.hours2: return '2 hours';
      case LunaShareDuration.hours4: return '4 hours';
      case LunaShareDuration.hours8: return '8 hours';
      case LunaShareDuration.untilArrival: return 'Until I arrive';
      case LunaShareDuration.indefinite: return 'Until I stop';
    }
  }

  Duration? get duration {
    switch (this) {
      case LunaShareDuration.minutes15: return const Duration(minutes: 15);
      case LunaShareDuration.minutes30: return const Duration(minutes: 30);
      case LunaShareDuration.hour1: return const Duration(hours: 1);
      case LunaShareDuration.hours2: return const Duration(hours: 2);
      case LunaShareDuration.hours4: return const Duration(hours: 4);
      case LunaShareDuration.hours8: return const Duration(hours: 8);
      case LunaShareDuration.untilArrival: return null;
      case LunaShareDuration.indefinite: return null;
    }
  }
}

/// Relationship options for contacts
class LunaRelationships {
  static const List<String> options = [
    'Partner',
    'Spouse',
    'Parent',
    'Sibling',
    'Friend',
    'Roommate',
    'Colleague',
    'Other',
  ];
}

/// Emergency helplines by country
class LunaEmergencyHelplines {
  static const Map<String, List<LunaHelpline>> byCountry = {
    'US': [
      LunaHelpline('911', 'Emergency', LunaHelplineType.emergency),
      LunaHelpline('1-800-799-7233', 'Domestic Violence Hotline', LunaHelplineType.domesticViolence),
      LunaHelpline('1-800-656-4673', 'RAINN Sexual Assault', LunaHelplineType.sexualAssault),
    ],
    'UK': [
      LunaHelpline('999', 'Emergency', LunaHelplineType.emergency),
      LunaHelpline('0808 2000 247', 'National Domestic Abuse', LunaHelplineType.domesticViolence),
    ],
    'IN': [
      LunaHelpline('112', 'Emergency', LunaHelplineType.emergency),
      LunaHelpline('181', 'Women Helpline', LunaHelplineType.womensHelpline),
      LunaHelpline('1091', 'Women in Distress', LunaHelplineType.womensHelpline),
    ],
    'AU': [
      LunaHelpline('000', 'Emergency', LunaHelplineType.emergency),
      LunaHelpline('1800 737 732', '1800RESPECT', LunaHelplineType.domesticViolence),
    ],
  };
}

/// Helpline entry
class LunaHelpline {
  final String number;
  final String name;
  final LunaHelplineType type;

  const LunaHelpline(this.number, this.name, this.type);
}

/// Helpline types
enum LunaHelplineType {
  emergency,
  domesticViolence,
  sexualAssault,
  womensHelpline,
  mentalHealth,
  suicide,
}

extension LunaHelplineTypeExtension on LunaHelplineType {
  String get displayName {
    switch (this) {
      case LunaHelplineType.emergency: return 'Emergency';
      case LunaHelplineType.domesticViolence: return 'Domestic Violence';
      case LunaHelplineType.sexualAssault: return 'Sexual Assault';
      case LunaHelplineType.womensHelpline: return 'Women\'s Helpline';
      case LunaHelplineType.mentalHealth: return 'Mental Health';
      case LunaHelplineType.suicide: return 'Suicide Prevention';
    }
  }

  IconData get icon {
    switch (this) {
      case LunaHelplineType.emergency: return Icons.local_hospital;
      case LunaHelplineType.domesticViolence: return Icons.shield;
      case LunaHelplineType.sexualAssault: return Icons.support;
      case LunaHelplineType.womensHelpline: return Icons.woman;
      case LunaHelplineType.mentalHealth: return Icons.psychology;
      case LunaHelplineType.suicide: return Icons.call;
    }
  }
}
