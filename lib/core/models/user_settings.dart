/// Model to store persistent user settings
class UserSettings {
  final int waterDailyGoalMl;
  final bool darkModeEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String? preferredRingtone;
  final bool showCompletedReminders;
  final int reminderSnoozeMinutes;
  final bool autoMarkMissed;
  final int missedThresholdMinutes;
  final DateTime? lastSyncTime;
  final bool analyticsEnabled;
  final String? locale;
  final int alarmRingDurationSeconds;
  final bool snoozeEnabled;
  final int snoozeIntervalMinutes;
  final int maxSnoozeCount;
  final String notificationSound;
  final bool persistentNotification;
  final bool showOnLockScreen;
  final bool fullScreenNotification;
  final bool isAdsDisabled;

  UserSettings({
    this.waterDailyGoalMl = 2500,
    this.darkModeEnabled = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.preferredRingtone,
    this.showCompletedReminders = true,
    this.reminderSnoozeMinutes = 10,
    this.autoMarkMissed = true,
    this.missedThresholdMinutes = 60,
    this.lastSyncTime,
    this.analyticsEnabled = true,
    this.locale,
    this.alarmRingDurationSeconds = 30,
    this.snoozeEnabled = true,
    this.snoozeIntervalMinutes = 5,
    this.maxSnoozeCount = 3,
    this.notificationSound = 'default',
    this.persistentNotification = true,
    this.showOnLockScreen = true,
    this.fullScreenNotification = true,
    this.isAdsDisabled = false,
  });

  UserSettings copyWith({
    int? waterDailyGoalMl,
    bool? darkModeEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? preferredRingtone,
    bool? showCompletedReminders,
    int? reminderSnoozeMinutes,
    bool? autoMarkMissed,
    int? missedThresholdMinutes,
    DateTime? lastSyncTime,
    bool? analyticsEnabled,
    String? locale,
    int? alarmRingDurationSeconds,
    bool? snoozeEnabled,
    int? snoozeIntervalMinutes,
    int? maxSnoozeCount,
    String? notificationSound,
    bool? persistentNotification,
    bool? showOnLockScreen,
    bool? fullScreenNotification,
    bool? isAdsDisabled,
  }) {
    return UserSettings(
      waterDailyGoalMl: waterDailyGoalMl ?? this.waterDailyGoalMl,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      preferredRingtone: preferredRingtone ?? this.preferredRingtone,
      showCompletedReminders: showCompletedReminders ?? this.showCompletedReminders,
      reminderSnoozeMinutes: reminderSnoozeMinutes ?? this.reminderSnoozeMinutes,
      autoMarkMissed: autoMarkMissed ?? this.autoMarkMissed,
      missedThresholdMinutes: missedThresholdMinutes ?? this.missedThresholdMinutes,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      locale: locale ?? this.locale,
      alarmRingDurationSeconds: alarmRingDurationSeconds ?? this.alarmRingDurationSeconds,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeIntervalMinutes: snoozeIntervalMinutes ?? this.snoozeIntervalMinutes,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      notificationSound: notificationSound ?? this.notificationSound,
      persistentNotification: persistentNotification ?? this.persistentNotification,
      showOnLockScreen: showOnLockScreen ?? this.showOnLockScreen,
      fullScreenNotification: fullScreenNotification ?? this.fullScreenNotification,
      isAdsDisabled: isAdsDisabled ?? this.isAdsDisabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'waterDailyGoalMl': waterDailyGoalMl,
    'darkModeEnabled': darkModeEnabled,
    'soundEnabled': soundEnabled,
    'vibrationEnabled': vibrationEnabled,
    'preferredRingtone': preferredRingtone,
    'showCompletedReminders': showCompletedReminders,
    'reminderSnoozeMinutes': reminderSnoozeMinutes,
    'autoMarkMissed': autoMarkMissed,
    'missedThresholdMinutes': missedThresholdMinutes,
    'lastSyncTime': lastSyncTime?.toIso8601String(),
    'analyticsEnabled': analyticsEnabled,
    'locale': locale,
    'alarmRingDurationSeconds': alarmRingDurationSeconds,
    'snoozeEnabled': snoozeEnabled,
    'snoozeIntervalMinutes': snoozeIntervalMinutes,
    'maxSnoozeCount': maxSnoozeCount,
    'notificationSound': notificationSound,
    'persistentNotification': persistentNotification,
    'showOnLockScreen': showOnLockScreen,
    'fullScreenNotification': fullScreenNotification,
    'isAdsDisabled': isAdsDisabled,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    waterDailyGoalMl: json['waterDailyGoalMl'] ?? 2500,
    darkModeEnabled: json['darkModeEnabled'] ?? false,
    soundEnabled: json['soundEnabled'] ?? true,
    vibrationEnabled: json['vibrationEnabled'] ?? true,
    preferredRingtone: json['preferredRingtone'],
    showCompletedReminders: json['showCompletedReminders'] ?? true,
    reminderSnoozeMinutes: json['reminderSnoozeMinutes'] ?? 10,
    autoMarkMissed: json['autoMarkMissed'] ?? true,
    missedThresholdMinutes: json['missedThresholdMinutes'] ?? 60,
    lastSyncTime: json['lastSyncTime'] != null 
        ? DateTime.parse(json['lastSyncTime']) 
        : null,
    analyticsEnabled: json['analyticsEnabled'] ?? true,
    locale: json['locale'],
    alarmRingDurationSeconds: json['alarmRingDurationSeconds'] ?? 30,
    snoozeEnabled: json['snoozeEnabled'] ?? true,
    snoozeIntervalMinutes: json['snoozeIntervalMinutes'] ?? 5,
    maxSnoozeCount: json['maxSnoozeCount'] ?? 3,
    notificationSound: json['notificationSound'] ?? 'default',
    persistentNotification: json['persistentNotification'] ?? true,
    showOnLockScreen: json['showOnLockScreen'] ?? true,
    fullScreenNotification: json['fullScreenNotification'] ?? true,
    isAdsDisabled: json['isAdsDisabled'] ?? false,
  );
}
