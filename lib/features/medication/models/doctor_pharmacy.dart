import 'care_team_scope.dart';

/// Doctor/Prescriber information
class Doctor {
  final String id;
  final String name;
  final String? specialty;
  final String? phone;
  final String? email;
  final String? address;
  final String? clinicName;

  /// The clinic or hospital record this doctor works at, when one was chosen rather
  /// than a name typed. [clinicName] is what is shown when it is not set, or when the
  /// record has since been deleted.
  final String? clinicId;
  final String? notes;
  final bool isPrimary;

  /// The household member this doctor belongs to; null is the account holder.
  final String? dependentId;

  /// Whether every profile sees this doctor (a family doctor) or only the owner.
  /// True for a record that never said, so nobody loses a doctor they had.
  final bool sharedWithFamily;

  Doctor({
    required this.id,
    required this.name,
    this.specialty,
    this.phone,
    this.email,
    this.address,
    this.clinicName,
    this.clinicId,
    this.notes,
    this.isPrimary = false,
    this.dependentId,
    this.sharedWithFamily = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'specialty': specialty,
    'phone': phone,
    'email': email,
    'address': address,
    'clinicName': clinicName,
    'clinicId': clinicId,
    'notes': notes,
    'isPrimary': isPrimary,
    'dependentId': dependentId,
    'sharedWithFamily': sharedWithFamily,
  };

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    specialty: json['specialty'],
    phone: json['phone'],
    email: json['email'],
    address: json['address'],
    clinicName: json['clinicName'],
    clinicId: json['clinicId'],
    notes: json['notes'],
    isPrimary: json['isPrimary'] ?? false,
    dependentId: json['dependentId'] as String?,
    sharedWithFamily: CareTeamScope.cleanShared(json['sharedWithFamily']),
  );

  Doctor copyWith({
    String? id,
    String? name,
    String? specialty,
    String? phone,
    String? email,
    String? address,
    String? clinicName,
    String? clinicId,
    String? notes,
    bool? isPrimary,
    String? dependentId,
    bool clearDependentId = false,
    bool? sharedWithFamily,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      clinicName: clinicName ?? this.clinicName,
      clinicId: clinicId ?? this.clinicId,
      notes: notes ?? this.notes,
      isPrimary: isPrimary ?? this.isPrimary,
      dependentId: clearDependentId ? null : (dependentId ?? this.dependentId),
      sharedWithFamily: sharedWithFamily ?? this.sharedWithFamily,
    );
  }
}

/// Pharmacy information
class Pharmacy {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? email;
  final String? website;
  final String? hours;
  final bool hasDelivery;
  final bool isPrimary;
  final String? notes;

  Pharmacy({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.email,
    this.website,
    this.hours,
    this.hasDelivery = false,
    this.isPrimary = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'email': email,
    'website': website,
    'hours': hours,
    'hasDelivery': hasDelivery,
    'isPrimary': isPrimary,
    'notes': notes,
  };

  factory Pharmacy.fromJson(Map<String, dynamic> json) => Pharmacy(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'],
    address: json['address'],
    email: json['email'],
    website: json['website'],
    hours: json['hours'],
    hasDelivery: json['hasDelivery'] ?? false,
    isPrimary: json['isPrimary'] ?? false,
    notes: json['notes'],
  );

  Pharmacy copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? email,
    String? website,
    String? hours,
    bool? hasDelivery,
    bool? isPrimary,
    String? notes,
  }) {
    return Pharmacy(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      website: website ?? this.website,
      hours: hours ?? this.hours,
      hasDelivery: hasDelivery ?? this.hasDelivery,
      isPrimary: isPrimary ?? this.isPrimary,
      notes: notes ?? this.notes,
    );
  }
}

/// Appointment with doctor
class Appointment {
  final String id;
  final String? doctorId;
  final String doctorName;
  final DateTime dateTime;
  final String? location;
  final String? purpose;
  final String? notes;
  final bool reminderEnabled;
  final int reminderMinutesBefore;
  final bool isCompleted;
  final String? dependentId;
  final List<String>? medicineIds; // Related medicines to discuss

  Appointment({
    required this.id,
    this.doctorId,
    required this.doctorName,
    required this.dateTime,
    this.location,
    this.purpose,
    this.notes,
    this.reminderEnabled = true,
    this.reminderMinutesBefore = 60,
    this.isCompleted = false,
    this.dependentId,
    this.medicineIds,
  });

  bool get isUpcoming => dateTime.isAfter(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year && 
           dateTime.month == now.month && 
           dateTime.day == now.day;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'doctorId': doctorId,
    'doctorName': doctorName,
    'dateTime': dateTime.toIso8601String(),
    'location': location,
    'purpose': purpose,
    'notes': notes,
    'reminderEnabled': reminderEnabled,
    'reminderMinutesBefore': reminderMinutesBefore,
    'isCompleted': isCompleted,
    'dependentId': dependentId,
    'medicineIds': medicineIds,
  };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] ?? '',
    doctorId: json['doctorId'],
    doctorName: json['doctorName'] ?? '',
    dateTime: DateTime.parse(json['dateTime']),
    location: json['location'],
    purpose: json['purpose'],
    notes: json['notes'],
    reminderEnabled: json['reminderEnabled'] ?? true,
    reminderMinutesBefore: json['reminderMinutesBefore'] ?? 60,
    isCompleted: json['isCompleted'] ?? false,
    dependentId: json['dependentId'],
    medicineIds: (json['medicineIds'] as List?)?.cast<String>(),
  );

  /// [clearDependentId] explicitly clears ownership to self (null) — the
  /// standard `dependentId ?? this.dependentId` pattern below can't express
  /// that, since a caller can't pass null to mean "clear" vs "leave alone"
  /// (see MedicineCleanStorageService.deleteDependent's other models for the
  /// same sentinel).
  Appointment copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
    DateTime? dateTime,
    String? location,
    String? purpose,
    String? notes,
    bool? reminderEnabled,
    int? reminderMinutesBefore,
    bool? isCompleted,
    String? dependentId,
    bool clearDependentId = false,
    List<String>? medicineIds,
  }) {
    return Appointment(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      isCompleted: isCompleted ?? this.isCompleted,
      dependentId: clearDependentId ? null : (dependentId ?? this.dependentId),
      medicineIds: medicineIds ?? this.medicineIds,
    );
  }
}
