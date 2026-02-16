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
  IconData get iconObj => IconData(icon, fontFamily: 'MaterialIcons');
  
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
