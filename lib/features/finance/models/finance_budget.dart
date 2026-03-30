import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'finance_enums.dart';

/// Budget model for tracking spending limits by category
class FinanceBudget {
  final String id;
  final String name;
  final double limit;
  final double spent;
  final BudgetPeriod period;
  final List<String> categoryIds;
  final int colorValue;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isArchived;
  final bool notifyAtPercent;
  final int notifyPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinanceBudget({
    required this.id,
    required this.name,
    required this.limit,
    this.spent = 0,
    required this.period,
    required this.categoryIds,
    required this.colorValue,
    required this.startDate,
    this.endDate,
    this.isArchived = false,
    this.notifyAtPercent = true,
    this.notifyPercent = 80,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get color => Color(colorValue);
  double get remaining => limit - spent;
  double get percentUsed => limit > 0 ? (spent / limit * 100).clamp(0, 100) : 0;
  bool get isOverBudget => spent > limit;
  bool get isNearLimit => percentUsed >= notifyPercent;

  factory FinanceBudget.create({
    required String name,
    required double limit,
    required BudgetPeriod period,
    required List<String> categoryIds,
    Color color = Colors.blue,
    DateTime? startDate,
  }) {
    final now = DateTime.now();
    return FinanceBudget(
      id: const Uuid().v4(),
      name: name,
      limit: limit,
      period: period,
      categoryIds: categoryIds,
      colorValue: color.value,
      startDate: startDate ?? now,
      createdAt: now,
      updatedAt: now,
    );
  }

  FinanceBudget copyWith({
    String? id,
    String? name,
    double? limit,
    double? spent,
    BudgetPeriod? period,
    List<String>? categoryIds,
    int? colorValue,
    DateTime? startDate,
    DateTime? endDate,
    bool? isArchived,
    bool? notifyAtPercent,
    int? notifyPercent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceBudget(
      id: id ?? this.id,
      name: name ?? this.name,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      period: period ?? this.period,
      categoryIds: categoryIds ?? this.categoryIds,
      colorValue: colorValue ?? this.colorValue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isArchived: isArchived ?? this.isArchived,
      notifyAtPercent: notifyAtPercent ?? this.notifyAtPercent,
      notifyPercent: notifyPercent ?? this.notifyPercent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'limit': limit,
      'spent': spent,
      'period': period.index,
      'categoryIds': categoryIds,
      'colorValue': colorValue,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isArchived': isArchived,
      'notifyAtPercent': notifyAtPercent,
      'notifyPercent': notifyPercent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FinanceBudget.fromJson(Map<String, dynamic> json) {
    return FinanceBudget(
      id: json['id'] as String,
      name: json['name'] as String,
      limit: (json['limit'] as num).toDouble(),
      spent: (json['spent'] as num?)?.toDouble() ?? 0,
      period: BudgetPeriod.fromIndex(json['period'] as int),
      categoryIds: (json['categoryIds'] as List<dynamic>).cast<String>(),
      colorValue: json['colorValue'] as int,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      isArchived: json['isArchived'] as bool? ?? false,
      notifyAtPercent: json['notifyAtPercent'] as bool? ?? true,
      notifyPercent: json['notifyPercent'] as int? ?? 80,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceBudget &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
