import 'package:flutter/material.dart';

enum PlantType {
  seedling,
  sprout,
  sapling,
  tree,
  floweringTree,
  sakura,
  bamboo,
  bonsai,
  cactus,
  sunflower,
  lavender,
  oak,
}

extension PlantTypeExtension on PlantType {
  String get name {
    switch (this) {
      case PlantType.seedling:
        return 'Seedling';
      case PlantType.sprout:
        return 'Sprout';
      case PlantType.sapling:
        return 'Sapling';
      case PlantType.tree:
        return 'Tree';
      case PlantType.floweringTree:
        return 'Flowering Tree';
      case PlantType.sakura:
        return 'Sakura';
      case PlantType.bamboo:
        return 'Bamboo';
      case PlantType.bonsai:
        return 'Bonsai';
      case PlantType.cactus:
        return 'Cactus';
      case PlantType.sunflower:
        return 'Sunflower';
      case PlantType.lavender:
        return 'Lavender';
      case PlantType.oak:
        return 'Oak Tree';
    }
  }

  String get emoji {
    switch (this) {
      case PlantType.seedling:
        return '🌱';
      case PlantType.sprout:
        return '🌿';
      case PlantType.sapling:
        return '🪴';
      case PlantType.tree:
        return '🌳';
      case PlantType.floweringTree:
        return '🌸';
      case PlantType.sakura:
        return '🌸';
      case PlantType.bamboo:
        return '🎋';
      case PlantType.bonsai:
        return '🌲';
      case PlantType.cactus:
        return '🌵';
      case PlantType.sunflower:
        return '🌻';
      case PlantType.lavender:
        return '💜';
      case PlantType.oak:
        return '🌳';
    }
  }

  Color get primaryColor {
    switch (this) {
      case PlantType.seedling:
        return const Color(0xFF8BC34A);
      case PlantType.sprout:
        return const Color(0xFF4CAF50);
      case PlantType.sapling:
        return const Color(0xFF43A047);
      case PlantType.tree:
        return const Color(0xFF2E7D32);
      case PlantType.floweringTree:
        return const Color(0xFFE91E63);
      case PlantType.sakura:
        return const Color(0xFFF8BBD9);
      case PlantType.bamboo:
        return const Color(0xFF66BB6A);
      case PlantType.bonsai:
        return const Color(0xFF1B5E20);
      case PlantType.cactus:
        return const Color(0xFF7CB342);
      case PlantType.sunflower:
        return const Color(0xFFFFC107);
      case PlantType.lavender:
        return const Color(0xFF9C27B0);
      case PlantType.oak:
        return const Color(0xFF5D4037);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case PlantType.seedling:
        return const Color(0xFFC5E1A5);
      case PlantType.sprout:
        return const Color(0xFFA5D6A7);
      case PlantType.sapling:
        return const Color(0xFF81C784);
      case PlantType.tree:
        return const Color(0xFF66BB6A);
      case PlantType.floweringTree:
        return const Color(0xFFF48FB1);
      case PlantType.sakura:
        return const Color(0xFFFCE4EC);
      case PlantType.bamboo:
        return const Color(0xFFA5D6A7);
      case PlantType.bonsai:
        return const Color(0xFF388E3C);
      case PlantType.cactus:
        return const Color(0xFFAED581);
      case PlantType.sunflower:
        return const Color(0xFFFFE082);
      case PlantType.lavender:
        return const Color(0xFFCE93D8);
      case PlantType.oak:
        return const Color(0xFF8D6E63);
    }
  }

  int get unlockMinutes {
    switch (this) {
      case PlantType.seedling:
        return 0;
      case PlantType.sprout:
        return 30;
      case PlantType.sapling:
        return 60;
      case PlantType.tree:
        return 120;
      case PlantType.floweringTree:
        return 180;
      case PlantType.sakura:
        return 300;
      case PlantType.bamboo:
        return 240;
      case PlantType.bonsai:
        return 360;
      case PlantType.cactus:
        return 150;
      case PlantType.sunflower:
        return 200;
      case PlantType.lavender:
        return 250;
      case PlantType.oak:
        return 500;
    }
  }

  int get minSessionMinutes {
    switch (this) {
      case PlantType.seedling:
        return 5;
      case PlantType.sprout:
        return 10;
      case PlantType.sapling:
        return 15;
      case PlantType.tree:
        return 25;
      case PlantType.floweringTree:
        return 30;
      case PlantType.sakura:
        return 30;
      case PlantType.bamboo:
        return 25;
      case PlantType.bonsai:
        return 45;
      case PlantType.cactus:
        return 20;
      case PlantType.sunflower:
        return 20;
      case PlantType.lavender:
        return 25;
      case PlantType.oak:
        return 60;
    }
  }
}

class FocusPlant {
  final String id;
  final PlantType type;
  final DateTime plantedAt;
  final int durationMinutes;
  final bool isAlive;
  final double growthProgress;
  final String? activity;

  FocusPlant({
    required this.id,
    required this.type,
    required this.plantedAt,
    required this.durationMinutes,
    this.isAlive = true,
    this.growthProgress = 0.0,
    this.activity,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'plantedAt': plantedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'isAlive': isAlive,
        'growthProgress': growthProgress,
        'activity': activity,
      };

  factory FocusPlant.fromJson(Map<String, dynamic> json) => FocusPlant(
        id: json['id'] ?? '',
        type: PlantType.values[json['type'] ?? 0],
        plantedAt: DateTime.parse(json['plantedAt']),
        durationMinutes: json['durationMinutes'] ?? 0,
        isAlive: json['isAlive'] ?? true,
        growthProgress: (json['growthProgress'] ?? 0.0).toDouble(),
        activity: json['activity'],
      );

  FocusPlant copyWith({
    String? id,
    PlantType? type,
    DateTime? plantedAt,
    int? durationMinutes,
    bool? isAlive,
    double? growthProgress,
    String? activity,
  }) {
    return FocusPlant(
      id: id ?? this.id,
      type: type ?? this.type,
      plantedAt: plantedAt ?? this.plantedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isAlive: isAlive ?? this.isAlive,
      growthProgress: growthProgress ?? this.growthProgress,
      activity: activity ?? this.activity,
    );
  }
}
