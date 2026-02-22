import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'finance_enums.dart';

part 'finance_account.g.dart';

@HiveType(typeId: 85)
class FinanceAccount extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final AccountType type;

  @HiveField(3)
  final double balance;

  @HiveField(4)
  final int colorValue;

  @HiveField(5)
  final int iconCodePoint;

  @HiveField(6)
  final String currency;

  @HiveField(7)
  final bool includeInTotal;

  @HiveField(8)
  final bool isArchived;

  @HiveField(9)
  final int sortOrder;

  @HiveField(10)
  final DateTime createdAt;

  FinanceAccount({
    String? id,
    required this.name,
    required this.type,
    this.balance = 0.0,
    int? colorValue,
    int? iconCodePoint,
    this.currency = '₹',
    this.includeInTotal = true,
    this.isArchived = false,
    this.sortOrder = 0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        colorValue = colorValue ?? const Color(0xFF3B82F6).value,
        iconCodePoint = iconCodePoint ?? Icons.account_balance_wallet_rounded.codePoint,
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  bool get isLiability => type == AccountType.creditCard;

  FinanceAccount copyWith({
    String? name,
    AccountType? type,
    double? balance,
    int? colorValue,
    int? iconCodePoint,
    String? currency,
    bool? includeInTotal,
    bool? isArchived,
    int? sortOrder,
  }) {
    return FinanceAccount(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      currency: currency ?? this.currency,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'balance': balance,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
        'currency': currency,
        'includeInTotal': includeInTotal,
        'isArchived': isArchived,
        'sortOrder': sortOrder,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FinanceAccount.fromJson(Map<String, dynamic> json) {
    return FinanceAccount(
      id: json['id'],
      name: json['name'],
      type: AccountType.values[json['type']],
      balance: (json['balance'] as num).toDouble(),
      colorValue: json['colorValue'],
      iconCodePoint: json['iconCodePoint'],
      currency: json['currency'] ?? '₹',
      includeInTotal: json['includeInTotal'] ?? true,
      isArchived: json['isArchived'] ?? false,
      sortOrder: json['sortOrder'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  static FinanceAccount createDefault() {
    return FinanceAccount(
      id: 'default_cash',
      name: 'Cash',
      type: AccountType.cash,
      balance: 0.0,
      colorValue: const Color(0xFF22C55E).value,
      iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
    );
  }
}
