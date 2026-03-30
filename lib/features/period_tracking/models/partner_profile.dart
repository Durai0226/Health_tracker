/// Partner profile model for sharing cycle data
class PartnerProfile {
  final String id;
  final String name;
  final String? email;
  final String? photoUrl;
  final PartnerPermissions permissions;
  final PartnerStatus status;
  final DateTime? linkedAt;
  final DateTime createdAt;
  final String? inviteCode;

  PartnerProfile({
    required this.id,
    required this.name,
    this.email,
    this.photoUrl,
    PartnerPermissions? permissions,
    this.status = PartnerStatus.pending,
    this.linkedAt,
    DateTime? createdAt,
    this.inviteCode,
  })  : permissions = permissions ?? PartnerPermissions(),
        createdAt = createdAt ?? DateTime.now();

  bool get isLinked => status == PartnerStatus.linked;
  bool get isPending => status == PartnerStatus.pending;

  PartnerProfile copyWith({
    String? name,
    String? email,
    String? photoUrl,
    PartnerPermissions? permissions,
    PartnerStatus? status,
    DateTime? linkedAt,
    String? inviteCode,
  }) {
    return PartnerProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
      linkedAt: linkedAt ?? this.linkedAt,
      createdAt: createdAt,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'permissions': permissions.toJson(),
        'status': status.index,
        'linkedAt': linkedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'inviteCode': inviteCode,
      };

  factory PartnerProfile.fromJson(Map<String, dynamic> json) => PartnerProfile(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        photoUrl: json['photoUrl'],
        permissions: json['permissions'] != null
            ? PartnerPermissions.fromJson(json['permissions'])
            : null,
        status: PartnerStatus.values[json['status'] ?? 0],
        linkedAt: json['linkedAt'] != null
            ? DateTime.parse(json['linkedAt'])
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        inviteCode: json['inviteCode'],
      );

  /// Generate a new invite code
  static String generateInviteCode() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final code = now.toRadixString(36).toUpperCase();
    return 'FLO-${code.substring(code.length - 6)}';
  }
}

/// Partner link status
enum PartnerStatus {
  pending,
  linked,
  rejected,
  unlinked,
}

/// What data the partner can see
class PartnerPermissions {
  final bool viewCyclePhase;
  final bool viewPeriodDates;
  final bool viewFertileWindow;
  final bool viewSymptoms;
  final bool viewMood;
  final bool viewPregnancy;
  final bool receiveNotifications;
  final bool viewStatistics;

  PartnerPermissions({
    this.viewCyclePhase = true,
    this.viewPeriodDates = true,
    this.viewFertileWindow = true,
    this.viewSymptoms = false,
    this.viewMood = false,
    this.viewPregnancy = true,
    this.receiveNotifications = true,
    this.viewStatistics = false,
  });

  PartnerPermissions copyWith({
    bool? viewCyclePhase,
    bool? viewPeriodDates,
    bool? viewFertileWindow,
    bool? viewSymptoms,
    bool? viewMood,
    bool? viewPregnancy,
    bool? receiveNotifications,
    bool? viewStatistics,
  }) {
    return PartnerPermissions(
      viewCyclePhase: viewCyclePhase ?? this.viewCyclePhase,
      viewPeriodDates: viewPeriodDates ?? this.viewPeriodDates,
      viewFertileWindow: viewFertileWindow ?? this.viewFertileWindow,
      viewSymptoms: viewSymptoms ?? this.viewSymptoms,
      viewMood: viewMood ?? this.viewMood,
      viewPregnancy: viewPregnancy ?? this.viewPregnancy,
      receiveNotifications: receiveNotifications ?? this.receiveNotifications,
      viewStatistics: viewStatistics ?? this.viewStatistics,
    );
  }

  Map<String, dynamic> toJson() => {
        'viewCyclePhase': viewCyclePhase,
        'viewPeriodDates': viewPeriodDates,
        'viewFertileWindow': viewFertileWindow,
        'viewSymptoms': viewSymptoms,
        'viewMood': viewMood,
        'viewPregnancy': viewPregnancy,
        'receiveNotifications': receiveNotifications,
        'viewStatistics': viewStatistics,
      };

  factory PartnerPermissions.fromJson(Map<String, dynamic> json) =>
      PartnerPermissions(
        viewCyclePhase: json['viewCyclePhase'] ?? true,
        viewPeriodDates: json['viewPeriodDates'] ?? true,
        viewFertileWindow: json['viewFertileWindow'] ?? true,
        viewSymptoms: json['viewSymptoms'] ?? false,
        viewMood: json['viewMood'] ?? false,
        viewPregnancy: json['viewPregnancy'] ?? true,
        receiveNotifications: json['receiveNotifications'] ?? true,
        viewStatistics: json['viewStatistics'] ?? false,
      );

  /// Default "everything visible" preset
  static PartnerPermissions get full => PartnerPermissions(
        viewCyclePhase: true,
        viewPeriodDates: true,
        viewFertileWindow: true,
        viewSymptoms: true,
        viewMood: true,
        viewPregnancy: true,
        receiveNotifications: true,
        viewStatistics: true,
      );

  /// Minimal visibility preset
  static PartnerPermissions get minimal => PartnerPermissions(
        viewCyclePhase: true,
        viewPeriodDates: false,
        viewFertileWindow: true,
        viewSymptoms: false,
        viewMood: false,
        viewPregnancy: false,
        receiveNotifications: false,
        viewStatistics: false,
      );
}

/// Partner shared data snapshot (what partner receives)
class PartnerSharedData {
  final String partnerName;
  final String? currentPhase;
  final int? cycleDay;
  final int? daysUntilPeriod;
  final bool? inFertileWindow;
  final String? pregnancyWeek;
  final DateTime? lastUpdated;

  PartnerSharedData({
    required this.partnerName,
    this.currentPhase,
    this.cycleDay,
    this.daysUntilPeriod,
    this.inFertileWindow,
    this.pregnancyWeek,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'partnerName': partnerName,
        'currentPhase': currentPhase,
        'cycleDay': cycleDay,
        'daysUntilPeriod': daysUntilPeriod,
        'inFertileWindow': inFertileWindow,
        'pregnancyWeek': pregnancyWeek,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory PartnerSharedData.fromJson(Map<String, dynamic> json) =>
      PartnerSharedData(
        partnerName: json['partnerName'],
        currentPhase: json['currentPhase'],
        cycleDay: json['cycleDay'],
        daysUntilPeriod: json['daysUntilPeriod'],
        inFertileWindow: json['inFertileWindow'],
        pregnancyWeek: json['pregnancyWeek'],
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'])
            : null,
      );
}
