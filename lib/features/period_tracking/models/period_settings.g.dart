// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PeriodSettingsAdapter extends TypeAdapter<PeriodSettings> {
  @override
  final int typeId = 41;

  @override
  PeriodSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PeriodSettings(
      defaultCycleLength: fields[0] as int,
      defaultPeriodDuration: fields[1] as int,
      trackOvulation: fields[2] as bool,
      trackFertility: fields[3] as bool,
      trackSymptoms: fields[4] as bool,
      trackMood: fields[5] as bool,
      enablePeriodReminders: fields[6] as bool,
      periodReminderDaysBefore: fields[7] as int,
      enableOvulationReminders: fields[8] as bool,
      enableFertileWindowReminders: fields[9] as bool,
      enablePMSReminders: fields[10] as bool,
      pmsReminderDaysBefore: fields[11] as int,
      showMotivationalMessages: fields[12] as bool,
      enableHealthTips: fields[13] as bool,
      syncWithCalendar: fields[14] as bool,
      linkedCalendarId: fields[15] as String?,
      reminderTime: fields[16] as DateTime?,
      privacyMode: fields[17] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PeriodSettings obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.defaultCycleLength)
      ..writeByte(1)
      ..write(obj.defaultPeriodDuration)
      ..writeByte(2)
      ..write(obj.trackOvulation)
      ..writeByte(3)
      ..write(obj.trackFertility)
      ..writeByte(4)
      ..write(obj.trackSymptoms)
      ..writeByte(5)
      ..write(obj.trackMood)
      ..writeByte(6)
      ..write(obj.enablePeriodReminders)
      ..writeByte(7)
      ..write(obj.periodReminderDaysBefore)
      ..writeByte(8)
      ..write(obj.enableOvulationReminders)
      ..writeByte(9)
      ..write(obj.enableFertileWindowReminders)
      ..writeByte(10)
      ..write(obj.enablePMSReminders)
      ..writeByte(11)
      ..write(obj.pmsReminderDaysBefore)
      ..writeByte(12)
      ..write(obj.showMotivationalMessages)
      ..writeByte(13)
      ..write(obj.enableHealthTips)
      ..writeByte(14)
      ..write(obj.syncWithCalendar)
      ..writeByte(15)
      ..write(obj.linkedCalendarId)
      ..writeByte(16)
      ..write(obj.reminderTime)
      ..writeByte(17)
      ..write(obj.privacyMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
