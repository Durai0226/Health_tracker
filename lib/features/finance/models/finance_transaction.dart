import 'package:uuid/uuid.dart';
import 'finance_enums.dart';

/// Financial transaction model
class FinanceTransaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final String? toAccountId; // For transfers
  final DateTime date;
  final String? note;
  final String? attachmentPath;
  final List<String> tags;
  final bool isRecurring;
  final String? recurringId;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinanceTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    required this.date,
    this.note,
    this.attachmentPath,
    this.tags = const [],
    this.isRecurring = false,
    this.recurringId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;
  bool get isTransfer => type == TransactionType.transfer;

  factory FinanceTransaction.create({
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String accountId,
    String? toAccountId,
    DateTime? date,
    String? note,
    String? attachmentPath,
    List<String>? tags,
  }) {
    final now = DateTime.now();
    return FinanceTransaction(
      id: const Uuid().v4(),
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: toAccountId,
      date: date ?? now,
      note: note,
      attachmentPath: attachmentPath,
      tags: tags ?? [],
      createdAt: now,
      updatedAt: now,
    );
  }

  FinanceTransaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    String? toAccountId,
    DateTime? date,
    String? note,
    String? attachmentPath,
    List<String>? tags,
    bool? isRecurring,
    String? recurringId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      date: date ?? this.date,
      note: note ?? this.note,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      tags: tags ?? this.tags,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringId: recurringId ?? this.recurringId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type.index,
      'categoryId': categoryId,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'date': date.toIso8601String(),
      'note': note,
      'attachmentPath': attachmentPath,
      'tags': tags,
      'isRecurring': isRecurring,
      'recurringId': recurringId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    return FinanceTransaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.fromIndex(json['type'] as int),
      categoryId: json['categoryId'] as String,
      accountId: json['accountId'] as String,
      toAccountId: json['toAccountId'] as String?,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      attachmentPath: json['attachmentPath'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurringId: json['recurringId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
