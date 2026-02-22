// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_enums.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillStatusAdapter extends TypeAdapter<BillStatus> {
  @override
  final int typeId = 50;

  @override
  BillStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BillStatus.upcoming;
      case 1:
        return BillStatus.dueToday;
      case 2:
        return BillStatus.overdue;
      case 3:
        return BillStatus.paid;
      case 4:
        return BillStatus.partiallyPaid;
      case 5:
        return BillStatus.cancelled;
      case 6:
        return BillStatus.archived;
      default:
        return BillStatus.upcoming;
    }
  }

  @override
  void write(BinaryWriter writer, BillStatus obj) {
    switch (obj) {
      case BillStatus.upcoming:
        writer.writeByte(0);
        break;
      case BillStatus.dueToday:
        writer.writeByte(1);
        break;
      case BillStatus.overdue:
        writer.writeByte(2);
        break;
      case BillStatus.paid:
        writer.writeByte(3);
        break;
      case BillStatus.partiallyPaid:
        writer.writeByte(4);
        break;
      case BillStatus.cancelled:
        writer.writeByte(5);
        break;
      case BillStatus.archived:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillRecurrenceAdapter extends TypeAdapter<BillRecurrence> {
  @override
  final int typeId = 51;

  @override
  BillRecurrence read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BillRecurrence.oneTime;
      case 1:
        return BillRecurrence.daily;
      case 2:
        return BillRecurrence.weekly;
      case 3:
        return BillRecurrence.biWeekly;
      case 4:
        return BillRecurrence.monthly;
      case 5:
        return BillRecurrence.quarterly;
      case 6:
        return BillRecurrence.yearly;
      case 7:
        return BillRecurrence.custom;
      default:
        return BillRecurrence.oneTime;
    }
  }

  @override
  void write(BinaryWriter writer, BillRecurrence obj) {
    switch (obj) {
      case BillRecurrence.oneTime:
        writer.writeByte(0);
        break;
      case BillRecurrence.daily:
        writer.writeByte(1);
        break;
      case BillRecurrence.weekly:
        writer.writeByte(2);
        break;
      case BillRecurrence.biWeekly:
        writer.writeByte(3);
        break;
      case BillRecurrence.monthly:
        writer.writeByte(4);
        break;
      case BillRecurrence.quarterly:
        writer.writeByte(5);
        break;
      case BillRecurrence.yearly:
        writer.writeByte(6);
        break;
      case BillRecurrence.custom:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillRecurrenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CustomRecurrenceUnitAdapter extends TypeAdapter<CustomRecurrenceUnit> {
  @override
  final int typeId = 52;

  @override
  CustomRecurrenceUnit read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CustomRecurrenceUnit.days;
      case 1:
        return CustomRecurrenceUnit.weeks;
      case 2:
        return CustomRecurrenceUnit.months;
      default:
        return CustomRecurrenceUnit.days;
    }
  }

  @override
  void write(BinaryWriter writer, CustomRecurrenceUnit obj) {
    switch (obj) {
      case CustomRecurrenceUnit.days:
        writer.writeByte(0);
        break;
      case CustomRecurrenceUnit.weeks:
        writer.writeByte(1);
        break;
      case CustomRecurrenceUnit.months:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomRecurrenceUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReminderTypeAdapter extends TypeAdapter<ReminderType> {
  @override
  final int typeId = 53;

  @override
  ReminderType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReminderType.daysBefore;
      case 1:
        return ReminderType.sameDay;
      case 2:
        return ReminderType.exactTime;
      default:
        return ReminderType.daysBefore;
    }
  }

  @override
  void write(BinaryWriter writer, ReminderType obj) {
    switch (obj) {
      case ReminderType.daysBefore:
        writer.writeByte(0);
        break;
      case ReminderType.sameDay:
        writer.writeByte(1);
        break;
      case ReminderType.exactTime:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillPriorityAdapter extends TypeAdapter<BillPriority> {
  @override
  final int typeId = 60;

  @override
  BillPriority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BillPriority.low;
      case 1:
        return BillPriority.medium;
      case 2:
        return BillPriority.high;
      default:
        return BillPriority.medium;
    }
  }

  @override
  void write(BinaryWriter writer, BillPriority obj) {
    switch (obj) {
      case BillPriority.low:
        writer.writeByte(0);
        break;
      case BillPriority.medium:
        writer.writeByte(1);
        break;
      case BillPriority.high:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillPriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdvancedRecurrenceTypeAdapter extends TypeAdapter<AdvancedRecurrenceType> {
  @override
  final int typeId = 61;

  @override
  AdvancedRecurrenceType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AdvancedRecurrenceType.none;
      case 1:
        return AdvancedRecurrenceType.lastDayOfMonth;
      case 2:
        return AdvancedRecurrenceType.firstWeekdayOfMonth;
      case 3:
        return AdvancedRecurrenceType.lastWeekdayOfMonth;
      case 4:
        return AdvancedRecurrenceType.nthWeekdayOfMonth;
      default:
        return AdvancedRecurrenceType.none;
    }
  }

  @override
  void write(BinaryWriter writer, AdvancedRecurrenceType obj) {
    switch (obj) {
      case AdvancedRecurrenceType.none:
        writer.writeByte(0);
        break;
      case AdvancedRecurrenceType.lastDayOfMonth:
        writer.writeByte(1);
        break;
      case AdvancedRecurrenceType.firstWeekdayOfMonth:
        writer.writeByte(2);
        break;
      case AdvancedRecurrenceType.lastWeekdayOfMonth:
        writer.writeByte(3);
        break;
      case AdvancedRecurrenceType.nthWeekdayOfMonth:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedRecurrenceTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillActivityTypeAdapter extends TypeAdapter<BillActivityType> {
  @override
  final int typeId = 62;

  @override
  BillActivityType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BillActivityType.created;
      case 1:
        return BillActivityType.edited;
      case 2:
        return BillActivityType.paid;
      case 3:
        return BillActivityType.partiallyPaid;
      case 4:
        return BillActivityType.deleted;
      case 5:
        return BillActivityType.archived;
      case 6:
        return BillActivityType.unarchived;
      case 7:
        return BillActivityType.reminderSent;
      case 8:
        return BillActivityType.instanceGenerated;
      default:
        return BillActivityType.created;
    }
  }

  @override
  void write(BinaryWriter writer, BillActivityType obj) {
    switch (obj) {
      case BillActivityType.created:
        writer.writeByte(0);
        break;
      case BillActivityType.edited:
        writer.writeByte(1);
        break;
      case BillActivityType.paid:
        writer.writeByte(2);
        break;
      case BillActivityType.partiallyPaid:
        writer.writeByte(3);
        break;
      case BillActivityType.deleted:
        writer.writeByte(4);
        break;
      case BillActivityType.archived:
        writer.writeByte(5);
        break;
      case BillActivityType.unarchived:
        writer.writeByte(6);
        break;
      case BillActivityType.reminderSent:
        writer.writeByte(7);
        break;
      case BillActivityType.instanceGenerated:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillActivityTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
