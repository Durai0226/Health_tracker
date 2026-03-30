import 'dart:convert';
import 'package:flutter/material.dart';

/// Predefined habit group types
enum HabitGroupType {
  all,
  study,
  exercise,
  work,
  health,
  social,
  creative,
  mindfulness,
  finance,
  custom,
}

/// Habit group/category for organizing habits
class HabitGroup {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final HabitGroupType type;
  final int sortOrder;
  final bool isDefault;
  final DateTime createdAt;

  const HabitGroup({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.type = HabitGroupType.custom,
    this.sortOrder = 0,
    this.isDefault = false,
    required this.createdAt,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  HabitGroup copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    HabitGroupType? type,
    int? sortOrder,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return HabitGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'type': type.index,
      'sortOrder': sortOrder,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HabitGroup.fromJson(Map<String, dynamic> json) {
    return HabitGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      type: HabitGroupType.values[json['type'] as int? ?? 0],
      sortOrder: json['sortOrder'] as int? ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitGroup.fromJsonString(String jsonString) {
    return HabitGroup.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Get default groups
  static List<HabitGroup> get defaultGroups {
    final now = DateTime.now();
    return [
      HabitGroup(
        id: 'all',
        name: 'All',
        iconCodePoint: Icons.grid_view_rounded.codePoint,
        colorValue: const Color(0xFF7C91F4).value,
        type: HabitGroupType.all,
        sortOrder: 0,
        isDefault: true,
        createdAt: now,
      ),
      HabitGroup(
        id: 'study',
        name: 'Study',
        iconCodePoint: Icons.school_outlined.codePoint,
        colorValue: const Color(0xFF7C91F4).value,
        type: HabitGroupType.study,
        sortOrder: 1,
        isDefault: true,
        createdAt: now,
      ),
      HabitGroup(
        id: 'exercise',
        name: 'Exercise',
        iconCodePoint: Icons.fitness_center.codePoint,
        colorValue: const Color(0xFF4CAF50).value,
        type: HabitGroupType.exercise,
        sortOrder: 2,
        isDefault: true,
        createdAt: now,
      ),
      HabitGroup(
        id: 'work',
        name: 'Work',
        iconCodePoint: Icons.work_outline.codePoint,
        colorValue: const Color(0xFFFF9800).value,
        type: HabitGroupType.work,
        sortOrder: 3,
        isDefault: true,
        createdAt: now,
      ),
      HabitGroup(
        id: 'health',
        name: 'Health',
        iconCodePoint: Icons.favorite_outline.codePoint,
        colorValue: const Color(0xFFE91E63).value,
        type: HabitGroupType.health,
        sortOrder: 4,
        isDefault: true,
        createdAt: now,
      ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitGroup && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
