import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Savings goal model for tracking progress toward financial targets
class FinanceSavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final int iconCodePoint;
  final int colorValue;
  final String? linkedAccountId;
  final SavingsFrequency contributionFrequency;
  final double? suggestedContribution;
  final bool isCompleted;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinanceSavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    required this.iconCodePoint,
    required this.colorValue,
    this.linkedAccountId,
    this.contributionFrequency = SavingsFrequency.monthly,
    this.suggestedContribution,
    this.isCompleted = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Computed properties
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
  
  double get progress => targetAmount > 0 
      ? (currentAmount / targetAmount * 100).clamp(0, 100) 
      : 0;
  
  double get remaining => (targetAmount - currentAmount).clamp(0, double.infinity);
  
  bool get isOnTrack {
    if (deadline == null) return true;
    final daysRemaining = deadline!.difference(DateTime.now()).inDays;
    if (daysRemaining <= 0) return isCompleted;
    final requiredDaily = remaining / daysRemaining;
    final currentDaily = currentAmount / DateTime.now().difference(createdAt).inDays.clamp(1, 9999);
    return currentDaily >= requiredDaily * 0.8;
  }

  int? get daysUntilDeadline {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  double get calculatedMonthlyContribution {
    if (deadline == null || remaining <= 0) return 0;
    final monthsRemaining = deadline!.difference(DateTime.now()).inDays / 30;
    if (monthsRemaining <= 0) return remaining;
    return remaining / monthsRemaining;
  }

  factory FinanceSavingsGoal.create({
    required String name,
    required double targetAmount,
    DateTime? deadline,
    IconData icon = Icons.savings,
    Color color = Colors.teal,
    String? linkedAccountId,
    SavingsFrequency frequency = SavingsFrequency.monthly,
  }) {
    final now = DateTime.now();
    return FinanceSavingsGoal(
      id: const Uuid().v4(),
      name: name,
      targetAmount: targetAmount,
      deadline: deadline,
      iconCodePoint: icon.codePoint,
      colorValue: color.value,
      linkedAccountId: linkedAccountId,
      contributionFrequency: frequency,
      createdAt: now,
      updatedAt: now,
    );
  }

  FinanceSavingsGoal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    int? iconCodePoint,
    int? colorValue,
    String? linkedAccountId,
    SavingsFrequency? contributionFrequency,
    double? suggestedContribution,
    bool? isCompleted,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceSavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      contributionFrequency: contributionFrequency ?? this.contributionFrequency,
      suggestedContribution: suggestedContribution ?? this.suggestedContribution,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  FinanceSavingsGoal addContribution(double amount) {
    final newAmount = currentAmount + amount;
    return copyWith(
      currentAmount: newAmount,
      isCompleted: newAmount >= targetAmount,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline?.toIso8601String(),
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'linkedAccountId': linkedAccountId,
      'contributionFrequency': contributionFrequency.index,
      'suggestedContribution': suggestedContribution,
      'isCompleted': isCompleted,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FinanceSavingsGoal.fromJson(Map<String, dynamic> json) {
    return FinanceSavingsGoal(
      id: json['id'] as String,
      name: json['name'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
      deadline: json['deadline'] != null 
          ? DateTime.parse(json['deadline'] as String) 
          : null,
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      linkedAccountId: json['linkedAccountId'] as String?,
      contributionFrequency: SavingsFrequency.fromIndex(
        json['contributionFrequency'] as int? ?? 1,
      ),
      suggestedContribution: (json['suggestedContribution'] as num?)?.toDouble(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceSavingsGoal &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // Common savings goal presets
  static List<SavingsGoalPreset> get presets => [
    SavingsGoalPreset(
      name: 'Emergency Fund',
      icon: Icons.shield,
      color: Colors.blue,
      suggestedTarget: 10000,
    ),
    SavingsGoalPreset(
      name: 'Vacation',
      icon: Icons.flight,
      color: Colors.orange,
      suggestedTarget: 3000,
    ),
    SavingsGoalPreset(
      name: 'New Car',
      icon: Icons.directions_car,
      color: Colors.red,
      suggestedTarget: 25000,
    ),
    SavingsGoalPreset(
      name: 'House Down Payment',
      icon: Icons.home,
      color: Colors.green,
      suggestedTarget: 50000,
    ),
    SavingsGoalPreset(
      name: 'Education',
      icon: Icons.school,
      color: Colors.purple,
      suggestedTarget: 15000,
    ),
    SavingsGoalPreset(
      name: 'Wedding',
      icon: Icons.favorite,
      color: Colors.pink,
      suggestedTarget: 20000,
    ),
    SavingsGoalPreset(
      name: 'Gadget',
      icon: Icons.devices,
      color: Colors.teal,
      suggestedTarget: 1500,
    ),
    SavingsGoalPreset(
      name: 'Custom',
      icon: Icons.star,
      color: Colors.amber,
      suggestedTarget: 1000,
    ),
  ];
}

/// Savings contribution frequency
enum SavingsFrequency {
  daily,
  weekly,
  biWeekly,
  monthly;

  String get label {
    switch (this) {
      case SavingsFrequency.daily:
        return 'Daily';
      case SavingsFrequency.weekly:
        return 'Weekly';
      case SavingsFrequency.biWeekly:
        return 'Bi-weekly';
      case SavingsFrequency.monthly:
        return 'Monthly';
    }
  }

  static SavingsFrequency fromIndex(int index) {
    return SavingsFrequency.values[index.clamp(0, SavingsFrequency.values.length - 1)];
  }
}

/// Preset template for common savings goals
class SavingsGoalPreset {
  final String name;
  final IconData icon;
  final Color color;
  final double suggestedTarget;

  const SavingsGoalPreset({
    required this.name,
    required this.icon,
    required this.color,
    required this.suggestedTarget,
  });
}
