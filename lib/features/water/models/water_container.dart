import 'package:hive/hive.dart';

part 'water_container.g.dart';

/// Custom containers that users can save for quick access
@HiveType(typeId: 21)
class WaterContainer extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String emoji;

  @HiveField(3)
  final int capacityMl;

  @HiveField(4)
  final bool isDefault;

  @HiveField(5)
  final String? colorHex;

  @HiveField(6)
  final int usageCount; // Track how often this container is used

  @HiveField(7)
  final DateTime? lastUsed;

  WaterContainer({
    required this.id,
    required this.name,
    required this.emoji,
    required this.capacityMl,
    this.isDefault = false,
    this.colorHex,
    this.usageCount = 0,
    this.lastUsed,
  });

  WaterContainer copyWith({
    String? name,
    String? emoji,
    int? capacityMl,
    bool? isDefault,
    String? colorHex,
    int? usageCount,
    DateTime? lastUsed,
  }) {
    return WaterContainer(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      capacityMl: capacityMl ?? this.capacityMl,
      isDefault: isDefault ?? this.isDefault,
      colorHex: colorHex ?? this.colorHex,
      usageCount: usageCount ?? this.usageCount,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'capacityMl': capacityMl,
    'isDefault': isDefault,
    'colorHex': colorHex,
    'usageCount': usageCount,
    'lastUsed': lastUsed?.toIso8601String(),
  };

  factory WaterContainer.fromJson(Map<String, dynamic> json) => WaterContainer(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    emoji: json['emoji'] ?? '🥛',
    capacityMl: json['capacityMl'] ?? 250,
    isDefault: json['isDefault'] ?? false,
    colorHex: json['colorHex'],
    usageCount: json['usageCount'] ?? 0,
    lastUsed: json['lastUsed'] != null ? DateTime.parse(json['lastUsed']) : null,
  );

  /// Default containers
  static List<WaterContainer> get defaultContainers => [
    WaterContainer(
      id: 'small_cup',
      name: 'Small Cup',
      emoji: '☕',
      capacityMl: 100,
      isDefault: true,
    ),
    WaterContainer(
      id: 'cup',
      name: 'Cup',
      emoji: '🍵',
      capacityMl: 150,
      isDefault: true,
    ),
    WaterContainer(
      id: 'glass',
      name: 'Glass',
      emoji: '🥛',
      capacityMl: 250,
      isDefault: true,
    ),
    WaterContainer(
      id: 'mug',
      name: 'Mug',
      emoji: '☕',
      capacityMl: 300,
      isDefault: true,
    ),
    WaterContainer(
      id: 'small_bottle',
      name: 'Small Bottle',
      emoji: '🧴',
      capacityMl: 350,
      isDefault: true,
    ),
    WaterContainer(
      id: 'bottle',
      name: 'Bottle',
      emoji: '🍼',
      capacityMl: 500,
      isDefault: true,
    ),
    WaterContainer(
      id: 'large_bottle',
      name: 'Large Bottle',
      emoji: '🧃',
      capacityMl: 750,
      isDefault: true,
    ),
    WaterContainer(
      id: 'sports_bottle',
      name: 'Sports Bottle',
      emoji: '🏃',
      capacityMl: 600,
      isDefault: true,
    ),
    WaterContainer(
      id: 'tumbler',
      name: 'Tumbler',
      emoji: '🥤',
      capacityMl: 450,
      isDefault: true,
    ),
    WaterContainer(
      id: 'liter_bottle',
      name: '1 Liter Bottle',
      emoji: '🫗',
      capacityMl: 1000,
      isDefault: true,
    ),
    WaterContainer(
      id: 'jug',
      name: 'Jug',
      emoji: '🫖',
      capacityMl: 1500,
      isDefault: true,
    ),
  ];
}
