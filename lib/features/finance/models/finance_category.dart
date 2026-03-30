import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Transaction category model
class FinanceCategory {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final bool isIncome;
  final bool isDefault;
  final int sortOrder;
  final DateTime createdAt;

  FinanceCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.isIncome = false,
    this.isDefault = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  factory FinanceCategory.create({
    required String name,
    required IconData icon,
    required Color color,
    bool isIncome = false,
    bool isDefault = false,
  }) {
    return FinanceCategory(
      id: const Uuid().v4(),
      name: name,
      iconCodePoint: icon.codePoint,
      colorValue: color.value,
      isIncome: isIncome,
      isDefault: isDefault,
      createdAt: DateTime.now(),
    );
  }

  FinanceCategory copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    bool? isIncome,
    bool? isDefault,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return FinanceCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isIncome: isIncome ?? this.isIncome,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isIncome': isIncome,
      'isDefault': isDefault,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FinanceCategory.fromJson(Map<String, dynamic> json) {
    return FinanceCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      isIncome: json['isIncome'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static List<FinanceCategory> getDefaultExpenseCategories() {
    return [
      FinanceCategory.create(
        name: 'Food & Drink',
        icon: Icons.restaurant,
        color: Colors.orange,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Shopping',
        icon: Icons.shopping_bag,
        color: Colors.pink,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Transport',
        icon: Icons.directions_car,
        color: Colors.blue,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Bills & Utilities',
        icon: Icons.receipt_long,
        color: Colors.red,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Entertainment',
        icon: Icons.movie,
        color: Colors.purple,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Health',
        icon: Icons.medical_services,
        color: Colors.teal,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Education',
        icon: Icons.school,
        color: Colors.indigo,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Groceries',
        icon: Icons.shopping_cart,
        color: Colors.green,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Rent',
        icon: Icons.home,
        color: Colors.brown,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Other',
        icon: Icons.more_horiz,
        color: Colors.grey,
        isDefault: true,
      ),
    ];
  }

  static List<FinanceCategory> getDefaultIncomeCategories() {
    return [
      FinanceCategory.create(
        name: 'Salary',
        icon: Icons.work,
        color: Colors.green,
        isIncome: true,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Freelance',
        icon: Icons.laptop_mac,
        color: Colors.blue,
        isIncome: true,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Investment',
        icon: Icons.trending_up,
        color: Colors.purple,
        isIncome: true,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Gift',
        icon: Icons.card_giftcard,
        color: Colors.pink,
        isIncome: true,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Refund',
        icon: Icons.replay,
        color: Colors.orange,
        isIncome: true,
        isDefault: true,
      ),
      FinanceCategory.create(
        name: 'Other Income',
        icon: Icons.attach_money,
        color: Colors.teal,
        isIncome: true,
        isDefault: true,
      ),
    ];
  }

  static List<FinanceCategory> getDefaultCategories() {
    return [
      ...getDefaultExpenseCategories(),
      ...getDefaultIncomeCategories(),
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
