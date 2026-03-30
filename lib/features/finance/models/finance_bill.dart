import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'finance_enums.dart';

/// Bill reminder model
class FinanceBill {
  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final BillStatus status;
  final BillRecurrence recurrence;
  final String? categoryId;
  final String? accountId;
  final String? note;
  final int iconCodePoint;
  final int colorValue;
  final int remindDaysBefore;
  final bool remindersEnabled;
  final double paidAmount;
  final DateTime? paidDate;
  final List<String> tags;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinanceBill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.status = BillStatus.upcoming,
    this.recurrence = BillRecurrence.monthly,
    this.categoryId,
    this.accountId,
    this.note,
    required this.iconCodePoint,
    required this.colorValue,
    this.remindDaysBefore = 3,
    this.remindersEnabled = true,
    this.paidAmount = 0,
    this.paidDate,
    this.tags = const [],
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
  
  bool get isPaid => status == BillStatus.paid;
  bool get isOverdue => status == BillStatus.overdue || 
      (status == BillStatus.upcoming && dueDate.isBefore(DateTime.now()));
  bool get isRecurring => recurrence != BillRecurrence.oneTime;
  double get remainingAmount => amount - paidAmount;

  int get daysUntilDue {
    final now = DateTime.now();
    return dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  factory FinanceBill.create({
    required String name,
    required double amount,
    required DateTime dueDate,
    BillRecurrence recurrence = BillRecurrence.monthly,
    String? categoryId,
    String? accountId,
    String? note,
    IconData icon = Icons.receipt,
    Color color = Colors.blue,
    int remindDaysBefore = 3,
  }) {
    final now = DateTime.now();
    return FinanceBill(
      id: const Uuid().v4(),
      name: name,
      amount: amount,
      dueDate: dueDate,
      recurrence: recurrence,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
      iconCodePoint: icon.codePoint,
      colorValue: color.value,
      remindDaysBefore: remindDaysBefore,
      createdAt: now,
      updatedAt: now,
    );
  }

  FinanceBill copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    BillStatus? status,
    BillRecurrence? recurrence,
    String? categoryId,
    String? accountId,
    String? note,
    int? iconCodePoint,
    int? colorValue,
    int? remindDaysBefore,
    bool? remindersEnabled,
    double? paidAmount,
    DateTime? paidDate,
    List<String>? tags,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceBill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      recurrence: recurrence ?? this.recurrence,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      paidAmount: paidAmount ?? this.paidAmount,
      paidDate: paidDate ?? this.paidDate,
      tags: tags ?? this.tags,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  FinanceBill markAsPaid({String? accountId, double? amount}) {
    return copyWith(
      status: BillStatus.paid,
      paidAmount: amount ?? this.amount,
      paidDate: DateTime.now(),
      accountId: accountId ?? this.accountId,
    );
  }

  FinanceBill generateNextInstance() {
    if (!isRecurring) return this;
    
    DateTime nextDueDate;
    switch (recurrence) {
      case BillRecurrence.daily:
        nextDueDate = dueDate.add(const Duration(days: 1));
        break;
      case BillRecurrence.weekly:
        nextDueDate = dueDate.add(const Duration(days: 7));
        break;
      case BillRecurrence.biWeekly:
        nextDueDate = dueDate.add(const Duration(days: 14));
        break;
      case BillRecurrence.monthly:
        nextDueDate = DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
        break;
      case BillRecurrence.quarterly:
        nextDueDate = DateTime(dueDate.year, dueDate.month + 3, dueDate.day);
        break;
      case BillRecurrence.yearly:
        nextDueDate = DateTime(dueDate.year + 1, dueDate.month, dueDate.day);
        break;
      default:
        return this;
    }

    return FinanceBill.create(
      name: name,
      amount: amount,
      dueDate: nextDueDate,
      recurrence: recurrence,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
      icon: icon,
      color: color,
      remindDaysBefore: remindDaysBefore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'status': status.index,
      'recurrence': recurrence.index,
      'categoryId': categoryId,
      'accountId': accountId,
      'note': note,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'remindDaysBefore': remindDaysBefore,
      'remindersEnabled': remindersEnabled,
      'paidAmount': paidAmount,
      'paidDate': paidDate?.toIso8601String(),
      'tags': tags,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FinanceBill.fromJson(Map<String, dynamic> json) {
    return FinanceBill(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: BillStatus.fromIndex(json['status'] as int? ?? 0),
      recurrence: BillRecurrence.fromIndex(json['recurrence'] as int? ?? 4),
      categoryId: json['categoryId'] as String?,
      accountId: json['accountId'] as String?,
      note: json['note'] as String?,
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      remindDaysBefore: json['remindDaysBefore'] as int? ?? 3,
      remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      paidDate: json['paidDate'] != null ? DateTime.parse(json['paidDate'] as String) : null,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceBill &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
