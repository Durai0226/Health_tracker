import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../models/focus_coins.dart';

class CoinsService extends ChangeNotifier {
  static final CoinsService _instance = CoinsService._internal();
  factory CoinsService() => _instance;
  CoinsService._internal();

  FocusCoins _coins = const FocusCoins();

  FocusCoins get coins => _coins;
  int get totalCoins => _coins.totalCoins;
  int get lifetimeCoins => _coins.lifetimeCoins;
  int get treesPlanted => _coins.treesPlanted;
  List<RealTreePlanting> get plantedTrees => _coins.plantedTrees;
  List<CoinTransaction> get transactions => _coins.transactions;

  Future<void> init() async {
    await _loadData();
    debugPrint('✓ CoinsService initialized');
  }

  Future<void> _loadData() async {
    try {
      final prefs = StorageService.getAppPreferences();
      final coinsJson = prefs['focusCoins'];
      if (coinsJson != null && coinsJson is Map) {
        _coins = FocusCoins.fromJson(Map<String, dynamic>.from(coinsJson));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading coins data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      await StorageService.setAppPreference('focusCoins', _coins.toJson());
    } catch (e) {
      debugPrint('Error saving coins data: $e');
    }
  }

  Future<void> earnCoins({
    required int minutes,
    required String sessionId,
    bool isCompleted = true,
  }) async {
    if (!isCompleted) return;

    final earnedCoins = CoinsCalculator.calculateCoinsForSession(minutes);
    
    final transaction = CoinTransaction(
      id: _generateId(),
      type: CoinTransactionType.earned,
      amount: earnedCoins,
      timestamp: DateTime.now(),
      description: 'Earned from $minutes min focus session',
      relatedSessionId: sessionId,
    );

    final updatedTransactions = [transaction, ..._coins.transactions];

    _coins = _coins.copyWith(
      totalCoins: _coins.totalCoins + earnedCoins,
      lifetimeCoins: _coins.lifetimeCoins + earnedCoins,
      transactions: updatedTransactions.take(100).toList(),
    );

    await _saveData();
    notifyListeners();
    
    debugPrint('✓ Earned $earnedCoins coins for $minutes minutes');
  }

  Future<void> addStreakBonus(int streakDays) async {
    final bonus = CoinsCalculator.calculateStreakBonus(streakDays);
    if (bonus <= 0) return;

    final transaction = CoinTransaction(
      id: _generateId(),
      type: CoinTransactionType.streakBonus,
      amount: bonus,
      timestamp: DateTime.now(),
      description: '$streakDays day streak bonus!',
    );

    final updatedTransactions = [transaction, ..._coins.transactions];

    _coins = _coins.copyWith(
      totalCoins: _coins.totalCoins + bonus,
      lifetimeCoins: _coins.lifetimeCoins + bonus,
      transactions: updatedTransactions.take(100).toList(),
    );

    await _saveData();
    notifyListeners();
    
    debugPrint('✓ Streak bonus: $bonus coins for $streakDays days');
  }

  Future<void> addAchievementBonus(int amount, String achievementName) async {
    final transaction = CoinTransaction(
      id: _generateId(),
      type: CoinTransactionType.achievementBonus,
      amount: amount,
      timestamp: DateTime.now(),
      description: 'Achievement unlocked: $achievementName',
    );

    final updatedTransactions = [transaction, ..._coins.transactions];

    _coins = _coins.copyWith(
      totalCoins: _coins.totalCoins + amount,
      lifetimeCoins: _coins.lifetimeCoins + amount,
      transactions: updatedTransactions.take(100).toList(),
    );

    await _saveData();
    notifyListeners();
  }

  Future<bool> plantRealTree(RealTreeType treeType) async {
    final cost = treeType.coinCost;
    
    if (_coins.totalCoins < cost) {
      debugPrint('✗ Not enough coins to plant ${treeType.name}');
      return false;
    }

    final planting = RealTreePlanting(
      id: _generateId(),
      treeType: treeType,
      plantedAt: DateTime.now(),
      coinsCost: cost,
      partnerOrganization: 'Trees for the Future',
      location: _getRandomLocation(),
    );

    final spendTransaction = CoinTransaction(
      id: _generateId(),
      type: CoinTransactionType.spent,
      amount: cost,
      timestamp: DateTime.now(),
      description: 'Planted a real ${treeType.name}!',
    );

    final updatedTransactions = [spendTransaction, ..._coins.transactions];
    final updatedTrees = [..._coins.plantedTrees, planting];

    _coins = _coins.copyWith(
      totalCoins: _coins.totalCoins - cost,
      coinsSpentOnTrees: _coins.coinsSpentOnTrees + cost,
      plantedTrees: updatedTrees,
      transactions: updatedTransactions.take(100).toList(),
    );

    await _saveData();
    notifyListeners();
    
    debugPrint('✓ Planted real ${treeType.name} for $cost coins');
    return true;
  }

  bool canAfford(RealTreeType treeType) {
    return _coins.totalCoins >= treeType.coinCost;
  }

  String _getRandomLocation() {
    final locations = [
      'Kenya, Africa',
      'Brazil, South America',
      'Indonesia, Asia',
      'India, Asia',
      'Madagascar, Africa',
      'Philippines, Asia',
      'Mexico, North America',
      'Ethiopia, Africa',
    ];
    return locations[Random().nextInt(locations.length)];
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  Map<RealTreeType, int> get treesCountByType {
    final Map<RealTreeType, int> counts = {};
    for (final tree in _coins.plantedTrees) {
      counts[tree.treeType] = (counts[tree.treeType] ?? 0) + 1;
    }
    return counts;
  }

  int get totalCO2Offset {
    return _coins.plantedTrees.length * 22;
  }
}
