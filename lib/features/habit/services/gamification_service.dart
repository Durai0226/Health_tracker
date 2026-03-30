import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service for gamification features - city, shop, collections, points
class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  static const String _cityKey = 'habit_gamification_city';

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  HabitCity? _city;

  // Points earned per action
  static const int pointsPerHabitComplete = 10;
  static const int pointsPerAllDayComplete = 50;
  static const int pointsPerStreakDay = 5;
  static const int pointsPerChallengeWin = 100;
  static const int coinsPerLevelUp = 50;

  // Getters
  bool get isInitialized => _isInitialized;
  HabitCity? get city => _city;
  int get totalPoints => _city?.totalPoints ?? 0;
  int get coins => _city?.coins ?? 0;
  int get cityLevel => _city?.cityLevel ?? 1;
  List<CityBuilding> get buildings => _city?.buildings ?? [];
  List<ShopItem> get inventory => _city?.inventory ?? [];
  List<CollectionBuilding> get collections => _city?.collections ?? [];

  /// Initialize the service
  Future<void> init(String oderId) async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    await _loadCity(oderId);
    _isInitialized = true;
    debugPrint('✓ GamificationService initialized');
    notifyListeners();
  }

  Future<void> _loadCity(String oderId) async {
    final json = _prefs?.getString(_cityKey);
    if (json != null) {
      _city = HabitCity.fromJson(jsonDecode(json));
    } else {
      _city = HabitCity.empty(oderId);
      _initializeDefaultBuildings();
      _initializeCollections();
      _initializeShopItems();
      await _saveCity();
    }
  }

  Future<void> _saveCity() async {
    if (_city != null) {
      final json = jsonEncode(_city!.toJson());
      await _prefs?.setString(_cityKey, json);
    }
  }

  void _initializeDefaultBuildings() {
    if (_city == null) return;
    
    final buildings = <CityBuilding>[
      CityBuilding(
        id: 'building_house_1',
        name: 'Starter Home',
        description: 'Your first home in the city',
        type: BuildingType.house,
        rarity: BuildingRarity.common,
        pointsRequired: 0,
        coinsReward: 10,
        assetPath: 'assets/images/city/house_1.png',
        gridX: 0,
        gridY: 0,
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      ),
      CityBuilding(
        id: 'building_park_1',
        name: 'Small Park',
        description: 'A peaceful green space',
        type: BuildingType.park,
        rarity: BuildingRarity.common,
        pointsRequired: 100,
        coinsReward: 20,
        assetPath: 'assets/images/city/park_1.png',
        gridX: 1,
        gridY: 0,
      ),
      CityBuilding(
        id: 'building_shop_1',
        name: 'Corner Shop',
        description: 'A local convenience store',
        type: BuildingType.shop,
        rarity: BuildingRarity.common,
        pointsRequired: 200,
        coinsReward: 30,
        assetPath: 'assets/images/city/shop_1.png',
        gridX: 2,
        gridY: 0,
      ),
      CityBuilding(
        id: 'building_office_1',
        name: 'Small Office',
        description: 'A modern workspace',
        type: BuildingType.office,
        rarity: BuildingRarity.uncommon,
        pointsRequired: 500,
        coinsReward: 50,
        assetPath: 'assets/images/city/office_1.png',
        gridX: 0,
        gridY: 1,
      ),
      CityBuilding(
        id: 'building_landmark_1',
        name: 'City Fountain',
        description: 'A beautiful landmark',
        type: BuildingType.landmark,
        rarity: BuildingRarity.rare,
        pointsRequired: 1000,
        coinsReward: 100,
        assetPath: 'assets/images/city/fountain.png',
        gridX: 1,
        gridY: 1,
      ),
      CityBuilding(
        id: 'building_special_1',
        name: 'Trophy Hall',
        description: 'Showcases your achievements',
        type: BuildingType.special,
        rarity: BuildingRarity.epic,
        pointsRequired: 2000,
        coinsReward: 200,
        assetPath: 'assets/images/city/trophy_hall.png',
        gridX: 2,
        gridY: 1,
      ),
    ];

    _city = _city!.copyWith(buildings: buildings);
  }

  void _initializeCollections() {
    if (_city == null) return;
    
    final collections = <CollectionBuilding>[
      CollectionBuilding(
        id: 'collection_eiffel',
        name: 'Eiffel Tower',
        location: 'Paris, France',
        description: 'The iconic iron lattice tower',
        assetPath: 'assets/images/collections/eiffel.png',
        pointsRequired: 500,
      ),
      CollectionBuilding(
        id: 'collection_bigben',
        name: 'Big Ben',
        location: 'London, UK',
        description: 'The famous clock tower',
        assetPath: 'assets/images/collections/bigben.png',
        pointsRequired: 750,
      ),
      CollectionBuilding(
        id: 'collection_liberty',
        name: 'Statue of Liberty',
        location: 'New York, USA',
        description: 'Symbol of freedom',
        assetPath: 'assets/images/collections/liberty.png',
        pointsRequired: 1000,
      ),
      CollectionBuilding(
        id: 'collection_colosseum',
        name: 'Colosseum',
        location: 'Rome, Italy',
        description: 'Ancient amphitheater',
        assetPath: 'assets/images/collections/colosseum.png',
        pointsRequired: 1500,
      ),
      CollectionBuilding(
        id: 'collection_tajmahal',
        name: 'Taj Mahal',
        location: 'Agra, India',
        description: 'Monument of love',
        assetPath: 'assets/images/collections/tajmahal.png',
        pointsRequired: 2000,
      ),
      CollectionBuilding(
        id: 'collection_greatwall',
        name: 'Great Wall',
        location: 'China',
        description: 'Ancient defensive wall',
        assetPath: 'assets/images/collections/greatwall.png',
        pointsRequired: 3000,
      ),
    ];

    _city = _city!.copyWith(collections: collections);
  }

  void _initializeShopItems() {
    // Shop items will be loaded/initialized separately
  }

  // ==========================================
  // POINTS & COINS
  // ==========================================

  /// Award points for completing a habit
  Future<void> awardHabitPoints() async {
    if (_city == null) return;
    await _addPoints(pointsPerHabitComplete);
    await _addCoins(1);
  }

  /// Award bonus for completing all habits in a day
  Future<void> awardAllDayBonus() async {
    if (_city == null) return;
    await _addPoints(pointsPerAllDayComplete);
    await _addCoins(5);
  }

  /// Award streak bonus
  Future<void> awardStreakBonus(int streakDays) async {
    if (_city == null) return;
    final bonus = pointsPerStreakDay * streakDays;
    await _addPoints(bonus);
  }

  Future<void> _addPoints(int points) async {
    if (_city == null) return;
    
    final newTotal = _city!.totalPoints + points;
    final newLevel = _calculateLevel(newTotal);
    final leveledUp = newLevel > _city!.cityLevel;

    _city = _city!.copyWith(
      totalPoints: newTotal,
      cityLevel: newLevel,
      coins: leveledUp ? _city!.coins + coinsPerLevelUp : _city!.coins,
      updatedAt: DateTime.now(),
    );

    // Check for building unlocks
    await _checkBuildingUnlocks();
    await _checkCollectionUnlocks();
    await _saveCity();
    notifyListeners();
  }

  Future<void> _addCoins(int amount) async {
    if (_city == null) return;
    
    _city = _city!.copyWith(
      coins: _city!.coins + amount,
      updatedAt: DateTime.now(),
    );
    
    await _saveCity();
    notifyListeners();
  }

  int _calculateLevel(int points) {
    // Each level requires 100 more points than the previous
    int level = 1;
    int pointsNeeded = 100;
    int accumulatedPoints = 0;
    
    while (accumulatedPoints + pointsNeeded <= points) {
      accumulatedPoints += pointsNeeded;
      level++;
      pointsNeeded = level * 100;
    }
    
    return level;
  }

  // ==========================================
  // BUILDINGS
  // ==========================================

  Future<void> _checkBuildingUnlocks() async {
    if (_city == null) return;
    
    final updatedBuildings = _city!.buildings.map((building) {
      if (!building.isUnlocked && _city!.totalPoints >= building.pointsRequired) {
        return building.copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now(),
        );
      }
      return building;
    }).toList();

    _city = _city!.copyWith(buildings: updatedBuildings);
  }

  /// Get unlocked buildings
  List<CityBuilding> get unlockedBuildings {
    return buildings.where((b) => b.isUnlocked).toList();
  }

  /// Get next building to unlock
  CityBuilding? get nextBuildingToUnlock {
    final locked = buildings.where((b) => !b.isUnlocked).toList();
    if (locked.isEmpty) return null;
    locked.sort((a, b) => a.pointsRequired.compareTo(b.pointsRequired));
    return locked.first;
  }

  // ==========================================
  // COLLECTIONS
  // ==========================================

  Future<void> _checkCollectionUnlocks() async {
    if (_city == null) return;
    
    final updatedCollections = _city!.collections.map((collection) {
      if (!collection.isUnlocked && _city!.totalPoints >= collection.pointsRequired) {
        return collection.copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now(),
        );
      }
      return collection;
    }).toList();

    _city = _city!.copyWith(collections: updatedCollections);
  }

  /// Get unlocked collections
  List<CollectionBuilding> get unlockedCollections {
    return collections.where((c) => c.isUnlocked).toList();
  }

  /// Number of unlocked collections
  int get unlockedCollectionsCount {
    return collections.where((c) => c.isUnlocked).length;
  }

  // ==========================================
  // SHOP
  // ==========================================

  /// Get available shop items
  List<ShopItem> getShopItems() {
    return [
      ShopItem(
        id: 'item_typewriter',
        name: 'Typewriter',
        description: 'A vintage writing machine',
        category: 'furniture',
        price: 200,
        assetPath: 'assets/images/shop/typewriter.png',
      ),
      ShopItem(
        id: 'item_scooter',
        name: 'Scooter',
        description: 'A fun way to get around',
        category: 'decoration',
        price: 150,
        assetPath: 'assets/images/shop/scooter.png',
      ),
      ShopItem(
        id: 'item_chair',
        name: 'Cozy Chair',
        description: 'A comfortable reading chair',
        category: 'furniture',
        price: 100,
        assetPath: 'assets/images/shop/chair.png',
      ),
      ShopItem(
        id: 'item_lamp',
        name: 'Floor Lamp',
        description: 'Warm ambient lighting',
        category: 'decoration',
        price: 80,
        assetPath: 'assets/images/shop/lamp.png',
      ),
      ShopItem(
        id: 'item_plant',
        name: 'Potted Plant',
        description: 'Brings life to any room',
        category: 'decoration',
        price: 50,
        assetPath: 'assets/images/shop/plant.png',
      ),
    ];
  }

  /// Purchase an item from the shop
  Future<bool> purchaseItem(String itemId) async {
    if (_city == null) return false;
    
    final shopItems = getShopItems();
    final item = shopItems.firstWhere(
      (i) => i.id == itemId,
      orElse: () => throw Exception('Item not found'),
    );

    // Check if already owned
    if (_city!.inventory.any((i) => i.id == itemId)) {
      return false; // Already owned
    }

    // Check if enough coins
    if (_city!.coins < item.price) {
      return false; // Not enough coins
    }

    // Purchase
    final purchasedItem = item.copyWith(
      isOwned: true,
      purchasedAt: DateTime.now(),
    );

    final updatedInventory = [..._city!.inventory, purchasedItem];
    
    _city = _city!.copyWith(
      coins: _city!.coins - item.price,
      inventory: updatedInventory,
      updatedAt: DateTime.now(),
    );

    await _saveCity();
    notifyListeners();
    return true;
  }

  /// Check if item is owned
  bool isItemOwned(String itemId) {
    return inventory.any((i) => i.id == itemId);
  }

  // ==========================================
  // PROGRESS
  // ==========================================

  /// Get progress to next level
  double get levelProgress {
    if (_city == null) return 0.0;
    return _city!.levelProgress;
  }

  /// Get points needed for next level
  int get pointsForNextLevel {
    if (_city == null) return 100;
    return _city!.pointsForNextLevel;
  }

  /// Get current points in level
  int get currentLevelPoints {
    if (_city == null) return 0;
    final prevLevelTotal = (cityLevel - 1) * 100 * cityLevel ~/ 2;
    return totalPoints - prevLevelTotal;
  }
}
