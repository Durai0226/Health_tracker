import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'bill_enums.dart';

part 'bill.g.dart';

@HiveType(typeId: 54)
class Bill extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double amount;

  @HiveField(3)
  DateTime dueDate;

  @HiveField(4)
  BillStatus status;

  @HiveField(5)
  BillRecurrence recurrence;

  @HiveField(6)
  int? customRecurrenceInterval;

  @HiveField(7)
  CustomRecurrenceUnit? customRecurrenceUnit;

  @HiveField(8)
  String? categoryId;

  @HiveField(9)
  String? accountId;

  @HiveField(10)
  String? note;

  @HiveField(11)
  String? receiptUrl;

  @HiveField(12)
  List<String> tags;

  @HiveField(13)
  int gracePeriodDays;

  @HiveField(14)
  bool isDeleted;

  @HiveField(15)
  bool isArchived;

  @HiveField(16)
  String? templateId;

  @HiveField(17)
  String? parentBillId;

  @HiveField(18)
  double paidAmount;

  @HiveField(19)
  List<BillReminder> reminders;

  @HiveField(20)
  String? currency;

  @HiveField(21)
  double? exchangeRate;

  @HiveField(22)
  int colorValue;

  @HiveField(23)
  int iconCodePoint;

  @HiveField(24)
  DateTime createdAt;

  @HiveField(25)
  DateTime updatedAt;

  @HiveField(26)
  String? deviceId;

  @HiveField(27)
  List<int> notificationIds;

  @HiveField(28)
  bool remindersEnabled;

  @HiveField(29)
  BillPriority priority;

  @HiveField(30)
  List<String> attachmentUrls;

  @HiveField(31)
  int escalationRemindersSent;

  @HiveField(32)
  DateTime? lastReminderSentAt;

  @HiveField(33)
  DateTime? lastScheduledAt;

  @HiveField(34)
  String? updatedByDeviceId;

  Bill({
    String? id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.status = BillStatus.upcoming,
    this.recurrence = BillRecurrence.oneTime,
    this.customRecurrenceInterval,
    this.customRecurrenceUnit,
    this.categoryId,
    this.accountId,
    this.note,
    this.receiptUrl,
    List<String>? tags,
    this.gracePeriodDays = 0,
    this.isDeleted = false,
    this.isArchived = false,
    this.templateId,
    this.parentBillId,
    this.paidAmount = 0,
    List<BillReminder>? reminders,
    this.currency = 'INR',
    this.exchangeRate = 1.0,
    this.colorValue = 0xFF3B82F6,
    this.iconCodePoint = 0xe227,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deviceId,
    List<int>? notificationIds,
    this.remindersEnabled = true,
    this.priority = BillPriority.medium,
    List<String>? attachmentUrls,
    this.escalationRemindersSent = 0,
    this.lastReminderSentAt,
    this.lastScheduledAt,
    this.updatedByDeviceId,
  })  : id = id ?? const Uuid().v4(),
        attachmentUrls = attachmentUrls ?? [],
        tags = tags ?? [],
        reminders = reminders ?? [],
        notificationIds = notificationIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  double get remainingAmount => amount - paidAmount;
  bool get isFullyPaid => paidAmount >= amount;
  bool get isPartiallyPaid => paidAmount > 0 && paidAmount < amount;

  bool get isOverdue {
    if (status == BillStatus.paid || status == BillStatus.cancelled) return false;
    final now = DateTime.now();
    final dueWithGrace = dueDate.add(Duration(days: gracePeriodDays));
    return now.isAfter(dueWithGrace);
  }

  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  bool get isUpcoming {
    if (status == BillStatus.paid || status == BillStatus.cancelled) return false;
    final now = DateTime.now();
    return dueDate.isAfter(now) && !isDueToday;
  }

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  int get daysOverdue {
    if (!isOverdue) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.difference(due).inDays;
  }

  BillStatus calculateStatus() {
    if (isDeleted) return BillStatus.cancelled;
    if (isArchived) return BillStatus.archived;
    if (isFullyPaid) return BillStatus.paid;
    if (isPartiallyPaid && isOverdue) return BillStatus.overdue;
    if (isPartiallyPaid) return BillStatus.partiallyPaid;
    if (isOverdue) return BillStatus.overdue;
    if (isDueToday) return BillStatus.dueToday;
    return BillStatus.upcoming;
  }

  DateTime? calculateNextDueDate() {
    if (recurrence == BillRecurrence.oneTime) return null;

    switch (recurrence) {
      case BillRecurrence.daily:
        return dueDate.add(const Duration(days: 1));
      case BillRecurrence.weekly:
        return dueDate.add(const Duration(days: 7));
      case BillRecurrence.biWeekly:
        return dueDate.add(const Duration(days: 14));
      case BillRecurrence.monthly:
        return DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
      case BillRecurrence.quarterly:
        return DateTime(dueDate.year, dueDate.month + 3, dueDate.day);
      case BillRecurrence.yearly:
        return DateTime(dueDate.year + 1, dueDate.month, dueDate.day);
      case BillRecurrence.custom:
        if (customRecurrenceInterval == null || customRecurrenceUnit == null) {
          return null;
        }
        switch (customRecurrenceUnit!) {
          case CustomRecurrenceUnit.days:
            return dueDate.add(Duration(days: customRecurrenceInterval!));
          case CustomRecurrenceUnit.weeks:
            return dueDate.add(Duration(days: customRecurrenceInterval! * 7));
          case CustomRecurrenceUnit.months:
            return DateTime(
              dueDate.year,
              dueDate.month + customRecurrenceInterval!,
              dueDate.day,
            );
        }
      default:
        return null;
    }
  }

  Bill copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    BillStatus? status,
    BillRecurrence? recurrence,
    int? customRecurrenceInterval,
    CustomRecurrenceUnit? customRecurrenceUnit,
    String? categoryId,
    String? accountId,
    String? note,
    String? receiptUrl,
    List<String>? tags,
    int? gracePeriodDays,
    bool? isDeleted,
    bool? isArchived,
    String? templateId,
    String? parentBillId,
    double? paidAmount,
    List<BillReminder>? reminders,
    String? currency,
    double? exchangeRate,
    int? colorValue,
    int? iconCodePoint,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deviceId,
    List<int>? notificationIds,
    bool? remindersEnabled,
    BillPriority? priority,
    List<String>? attachmentUrls,
    int? escalationRemindersSent,
    DateTime? lastReminderSentAt,
    DateTime? lastScheduledAt,
    String? updatedByDeviceId,
  }) {
    return Bill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      recurrence: recurrence ?? this.recurrence,
      customRecurrenceInterval: customRecurrenceInterval ?? this.customRecurrenceInterval,
      customRecurrenceUnit: customRecurrenceUnit ?? this.customRecurrenceUnit,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      tags: tags ?? List.from(this.tags),
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      isDeleted: isDeleted ?? this.isDeleted,
      isArchived: isArchived ?? this.isArchived,
      templateId: templateId ?? this.templateId,
      parentBillId: parentBillId ?? this.parentBillId,
      paidAmount: paidAmount ?? this.paidAmount,
      reminders: reminders ?? List.from(this.reminders),
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deviceId: deviceId ?? this.deviceId,
      notificationIds: notificationIds ?? List.from(this.notificationIds),
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      priority: priority ?? this.priority,
      attachmentUrls: attachmentUrls ?? List.from(this.attachmentUrls),
      escalationRemindersSent: escalationRemindersSent ?? this.escalationRemindersSent,
      lastReminderSentAt: lastReminderSentAt ?? this.lastReminderSentAt,
      lastScheduledAt: lastScheduledAt ?? this.lastScheduledAt,
      updatedByDeviceId: updatedByDeviceId ?? this.updatedByDeviceId,
    );
  }

  Bill duplicate() {
    return Bill(
      name: '$name (Copy)',
      amount: amount,
      dueDate: dueDate,
      recurrence: recurrence,
      customRecurrenceInterval: customRecurrenceInterval,
      customRecurrenceUnit: customRecurrenceUnit,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
      tags: List.from(tags),
      gracePeriodDays: gracePeriodDays,
      reminders: reminders.map((r) => r.copyWith()).toList(),
      currency: currency,
      exchangeRate: exchangeRate,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      remindersEnabled: remindersEnabled,
      priority: priority,
    );
  }

  Bill createNextRecurrence() {
    final nextDue = calculateNextDueDate();
    if (nextDue == null) return this;

    return Bill(
      name: name,
      amount: amount,
      dueDate: nextDue,
      recurrence: recurrence,
      customRecurrenceInterval: customRecurrenceInterval,
      customRecurrenceUnit: customRecurrenceUnit,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
      tags: List.from(tags),
      gracePeriodDays: gracePeriodDays,
      templateId: templateId ?? id,
      parentBillId: id,
      reminders: reminders.map((r) => r.copyWith()).toList(),
      currency: currency,
      exchangeRate: exchangeRate,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      remindersEnabled: remindersEnabled,
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
      'customRecurrenceInterval': customRecurrenceInterval,
      'customRecurrenceUnit': customRecurrenceUnit?.index,
      'categoryId': categoryId,
      'accountId': accountId,
      'note': note,
      'receiptUrl': receiptUrl,
      'tags': tags,
      'gracePeriodDays': gracePeriodDays,
      'isDeleted': isDeleted,
      'isArchived': isArchived,
      'templateId': templateId,
      'parentBillId': parentBillId,
      'paidAmount': paidAmount,
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'currency': currency,
      'exchangeRate': exchangeRate,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deviceId': deviceId,
      'notificationIds': notificationIds,
      'remindersEnabled': remindersEnabled,
      'priority': priority.index,
      'attachmentUrls': attachmentUrls,
      'escalationRemindersSent': escalationRemindersSent,
      'lastReminderSentAt': lastReminderSentAt?.toIso8601String(),
      'lastScheduledAt': lastScheduledAt?.toIso8601String(),
      'updatedByDeviceId': updatedByDeviceId,
    };
  }

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: BillStatus.values[json['status'] as int],
      recurrence: BillRecurrence.values[json['recurrence'] as int],
      customRecurrenceInterval: json['customRecurrenceInterval'] as int?,
      customRecurrenceUnit: json['customRecurrenceUnit'] != null
          ? CustomRecurrenceUnit.values[json['customRecurrenceUnit'] as int]
          : null,
      categoryId: json['categoryId'] as String?,
      accountId: json['accountId'] as String?,
      note: json['note'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      gracePeriodDays: json['gracePeriodDays'] as int? ?? 0,
      isDeleted: json['isDeleted'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      templateId: json['templateId'] as String?,
      parentBillId: json['parentBillId'] as String?,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((e) => BillReminder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      currency: json['currency'] as String? ?? 'INR',
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      colorValue: json['colorValue'] as int? ?? 0xFF3B82F6,
      iconCodePoint: json['iconCodePoint'] as int? ?? 0xe227,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      deviceId: json['deviceId'] as String?,
      notificationIds: (json['notificationIds'] as List<dynamic>?)?.cast<int>() ?? [],
      remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      priority: BillPriority.values[json['priority'] as int? ?? 1],
      attachmentUrls: (json['attachmentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      escalationRemindersSent: json['escalationRemindersSent'] as int? ?? 0,
      lastReminderSentAt: json['lastReminderSentAt'] != null
          ? DateTime.parse(json['lastReminderSentAt'] as String)
          : null,
      lastScheduledAt: json['lastScheduledAt'] != null
          ? DateTime.parse(json['lastScheduledAt'] as String)
          : null,
      updatedByDeviceId: json['updatedByDeviceId'] as String?,
    );
  }
}

@HiveType(typeId: 55)
class BillReminder extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  ReminderType type;

  @HiveField(2)
  int daysBefore;

  @HiveField(3)
  int hour;

  @HiveField(4)
  int minute;

  @HiveField(5)
  bool isEnabled;

  @HiveField(6)
  int? notificationId;

  @HiveField(7)
  DateTime? scheduledTime;

  @HiveField(8)
  bool isSent;

  BillReminder({
    String? id,
    this.type = ReminderType.daysBefore,
    this.daysBefore = 1,
    this.hour = 9,
    this.minute = 0,
    this.isEnabled = true,
    this.notificationId,
    this.scheduledTime,
    this.isSent = false,
  }) : id = id ?? const Uuid().v4();

  BillReminder copyWith({
    String? id,
    ReminderType? type,
    int? daysBefore,
    int? hour,
    int? minute,
    bool? isEnabled,
    int? notificationId,
    DateTime? scheduledTime,
    bool? isSent,
  }) {
    return BillReminder(
      id: id ?? const Uuid().v4(),
      type: type ?? this.type,
      daysBefore: daysBefore ?? this.daysBefore,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
      notificationId: notificationId,
      scheduledTime: scheduledTime,
      isSent: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'daysBefore': daysBefore,
      'hour': hour,
      'minute': minute,
      'isEnabled': isEnabled,
      'notificationId': notificationId,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'isSent': isSent,
    };
  }

  factory BillReminder.fromJson(Map<String, dynamic> json) {
    return BillReminder(
      id: json['id'] as String,
      type: ReminderType.values[json['type'] as int],
      daysBefore: json['daysBefore'] as int? ?? 1,
      hour: json['hour'] as int? ?? 9,
      minute: json['minute'] as int? ?? 0,
      isEnabled: json['isEnabled'] as bool? ?? true,
      notificationId: json['notificationId'] as int?,
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'] as String)
          : null,
      isSent: json['isSent'] as bool? ?? false,
    );
  }

  String get displayText {
    switch (type) {
      case ReminderType.daysBefore:
        if (daysBefore == 0) return 'On due date at ${_formatTime()}';
        if (daysBefore == 1) return '1 day before at ${_formatTime()}';
        return '$daysBefore days before at ${_formatTime()}';
      case ReminderType.sameDay:
        return 'On due date at ${_formatTime()}';
      case ReminderType.exactTime:
        return 'At ${_formatTime()}';
    }
  }

  String _formatTime() {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }
}

@HiveType(typeId: 56)
class BillPayment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String billId;

  @HiveField(2)
  double amount;

  @HiveField(3)
  DateTime paidAt;

  @HiveField(4)
  String? accountId;

  @HiveField(5)
  String? note;

  @HiveField(6)
  String? transactionId;

  @HiveField(7)
  DateTime createdAt;

  BillPayment({
    String? id,
    required this.billId,
    required this.amount,
    DateTime? paidAt,
    this.accountId,
    this.note,
    this.transactionId,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        paidAt = paidAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  BillPayment copyWith({
    String? id,
    String? billId,
    double? amount,
    DateTime? paidAt,
    String? accountId,
    String? note,
    String? transactionId,
    DateTime? createdAt,
  }) {
    return BillPayment(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      amount: amount ?? this.amount,
      paidAt: paidAt ?? this.paidAt,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'billId': billId,
      'amount': amount,
      'paidAt': paidAt.toIso8601String(),
      'accountId': accountId,
      'note': note,
      'transactionId': transactionId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BillPayment.fromJson(Map<String, dynamic> json) {
    return BillPayment(
      id: json['id'] as String,
      billId: json['billId'] as String,
      amount: (json['amount'] as num).toDouble(),
      paidAt: DateTime.parse(json['paidAt'] as String),
      accountId: json['accountId'] as String?,
      note: json['note'] as String?,
      transactionId: json['transactionId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

@HiveType(typeId: 57)
class BillCategory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  int iconCodePoint;

  @HiveField(4)
  bool isCustom;

  @HiveField(5)
  DateTime createdAt;

  BillCategory({
    String? id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    this.isCustom = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  static List<BillCategory> get defaults => [
        BillCategory(
          id: 'utilities',
          name: 'Utilities',
          colorValue: 0xFF3B82F6,
          iconCodePoint: Icons.lightbulb_outline.codePoint,
        ),
        BillCategory(
          id: 'rent',
          name: 'Rent',
          colorValue: 0xFF8B5CF6,
          iconCodePoint: Icons.home_outlined.codePoint,
        ),
        BillCategory(
          id: 'insurance',
          name: 'Insurance',
          colorValue: 0xFF10B981,
          iconCodePoint: Icons.security_outlined.codePoint,
        ),
        BillCategory(
          id: 'subscriptions',
          name: 'Subscriptions',
          colorValue: 0xFFF59E0B,
          iconCodePoint: Icons.subscriptions_outlined.codePoint,
        ),
        BillCategory(
          id: 'phone',
          name: 'Phone',
          colorValue: 0xFFEC4899,
          iconCodePoint: Icons.phone_android_outlined.codePoint,
        ),
        BillCategory(
          id: 'internet',
          name: 'Internet',
          colorValue: 0xFF06B6D4,
          iconCodePoint: Icons.wifi_outlined.codePoint,
        ),
        BillCategory(
          id: 'credit_card',
          name: 'Credit Card',
          colorValue: 0xFFEF4444,
          iconCodePoint: Icons.credit_card_outlined.codePoint,
        ),
        BillCategory(
          id: 'loan',
          name: 'Loan/EMI',
          colorValue: 0xFF6366F1,
          iconCodePoint: Icons.account_balance_outlined.codePoint,
        ),
        BillCategory(
          id: 'medical',
          name: 'Medical',
          colorValue: 0xFFDC2626,
          iconCodePoint: Icons.medical_services_outlined.codePoint,
        ),
        BillCategory(
          id: 'education',
          name: 'Education',
          colorValue: 0xFF0EA5E9,
          iconCodePoint: Icons.school_outlined.codePoint,
        ),
        BillCategory(
          id: 'other',
          name: 'Other',
          colorValue: 0xFF6B7280,
          iconCodePoint: Icons.receipt_long_outlined.codePoint,
        ),
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'isCustom': isCustom,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BillCategory.fromJson(Map<String, dynamic> json) {
    return BillCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int,
      iconCodePoint: json['iconCodePoint'] as int,
      isCustom: json['isCustom'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
