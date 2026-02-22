import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'bill_enums.dart';
import 'bill.dart';

part 'bill_template.g.dart';

@HiveType(typeId: 60)
class BillTemplate extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final BillRecurrence recurrence;

  @HiveField(4)
  final int? customRecurrenceInterval;

  @HiveField(5)
  final CustomRecurrenceUnit? customRecurrenceUnit;

  @HiveField(6)
  final AdvancedRecurrenceType advancedRecurrenceType;

  @HiveField(7)
  final int? nthWeekday;

  @HiveField(8)
  final int? weekdayIndex;

  @HiveField(9)
  final DateTime nextDueDate;

  @HiveField(10)
  final String? categoryId;

  @HiveField(11)
  final String? accountId;

  @HiveField(12)
  final String? note;

  @HiveField(13)
  final int gracePeriodDays;

  @HiveField(14)
  final int colorValue;

  @HiveField(15)
  final int iconCodePoint;

  @HiveField(16)
  final List<BillReminder> reminders;

  @HiveField(17)
  final bool remindersEnabled;

  @HiveField(18)
  final String? currency;

  @HiveField(19)
  final List<String> tags;

  @HiveField(20)
  final BillPriority priority;

  @HiveField(21)
  final DateTime createdAt;

  @HiveField(22)
  final DateTime updatedAt;

  @HiveField(23)
  final bool isActive;

  @HiveField(24)
  final DateTime? lastInstanceGeneratedAt;

  @HiveField(25)
  final int instanceGenerationWindowDays;

  BillTemplate({
    String? id,
    required this.name,
    required this.amount,
    this.recurrence = BillRecurrence.monthly,
    this.customRecurrenceInterval,
    this.customRecurrenceUnit,
    this.advancedRecurrenceType = AdvancedRecurrenceType.none,
    this.nthWeekday,
    this.weekdayIndex,
    required this.nextDueDate,
    this.categoryId,
    this.accountId,
    this.note,
    this.gracePeriodDays = 0,
    this.colorValue = 0xFF3B82F6,
    this.iconCodePoint = 0xe532,
    this.reminders = const [],
    this.remindersEnabled = true,
    this.currency,
    this.tags = const [],
    this.priority = BillPriority.medium,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
    this.lastInstanceGeneratedAt,
    this.instanceGenerationWindowDays = 30,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  bool get shouldGenerateInstance {
    if (!isActive || recurrence == BillRecurrence.oneTime) return false;
    
    final now = DateTime.now();
    final daysUntilDue = nextDueDate.difference(now).inDays;
    
    return daysUntilDue <= instanceGenerationWindowDays && daysUntilDue >= 0;
  }

  DateTime calculateNextDueDate() {
    if (advancedRecurrenceType != AdvancedRecurrenceType.none) {
      return _calculateAdvancedNextDueDate();
    }
    return _calculateStandardNextDueDate();
  }

  DateTime _calculateStandardNextDueDate() {
    switch (recurrence) {
      case BillRecurrence.oneTime:
        return nextDueDate;
      case BillRecurrence.daily:
        return nextDueDate.add(const Duration(days: 1));
      case BillRecurrence.weekly:
        return nextDueDate.add(const Duration(days: 7));
      case BillRecurrence.biWeekly:
        return nextDueDate.add(const Duration(days: 14));
      case BillRecurrence.monthly:
        return DateTime(nextDueDate.year, nextDueDate.month + 1, nextDueDate.day);
      case BillRecurrence.quarterly:
        return DateTime(nextDueDate.year, nextDueDate.month + 3, nextDueDate.day);
      case BillRecurrence.yearly:
        return DateTime(nextDueDate.year + 1, nextDueDate.month, nextDueDate.day);
      case BillRecurrence.custom:
        if (customRecurrenceUnit == null || customRecurrenceInterval == null) {
          return nextDueDate;
        }
        switch (customRecurrenceUnit!) {
          case CustomRecurrenceUnit.days:
            return nextDueDate.add(Duration(days: customRecurrenceInterval!));
          case CustomRecurrenceUnit.weeks:
            return nextDueDate.add(Duration(days: customRecurrenceInterval! * 7));
          case CustomRecurrenceUnit.months:
            return DateTime(
              nextDueDate.year,
              nextDueDate.month + customRecurrenceInterval!,
              nextDueDate.day,
            );
        }
    }
  }

  DateTime _calculateAdvancedNextDueDate() {
    final baseDate = _calculateStandardNextDueDate();
    
    switch (advancedRecurrenceType) {
      case AdvancedRecurrenceType.none:
        return baseDate;
        
      case AdvancedRecurrenceType.lastDayOfMonth:
        return DateTime(baseDate.year, baseDate.month + 1, 0);
        
      case AdvancedRecurrenceType.firstWeekdayOfMonth:
        var date = DateTime(baseDate.year, baseDate.month, 1);
        while (date.weekday > 5) {
          date = date.add(const Duration(days: 1));
        }
        return date;
        
      case AdvancedRecurrenceType.lastWeekdayOfMonth:
        var date = DateTime(baseDate.year, baseDate.month + 1, 0);
        while (date.weekday > 5) {
          date = date.subtract(const Duration(days: 1));
        }
        return date;
        
      case AdvancedRecurrenceType.nthWeekdayOfMonth:
        if (nthWeekday == null || weekdayIndex == null) return baseDate;
        var date = DateTime(baseDate.year, baseDate.month, 1);
        int count = 0;
        while (count < nthWeekday!) {
          if (date.weekday == weekdayIndex!) {
            count++;
            if (count == nthWeekday!) break;
          }
          date = date.add(const Duration(days: 1));
        }
        return date;
    }
  }

  Bill generateInstance() {
    return Bill(
      name: name,
      amount: amount,
      dueDate: nextDueDate,
      recurrence: BillRecurrence.oneTime,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
      gracePeriodDays: gracePeriodDays,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      reminders: reminders,
      remindersEnabled: remindersEnabled,
      currency: currency,
      tags: tags,
      priority: priority,
      templateId: id,
    );
  }

  BillTemplate copyWith({
    String? name,
    double? amount,
    BillRecurrence? recurrence,
    int? customRecurrenceInterval,
    CustomRecurrenceUnit? customRecurrenceUnit,
    AdvancedRecurrenceType? advancedRecurrenceType,
    int? nthWeekday,
    int? weekdayIndex,
    DateTime? nextDueDate,
    String? categoryId,
    String? accountId,
    String? note,
    int? gracePeriodDays,
    int? colorValue,
    int? iconCodePoint,
    List<BillReminder>? reminders,
    bool? remindersEnabled,
    String? currency,
    List<String>? tags,
    BillPriority? priority,
    bool? isActive,
    DateTime? lastInstanceGeneratedAt,
    int? instanceGenerationWindowDays,
  }) {
    return BillTemplate(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      recurrence: recurrence ?? this.recurrence,
      customRecurrenceInterval: customRecurrenceInterval ?? this.customRecurrenceInterval,
      customRecurrenceUnit: customRecurrenceUnit ?? this.customRecurrenceUnit,
      advancedRecurrenceType: advancedRecurrenceType ?? this.advancedRecurrenceType,
      nthWeekday: nthWeekday ?? this.nthWeekday,
      weekdayIndex: weekdayIndex ?? this.weekdayIndex,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      reminders: reminders ?? this.reminders,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      currency: currency ?? this.currency,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
      lastInstanceGeneratedAt: lastInstanceGeneratedAt ?? this.lastInstanceGeneratedAt,
      instanceGenerationWindowDays: instanceGenerationWindowDays ?? this.instanceGenerationWindowDays,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'recurrence': recurrence.index,
    'customRecurrenceInterval': customRecurrenceInterval,
    'customRecurrenceUnit': customRecurrenceUnit?.index,
    'advancedRecurrenceType': advancedRecurrenceType.index,
    'nthWeekday': nthWeekday,
    'weekdayIndex': weekdayIndex,
    'nextDueDate': nextDueDate.toIso8601String(),
    'categoryId': categoryId,
    'accountId': accountId,
    'note': note,
    'gracePeriodDays': gracePeriodDays,
    'colorValue': colorValue,
    'iconCodePoint': iconCodePoint,
    'reminders': reminders.map((r) => r.toJson()).toList(),
    'remindersEnabled': remindersEnabled,
    'currency': currency,
    'tags': tags,
    'priority': priority.index,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isActive': isActive,
    'lastInstanceGeneratedAt': lastInstanceGeneratedAt?.toIso8601String(),
    'instanceGenerationWindowDays': instanceGenerationWindowDays,
  };

  factory BillTemplate.fromJson(Map<String, dynamic> json) {
    return BillTemplate(
      id: json['id'],
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      recurrence: BillRecurrence.values[json['recurrence'] ?? 4],
      customRecurrenceInterval: json['customRecurrenceInterval'],
      customRecurrenceUnit: json['customRecurrenceUnit'] != null
          ? CustomRecurrenceUnit.values[json['customRecurrenceUnit']]
          : null,
      advancedRecurrenceType: AdvancedRecurrenceType.values[json['advancedRecurrenceType'] ?? 0],
      nthWeekday: json['nthWeekday'],
      weekdayIndex: json['weekdayIndex'],
      nextDueDate: DateTime.parse(json['nextDueDate']),
      categoryId: json['categoryId'],
      accountId: json['accountId'],
      note: json['note'],
      gracePeriodDays: json['gracePeriodDays'] ?? 0,
      colorValue: json['colorValue'] ?? 0xFF3B82F6,
      iconCodePoint: json['iconCodePoint'] ?? 0xe532,
      reminders: (json['reminders'] as List?)
          ?.map((r) => BillReminder.fromJson(r))
          .toList() ?? [],
      remindersEnabled: json['remindersEnabled'] ?? true,
      currency: json['currency'],
      tags: List<String>.from(json['tags'] ?? []),
      priority: BillPriority.values[json['priority'] ?? 1],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isActive: json['isActive'] ?? true,
      lastInstanceGeneratedAt: json['lastInstanceGeneratedAt'] != null
          ? DateTime.parse(json['lastInstanceGeneratedAt'])
          : null,
      instanceGenerationWindowDays: json['instanceGenerationWindowDays'] ?? 30,
    );
  }
}

@HiveType(typeId: 61)
class BillActivity extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String billId;

  @HiveField(2)
  final BillActivityType activityType;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final double? amount;

  @HiveField(6)
  final Map<String, dynamic>? metadata;

  @HiveField(7)
  final String? deviceId;

  BillActivity({
    String? id,
    required this.billId,
    required this.activityType,
    DateTime? timestamp,
    this.description,
    this.amount,
    this.metadata,
    this.deviceId,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'billId': billId,
    'activityType': activityType.index,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'amount': amount,
    'metadata': metadata,
    'deviceId': deviceId,
  };

  factory BillActivity.fromJson(Map<String, dynamic> json) {
    return BillActivity(
      id: json['id'],
      billId: json['billId'],
      activityType: BillActivityType.values[json['activityType'] ?? 0],
      timestamp: DateTime.parse(json['timestamp']),
      description: json['description'],
      amount: json['amount']?.toDouble(),
      metadata: json['metadata'],
      deviceId: json['deviceId'],
    );
  }
}

@HiveType(typeId: 62)
class CategoryKeywordMap extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String keyword;

  @HiveField(2)
  final String categoryId;

  @HiveField(3)
  final int frequency;

  @HiveField(4)
  final DateTime lastUsed;

  CategoryKeywordMap({
    String? id,
    required this.keyword,
    required this.categoryId,
    this.frequency = 1,
    DateTime? lastUsed,
  })  : id = id ?? const Uuid().v4(),
        lastUsed = lastUsed ?? DateTime.now();

  CategoryKeywordMap incrementFrequency() {
    return CategoryKeywordMap(
      id: id,
      keyword: keyword,
      categoryId: categoryId,
      frequency: frequency + 1,
      lastUsed: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'keyword': keyword,
    'categoryId': categoryId,
    'frequency': frequency,
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory CategoryKeywordMap.fromJson(Map<String, dynamic> json) {
    return CategoryKeywordMap(
      id: json['id'],
      keyword: json['keyword'],
      categoryId: json['categoryId'],
      frequency: json['frequency'] ?? 1,
      lastUsed: DateTime.parse(json['lastUsed']),
    );
  }
}

@HiveType(typeId: 63)
class BillSettings extends HiveObject {
  @HiveField(0)
  final int defaultReminderDaysBefore;

  @HiveField(1)
  final int defaultReminderHour;

  @HiveField(2)
  final int defaultReminderMinute;

  @HiveField(3)
  final bool enableEscalationReminders;

  @HiveField(4)
  final int maxEscalationReminders;

  @HiveField(5)
  final bool requireBiometricLock;

  @HiveField(6)
  final int instanceGenerationWindowDays;

  @HiveField(7)
  final bool showBadgeCount;

  @HiveField(8)
  final String defaultCurrency;

  @HiveField(9)
  final BillPriority defaultPriority;

  @HiveField(10)
  final DateTime? lastSyncAt;

  @HiveField(11)
  final String? lastSyncDeviceId;

  BillSettings({
    this.defaultReminderDaysBefore = 3,
    this.defaultReminderHour = 9,
    this.defaultReminderMinute = 0,
    this.enableEscalationReminders = true,
    this.maxEscalationReminders = 3,
    this.requireBiometricLock = false,
    this.instanceGenerationWindowDays = 30,
    this.showBadgeCount = true,
    this.defaultCurrency = 'INR',
    this.defaultPriority = BillPriority.medium,
    this.lastSyncAt,
    this.lastSyncDeviceId,
  });

  BillSettings copyWith({
    int? defaultReminderDaysBefore,
    int? defaultReminderHour,
    int? defaultReminderMinute,
    bool? enableEscalationReminders,
    int? maxEscalationReminders,
    bool? requireBiometricLock,
    int? instanceGenerationWindowDays,
    bool? showBadgeCount,
    String? defaultCurrency,
    BillPriority? defaultPriority,
    DateTime? lastSyncAt,
    String? lastSyncDeviceId,
  }) {
    return BillSettings(
      defaultReminderDaysBefore: defaultReminderDaysBefore ?? this.defaultReminderDaysBefore,
      defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
      defaultReminderMinute: defaultReminderMinute ?? this.defaultReminderMinute,
      enableEscalationReminders: enableEscalationReminders ?? this.enableEscalationReminders,
      maxEscalationReminders: maxEscalationReminders ?? this.maxEscalationReminders,
      requireBiometricLock: requireBiometricLock ?? this.requireBiometricLock,
      instanceGenerationWindowDays: instanceGenerationWindowDays ?? this.instanceGenerationWindowDays,
      showBadgeCount: showBadgeCount ?? this.showBadgeCount,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncDeviceId: lastSyncDeviceId ?? this.lastSyncDeviceId,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultReminderDaysBefore': defaultReminderDaysBefore,
    'defaultReminderHour': defaultReminderHour,
    'defaultReminderMinute': defaultReminderMinute,
    'enableEscalationReminders': enableEscalationReminders,
    'maxEscalationReminders': maxEscalationReminders,
    'requireBiometricLock': requireBiometricLock,
    'instanceGenerationWindowDays': instanceGenerationWindowDays,
    'showBadgeCount': showBadgeCount,
    'defaultCurrency': defaultCurrency,
    'defaultPriority': defaultPriority.index,
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'lastSyncDeviceId': lastSyncDeviceId,
  };

  factory BillSettings.fromJson(Map<String, dynamic> json) {
    return BillSettings(
      defaultReminderDaysBefore: json['defaultReminderDaysBefore'] ?? 3,
      defaultReminderHour: json['defaultReminderHour'] ?? 9,
      defaultReminderMinute: json['defaultReminderMinute'] ?? 0,
      enableEscalationReminders: json['enableEscalationReminders'] ?? true,
      maxEscalationReminders: json['maxEscalationReminders'] ?? 3,
      requireBiometricLock: json['requireBiometricLock'] ?? false,
      instanceGenerationWindowDays: json['instanceGenerationWindowDays'] ?? 30,
      showBadgeCount: json['showBadgeCount'] ?? true,
      defaultCurrency: json['defaultCurrency'] ?? 'INR',
      defaultPriority: BillPriority.values[json['defaultPriority'] ?? 1],
      lastSyncAt: json['lastSyncAt'] != null ? DateTime.parse(json['lastSyncAt']) : null,
      lastSyncDeviceId: json['lastSyncDeviceId'],
    );
  }
}
