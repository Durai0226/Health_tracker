import 'package:flutter/material.dart';
import '../../../core/utils/enum_json.dart';

enum RealTreeType {
  oak,
  maple,
  pine,
  cherry,
  bamboo,
  mangrove,
  rainforest,
  fruit,
}

extension RealTreeTypeExtension on RealTreeType {
  String get name {
    switch (this) {
      case RealTreeType.oak:
        return 'Oak Tree';
      case RealTreeType.maple:
        return 'Maple Tree';
      case RealTreeType.pine:
        return 'Pine Tree';
      case RealTreeType.cherry:
        return 'Cherry Tree';
      case RealTreeType.bamboo:
        return 'Bamboo Grove';
      case RealTreeType.mangrove:
        return 'Mangrove Tree';
      case RealTreeType.rainforest:
        return 'Rainforest Tree';
      case RealTreeType.fruit:
        return 'Fruit Tree';
    }
  }

  String get emoji {
    switch (this) {
      case RealTreeType.oak:
        return '🌳';
      case RealTreeType.maple:
        return '🍁';
      case RealTreeType.pine:
        return '🌲';
      case RealTreeType.cherry:
        return '🌸';
      case RealTreeType.bamboo:
        return '🎋';
      case RealTreeType.mangrove:
        return '🌴';
      case RealTreeType.rainforest:
        return '🌿';
      case RealTreeType.fruit:
        return '🍎';
    }
  }

  String get description {
    switch (this) {
      case RealTreeType.oak:
        return 'Strong and long-lasting, absorbs tons of CO2 over its lifetime';
      case RealTreeType.maple:
        return 'Beautiful deciduous tree that provides habitat for wildlife';
      case RealTreeType.pine:
        return 'Evergreen tree perfect for cooler climates';
      case RealTreeType.cherry:
        return 'Flowering tree that supports pollinators';
      case RealTreeType.bamboo:
        return 'Fast-growing plant that absorbs more CO2 than trees';
      case RealTreeType.mangrove:
        return 'Coastal tree that prevents erosion and protects marine life';
      case RealTreeType.rainforest:
        return 'Native tropical tree supporting biodiversity';
      case RealTreeType.fruit:
        return 'Provides food for local communities';
    }
  }

  int get coinCost {
    switch (this) {
      case RealTreeType.oak:
        return 500;
      case RealTreeType.maple:
        return 400;
      case RealTreeType.pine:
        return 350;
      case RealTreeType.cherry:
        return 600;
      case RealTreeType.bamboo:
        return 200;
      case RealTreeType.mangrove:
        return 450;
      case RealTreeType.rainforest:
        return 550;
      case RealTreeType.fruit:
        return 500;
    }
  }

  Color get color {
    switch (this) {
      case RealTreeType.oak:
        return const Color(0xFF5D4037);
      case RealTreeType.maple:
        return const Color(0xFFE65100);
      case RealTreeType.pine:
        return const Color(0xFF1B5E20);
      case RealTreeType.cherry:
        return const Color(0xFFF8BBD9);
      case RealTreeType.bamboo:
        return const Color(0xFF66BB6A);
      case RealTreeType.mangrove:
        return const Color(0xFF00695C);
      case RealTreeType.rainforest:
        return const Color(0xFF2E7D32);
      case RealTreeType.fruit:
        return const Color(0xFFD32F2F);
    }
  }
}

class FocusCoins {
  final int totalCoins;
  final int lifetimeCoins;
  final int coinsSpentOnTrees;
  final List<RealTreePlanting> plantedTrees;
  final List<CoinTransaction> transactions;

  const FocusCoins({
    this.totalCoins = 0,
    this.lifetimeCoins = 0,
    this.coinsSpentOnTrees = 0,
    this.plantedTrees = const [],
    this.transactions = const [],
  });

  int get treesPlanted => plantedTrees.length;

  Map<String, dynamic> toJson() => {
        'totalCoins': totalCoins,
        'lifetimeCoins': lifetimeCoins,
        'coinsSpentOnTrees': coinsSpentOnTrees,
        'plantedTrees': plantedTrees.map((t) => t.toJson()).toList(),
        'transactions': transactions.take(100).map((t) => t.toJson()).toList(),
      };

  factory FocusCoins.fromJson(Map<String, dynamic> json) => FocusCoins(
        totalCoins: json['totalCoins'] ?? 0,
        lifetimeCoins: json['lifetimeCoins'] ?? 0,
        coinsSpentOnTrees: json['coinsSpentOnTrees'] ?? 0,
        plantedTrees: (json['plantedTrees'] as List?)
                ?.map((t) => RealTreePlanting.fromJson(Map<String, dynamic>.from(t)))
                .toList() ??
            [],
        transactions: (json['transactions'] as List?)
                ?.map((t) => CoinTransaction.fromJson(Map<String, dynamic>.from(t)))
                .toList() ??
            [],
      );

  FocusCoins copyWith({
    int? totalCoins,
    int? lifetimeCoins,
    int? coinsSpentOnTrees,
    List<RealTreePlanting>? plantedTrees,
    List<CoinTransaction>? transactions,
  }) {
    return FocusCoins(
      totalCoins: totalCoins ?? this.totalCoins,
      lifetimeCoins: lifetimeCoins ?? this.lifetimeCoins,
      coinsSpentOnTrees: coinsSpentOnTrees ?? this.coinsSpentOnTrees,
      plantedTrees: plantedTrees ?? this.plantedTrees,
      transactions: transactions ?? this.transactions,
    );
  }
}

/// A commemorative tree the user redeemed with focus coins, kept **in their own
/// garden**. It is an in-app reward and nothing more.
///
/// It did not used to be described that way. Redeeming one wrote a record
/// carrying `partnerOrganization: 'Trees for the Future'` — a real 501(c)(3),
/// hardcoded with no agreement — and a `location` chosen by `Random()` from eight
/// countries, which the screen then presented to the user as fact ("📍 Kenya,
/// Africa"). `CoinsService` had no HTTP client and no Firestore write, so nothing
/// left the device: coins were debited for a real-world outcome that never
/// happened, and the geography was invented per redemption.
///
/// Those three fields are gone. Not deprecated — removed, because a field that
/// exists gets rendered again. `fromJson` deliberately ignores them so records
/// written by the old build still load, minus the fabrications.
///
/// If a genuine planting partnership is ever signed, the honest shape is the one
/// Forest uses: a named partner who **publicly reciprocates**, plantings funded
/// from app revenue rather than the user's currency, a hard per-account cap, and
/// no certificate. Until such an agreement exists, this stays an in-app reward.
class RealTreePlanting {
  final String id;
  final RealTreeType treeType;
  final DateTime plantedAt;
  final int coinsCost;

  RealTreePlanting({
    required this.id,
    required this.treeType,
    required this.plantedAt,
    required this.coinsCost,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'treeType': treeType.index,
        'plantedAt': plantedAt.toIso8601String(),
        'coinsCost': coinsCost,
      };

  /// Tolerant by design: older records carry `certificateId`, `location` and
  /// `partnerOrganization`, and an unknown `treeType` index can arrive from a
  /// build that had more species. Both degrade instead of throwing — persisted
  /// data outlives the code that wrote it.
  factory RealTreePlanting.fromJson(Map<String, dynamic> json) {
    return RealTreePlanting(
      id: json['id'] ?? '',
      treeType:
          EnumJson.at(RealTreeType.values, json['treeType'], RealTreeType.oak),
      plantedAt:
          DateTime.tryParse(json['plantedAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      coinsCost: json['coinsCost'] ?? 0,
    );
  }
}

enum CoinTransactionType {
  earned,
  spent,
  bonus,
  streakBonus,
  achievementBonus,
  referralBonus,
}

extension CoinTransactionTypeExtension on CoinTransactionType {
  String get name {
    switch (this) {
      case CoinTransactionType.earned:
        return 'Earned';
      case CoinTransactionType.spent:
        return 'Spent';
      case CoinTransactionType.bonus:
        return 'Bonus';
      case CoinTransactionType.streakBonus:
        return 'Streak Bonus';
      case CoinTransactionType.achievementBonus:
        return 'Achievement Bonus';
      case CoinTransactionType.referralBonus:
        return 'Referral Bonus';
    }
  }

  String get emoji {
    switch (this) {
      case CoinTransactionType.earned:
        return '💰';
      case CoinTransactionType.spent:
        return '🌱';
      case CoinTransactionType.bonus:
        return '🎁';
      case CoinTransactionType.streakBonus:
        return '🔥';
      case CoinTransactionType.achievementBonus:
        return '🏆';
      case CoinTransactionType.referralBonus:
        return '👥';
    }
  }
}

class CoinTransaction {
  final String id;
  final CoinTransactionType type;
  final int amount;
  final DateTime timestamp;
  final String description;
  final String? relatedSessionId;

  CoinTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.description,
    this.relatedSessionId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
        'description': description,
        'relatedSessionId': relatedSessionId,
      };

  factory CoinTransaction.fromJson(Map<String, dynamic> json) => CoinTransaction(
        id: json['id'] ?? '',
        type: EnumJson.at(CoinTransactionType.values, json['type'],
            CoinTransactionType.earned),
        amount: json['amount'] ?? 0,
        timestamp: DateTime.parse(json['timestamp']),
        description: json['description'] ?? '',
        relatedSessionId: json['relatedSessionId'],
      );
}

class CoinsCalculator {
  static int calculateCoinsForSession(int minutes, {bool isCompleted = true}) {
    if (!isCompleted) return 0;
    return minutes * 2;
  }

  static int calculateStreakBonus(int streakDays) {
    if (streakDays >= 30) return 100;
    if (streakDays >= 14) return 50;
    if (streakDays >= 7) return 25;
    if (streakDays >= 3) return 10;
    return 0;
  }
}
