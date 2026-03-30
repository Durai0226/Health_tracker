/// Finance module enums

/// Type of financial transaction
enum TransactionType {
  income,
  expense,
  transfer;

  String get label {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  static TransactionType fromIndex(int index) {
    return TransactionType.values[index.clamp(0, TransactionType.values.length - 1)];
  }
}

/// Type of financial account
enum AccountType {
  cash,
  bank,
  creditCard,
  savings,
  investment,
  wallet;

  String get label {
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
        return '📱';
    }
  }

  static AccountType fromIndex(int index) {
    return AccountType.values[index.clamp(0, AccountType.values.length - 1)];
  }
}

/// Budget period
enum BudgetPeriod {
  weekly,
  monthly,
  yearly;

  String get label {
    switch (this) {
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
      case BudgetPeriod.yearly:
        return 'Yearly';
    }
  }

  static BudgetPeriod fromIndex(int index) {
    return BudgetPeriod.values[index.clamp(0, BudgetPeriod.values.length - 1)];
  }
}

/// Bill status
enum BillStatus {
  upcoming,
  overdue,
  paid,
  cancelled,
  skipped;

  String get label {
    switch (this) {
      case BillStatus.upcoming:
        return 'Upcoming';
      case BillStatus.overdue:
        return 'Overdue';
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.cancelled:
        return 'Cancelled';
      case BillStatus.skipped:
        return 'Skipped';
    }
  }

  static BillStatus fromIndex(int index) {
    return BillStatus.values[index.clamp(0, BillStatus.values.length - 1)];
  }
}

/// Bill recurrence
enum BillRecurrence {
  oneTime,
  daily,
  weekly,
  biWeekly,
  monthly,
  quarterly,
  yearly;

  String get label {
    switch (this) {
      case BillRecurrence.oneTime:
        return 'One Time';
      case BillRecurrence.daily:
        return 'Daily';
      case BillRecurrence.weekly:
        return 'Weekly';
      case BillRecurrence.biWeekly:
        return 'Bi-Weekly';
      case BillRecurrence.monthly:
        return 'Monthly';
      case BillRecurrence.quarterly:
        return 'Quarterly';
      case BillRecurrence.yearly:
        return 'Yearly';
    }
  }

  static BillRecurrence fromIndex(int index) {
    return BillRecurrence.values[index.clamp(0, BillRecurrence.values.length - 1)];
  }
}

/// Investment type
enum InvestmentType {
  deposit,
  stock,
  bond,
  mutualFund,
  insurance,
  realEstate,
  crypto,
  other;

  String get label {
    switch (this) {
      case InvestmentType.deposit:
        return 'Fixed Deposit';
      case InvestmentType.stock:
        return 'Stock';
      case InvestmentType.bond:
        return 'Bond';
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.insurance:
        return 'Insurance';
      case InvestmentType.realEstate:
        return 'Real Estate';
      case InvestmentType.crypto:
        return 'Cryptocurrency';
      case InvestmentType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case InvestmentType.deposit:
        return '🏦';
      case InvestmentType.stock:
        return '📈';
      case InvestmentType.bond:
        return '📜';
      case InvestmentType.mutualFund:
        return '📊';
      case InvestmentType.insurance:
        return '🛡️';
      case InvestmentType.realEstate:
        return '🏠';
      case InvestmentType.crypto:
        return '₿';
      case InvestmentType.other:
        return '💰';
    }
  }

  static InvestmentType fromIndex(int index) {
    return InvestmentType.values[index.clamp(0, InvestmentType.values.length - 1)];
  }
}
