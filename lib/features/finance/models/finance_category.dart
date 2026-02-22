import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'finance_category.g.dart';

@HiveType(typeId: 84)
class FinanceCategory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int iconCodePoint;

  @HiveField(3)
  final int colorValue;

  @HiveField(4)
  final bool isIncome;

  @HiveField(5)
  final bool isDefault;

  @HiveField(6)
  final int sortOrder;

  FinanceCategory({
    String? id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.isIncome = false,
    this.isDefault = false,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  FinanceCategory copyWith({
    String? name,
    int? iconCodePoint,
    int? colorValue,
    bool? isIncome,
    bool? isDefault,
    int? sortOrder,
  }) {
    return FinanceCategory(
      id: id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isIncome: isIncome ?? this.isIncome,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'isIncome': isIncome,
        'isDefault': isDefault,
        'sortOrder': sortOrder,
      };

  factory FinanceCategory.fromJson(Map<String, dynamic> json) {
    return FinanceCategory(
      id: json['id'],
      name: json['name'],
      iconCodePoint: json['iconCodePoint'],
      colorValue: json['colorValue'],
      isIncome: json['isIncome'] ?? false,
      isDefault: json['isDefault'] ?? false,
      sortOrder: json['sortOrder'] ?? 0,
    );
  }

  static List<FinanceCategory> getDefaultCategories() {
    return [
      // Expense categories
      FinanceCategory(
        id: 'food',
        name: 'Food & Dining',
        iconCodePoint: Icons.restaurant_rounded.codePoint,
        colorValue: const Color(0xFFFF6B6B).value,
        isDefault: true,
        sortOrder: 1,
      ),
      FinanceCategory(
        id: 'transport',
        name: 'Transportation',
        iconCodePoint: Icons.directions_car_rounded.codePoint,
        colorValue: const Color(0xFF4ECDC4).value,
        isDefault: true,
        sortOrder: 2,
      ),
      FinanceCategory(
        id: 'shopping',
        name: 'Shopping',
        iconCodePoint: Icons.shopping_bag_rounded.codePoint,
        colorValue: const Color(0xFFFFBE0B).value,
        isDefault: true,
        sortOrder: 3,
      ),
      FinanceCategory(
        id: 'entertainment',
        name: 'Entertainment',
        iconCodePoint: Icons.movie_rounded.codePoint,
        colorValue: const Color(0xFF9B5DE5).value,
        isDefault: true,
        sortOrder: 4,
      ),
      FinanceCategory(
        id: 'bills',
        name: 'Bills & Utilities',
        iconCodePoint: Icons.receipt_long_rounded.codePoint,
        colorValue: const Color(0xFF00BBF9).value,
        isDefault: true,
        sortOrder: 5,
      ),
      FinanceCategory(
        id: 'health',
        name: 'Health & Medical',
        iconCodePoint: Icons.medical_services_rounded.codePoint,
        colorValue: const Color(0xFFFF006E).value,
        isDefault: true,
        sortOrder: 6,
      ),
      FinanceCategory(
        id: 'education',
        name: 'Education',
        iconCodePoint: Icons.school_rounded.codePoint,
        colorValue: const Color(0xFF3A86FF).value,
        isDefault: true,
        sortOrder: 7,
      ),
      FinanceCategory(
        id: 'groceries',
        name: 'Groceries',
        iconCodePoint: Icons.local_grocery_store_rounded.codePoint,
        colorValue: const Color(0xFF8AC926).value,
        isDefault: true,
        sortOrder: 8,
      ),
      FinanceCategory(
        id: 'other_expense',
        name: 'Other',
        iconCodePoint: Icons.more_horiz_rounded.codePoint,
        colorValue: const Color(0xFF6C757D).value,
        isDefault: true,
        sortOrder: 99,
      ),
      // Income categories
      FinanceCategory(
        id: 'salary',
        name: 'Salary',
        iconCodePoint: Icons.work_rounded.codePoint,
        colorValue: const Color(0xFF22C55E).value,
        isIncome: true,
        isDefault: true,
        sortOrder: 1,
      ),
      FinanceCategory(
        id: 'freelance',
        name: 'Freelance',
        iconCodePoint: Icons.laptop_rounded.codePoint,
        colorValue: const Color(0xFF10B981).value,
        isIncome: true,
        isDefault: true,
        sortOrder: 2,
      ),
      FinanceCategory(
        id: 'investment_income',
        name: 'Investments',
        iconCodePoint: Icons.trending_up_rounded.codePoint,
        colorValue: const Color(0xFF059669).value,
        isIncome: true,
        isDefault: true,
        sortOrder: 3,
      ),
      FinanceCategory(
        id: 'other_income',
        name: 'Other Income',
        iconCodePoint: Icons.attach_money_rounded.codePoint,
        colorValue: const Color(0xFF047857).value,
        isIncome: true,
        isDefault: true,
        sortOrder: 99,
      ),
    ];
  }
}
