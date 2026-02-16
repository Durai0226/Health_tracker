import 'package:hive/hive.dart';

part 'period_settings.g.dart';

@HiveType(typeId: 41)
class PeriodSettings extends HiveObject {
  @HiveField(0)
  final int defaultCycleLength;

  @HiveField(1)
  final int defaultPeriodDuration;

  @HiveField(2)
  final bool trackOvulation;

  @HiveField(3)
  final bool trackFertility;

  @HiveField(4)
  final bool trackSymptoms;

  @HiveField(5)
  final bool trackMood;

  @HiveField(6)
  final bool enablePeriodReminders;

  @HiveField(7)
  final int periodReminderDaysBefore;

  @HiveField(8)
  final bool enableOvulationReminders;

  @HiveField(9)
  final bool enableFertileWindowReminders;

  @HiveField(10)
  final bool enablePMSReminders;

  @HiveField(11)
  final int pmsReminderDaysBefore;

  @HiveField(12)
  final bool showMotivationalMessages;

  @HiveField(13)
  final bool enableHealthTips;

  @HiveField(14)
  final bool syncWithCalendar;

  @HiveField(15)
  final String? linkedCalendarId;

  @HiveField(16)
  final DateTime? reminderTime;

  @HiveField(17)
  final bool privacyMode; // Hide sensitive info on lock screen

  PeriodSettings({
    this.defaultCycleLength = 28,
    this.defaultPeriodDuration = 5,
    this.trackOvulation = true,
    this.trackFertility = true,
    this.trackSymptoms = true,
    this.trackMood = true,
    this.enablePeriodReminders = true,
    this.periodReminderDaysBefore = 2,
    this.enableOvulationReminders = false,
    this.enableFertileWindowReminders = false,
    this.enablePMSReminders = true,
    this.pmsReminderDaysBefore = 5,
    this.showMotivationalMessages = true,
    this.enableHealthTips = true,
    this.syncWithCalendar = false,
    this.linkedCalendarId,
    this.reminderTime,
    this.privacyMode = true,
  });

  PeriodSettings copyWith({
    int? defaultCycleLength,
    int? defaultPeriodDuration,
    bool? trackOvulation,
    bool? trackFertility,
    bool? trackSymptoms,
    bool? trackMood,
    bool? enablePeriodReminders,
    int? periodReminderDaysBefore,
    bool? enableOvulationReminders,
    bool? enableFertileWindowReminders,
    bool? enablePMSReminders,
    int? pmsReminderDaysBefore,
    bool? showMotivationalMessages,
    bool? enableHealthTips,
    bool? syncWithCalendar,
    String? linkedCalendarId,
    DateTime? reminderTime,
    bool? privacyMode,
  }) {
    return PeriodSettings(
      defaultCycleLength: defaultCycleLength ?? this.defaultCycleLength,
      defaultPeriodDuration: defaultPeriodDuration ?? this.defaultPeriodDuration,
      trackOvulation: trackOvulation ?? this.trackOvulation,
      trackFertility: trackFertility ?? this.trackFertility,
      trackSymptoms: trackSymptoms ?? this.trackSymptoms,
      trackMood: trackMood ?? this.trackMood,
      enablePeriodReminders: enablePeriodReminders ?? this.enablePeriodReminders,
      periodReminderDaysBefore: periodReminderDaysBefore ?? this.periodReminderDaysBefore,
      enableOvulationReminders: enableOvulationReminders ?? this.enableOvulationReminders,
      enableFertileWindowReminders: enableFertileWindowReminders ?? this.enableFertileWindowReminders,
      enablePMSReminders: enablePMSReminders ?? this.enablePMSReminders,
      pmsReminderDaysBefore: pmsReminderDaysBefore ?? this.pmsReminderDaysBefore,
      showMotivationalMessages: showMotivationalMessages ?? this.showMotivationalMessages,
      enableHealthTips: enableHealthTips ?? this.enableHealthTips,
      syncWithCalendar: syncWithCalendar ?? this.syncWithCalendar,
      linkedCalendarId: linkedCalendarId ?? this.linkedCalendarId,
      reminderTime: reminderTime ?? this.reminderTime,
      privacyMode: privacyMode ?? this.privacyMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultCycleLength': defaultCycleLength,
    'defaultPeriodDuration': defaultPeriodDuration,
    'trackOvulation': trackOvulation,
    'trackFertility': trackFertility,
    'trackSymptoms': trackSymptoms,
    'trackMood': trackMood,
    'enablePeriodReminders': enablePeriodReminders,
    'periodReminderDaysBefore': periodReminderDaysBefore,
    'enableOvulationReminders': enableOvulationReminders,
    'enableFertileWindowReminders': enableFertileWindowReminders,
    'enablePMSReminders': enablePMSReminders,
    'pmsReminderDaysBefore': pmsReminderDaysBefore,
    'showMotivationalMessages': showMotivationalMessages,
    'enableHealthTips': enableHealthTips,
    'syncWithCalendar': syncWithCalendar,
    'linkedCalendarId': linkedCalendarId,
    'reminderTime': reminderTime?.toIso8601String(),
    'privacyMode': privacyMode,
  };

  factory PeriodSettings.fromJson(Map<String, dynamic> json) => PeriodSettings(
    defaultCycleLength: json['defaultCycleLength'] ?? 28,
    defaultPeriodDuration: json['defaultPeriodDuration'] ?? 5,
    trackOvulation: json['trackOvulation'] ?? true,
    trackFertility: json['trackFertility'] ?? true,
    trackSymptoms: json['trackSymptoms'] ?? true,
    trackMood: json['trackMood'] ?? true,
    enablePeriodReminders: json['enablePeriodReminders'] ?? true,
    periodReminderDaysBefore: json['periodReminderDaysBefore'] ?? 2,
    enableOvulationReminders: json['enableOvulationReminders'] ?? false,
    enableFertileWindowReminders: json['enableFertileWindowReminders'] ?? false,
    enablePMSReminders: json['enablePMSReminders'] ?? true,
    pmsReminderDaysBefore: json['pmsReminderDaysBefore'] ?? 5,
    showMotivationalMessages: json['showMotivationalMessages'] ?? true,
    enableHealthTips: json['enableHealthTips'] ?? true,
    syncWithCalendar: json['syncWithCalendar'] ?? false,
    linkedCalendarId: json['linkedCalendarId'],
    reminderTime: json['reminderTime'] != null ? DateTime.parse(json['reminderTime']) : null,
    privacyMode: json['privacyMode'] ?? true,
  );
}
