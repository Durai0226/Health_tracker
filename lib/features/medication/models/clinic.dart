import 'dart:convert';

/// Operating hours for a single day
class DayHours {
  final bool isOpen;
  final String? openTime; // HH:mm format
  final String? closeTime; // HH:mm format

  const DayHours({
    this.isOpen = false,
    this.openTime,
    this.closeTime,
  });

  factory DayHours.closed() => const DayHours(isOpen: false);

  factory DayHours.open(String open, String close) => DayHours(
        isOpen: true,
        openTime: open,
        closeTime: close,
      );

  Map<String, dynamic> toJson() => {
        'isOpen': isOpen,
        'openTime': openTime,
        'closeTime': closeTime,
      };

  factory DayHours.fromJson(Map<String, dynamic> json) => DayHours(
        isOpen: json['isOpen'] as bool? ?? false,
        openTime: json['openTime'] as String?,
        closeTime: json['closeTime'] as String?,
      );

  String get displayText {
    if (!isOpen) return 'Closed';
    if (openTime == null || closeTime == null) return 'Hours not set';
    return '$openTime - $closeTime';
  }

  DayHours copyWith({
    bool? isOpen,
    String? openTime,
    String? closeTime,
  }) =>
      DayHours(
        isOpen: isOpen ?? this.isOpen,
        openTime: openTime ?? this.openTime,
        closeTime: closeTime ?? this.closeTime,
      );
}

/// Weekly operating hours
class OperatingHours {
  final DayHours monday;
  final DayHours tuesday;
  final DayHours wednesday;
  final DayHours thursday;
  final DayHours friday;
  final DayHours saturday;
  final DayHours sunday;

  const OperatingHours({
    this.monday = const DayHours(),
    this.tuesday = const DayHours(),
    this.wednesday = const DayHours(),
    this.thursday = const DayHours(),
    this.friday = const DayHours(),
    this.saturday = const DayHours(),
    this.sunday = const DayHours(),
  });

  factory OperatingHours.weekdays({
    required String openTime,
    required String closeTime,
  }) =>
      OperatingHours(
        monday: DayHours.open(openTime, closeTime),
        tuesday: DayHours.open(openTime, closeTime),
        wednesday: DayHours.open(openTime, closeTime),
        thursday: DayHours.open(openTime, closeTime),
        friday: DayHours.open(openTime, closeTime),
        saturday: DayHours.closed(),
        sunday: DayHours.closed(),
      );

  factory OperatingHours.allDays({
    required String openTime,
    required String closeTime,
  }) =>
      OperatingHours(
        monday: DayHours.open(openTime, closeTime),
        tuesday: DayHours.open(openTime, closeTime),
        wednesday: DayHours.open(openTime, closeTime),
        thursday: DayHours.open(openTime, closeTime),
        friday: DayHours.open(openTime, closeTime),
        saturday: DayHours.open(openTime, closeTime),
        sunday: DayHours.open(openTime, closeTime),
      );

  DayHours getDay(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return monday;
      case DateTime.tuesday:
        return tuesday;
      case DateTime.wednesday:
        return wednesday;
      case DateTime.thursday:
        return thursday;
      case DateTime.friday:
        return friday;
      case DateTime.saturday:
        return saturday;
      case DateTime.sunday:
        return sunday;
      default:
        return const DayHours();
    }
  }

  bool get isOpenNow {
    final now = DateTime.now();
    final todayHours = getDay(now.weekday);
    if (!todayHours.isOpen) return false;

    if (todayHours.openTime == null || todayHours.closeTime == null) {
      return false;
    }

    final openParts = todayHours.openTime!.split(':');
    final closeParts = todayHours.closeTime!.split(':');

    final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    final closeMinutes =
        int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
    final nowMinutes = now.hour * 60 + now.minute;

    return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
  }

  String get todayHoursText => getDay(DateTime.now().weekday).displayText;

  Map<String, dynamic> toJson() => {
        'monday': monday.toJson(),
        'tuesday': tuesday.toJson(),
        'wednesday': wednesday.toJson(),
        'thursday': thursday.toJson(),
        'friday': friday.toJson(),
        'saturday': saturday.toJson(),
        'sunday': sunday.toJson(),
      };

  factory OperatingHours.fromJson(Map<String, dynamic> json) => OperatingHours(
        monday: json['monday'] != null
            ? DayHours.fromJson(json['monday'] as Map<String, dynamic>)
            : const DayHours(),
        tuesday: json['tuesday'] != null
            ? DayHours.fromJson(json['tuesday'] as Map<String, dynamic>)
            : const DayHours(),
        wednesday: json['wednesday'] != null
            ? DayHours.fromJson(json['wednesday'] as Map<String, dynamic>)
            : const DayHours(),
        thursday: json['thursday'] != null
            ? DayHours.fromJson(json['thursday'] as Map<String, dynamic>)
            : const DayHours(),
        friday: json['friday'] != null
            ? DayHours.fromJson(json['friday'] as Map<String, dynamic>)
            : const DayHours(),
        saturday: json['saturday'] != null
            ? DayHours.fromJson(json['saturday'] as Map<String, dynamic>)
            : const DayHours(),
        sunday: json['sunday'] != null
            ? DayHours.fromJson(json['sunday'] as Map<String, dynamic>)
            : const DayHours(),
      );

  OperatingHours copyWith({
    DayHours? monday,
    DayHours? tuesday,
    DayHours? wednesday,
    DayHours? thursday,
    DayHours? friday,
    DayHours? saturday,
    DayHours? sunday,
  }) =>
      OperatingHours(
        monday: monday ?? this.monday,
        tuesday: tuesday ?? this.tuesday,
        wednesday: wednesday ?? this.wednesday,
        thursday: thursday ?? this.thursday,
        friday: friday ?? this.friday,
        saturday: saturday ?? this.saturday,
        sunday: sunday ?? this.sunday,
      );
}

/// Clinic/Hospital model for full clinic management
class Clinic {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final OperatingHours? operatingHours;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final List<String> doctorIds;
  final String? imagePath;
  final String? type; // Hospital, Clinic, Pharmacy, Lab, etc.
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? version;

  Clinic({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.operatingHours,
    this.latitude,
    this.longitude,
    this.notes,
    this.doctorIds = const [],
    this.imagePath,
    this.type,
    DateTime? createdAt,
    this.updatedAt,
    this.version,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasLocation => latitude != null && longitude != null;

  bool get hasOperatingHours => operatingHours != null;

  String get displayType => type ?? 'Clinic';

  String get doctorCountText {
    if (doctorIds.isEmpty) return 'No doctors';
    if (doctorIds.length == 1) return '1 doctor';
    return '${doctorIds.length} doctors';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'website': website,
        'operatingHoursJson': operatingHours != null
            ? jsonEncode(operatingHours!.toJson())
            : null,
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
        'doctorIdsJson': jsonEncode(doctorIds),
        'imagePath': imagePath,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'version': version ?? 1,
      };

  factory Clinic.fromJson(Map<String, dynamic> json) {
    List<String> parseDoctorIds() {
      final doctorIdsJson = json['doctorIdsJson'] as String?;
      if (doctorIdsJson == null || doctorIdsJson.isEmpty) return [];
      try {
        final decoded = jsonDecode(doctorIdsJson) as List;
        return decoded.cast<String>();
      } catch (_) {
        return [];
      }
    }

    OperatingHours? parseOperatingHours() {
      final hoursJson = json['operatingHoursJson'] as String?;
      if (hoursJson == null || hoursJson.isEmpty) return null;
      try {
        final decoded = jsonDecode(hoursJson) as Map<String, dynamic>;
        return OperatingHours.fromJson(decoded);
      } catch (_) {
        return null;
      }
    }

    return Clinic(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      operatingHours: parseOperatingHours(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      doctorIds: parseDoctorIds(),
      imagePath: json['imagePath'] as String?,
      type: json['type'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      version: json['version'] as int?,
    );
  }

  Clinic copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? website,
    OperatingHours? operatingHours,
    double? latitude,
    double? longitude,
    String? notes,
    List<String>? doctorIds,
    String? imagePath,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) =>
      Clinic(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        website: website ?? this.website,
        operatingHours: operatingHours ?? this.operatingHours,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        notes: notes ?? this.notes,
        doctorIds: doctorIds ?? this.doctorIds,
        imagePath: imagePath ?? this.imagePath,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Clinic && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Clinic(id: $id, name: $name)';
}

/// Clinic types enum
class ClinicType {
  static const String hospital = 'Hospital';
  static const String clinic = 'Clinic';
  static const String pharmacy = 'Pharmacy';
  static const String lab = 'Laboratory';
  static const String imaging = 'Imaging Center';
  static const String specialist = 'Specialist Center';
  static const String urgent = 'Urgent Care';
  static const String rehab = 'Rehabilitation';
  static const String other = 'Other';

  static const List<String> all = [
    hospital,
    clinic,
    pharmacy,
    lab,
    imaging,
    specialist,
    urgent,
    rehab,
    other,
  ];
}
