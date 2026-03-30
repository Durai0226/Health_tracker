import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'finance_enums.dart';

/// Financial account model (bank, cash, card, wallet)
class FinanceAccount {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final int iconCodePoint;
  final int colorValue;
  final String currency;
  final bool includeInTotal;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinanceAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.iconCodePoint,
    required this.colorValue,
    this.currency = 'INR',
    this.includeInTotal = true,
    this.isArchived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  factory FinanceAccount.create({
    required String name,
    required AccountType type,
    double balance = 0,
    IconData icon = Icons.account_balance_wallet,
    Color color = Colors.blue,
    String currency = 'INR',
    bool includeInTotal = true,
  }) {
    final now = DateTime.now();
    return FinanceAccount(
      id: const Uuid().v4(),
      name: name,
      type: type,
      balance: balance,
      iconCodePoint: icon.codePoint,
      colorValue: color.value,
      currency: currency,
      includeInTotal: includeInTotal,
      createdAt: now,
      updatedAt: now,
    );
  }

  FinanceAccount copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    int? iconCodePoint,
    int? colorValue,
    String? currency,
    bool? includeInTotal,
    bool? isArchived,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      currency: currency ?? this.currency,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'balance': balance,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'currency': currency,
      'includeInTotal': includeInTotal,
      'isArchived': isArchived,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FinanceAccount.fromJson(Map<String, dynamic> json) {
    return FinanceAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AccountType.fromIndex(json['type'] as int),
      balance: (json['balance'] as num).toDouble(),
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      currency: json['currency'] as String? ?? 'INR',
      includeInTotal: json['includeInTotal'] as bool? ?? true,
      isArchived: json['isArchived'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static List<FinanceAccount> getDefaultAccounts() {
    return [
      FinanceAccount.create(
        name: 'Cash',
        type: AccountType.cash,
        icon: Icons.money,
        color: Colors.green,
      ),
      FinanceAccount.create(
        name: 'Bank Account',
        type: AccountType.bank,
        icon: Icons.account_balance,
        color: Colors.blue,
      ),
      FinanceAccount.create(
        name: 'Credit Card',
        type: AccountType.creditCard,
        icon: Icons.credit_card,
        color: Colors.purple,
      ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
