// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 22;

  @override
  UserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettings(
      waterDailyGoalMl: fields[0] as int,
      darkModeEnabled: fields[1] as bool,
      soundEnabled: fields[2] as bool,
      vibrationEnabled: fields[3] as bool,
      preferredRingtone: fields[4] as String?,
      showCompletedReminders: fields[5] as bool,
      reminderSnoozeMinutes: fields[6] as int,
      autoMarkMissed: fields[7] as bool,
      missedThresholdMinutes: fields[8] as int,
      lastSyncTime: fields[9] as DateTime?,
      analyticsEnabled: fields[10] as bool,
      locale: fields[11] as String?,
      alarmRingDurationSeconds: fields[12] as int,
      snoozeEnabled: fields[13] as bool,
      snoozeIntervalMinutes: fields[14] as int,
      maxSnoozeCount: fields[15] as int,
      notificationSound: fields[16] as String,
      persistentNotification: fields[17] as bool,
      showOnLockScreen: fields[18] as bool,
      fullScreenNotification: fields[19] as bool,
      isAdsDisabled: fields[20] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.waterDailyGoalMl)
      ..writeByte(1)
      ..write(obj.darkModeEnabled)
      ..writeByte(2)
      ..write(obj.soundEnabled)
      ..writeByte(3)
      ..write(obj.vibrationEnabled)
      ..writeByte(4)
      ..write(obj.preferredRingtone)
      ..writeByte(5)
      ..write(obj.showCompletedReminders)
      ..writeByte(6)
      ..write(obj.reminderSnoozeMinutes)
      ..writeByte(7)
      ..write(obj.autoMarkMissed)
      ..writeByte(8)
      ..write(obj.missedThresholdMinutes)
      ..writeByte(9)
      ..write(obj.lastSyncTime)
      ..writeByte(10)
      ..write(obj.analyticsEnabled)
      ..writeByte(11)
      ..write(obj.locale)
      ..writeByte(12)
      ..write(obj.alarmRingDurationSeconds)
      ..writeByte(13)
      ..write(obj.snoozeEnabled)
      ..writeByte(14)
      ..write(obj.snoozeIntervalMinutes)
      ..writeByte(15)
      ..write(obj.maxSnoozeCount)
      ..writeByte(16)
      ..write(obj.notificationSound)
      ..writeByte(17)
      ..write(obj.persistentNotification)
      ..writeByte(18)
      ..write(obj.showOnLockScreen)
      ..writeByte(19)
      ..write(obj.fullScreenNotification)
      ..writeByte(20)
      ..write(obj.isAdsDisabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
