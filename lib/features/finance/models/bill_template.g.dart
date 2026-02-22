// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillTemplateAdapter extends TypeAdapter<BillTemplate> {
  @override
  final int typeId = 70;

  @override
  BillTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillTemplate(
      id: fields[0] as String?,
      name: fields[1] as String,
      amount: fields[2] as double,
      recurrence: fields[3] as BillRecurrence,
      customRecurrenceInterval: fields[4] as int?,
      customRecurrenceUnit: fields[5] as CustomRecurrenceUnit?,
      advancedRecurrenceType: fields[6] as AdvancedRecurrenceType,
      nthWeekday: fields[7] as int?,
      weekdayIndex: fields[8] as int?,
      nextDueDate: fields[9] as DateTime,
      categoryId: fields[10] as String?,
      accountId: fields[11] as String?,
      note: fields[12] as String?,
      gracePeriodDays: fields[13] as int,
      colorValue: fields[14] as int,
      iconCodePoint: fields[15] as int,
      reminders: (fields[16] as List).cast<BillReminder>(),
      remindersEnabled: fields[17] as bool,
      currency: fields[18] as String?,
      tags: (fields[19] as List).cast<String>(),
      priority: fields[20] as BillPriority,
      createdAt: fields[21] as DateTime?,
      updatedAt: fields[22] as DateTime?,
      isActive: fields[23] as bool,
      lastInstanceGeneratedAt: fields[24] as DateTime?,
      instanceGenerationWindowDays: fields[25] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BillTemplate obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.recurrence)
      ..writeByte(4)
      ..write(obj.customRecurrenceInterval)
      ..writeByte(5)
      ..write(obj.customRecurrenceUnit)
      ..writeByte(6)
      ..write(obj.advancedRecurrenceType)
      ..writeByte(7)
      ..write(obj.nthWeekday)
      ..writeByte(8)
      ..write(obj.weekdayIndex)
      ..writeByte(9)
      ..write(obj.nextDueDate)
      ..writeByte(10)
      ..write(obj.categoryId)
      ..writeByte(11)
      ..write(obj.accountId)
      ..writeByte(12)
      ..write(obj.note)
      ..writeByte(13)
      ..write(obj.gracePeriodDays)
      ..writeByte(14)
      ..write(obj.colorValue)
      ..writeByte(15)
      ..write(obj.iconCodePoint)
      ..writeByte(16)
      ..write(obj.reminders)
      ..writeByte(17)
      ..write(obj.remindersEnabled)
      ..writeByte(18)
      ..write(obj.currency)
      ..writeByte(19)
      ..write(obj.tags)
      ..writeByte(20)
      ..write(obj.priority)
      ..writeByte(21)
      ..write(obj.createdAt)
      ..writeByte(22)
      ..write(obj.updatedAt)
      ..writeByte(23)
      ..write(obj.isActive)
      ..writeByte(24)
      ..write(obj.lastInstanceGeneratedAt)
      ..writeByte(25)
      ..write(obj.instanceGenerationWindowDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillActivityAdapter extends TypeAdapter<BillActivity> {
  @override
  final int typeId = 71;

  @override
  BillActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillActivity(
      id: fields[0] as String?,
      billId: fields[1] as String,
      activityType: fields[2] as BillActivityType,
      timestamp: fields[3] as DateTime?,
      description: fields[4] as String?,
      amount: fields[5] as double?,
      metadata: (fields[6] as Map?)?.cast<String, dynamic>(),
      deviceId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BillActivity obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.billId)
      ..writeByte(2)
      ..write(obj.activityType)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.amount)
      ..writeByte(6)
      ..write(obj.metadata)
      ..writeByte(7)
      ..write(obj.deviceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CategoryKeywordMapAdapter extends TypeAdapter<CategoryKeywordMap> {
  @override
  final int typeId = 72;

  @override
  CategoryKeywordMap read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryKeywordMap(
      id: fields[0] as String?,
      keyword: fields[1] as String,
      categoryId: fields[2] as String,
      frequency: fields[3] as int,
      lastUsed: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryKeywordMap obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.keyword)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.frequency)
      ..writeByte(4)
      ..write(obj.lastUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryKeywordMapAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillSettingsAdapter extends TypeAdapter<BillSettings> {
  @override
  final int typeId = 73;

  @override
  BillSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillSettings(
      defaultReminderDaysBefore: fields[0] as int,
      defaultReminderHour: fields[1] as int,
      defaultReminderMinute: fields[2] as int,
      enableEscalationReminders: fields[3] as bool,
      maxEscalationReminders: fields[4] as int,
      requireBiometricLock: fields[5] as bool,
      instanceGenerationWindowDays: fields[6] as int,
      showBadgeCount: fields[7] as bool,
      defaultCurrency: fields[8] as String,
      defaultPriority: fields[9] as BillPriority,
      lastSyncAt: fields[10] as DateTime?,
      lastSyncDeviceId: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BillSettings obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.defaultReminderDaysBefore)
      ..writeByte(1)
      ..write(obj.defaultReminderHour)
      ..writeByte(2)
      ..write(obj.defaultReminderMinute)
      ..writeByte(3)
      ..write(obj.enableEscalationReminders)
      ..writeByte(4)
      ..write(obj.maxEscalationReminders)
      ..writeByte(5)
      ..write(obj.requireBiometricLock)
      ..writeByte(6)
      ..write(obj.instanceGenerationWindowDays)
      ..writeByte(7)
      ..write(obj.showBadgeCount)
      ..writeByte(8)
      ..write(obj.defaultCurrency)
      ..writeByte(9)
      ..write(obj.defaultPriority)
      ..writeByte(10)
      ..write(obj.lastSyncAt)
      ..writeByte(11)
      ..write(obj.lastSyncDeviceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
