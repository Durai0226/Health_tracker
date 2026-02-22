import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'finance_enums.dart';

part 'budget.g.dart';

@HiveType(typeId: 87)
class Budget extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double limit;

  @HiveField(3)
  final double spent;

  @HiveField(4)
  final BudgetPeriod period;

  @HiveField(5)
  final List<String> categoryIds;

  @HiveField(6)
  final int colorValue;

  @HiveField(7)
  final DateTime startDate;

  @HiveField(8)
  final bool isArchived;

  @HiveField(9)
  final bool notifyAtPercent;

  @HiveField(10)
  final int notifyPercent;

  Budget({
    String? id,
    required this.name,
    required this.limit,
    this.spent = 0.0,
    required this.period,
    required this.categoryIds,
    int? colorValue,
    DateTime? startDate,
    this.isArchived = false,
    this.notifyAtPercent = true,
    this.notifyPercent = 80,
  })  : id = id ?? const Uuid().v4(),
        colorValue = colorValue ?? const Color(0xFFF59E0B).value,
        startDate = startDate ?? DateTime.now();

  Color get color => Color(colorValue);

  double get remaining => limit - spent;
  double get percentUsed => limit > 0 ? (spent / limit * 100).clamp(0, 100) : 0;
  bool get isOverBudget => spent > limit;
  bool get isNearLimit => percentUsed >= notifyPercent;

  Budget copyWith({
    String? name,
    double? limit,
    double? spent,
    BudgetPeriod? period,
    List<String>? categoryIds,
    int? colorValue,
    DateTime? startDate,
    bool? isArchived,
    bool? notifyAtPercent,
    int? notifyPercent,
  }) {
    return Budget(
      id: id,
      name: name ?? this.name,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      period: period ?? this.period,
      categoryIds: categoryIds ?? this.categoryIds,
      colorValue: colorValue ?? this.colorValue,
      startDate: startDate ?? this.startDate,
      isArchived: isArchived ?? this.isArchived,
      notifyAtPercent: notifyAtPercent ?? this.notifyAtPercent,
      notifyPercent: notifyPercent ?? this.notifyPercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'limit': limit,
        'spent': spent,
        'period': period.index,
        'categoryIds': categoryIds,
        'colorValue': colorValue,
        'startDate': startDate.toIso8601String(),
        'isArchived': isArchived,
        'notifyAtPercent': notifyAtPercent,
        'notifyPercent': notifyPercent,
      };

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'],
      name: json['name'],
      limit: (json['limit'] as num).toDouble(),
      spent: (json['spent'] as num).toDouble(),
      period: BudgetPeriod.values[json['period']],
      categoryIds: List<String>.from(json['categoryIds']),
      colorValue: json['colorValue'],
      startDate: DateTime.parse(json['startDate']),
      isArchived: json['isArchived'] ?? false,
      notifyAtPercent: json['notifyAtPercent'] ?? true,
      notifyPercent: json['notifyPercent'] ?? 80,
    );
  }
}
