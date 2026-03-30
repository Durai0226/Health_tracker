import 'package:drift/drift.dart';

/// Finance Accounts Table - Bank, Cash, Credit Card, etc.
class FinanceAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get type => integer()(); // AccountType enum
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  IntColumn get iconCodePoint => integer().withDefault(const Constant(0xe227))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF3B82F6))();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  BoolColumn get includeInTotal => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Finance Categories Table - Expense/Income categories
class FinanceCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get iconCodePoint => integer()();
  IntColumn get colorValue => integer()();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Finance Transactions Table - Income/Expense/Transfer
class FinanceTransactions extends Table {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  IntColumn get type => integer()(); // TransactionType enum
  TextColumn get categoryId => text()();
  TextColumn get accountId => text()();
  TextColumn get toAccountId => text().nullable()(); // For transfers
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get attachmentPath => text().nullable()();
  TextColumn get tagsJson => text().nullable()(); // JSON array
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Finance Budgets Table - Spending limits by category
class FinanceBudgets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get budgetLimit => real()();
  RealColumn get spent => real().withDefault(const Constant(0.0))();
  IntColumn get period => integer()(); // BudgetPeriod enum
  TextColumn get categoryIdsJson => text()(); // JSON array of category IDs
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF3B82F6))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get notifyAtPercent => boolean().withDefault(const Constant(true))();
  IntColumn get notifyPercent => integer().withDefault(const Constant(80))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Finance Investments Table - Deposits, Stocks, Bonds, etc.
class FinanceInvestments extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get type => integer()(); // InvestmentType enum
  RealColumn get investedAmount => real()();
  RealColumn get currentValue => real()();
  TextColumn get institution => text().nullable()();
  TextColumn get accountNumber => text().nullable()();
  DateTimeColumn get purchaseDate => dateTime()();
  DateTimeColumn get maturityDate => dateTime().nullable()();
  RealColumn get interestRate => real().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get iconCodePoint => integer().withDefault(const Constant(0xe227))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF3B82F6))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bills Table - Full model alignment with lib/features/finance/models/bill.dart
class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get status => integer()(); // BillStatus enum
  IntColumn get recurrence => integer().withDefault(const Constant(0))(); // BillRecurrence enum
  IntColumn get customRecurrenceInterval => integer().nullable()();
  IntColumn get customRecurrenceUnit => integer().nullable()(); // CustomRecurrenceUnit enum
  TextColumn get categoryId => text().nullable()();
  TextColumn get accountId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get receiptUrl => text().nullable()();
  TextColumn get tagsJson => text().nullable()(); // JSON array
  IntColumn get gracePeriodDays => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get templateId => text().nullable()();
  TextColumn get parentBillId => text().nullable()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  TextColumn get remindersJson => text().nullable()(); // JSON array of BillReminder
  TextColumn get currency => text().nullable()();
  RealColumn get exchangeRate => real().nullable()();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF3B82F6))();
  IntColumn get iconCodePoint => integer().withDefault(const Constant(0xe227))();
  TextColumn get deviceId => text().nullable()();
  TextColumn get notificationIdsJson => text().nullable()(); // JSON array of int
  BoolColumn get remindersEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(1))(); // BillPriority enum
  TextColumn get attachmentsJson => text().nullable()(); // JSON array
  IntColumn get escalationRemindersSent => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReminderSentAt => dateTime().nullable()();
  DateTimeColumn get lastScheduledAt => dateTime().nullable()();
  TextColumn get updatedByDeviceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bill Payments Table - Matches BillPayment class
class BillPayments extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  RealColumn get amount => real()();
  DateTimeColumn get paidAt => dateTime()();
  TextColumn get accountId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get transactionId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bill Categories Table - Matches BillCategory class
class BillCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodePoint => integer()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bill Templates Table - Matches BillTemplate class
class BillTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  IntColumn get recurrence => integer().withDefault(const Constant(4))(); // BillRecurrence.monthly
  IntColumn get customRecurrenceInterval => integer().nullable()();
  IntColumn get customRecurrenceUnit => integer().nullable()();
  IntColumn get advancedRecurrenceType => integer().withDefault(const Constant(0))();
  IntColumn get nthWeekday => integer().nullable()();
  IntColumn get weekdayIndex => integer().nullable()();
  DateTimeColumn get nextDueDate => dateTime()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get accountId => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get gracePeriodDays => integer().withDefault(const Constant(0))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF3B82F6))();
  IntColumn get iconCodePoint => integer().withDefault(const Constant(0xe532))();
  TextColumn get remindersJson => text().nullable()(); // JSON array
  BoolColumn get remindersEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get currency => text().nullable()();
  TextColumn get tagsJson => text().nullable()(); // JSON array
  IntColumn get priority => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastInstanceGeneratedAt => dateTime().nullable()();
  IntColumn get instanceGenerationWindowDays => integer().withDefault(const Constant(30))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bill Activities Table - Matches BillActivity class
class BillActivities extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  IntColumn get activityType => integer()(); // BillActivityType enum
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get description => text().nullable()();
  RealColumn get amount => real().nullable()();
  TextColumn get metadataJson => text().nullable()(); // JSON map
  TextColumn get deviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Category Keyword Maps Table - For auto-categorization
class CategoryKeywordMaps extends Table {
  TextColumn get id => text()();
  TextColumn get keyword => text()();
  TextColumn get categoryId => text()();
  IntColumn get frequency => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastUsed => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bill Settings Table - Matches BillSettings class
class BillSettingsTable extends Table {
  TextColumn get id => text().withDefault(const Constant('default'))();
  IntColumn get defaultReminderDaysBefore => integer().withDefault(const Constant(3))();
  IntColumn get defaultReminderHour => integer().withDefault(const Constant(9))();
  IntColumn get defaultReminderMinute => integer().withDefault(const Constant(0))();
  BoolColumn get enableEscalationReminders => boolean().withDefault(const Constant(true))();
  IntColumn get maxEscalationReminders => integer().withDefault(const Constant(3))();
  BoolColumn get requireBiometricLock => boolean().withDefault(const Constant(false))();
  IntColumn get instanceGenerationWindowDays => integer().withDefault(const Constant(30))();
  BoolColumn get showBadgeCount => boolean().withDefault(const Constant(true))();
  TextColumn get defaultCurrency => text().withDefault(const Constant('INR'))();
  IntColumn get defaultPriority => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get lastSyncDeviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Finance Settings Table (legacy key-value store)
class FinanceSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  IntColumn get intValue => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
