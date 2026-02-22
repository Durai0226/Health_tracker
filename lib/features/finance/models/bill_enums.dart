import 'package:hive/hive.dart';

part 'bill_enums.g.dart';

@HiveType(typeId: 50)
enum BillStatus {
  @HiveField(0)
  upcoming,
  @HiveField(1)
  dueToday,
  @HiveField(2)
  overdue,
  @HiveField(3)
  paid,
  @HiveField(4)
  partiallyPaid,
  @HiveField(5)
  cancelled,
  @HiveField(6)
  archived,
}

@HiveType(typeId: 51)
enum BillRecurrence {
  @HiveField(0)
  oneTime,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
  @HiveField(3)
  biWeekly,
  @HiveField(4)
  monthly,
  @HiveField(5)
  quarterly,
  @HiveField(6)
  yearly,
  @HiveField(7)
  custom,
}

@HiveType(typeId: 52)
enum CustomRecurrenceUnit {
  @HiveField(0)
  days,
  @HiveField(1)
  weeks,
  @HiveField(2)
  months,
}

@HiveType(typeId: 53)
enum ReminderType {
  @HiveField(0)
  daysBefore,
  @HiveField(1)
  sameDay,
  @HiveField(2)
  exactTime,
}

@HiveType(typeId: 60)
enum BillPriority {
  @HiveField(0)
  low,
  @HiveField(1)
  medium,
  @HiveField(2)
  high,
}

@HiveType(typeId: 61)
enum AdvancedRecurrenceType {
  @HiveField(0)
  none,
  @HiveField(1)
  lastDayOfMonth,
  @HiveField(2)
  firstWeekdayOfMonth,
  @HiveField(3)
  lastWeekdayOfMonth,
  @HiveField(4)
  nthWeekdayOfMonth,
}

@HiveType(typeId: 62)
enum BillActivityType {
  @HiveField(0)
  created,
  @HiveField(1)
  edited,
  @HiveField(2)
  paid,
  @HiveField(3)
  partiallyPaid,
  @HiveField(4)
  deleted,
  @HiveField(5)
  archived,
  @HiveField(6)
  unarchived,
  @HiveField(7)
  reminderSent,
  @HiveField(8)
  instanceGenerated,
}

extension BillStatusExtension on BillStatus {
  String get displayName {
    switch (this) {
      case BillStatus.upcoming:
        return 'Upcoming';
      case BillStatus.dueToday:
        return 'Due Today';
      case BillStatus.overdue:
        return 'Overdue';
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.partiallyPaid:
        return 'Partially Paid';
      case BillStatus.cancelled:
        return 'Cancelled';
      case BillStatus.archived:
        return 'Archived';
    }
  }

  String get icon {
    switch (this) {
      case BillStatus.upcoming:
        return '📅';
      case BillStatus.dueToday:
        return '⚠️';
      case BillStatus.overdue:
        return '🔴';
      case BillStatus.paid:
        return '✅';
      case BillStatus.partiallyPaid:
        return '🔶';
      case BillStatus.cancelled:
        return '❌';
      case BillStatus.archived:
        return '📦';
    }
  }

  int get colorValue {
    switch (this) {
      case BillStatus.upcoming:
        return 0xFF3B82F6; // Blue
      case BillStatus.dueToday:
        return 0xFFF59E0B; // Amber
      case BillStatus.overdue:
        return 0xFFEF4444; // Red
      case BillStatus.paid:
        return 0xFF22C55E; // Green
      case BillStatus.partiallyPaid:
        return 0xFFF97316; // Orange
      case BillStatus.cancelled:
        return 0xFF6B7280; // Gray
      case BillStatus.archived:
        return 0xFF9CA3AF; // Light Gray
    }
  }
}

extension BillRecurrenceExtension on BillRecurrence {
  String get displayName {
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
      case BillRecurrence.custom:
        return 'Custom';
    }
  }

  String get icon {
    switch (this) {
      case BillRecurrence.oneTime:
        return '1️⃣';
      case BillRecurrence.daily:
        return '📆';
      case BillRecurrence.weekly:
        return '📅';
      case BillRecurrence.biWeekly:
        return '📅';
      case BillRecurrence.monthly:
        return '🗓️';
      case BillRecurrence.quarterly:
        return '📊';
      case BillRecurrence.yearly:
        return '🎯';
      case BillRecurrence.custom:
        return '⚙️';
    }
  }
}

extension CustomRecurrenceUnitExtension on CustomRecurrenceUnit {
  String get displayName {
    switch (this) {
      case CustomRecurrenceUnit.days:
        return 'Days';
      case CustomRecurrenceUnit.weeks:
        return 'Weeks';
      case CustomRecurrenceUnit.months:
        return 'Months';
    }
  }
}

extension BillPriorityExtension on BillPriority {
  String get displayName {
    switch (this) {
      case BillPriority.low:
        return 'Low';
      case BillPriority.medium:
        return 'Medium';
      case BillPriority.high:
        return 'High';
    }
  }

  int get colorValue {
    switch (this) {
      case BillPriority.low:
        return 0xFF22C55E;
      case BillPriority.medium:
        return 0xFFF59E0B;
      case BillPriority.high:
        return 0xFFEF4444;
    }
  }

  int get sortOrder {
    switch (this) {
      case BillPriority.high:
        return 0;
      case BillPriority.medium:
        return 1;
      case BillPriority.low:
        return 2;
    }
  }
}

extension AdvancedRecurrenceTypeExtension on AdvancedRecurrenceType {
  String get displayName {
    switch (this) {
      case AdvancedRecurrenceType.none:
        return 'Standard';
      case AdvancedRecurrenceType.lastDayOfMonth:
        return 'Last Day of Month';
      case AdvancedRecurrenceType.firstWeekdayOfMonth:
        return 'First Weekday of Month';
      case AdvancedRecurrenceType.lastWeekdayOfMonth:
        return 'Last Weekday of Month';
      case AdvancedRecurrenceType.nthWeekdayOfMonth:
        return 'Nth Weekday of Month';
    }
  }
}

extension BillActivityTypeExtension on BillActivityType {
  String get displayName {
    switch (this) {
      case BillActivityType.created:
        return 'Created';
      case BillActivityType.edited:
        return 'Edited';
      case BillActivityType.paid:
        return 'Paid';
      case BillActivityType.partiallyPaid:
        return 'Partially Paid';
      case BillActivityType.deleted:
        return 'Deleted';
      case BillActivityType.archived:
        return 'Archived';
      case BillActivityType.unarchived:
        return 'Unarchived';
      case BillActivityType.reminderSent:
        return 'Reminder Sent';
      case BillActivityType.instanceGenerated:
        return 'Instance Generated';
    }
  }

  String get icon {
    switch (this) {
      case BillActivityType.created:
        return '➕';
      case BillActivityType.edited:
        return '✏️';
      case BillActivityType.paid:
        return '✅';
      case BillActivityType.partiallyPaid:
        return '🔶';
      case BillActivityType.deleted:
        return '🗑️';
      case BillActivityType.archived:
        return '📦';
      case BillActivityType.unarchived:
        return '📤';
      case BillActivityType.reminderSent:
        return '🔔';
      case BillActivityType.instanceGenerated:
        return '🔄';
    }
  }
}
