import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'finance_enums.dart';

/// Investment model for tracking deposits, stocks, bonds, etc.
class FinanceInvestment {
  final String id;
  final String name;
  final InvestmentType type;
  final double investedAmount;
  final double currentValue;
  final String? institution;
  final String? accountNumber;
  final DateTime purchaseDate;
  final DateTime? maturityDate;
  final double? interestRate;
  final String? note;
  final int iconCodePoint;
  final int colorValue;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinanceInvestment({
    required this.id,
    required this.name,
    required this.type,
    required this.investedAmount,
    required this.currentValue,
    this.institution,
    this.accountNumber,
    required this.purchaseDate,
    this.maturityDate,
    this.interestRate,
    this.note,
    required this.iconCodePoint,
    required this.colorValue,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
  
  double get totalReturn => currentValue - investedAmount;
  double get returnPercent => investedAmount > 0 
      ? ((currentValue - investedAmount) / investedAmount * 100) 
      : 0;
  bool get isProfit => totalReturn > 0;
  bool get isLoss => totalReturn < 0;

  factory FinanceInvestment.create({
    required String name,
    required InvestmentType type,
    required double investedAmount,
    double? currentValue,
    String? institution,
    String? accountNumber,
    DateTime? purchaseDate,
    DateTime? maturityDate,
    double? interestRate,
    String? note,
    IconData? icon,
    Color? color,
  }) {
    final now = DateTime.now();
    return FinanceInvestment(
      id: const Uuid().v4(),
      name: name,
      type: type,
      investedAmount: investedAmount,
      currentValue: currentValue ?? investedAmount,
      institution: institution,
      accountNumber: accountNumber,
      purchaseDate: purchaseDate ?? now,
      maturityDate: maturityDate,
      interestRate: interestRate,
      note: note,
      iconCodePoint: (icon ?? _getDefaultIcon(type)).codePoint,
      colorValue: (color ?? _getDefaultColor(type)).value,
      createdAt: now,
      updatedAt: now,
    );
  }

  static IconData _getDefaultIcon(InvestmentType type) {
    switch (type) {
      case InvestmentType.deposit:
        return Icons.account_balance;
      case InvestmentType.stock:
        return Icons.show_chart;
      case InvestmentType.bond:
        return Icons.description;
      case InvestmentType.mutualFund:
        return Icons.pie_chart;
      case InvestmentType.insurance:
        return Icons.security;
      case InvestmentType.realEstate:
        return Icons.home;
      case InvestmentType.crypto:
        return Icons.currency_bitcoin;
      case InvestmentType.other:
        return Icons.savings;
    }
  }

  static Color _getDefaultColor(InvestmentType type) {
    switch (type) {
      case InvestmentType.deposit:
        return Colors.blue;
      case InvestmentType.stock:
        return Colors.green;
      case InvestmentType.bond:
        return Colors.orange;
      case InvestmentType.mutualFund:
        return Colors.purple;
      case InvestmentType.insurance:
        return Colors.teal;
      case InvestmentType.realEstate:
        return Colors.brown;
      case InvestmentType.crypto:
        return Colors.amber;
      case InvestmentType.other:
        return Colors.grey;
    }
  }

  FinanceInvestment copyWith({
    String? id,
    String? name,
    InvestmentType? type,
    double? investedAmount,
    double? currentValue,
    String? institution,
    String? accountNumber,
    DateTime? purchaseDate,
    DateTime? maturityDate,
    double? interestRate,
    String? note,
    int? iconCodePoint,
    int? colorValue,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceInvestment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      investedAmount: investedAmount ?? this.investedAmount,
      currentValue: currentValue ?? this.currentValue,
      institution: institution ?? this.institution,
      accountNumber: accountNumber ?? this.accountNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      maturityDate: maturityDate ?? this.maturityDate,
      interestRate: interestRate ?? this.interestRate,
      note: note ?? this.note,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'investedAmount': investedAmount,
      'currentValue': currentValue,
      'institution': institution,
      'accountNumber': accountNumber,
      'purchaseDate': purchaseDate.toIso8601String(),
      'maturityDate': maturityDate?.toIso8601String(),
      'interestRate': interestRate,
      'note': note,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FinanceInvestment.fromJson(Map<String, dynamic> json) {
    return FinanceInvestment(
      id: json['id'] as String,
      name: json['name'] as String,
      type: InvestmentType.fromIndex(json['type'] as int),
      investedAmount: (json['investedAmount'] as num).toDouble(),
      currentValue: (json['currentValue'] as num).toDouble(),
      institution: json['institution'] as String?,
      accountNumber: json['accountNumber'] as String?,
      purchaseDate: DateTime.parse(json['purchaseDate'] as String),
      maturityDate: json['maturityDate'] != null 
          ? DateTime.parse(json['maturityDate'] as String) 
          : null,
      interestRate: (json['interestRate'] as num?)?.toDouble(),
      note: json['note'] as String?,
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceInvestment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
