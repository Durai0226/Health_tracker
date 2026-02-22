import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'reminder_category_model.g.dart';

@HiveType(typeId: 204)
class ReminderCategory {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int color; // Store as int (Color.value)

  @HiveField(3)
  final int icon; // Store as int (IconData.codePoint)

  @HiveField(4)
  final bool isDefault; // To prevent deleting default categories if needed

  ReminderCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.isDefault = false,
  });

  // Helpers to get Color and IconData
  Color get colorObj => Color(color);
  IconData get iconObj {
    // Use predefined Material Icons to enable tree shaking
    const iconMap = {
      0xe7e9: Icons.notifications_outlined, // notification icon
      0xe547: Icons.local_hospital_outlined, // healthcare icon
      0xe8c9: Icons.school_outlined, // education icon
      0xe8e8: Icons.home_outlined, // home icon
      0xe263: Icons.business_outlined, // work icon
      0xe3e7: Icons.restaurant_outlined, // food icon
      0xe1a3: Icons.directions_car_outlined, // transport icon
      0xe8b7: Icons.account_balance_wallet_outlined, // finance icon
      0xe90c: Icons.bolt_outlined, // utilities icon
      0xe8c4: Icons.monetization_on_outlined, // general icon
    };
    return iconMap[icon] ?? Icons.notifications_outlined;
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
