import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'finance_enums.dart';

part 'transaction.g.dart';

@HiveType(typeId: 86)
class FinanceTransaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final TransactionType type;

  @HiveField(3)
  final String categoryId;

  @HiveField(4)
  final String accountId;

  @HiveField(5)
  final String? toAccountId;

  @HiveField(6)
  final DateTime date;

  @HiveField(7)
  final String? note;

  @HiveField(8)
  final RecurrenceType recurrence;

  @HiveField(9)
  final List<String>? tags;

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final String? attachmentPath;

  FinanceTransaction({
    String? id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    DateTime? date,
    this.note,
    this.recurrence = RecurrenceType.none,
    this.tags,
    DateTime? createdAt,
    this.attachmentPath,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get isRecurring => recurrence != RecurrenceType.none;
  bool get isTransfer => type == TransactionType.transfer;
  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  FinanceTransaction copyWith({
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    String? toAccountId,
    DateTime? date,
    String? note,
    RecurrenceType? recurrence,
    List<String>? tags,
    String? attachmentPath,
  }) {
    return FinanceTransaction(
      id: id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      date: date ?? this.date,
      note: note ?? this.note,
      recurrence: recurrence ?? this.recurrence,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      attachmentPath: attachmentPath ?? this.attachmentPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'type': type.index,
        'categoryId': categoryId,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'date': date.toIso8601String(),
        'note': note,
        'recurrence': recurrence.index,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'attachmentPath': attachmentPath,
      };

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    return FinanceTransaction(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values[json['type']],
      categoryId: json['categoryId'],
      accountId: json['accountId'],
      toAccountId: json['toAccountId'],
      date: DateTime.parse(json['date']),
      note: json['note'],
      recurrence: RecurrenceType.values[json['recurrence'] ?? 0],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      attachmentPath: json['attachmentPath'],
    );
  }

  String toCsvRow() {
    return '${date.toIso8601String()},$type,$amount,$categoryId,$accountId,"${note ?? ""}"';
  }
}
