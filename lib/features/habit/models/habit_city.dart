import 'dart:convert';

/// Building type in the city
enum BuildingType {
  house,
  office,
  shop,
  park,
  landmark,
  special,
}

/// Building rarity
enum BuildingRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

/// A building in the habit city
class CityBuilding {
  final String id;
  final String name;
  final String description;
  final BuildingType type;
  final BuildingRarity rarity;
  final int pointsRequired;
  final int coinsReward;
  final String assetPath;
  final int gridX;
  final int gridY;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const CityBuilding({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.rarity = BuildingRarity.common,
    required this.pointsRequired,
    this.coinsReward = 0,
    required this.assetPath,
    this.gridX = 0,
    this.gridY = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  CityBuilding copyWith({
    String? id,
    String? name,
    String? description,
    BuildingType? type,
    BuildingRarity? rarity,
    int? pointsRequired,
    int? coinsReward,
    String? assetPath,
    int? gridX,
    int? gridY,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return CityBuilding(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      pointsRequired: pointsRequired ?? this.pointsRequired,
      coinsReward: coinsReward ?? this.coinsReward,
      assetPath: assetPath ?? this.assetPath,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.index,
      'rarity': rarity.index,
      'pointsRequired': pointsRequired,
      'coinsReward': coinsReward,
      'assetPath': assetPath,
      'gridX': gridX,
      'gridY': gridY,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  factory CityBuilding.fromJson(Map<String, dynamic> json) {
    return CityBuilding(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: BuildingType.values[json['type'] as int? ?? 0],
      rarity: BuildingRarity.values[json['rarity'] as int? ?? 0],
      pointsRequired: json['pointsRequired'] as int? ?? 0,
      coinsReward: json['coinsReward'] as int? ?? 0,
      assetPath: json['assetPath'] as String,
      gridX: json['gridX'] as int? ?? 0,
      gridY: json['gridY'] as int? ?? 0,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
    );
  }
}

/// Shop item for house decoration
class ShopItem {
  final String id;
  final String name;
  final String description;
  final String category; // furniture, decoration, etc.
  final int price;
  final String assetPath;
  final bool isOwned;
  final DateTime? purchasedAt;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.assetPath,
    this.isOwned = false,
    this.purchasedAt,
  });

  ShopItem copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    int? price,
    String? assetPath,
    bool? isOwned,
    DateTime? purchasedAt,
  }) {
    return ShopItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      assetPath: assetPath ?? this.assetPath,
      isOwned: isOwned ?? this.isOwned,
      purchasedAt: purchasedAt ?? this.purchasedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'assetPath': assetPath,
      'isOwned': isOwned,
      'purchasedAt': purchasedAt?.toIso8601String(),
    };
  }

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'decoration',
      price: json['price'] as int? ?? 0,
      assetPath: json['assetPath'] as String,
      isOwned: json['isOwned'] as bool? ?? false,
      purchasedAt: json['purchasedAt'] != null
          ? DateTime.parse(json['purchasedAt'] as String)
          : null,
    );
  }
}

/// Famous world building collection item
class CollectionBuilding {
  final String id;
  final String name;
  final String location;
  final String description;
  final String assetPath;
  final int pointsRequired;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const CollectionBuilding({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.assetPath,
    required this.pointsRequired,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  CollectionBuilding copyWith({
    String? id,
    String? name,
    String? location,
    String? description,
    String? assetPath,
    int? pointsRequired,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return CollectionBuilding(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      assetPath: assetPath ?? this.assetPath,
      pointsRequired: pointsRequired ?? this.pointsRequired,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'description': description,
      'assetPath': assetPath,
      'pointsRequired': pointsRequired,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  factory CollectionBuilding.fromJson(Map<String, dynamic> json) {
    return CollectionBuilding(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      assetPath: json['assetPath'] as String,
      pointsRequired: json['pointsRequired'] as int? ?? 0,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
    );
  }
}

/// User's city state
class HabitCity {
  final String id;
  final String userId;
  final int totalPoints;
  final int coins;
  final int cityLevel;
  final List<CityBuilding> buildings;
  final List<ShopItem> inventory;
  final List<CollectionBuilding> collections;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HabitCity({
    required this.id,
    required this.userId,
    this.totalPoints = 0,
    this.coins = 0,
    this.cityLevel = 1,
    this.buildings = const [],
    this.inventory = const [],
    this.collections = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Points needed for next level
  int get pointsForNextLevel => cityLevel * 100;

  /// Progress to next level (0.0 - 1.0)
  double get levelProgress {
    final prevLevelPoints = (cityLevel - 1) * 100;
    final pointsInLevel = totalPoints - prevLevelPoints;
    return (pointsInLevel / 100).clamp(0.0, 1.0);
  }

  /// Number of unlocked buildings
  int get unlockedBuildingsCount => buildings.where((b) => b.isUnlocked).length;

  /// Number of unlocked collections
  int get unlockedCollectionsCount => collections.where((c) => c.isUnlocked).length;

  HabitCity copyWith({
    String? id,
    String? userId,
    int? totalPoints,
    int? coins,
    int? cityLevel,
    List<CityBuilding>? buildings,
    List<ShopItem>? inventory,
    List<CollectionBuilding>? collections,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitCity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      totalPoints: totalPoints ?? this.totalPoints,
      coins: coins ?? this.coins,
      cityLevel: cityLevel ?? this.cityLevel,
      buildings: buildings ?? this.buildings,
      inventory: inventory ?? this.inventory,
      collections: collections ?? this.collections,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'totalPoints': totalPoints,
      'coins': coins,
      'cityLevel': cityLevel,
      'buildings': buildings.map((b) => b.toJson()).toList(),
      'inventory': inventory.map((i) => i.toJson()).toList(),
      'collections': collections.map((c) => c.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HabitCity.fromJson(Map<String, dynamic> json) {
    return HabitCity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      totalPoints: json['totalPoints'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      cityLevel: json['cityLevel'] as int? ?? 1,
      buildings: (json['buildings'] as List<dynamic>?)
              ?.map((b) => CityBuilding.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      inventory: (json['inventory'] as List<dynamic>?)
              ?.map((i) => ShopItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      collections: (json['collections'] as List<dynamic>?)
              ?.map((c) => CollectionBuilding.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitCity.fromJsonString(String jsonString) {
    return HabitCity.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Create empty city for new user
  factory HabitCity.empty(String userId) {
    final now = DateTime.now();
    return HabitCity(
      id: 'city_$userId',
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );
  }
}
