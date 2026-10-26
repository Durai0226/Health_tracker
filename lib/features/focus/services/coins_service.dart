import 'dart:math';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/services/clean_storage_service.dart';
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

  /// Guarded, like `RelaxationService.init`.
  ///
  /// `PlantRealTreesScreen.initState` calls this on every mount and
  /// `FocusService.init` calls it again, so an unguarded `init` re-read the
  /// store and re-notified every listener each time the shop was opened.
  /// Zero the balance and the shop history after "Delete all data" — the
  /// singleton would otherwise keep them in memory and save them again.
  void resetAfterWipe() {
    _coins = const FocusCoins();
    notifyListeners();
  }

  bool _didInit = false;

  Future<void> init() async {
    if (_didInit) return;
    _didInit = true;
    await _loadData();
    debugPrint('✓ CoinsService initialized');
  }

  Future<void> _loadData() async {
    try {
      final prefs = CleanStorageService.getAppPreferences();
      final coinsJson = prefs['focusCoins'];
      if (coinsJson != null && coinsJson is Map) {
        _coins = FocusCoins.fromJson(Map<String, dynamic>.from(coinsJson));
      }
      _notifyWhenSafe();
    } catch (e) {
      debugPrint('Error loading coins data: $e');
    }
  }

  /// Notify without tripping "setState() called during build".
  ///
  /// `init()` is called from `initState`, and everything above reads a
  /// SYNCHRONOUS cache — `getAppPreferences` returns the in-memory map, so
  /// despite the `async` signature nothing yields before this point and the
  /// notification lands inside the frame that is still building. A
  /// `ListenableBuilder` already listening to this service (the coin badge on
  /// the Focus screen) is then marked dirty mid-build, which the framework
  /// reports as `setState() or markNeedsBuild() called during build` — a
  /// caught exception on every open of the shop.
  ///
  /// Only the LOAD path needs this. The other four notify sites run from user
  /// actions — earning, spending, bonuses — which are never inside a build.
  void _notifyWhenSafe() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance
          .addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  Future<void> _saveData() async {
    try {
      await CleanStorageService.setAppPreference('focusCoins', _coins.toJson());
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
      timestamp: clock.now(),
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
      timestamp: clock.now(),
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
      timestamp: clock.now(),
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

  /// Redeem coins for a commemorative tree in the user's own garden.
  ///
  /// Formerly `plantRealTree`. It never planted a real tree: it wrote a hardcoded
  /// partner organisation and a `Random()` planting location into the record, and
  /// made no network call of any kind. Renamed so no caller can believe otherwise.
  Future<bool> redeemGardenTree(RealTreeType treeType) async {
    final cost = treeType.coinCost;

    if (_coins.totalCoins < cost) {
      debugPrint('✗ Not enough coins to redeem ${treeType.name}');
      return false;
    }

    final planting = RealTreePlanting(
      id: _generateId(),
      treeType: treeType,
      plantedAt: clock.now(),
      coinsCost: cost,
    );

    final spendTransaction = CoinTransaction(
      id: _generateId(),
      type: CoinTransactionType.spent,
      amount: cost,
      timestamp: clock.now(),
      description: 'Added a ${treeType.name} to your garden',
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
    
    debugPrint('✓ Added ${treeType.name} to the garden for $cost coins');
    return true;
  }

  /// Fresh-install state between tests. See FocusService.resetForTesting.
  @visibleForTesting
  void resetForTesting() {
    _coins = const FocusCoins();
    // Without this the `_didInit` guard survives the reset, so the SECOND
    // test in a file would get a silent no-op `init()` and assert against
    // whatever the first one left behind.
    _didInit = false;
  }

  bool canAfford(RealTreeType treeType) {
    return _coins.totalCoins >= treeType.coinCost;
  }

  String _generateId() {
    return '${clock.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  Map<RealTreeType, int> get treesCountByType {
    final Map<RealTreeType, int> counts = {};
    for (final tree in _coins.plantedTrees) {
      counts[tree.treeType] = (counts[tree.treeType] ?? 0) + 1;
    }
    return counts;
  }

  // `totalCO2Offset` was removed, not corrected.
  //
  // It returned `plantedTrees.length * 22`, presented in the UI as "N kg CO₂
  // Offset" — a specific environmental claim derived from a constant, for
  // plantings that never happened. There is no smaller honest version of that
  // number, because the app has no basis for any number: no partner, no
  // agreement, no request ever leaving the device. Under the FTC Green Guides an
  // environmental claim needs competent and reliable substantiation, so the fix
  // is deletion rather than a better multiplier.
}
