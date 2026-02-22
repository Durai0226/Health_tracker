import 'package:hive_flutter/hive_flutter.dart';

part 'finance_enums.g.dart';

@HiveType(typeId: 80)
enum TransactionType {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
  @HiveField(2)
  transfer,
}

@HiveType(typeId: 81)
enum AccountType {
  @HiveField(0)
  cash,
  @HiveField(1)
  bank,
  @HiveField(2)
  creditCard,
  @HiveField(3)
  savings,
  @HiveField(4)
  investment,
  @HiveField(5)
  wallet,
}

@HiveType(typeId: 82)
enum RecurrenceType {
  @HiveField(0)
  none,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
  @HiveField(3)
  monthly,
  @HiveField(4)
  yearly,
}

@HiveType(typeId: 83)
enum BudgetPeriod {
  @HiveField(0)
  weekly,
  @HiveField(1)
  monthly,
  @HiveField(2)
  yearly,
}

extension TransactionTypeExtension on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }
}

extension AccountTypeExtension on AccountType {
  String get displayName {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.savings:
        return 'Savings';
      case AccountType.investment:
        return 'Investment';
      case AccountType.wallet:
        return 'Digital Wallet';
    }
  }

  String get icon {
    switch (this) {
      case AccountType.cash:
        return '💵';
      case AccountType.bank:
        return '🏦';
      case AccountType.creditCard:
        return '💳';
      case AccountType.savings:
        return '🏧';
      case AccountType.investment:
        return '📈';
      case AccountType.wallet:
        return '👛';
    }
  }
}

extension RecurrenceTypeExtension on RecurrenceType {
  String get displayName {
    switch (this) {
      case RecurrenceType.none:
        return 'One-time';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.yearly:
        return 'Yearly';
    }
  }
}

extension BudgetPeriodExtension on BudgetPeriod {
  String get displayName {
    switch (this) {
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
      case BudgetPeriod.yearly:
        return 'Yearly';
    }
  }
}
