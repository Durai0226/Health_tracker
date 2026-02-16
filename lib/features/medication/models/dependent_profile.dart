import 'package:hive/hive.dart';

part 'dependent_profile.g.dart';

/// Relationship type for dependents
@HiveType(typeId: 68)
enum RelationshipType {
  @HiveField(0)
  self,
  @HiveField(1)
  child,
  @HiveField(2)
  parent,
  @HiveField(3)
  spouse,
  @HiveField(4)
  grandparent,
  @HiveField(5)
  sibling,
  @HiveField(6)
  other;

  String get displayName {
    switch (this) {
      case RelationshipType.self:
        return 'Myself';
      case RelationshipType.child:
        return 'Child';
      case RelationshipType.parent:
        return 'Parent';
      case RelationshipType.spouse:
        return 'Spouse/Partner';
      case RelationshipType.grandparent:
        return 'Grandparent';
      case RelationshipType.sibling:
        return 'Sibling';
      case RelationshipType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case RelationshipType.self:
        return '👤';
      case RelationshipType.child:
        return '👶';
      case RelationshipType.parent:
        return '👨‍👩‍👦';
      case RelationshipType.spouse:
        return '💑';
      case RelationshipType.grandparent:
        return '👴';
      case RelationshipType.sibling:
        return '👫';
      case RelationshipType.other:
        return '👥';
    }
  }
}

/// Family member/dependent profile for managing their medications
@HiveType(typeId: 69)
class DependentProfile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final RelationshipType relationship;

  @HiveField(3)
  final DateTime? dateOfBirth;

  @HiveField(4)
  final String? gender;

  @HiveField(5)
  final String? bloodType;

  @HiveField(6)
  final double? weight; // in kg

  @HiveField(7)
  final double? height; // in cm

  @HiveField(8)
  final List<String>? allergies;

  @HiveField(9)
  final List<String>? conditions; // Medical conditions

  @HiveField(10)
  final String? emergencyContact;

  @HiveField(11)
  final String? emergencyPhone;

  @HiveField(12)
  final String? primaryDoctorId;

  @HiveField(13)
  final String? insuranceInfo;

  @HiveField(14)
  final String? notes;

  @HiveField(15)
  final String? avatarPath;

  @HiveField(16)
  final bool isActive;

  @HiveField(17)
  final DateTime createdAt;

  DependentProfile({
    required this.id,
    required this.name,
    required this.relationship,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.weight,
    this.height,
    this.allergies,
    this.conditions,
    this.emergencyContact,
    this.emergencyPhone,
    this.primaryDoctorId,
    this.insuranceInfo,
    this.notes,
    this.avatarPath,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  bool get isSelf => relationship == RelationshipType.self;

  String get displayAge {
    final a = age;
    if (a == null) return '';
    if (a < 1) {
      final months = DateTime.now().difference(dateOfBirth!).inDays ~/ 30;
      return '$months months';
    }
    return '$a years';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship.index,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'gender': gender,
    'bloodType': bloodType,
    'weight': weight,
    'height': height,
    'allergies': allergies,
    'conditions': conditions,
    'emergencyContact': emergencyContact,
    'emergencyPhone': emergencyPhone,
    'primaryDoctorId': primaryDoctorId,
    'insuranceInfo': insuranceInfo,
    'notes': notes,
    'avatarPath': avatarPath,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DependentProfile.fromJson(Map<String, dynamic> json) => DependentProfile(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    relationship: RelationshipType.values[json['relationship'] ?? 0],
    dateOfBirth: json['dateOfBirth'] != null ? DateTime.parse(json['dateOfBirth']) : null,
    gender: json['gender'],
    bloodType: json['bloodType'],
    weight: json['weight']?.toDouble(),
    height: json['height']?.toDouble(),
    allergies: (json['allergies'] as List?)?.cast<String>(),
    conditions: (json['conditions'] as List?)?.cast<String>(),
    emergencyContact: json['emergencyContact'],
    emergencyPhone: json['emergencyPhone'],
    primaryDoctorId: json['primaryDoctorId'],
    insuranceInfo: json['insuranceInfo'],
    notes: json['notes'],
    avatarPath: json['avatarPath'],
    isActive: json['isActive'] ?? true,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
  );

  DependentProfile copyWith({
    String? id,
    String? name,
    RelationshipType? relationship,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    double? weight,
    double? height,
    List<String>? allergies,
    List<String>? conditions,
    String? emergencyContact,
    String? emergencyPhone,
    String? primaryDoctorId,
    String? insuranceInfo,
    String? notes,
    String? avatarPath,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return DependentProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      primaryDoctorId: primaryDoctorId ?? this.primaryDoctorId,
      insuranceInfo: insuranceInfo ?? this.insuranceInfo,
      notes: notes ?? this.notes,
      avatarPath: avatarPath ?? this.avatarPath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Create default "self" profile
  factory DependentProfile.self({required String name}) {
    return DependentProfile(
      id: 'self',
      name: name,
      relationship: RelationshipType.self,
    );
  }
}
