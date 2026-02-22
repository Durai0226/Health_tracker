// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillAdapter extends TypeAdapter<Bill> {
  @override
  final int typeId = 54;

  @override
  Bill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bill(
      id: fields[0] as String?,
      name: fields[1] as String,
      amount: fields[2] as double,
      dueDate: fields[3] as DateTime,
      status: fields[4] as BillStatus? ?? BillStatus.upcoming,
      recurrence: fields[5] as BillRecurrence? ?? BillRecurrence.oneTime,
      customRecurrenceInterval: fields[6] as int?,
      customRecurrenceUnit: fields[7] as CustomRecurrenceUnit?,
      categoryId: fields[8] as String?,
      accountId: fields[9] as String?,
      note: fields[10] as String?,
      receiptUrl: fields[11] as String?,
      tags: (fields[12] as List?)?.cast<String>() ?? [],
      gracePeriodDays: fields[13] as int? ?? 0,
      isDeleted: fields[14] as bool? ?? false,
      isArchived: fields[15] as bool? ?? false,
      templateId: fields[16] as String?,
      parentBillId: fields[17] as String?,
      paidAmount: fields[18] as double? ?? 0,
      reminders: (fields[19] as List?)?.cast<BillReminder>() ?? [],
      currency: fields[20] as String? ?? 'INR',
      exchangeRate: fields[21] as double? ?? 1.0,
      colorValue: fields[22] as int? ?? 0xFF3B82F6,
      iconCodePoint: fields[23] as int? ?? 0xe227,
      createdAt: fields[24] as DateTime?,
      updatedAt: fields[25] as DateTime?,
      deviceId: fields[26] as String?,
      notificationIds: (fields[27] as List?)?.cast<int>() ?? [],
      remindersEnabled: fields[28] as bool? ?? true,
      priority: fields[29] as BillPriority? ?? BillPriority.medium,
      attachmentUrls: (fields[30] as List?)?.cast<String>() ?? [],
      escalationRemindersSent: fields[31] as int? ?? 0,
      lastReminderSentAt: fields[32] as DateTime?,
      lastScheduledAt: fields[33] as DateTime?,
      updatedByDeviceId: fields[34] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Bill obj) {
    writer
      ..writeByte(35)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.recurrence)
      ..writeByte(6)
      ..write(obj.customRecurrenceInterval)
      ..writeByte(7)
      ..write(obj.customRecurrenceUnit)
      ..writeByte(8)
      ..write(obj.categoryId)
      ..writeByte(9)
      ..write(obj.accountId)
      ..writeByte(10)
      ..write(obj.note)
      ..writeByte(11)
      ..write(obj.receiptUrl)
      ..writeByte(12)
      ..write(obj.tags)
      ..writeByte(13)
      ..write(obj.gracePeriodDays)
      ..writeByte(14)
      ..write(obj.isDeleted)
      ..writeByte(15)
      ..write(obj.isArchived)
      ..writeByte(16)
      ..write(obj.templateId)
      ..writeByte(17)
      ..write(obj.parentBillId)
      ..writeByte(18)
      ..write(obj.paidAmount)
      ..writeByte(19)
      ..write(obj.reminders)
      ..writeByte(20)
      ..write(obj.currency)
      ..writeByte(21)
      ..write(obj.exchangeRate)
      ..writeByte(22)
      ..write(obj.colorValue)
      ..writeByte(23)
      ..write(obj.iconCodePoint)
      ..writeByte(24)
      ..write(obj.createdAt)
      ..writeByte(25)
      ..write(obj.updatedAt)
      ..writeByte(26)
      ..write(obj.deviceId)
      ..writeByte(27)
      ..write(obj.notificationIds)
      ..writeByte(28)
      ..write(obj.remindersEnabled)
      ..writeByte(29)
      ..write(obj.priority)
      ..writeByte(30)
      ..write(obj.attachmentUrls)
      ..writeByte(31)
      ..write(obj.escalationRemindersSent)
      ..writeByte(32)
      ..write(obj.lastReminderSentAt)
      ..writeByte(33)
      ..write(obj.lastScheduledAt)
      ..writeByte(34)
      ..write(obj.updatedByDeviceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillReminderAdapter extends TypeAdapter<BillReminder> {
  @override
  final int typeId = 55;

  @override
  BillReminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillReminder(
      id: fields[0] as String?,
      type: fields[1] as ReminderType? ?? ReminderType.daysBefore,
      daysBefore: fields[2] as int? ?? 1,
      hour: fields[3] as int? ?? 9,
      minute: fields[4] as int? ?? 0,
      isEnabled: fields[5] as bool? ?? true,
      notificationId: fields[6] as int?,
      scheduledTime: fields[7] as DateTime?,
      isSent: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, BillReminder obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.daysBefore)
      ..writeByte(3)
      ..write(obj.hour)
      ..writeByte(4)
      ..write(obj.minute)
      ..writeByte(5)
      ..write(obj.isEnabled)
      ..writeByte(6)
      ..write(obj.notificationId)
      ..writeByte(7)
      ..write(obj.scheduledTime)
      ..writeByte(8)
      ..write(obj.isSent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillPaymentAdapter extends TypeAdapter<BillPayment> {
  @override
  final int typeId = 56;

  @override
  BillPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillPayment(
      id: fields[0] as String?,
      billId: fields[1] as String,
      amount: fields[2] as double,
      paidAt: fields[3] as DateTime?,
      accountId: fields[4] as String?,
      note: fields[5] as String?,
      transactionId: fields[6] as String?,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BillPayment obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.billId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.paidAt)
      ..writeByte(4)
      ..write(obj.accountId)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.transactionId)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillPaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillCategoryAdapter extends TypeAdapter<BillCategory> {
  @override
  final int typeId = 57;

  @override
  BillCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillCategory(
      id: fields[0] as String?,
      name: fields[1] as String,
      colorValue: fields[2] as int,
      iconCodePoint: fields[3] as int,
      isCustom: fields[4] as bool? ?? false,
      createdAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BillCategory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.iconCodePoint)
      ..writeByte(4)
      ..write(obj.isCustom)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
