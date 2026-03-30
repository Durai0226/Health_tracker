/// Day of week for scheduling
enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

/// Reminder sound options
enum ReminderSound {
  defaultSound,
  waterDrop,
  gentle,
  chime,
  none,
}

/// Advanced water reminder with day-specific scheduling
class AdvancedWaterReminder {
  final String id;
  final bool isEnabled;
  final List<DaySchedule> daySchedules;
  final ReminderSound sound;
  final bool vibrationEnabled;
  final bool smartReminders; // Adjust based on drinking patterns
  final bool skipIfGoalMet; // Don't remind if daily goal is met
  final int snoozeMinutes;
  final String? customMessage;

  AdvancedWaterReminder({
    required this.id,
    this.isEnabled = true,
    List<DaySchedule>? daySchedules,
    this.sound = ReminderSound.defaultSound,
    this.vibrationEnabled = true,
    this.smartReminders = false,
    this.skipIfGoalMet = false,
    this.snoozeMinutes = 15,
    this.customMessage,
  }) : daySchedules = daySchedules ?? DaySchedule.defaultSchedules;

  AdvancedWaterReminder copyWith({
    bool? isEnabled,
    List<DaySchedule>? daySchedules,
    ReminderSound? sound,
    bool? vibrationEnabled,
    bool? smartReminders,
    bool? skipIfGoalMet,
    int? snoozeMinutes,
    String? customMessage,
  }) {
    return AdvancedWaterReminder(
      id: id,
      isEnabled: isEnabled ?? this.isEnabled,
      daySchedules: daySchedules ?? this.daySchedules,
      sound: sound ?? this.sound,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      smartReminders: smartReminders ?? this.smartReminders,
      skipIfGoalMet: skipIfGoalMet ?? this.skipIfGoalMet,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      customMessage: customMessage ?? this.customMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'isEnabled': isEnabled,
    'daySchedules': daySchedules.map((s) => s.toJson()).toList(),
    'sound': sound.index,
    'vibrationEnabled': vibrationEnabled,
    'smartReminders': smartReminders,
    'skipIfGoalMet': skipIfGoalMet,
    'snoozeMinutes': snoozeMinutes,
    'customMessage': customMessage,
  };

  factory AdvancedWaterReminder.fromJson(Map<String, dynamic> json) => AdvancedWaterReminder(
    id: json['id'] ?? 'default',
    isEnabled: json['isEnabled'] ?? true,
    daySchedules: (json['daySchedules'] as List<dynamic>?)
        ?.map((s) => DaySchedule.fromJson(s))
        .toList(),
    sound: ReminderSound.values[json['sound'] ?? 0],
    vibrationEnabled: json['vibrationEnabled'] ?? true,
    smartReminders: json['smartReminders'] ?? false,
    skipIfGoalMet: json['skipIfGoalMet'] ?? false,
    snoozeMinutes: json['snoozeMinutes'] ?? 15,
    customMessage: json['customMessage'],
  );
}

/// Schedule for a specific day
class DaySchedule {
  final DayOfWeek day;
  final bool isEnabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int intervalMinutes;
  final List<TimeSlot>? customTimes; // If set, use these instead of interval

  DaySchedule({
    required this.day,
    this.isEnabled = true,
    this.startHour = 8,
    this.startMinute = 0,
    this.endHour = 22,
    this.endMinute = 0,
    this.intervalMinutes = 60,
    this.customTimes,
  });

  /// Generate reminder times based on schedule
  List<DateTime> generateTimes(DateTime date) {
    if (!isEnabled) return [];

    if (customTimes != null && customTimes!.isNotEmpty) {
      return customTimes!.map((t) => DateTime(
        date.year, date.month, date.day, t.hour, t.minute,
      )).toList();
    }

    final times = <DateTime>[];
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    for (int m = startMinutes; m <= endMinutes; m += intervalMinutes) {
      times.add(DateTime(
        date.year, date.month, date.day, m ~/ 60, m % 60,
      ));
    }

    return times;
  }

  DaySchedule copyWith({
    bool? isEnabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? intervalMinutes,
    List<TimeSlot>? customTimes,
  }) {
    return DaySchedule(
      day: day,
      isEnabled: isEnabled ?? this.isEnabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      customTimes: customTimes ?? this.customTimes,
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day.index,
    'isEnabled': isEnabled,
    'startHour': startHour,
    'startMinute': startMinute,
    'endHour': endHour,
    'endMinute': endMinute,
    'intervalMinutes': intervalMinutes,
    'customTimes': customTimes?.map((t) => t.toJson()).toList(),
  };

  factory DaySchedule.fromJson(Map<String, dynamic> json) => DaySchedule(
    day: DayOfWeek.values[json['day'] ?? 0],
    isEnabled: json['isEnabled'] ?? true,
    startHour: json['startHour'] ?? 8,
    startMinute: json['startMinute'] ?? 0,
    endHour: json['endHour'] ?? 22,
    endMinute: json['endMinute'] ?? 0,
    intervalMinutes: json['intervalMinutes'] ?? 60,
    customTimes: (json['customTimes'] as List<dynamic>?)
        ?.map((t) => TimeSlot.fromJson(t))
        .toList(),
  );

  static String getDayName(DayOfWeek day) {
    switch (day) {
      case DayOfWeek.monday: return 'Monday';
      case DayOfWeek.tuesday: return 'Tuesday';
      case DayOfWeek.wednesday: return 'Wednesday';
      case DayOfWeek.thursday: return 'Thursday';
      case DayOfWeek.friday: return 'Friday';
      case DayOfWeek.saturday: return 'Saturday';
      case DayOfWeek.sunday: return 'Sunday';
    }
  }

  static String getDayShort(DayOfWeek day) {
    switch (day) {
      case DayOfWeek.monday: return 'Mon';
      case DayOfWeek.tuesday: return 'Tue';
      case DayOfWeek.wednesday: return 'Wed';
      case DayOfWeek.thursday: return 'Thu';
      case DayOfWeek.friday: return 'Fri';
      case DayOfWeek.saturday: return 'Sat';
      case DayOfWeek.sunday: return 'Sun';
    }
  }

  static List<DaySchedule> get defaultSchedules => [
    DaySchedule(day: DayOfWeek.monday),
    DaySchedule(day: DayOfWeek.tuesday),
    DaySchedule(day: DayOfWeek.wednesday),
    DaySchedule(day: DayOfWeek.thursday),
    DaySchedule(day: DayOfWeek.friday),
    DaySchedule(day: DayOfWeek.saturday, startHour: 9),
    DaySchedule(day: DayOfWeek.sunday, startHour: 9),
  ];
}

/// Time slot for custom reminder times
class TimeSlot {
  final int hour;
  final int minute;

  TimeSlot({required this.hour, required this.minute});

  String get formatted => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
    hour: json['hour'] ?? 0,
    minute: json['minute'] ?? 0,
  );
}
