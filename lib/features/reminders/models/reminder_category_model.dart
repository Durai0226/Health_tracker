import 'package:flutter/material.dart';

class ReminderCategory {
  final String id;
  final String name;
  final int color; // Store as int (Color.value)
  final int icon; // Store as int (IconData.codePoint)
  final bool isDefault; // To prevent deleting default categories if needed

  ReminderCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.isDefault = false,
  });

  /// Colors offered by the category editor (ARGB ints).
  static const List<int> availableColors = [
    0xFF4CAF50, // green
    0xFF2196F3, // blue
    0xFFFF5722, // deep orange
    0xFF9C27B0, // purple
    0xFF009688, // teal
    0xFFE91E63, // pink
    0xFF3F51B5, // indigo
    0xFFFF9800, // orange
    0xFFF44336, // red
    0xFF607D8B, // blue grey
  ];

  /// Icons offered by the category editor. Kept as const [IconData] literals so
  /// the icon tree-shaker retains them.
  static const List<IconData> availableIcons = [
    Icons.label_rounded,
    Icons.notifications_rounded,
    Icons.person_rounded,
    Icons.work_rounded,
    Icons.health_and_safety_rounded,
    Icons.favorite_rounded,
    Icons.school_rounded,
    Icons.home_rounded,
    Icons.attach_money_rounded,
    Icons.shopping_cart_rounded,
    Icons.fitness_center_rounded,
    Icons.restaurant_rounded,
    Icons.flight_rounded,
    Icons.directions_car_rounded,
    Icons.pets_rounded,
    Icons.celebration_rounded,
  ];

  // Helpers to get Color and IconData
  Color get colorObj => Color(color);
  IconData get iconObj {
    // Prefer the editor's icon set so picker and rendering stay in sync.
    for (final ic in availableIcons) {
      if (ic.codePoint == icon) return ic;
    }
    // Fall back to legacy / seeded code points (const map => tree-shake safe).
    const legacyIconMap = {
      0xe7fd: Icons.person_rounded, // seed: Personal
      0xe89c: Icons.work_rounded, // seed: Work
      0xe3f4: Icons.health_and_safety_rounded, // seed: Health
      0xe7e9: Icons.notifications_outlined,
      0xe547: Icons.local_hospital_outlined,
      0xe8c9: Icons.school_outlined,
      0xe8e8: Icons.home_outlined,
      0xe263: Icons.business_outlined,
      0xe3e7: Icons.restaurant_outlined,
      0xe1a3: Icons.directions_car_outlined,
      0xe8b7: Icons.account_balance_wallet_outlined,
      0xe90c: Icons.bolt_outlined,
      0xe8c4: Icons.monetization_on_outlined,
    };
    return legacyIconMap[icon] ?? Icons.label_rounded;
  }
  
  ReminderCategory copyWith({
    String? name,
    int? color,
    int? icon,
  }) {
    return ReminderCategory(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isDefault: isDefault,
    );
  }
}
