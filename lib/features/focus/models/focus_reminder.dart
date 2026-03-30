import 'meditation_activity.dart';

/// Enum for reminder frequency types
enum ReminderFrequency {
  once,
  daily,
  weekdays,
  weekends,
  custom,
}

extension ReminderFrequencyExtension on ReminderFrequency {
  String get id {
    switch (this) {
      case ReminderFrequency.once:
        return 'once';
      case ReminderFrequency.daily:
        return 'daily';
      case ReminderFrequency.weekdays:
        return 'weekdays';
      case ReminderFrequency.weekends:
        return 'weekends';
      case ReminderFrequency.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case ReminderFrequency.once:
        return 'Once';
      case ReminderFrequency.daily:
        return 'Daily';
      case ReminderFrequency.weekdays:
        return 'Weekdays';
      case ReminderFrequency.weekends:
        return 'Weekends';
      case ReminderFrequency.custom:
        return 'Custom';
    }
  }

  String get description {
    switch (this) {
      case ReminderFrequency.once:
        return 'One-time reminder';
      case ReminderFrequency.daily:
        return 'Every day';
      case ReminderFrequency.weekdays:
        return 'Monday to Friday';
      case ReminderFrequency.weekends:
        return 'Saturday & Sunday';
      case ReminderFrequency.custom:
        return 'Custom days';
    }
  }

  static ReminderFrequency fromString(String value) {
    return ReminderFrequency.values.firstWhere(
      (e) => e.id == value || e.name == value,
      orElse: () => ReminderFrequency.daily,
    );
  }
}

/// Enum for reminder types
enum FocusReminderType {
  activityReminder,
  streakProtection,
  dailyGoal,
  sessionCompletion,
  weeklySummary,
}

extension FocusReminderTypeExtension on FocusReminderType {
  String get id {
    switch (this) {
      case FocusReminderType.activityReminder:
        return 'activity_reminder';
      case FocusReminderType.streakProtection:
        return 'streak_protection';
      case FocusReminderType.dailyGoal:
        return 'daily_goal';
      case FocusReminderType.sessionCompletion:
        return 'session_completion';
      case FocusReminderType.weeklySummary:
        return 'weekly_summary';
    }
  }

  String get displayName {
    switch (this) {
      case FocusReminderType.activityReminder:
        return 'Activity Reminder';
      case FocusReminderType.streakProtection:
        return 'Streak Protection';
      case FocusReminderType.dailyGoal:
        return 'Daily Goal';
      case FocusReminderType.sessionCompletion:
        return 'Session Completion';
      case FocusReminderType.weeklySummary:
        return 'Weekly Summary';
    }
  }

  String get description {
    switch (this) {
      case FocusReminderType.activityReminder:
        return 'Remind you to practice an activity';
      case FocusReminderType.streakProtection:
        return 'Alert before losing your streak';
      case FocusReminderType.dailyGoal:
        return 'Track your daily mindfulness goal';
      case FocusReminderType.sessionCompletion:
        return 'Celebrate completed sessions';
      case FocusReminderType.weeklySummary:
        return 'Weekly progress report';
    }
  }

  String get emoji {
    switch (this) {
      case FocusReminderType.activityReminder:
        return '🔔';
      case FocusReminderType.streakProtection:
        return '🔥';
      case FocusReminderType.dailyGoal:
        return '🎯';
      case FocusReminderType.sessionCompletion:
        return '✨';
      case FocusReminderType.weeklySummary:
        return '📊';
    }
  }

  static FocusReminderType fromString(String value) {
    return FocusReminderType.values.firstWhere(
      (e) => e.id == value || e.name == value,
      orElse: () => FocusReminderType.activityReminder,
    );
  }
}

/// Model representing a focus/wellness reminder
class FocusReminder {
  final String id;
  final FocusReminderType type;
  final WellnessActivityType? activityType;
  final String title;
  final String body;
  final int hour;
  final int minute;
  final ReminderFrequency frequency;
  final List<int> customDays;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? notificationId;
  final Map<String, dynamic>? metadata;

  const FocusReminder({
    required this.id,
    required this.type,
    this.activityType,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    this.frequency = ReminderFrequency.daily,
    this.customDays = const [],
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
    this.notificationId,
    this.metadata,
  });

  String get timeString {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get timeDisplay {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$displayHour:$m $period';
  }

  List<int> get effectiveDays {
    switch (frequency) {
      case ReminderFrequency.daily:
        return [1, 2, 3, 4, 5, 6, 7];
      case ReminderFrequency.weekdays:
        return [1, 2, 3, 4, 5];
      case ReminderFrequency.weekends:
        return [6, 7];
      case ReminderFrequency.custom:
        return customDays;
      case ReminderFrequency.once:
        return [];
    }
  }

  bool shouldTriggerOn(DateTime date) {
    if (!isEnabled) return false;
    if (frequency == ReminderFrequency.once) {
      return date.hour == hour && date.minute == minute;
    }
    return effectiveDays.contains(date.weekday);
  }

  FocusReminder copyWith({
    String? id,
    FocusReminderType? type,
    WellnessActivityType? activityType,
    String? title,
    String? body,
    int? hour,
    int? minute,
    ReminderFrequency? frequency,
    List<int>? customDays,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? notificationId,
    Map<String, dynamic>? metadata,
  }) {
    return FocusReminder(
      id: id ?? this.id,
      type: type ?? this.type,
      activityType: activityType ?? this.activityType,
      title: title ?? this.title,
      body: body ?? this.body,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      frequency: frequency ?? this.frequency,
      customDays: customDays ?? this.customDays,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notificationId: notificationId ?? this.notificationId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.id,
    'activityType': activityType?.id,
    'title': title,
    'body': body,
    'hour': hour,
    'minute': minute,
    'frequency': frequency.id,
    'customDays': customDays,
    'isEnabled': isEnabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'notificationId': notificationId,
    'metadata': metadata,
  };

  factory FocusReminder.fromJson(Map<String, dynamic> json) {
    return FocusReminder(
      id: json['id'] as String,
      type: FocusReminderTypeExtension.fromString(json['type'] as String),
      activityType: json['activityType'] != null
          ? WellnessActivityTypeExtension.fromString(json['activityType'] as String)
          : null,
      title: json['title'] as String,
      body: json['body'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      frequency: ReminderFrequencyExtension.fromString(json['frequency'] as String? ?? 'daily'),
      customDays: List<int>.from(json['customDays'] ?? []),
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      notificationId: json['notificationId'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  factory FocusReminder.createActivityReminder({
    required WellnessActivityType activityType,
    required int hour,
    required int minute,
    ReminderFrequency frequency = ReminderFrequency.daily,
    List<int> customDays = const [],
  }) {
    final now = DateTime.now();
    return FocusReminder(
      id: 'reminder_${activityType.id}_${now.millisecondsSinceEpoch}',
      type: FocusReminderType.activityReminder,
      activityType: activityType,
      title: 'Time for ${activityType.displayName}',
      body: 'Take a moment to practice ${activityType.displayName.toLowerCase()}',
      hour: hour,
      minute: minute,
      frequency: frequency,
      customDays: customDays,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory FocusReminder.createStreakProtection({
    int hour = 20,
    int minute = 0,
  }) {
    final now = DateTime.now();
    return FocusReminder(
      id: 'reminder_streak_${now.millisecondsSinceEpoch}',
      type: FocusReminderType.streakProtection,
      title: "Don't break your streak! 🔥",
      body: 'Complete a quick session to keep your streak going',
      hour: hour,
      minute: minute,
      frequency: ReminderFrequency.daily,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory FocusReminder.createDailyGoal({
    int hour = 9,
    int minute = 0,
  }) {
    final now = DateTime.now();
    return FocusReminder(
      id: 'reminder_goal_${now.millisecondsSinceEpoch}',
      type: FocusReminderType.dailyGoal,
      title: 'Start your day mindfully 🎯',
      body: 'Begin with a meditation or breathing exercise',
      hour: hour,
      minute: minute,
      frequency: ReminderFrequency.daily,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory FocusReminder.createWeeklySummary({
    int dayOfWeek = 7,
    int hour = 18,
    int minute = 0,
  }) {
    final now = DateTime.now();
    return FocusReminder(
      id: 'reminder_weekly_${now.millisecondsSinceEpoch}',
      type: FocusReminderType.weeklySummary,
      title: 'Your weekly wellness summary 📊',
      body: 'Check your progress and set goals for next week',
      hour: hour,
      minute: minute,
      frequency: ReminderFrequency.custom,
      customDays: [dayOfWeek],
      createdAt: now,
      updatedAt: now,
    );
  }

  static List<FocusReminder> createDefaultReminders() {
    return [
      FocusReminder.createDailyGoal(hour: 8, minute: 0),
      FocusReminder.createActivityReminder(
        activityType: WellnessActivityType.meditation,
        hour: 7,
        minute: 30,
      ),
      FocusReminder.createStreakProtection(hour: 21, minute: 0),
      FocusReminder.createWeeklySummary(dayOfWeek: 7, hour: 19, minute: 0),
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
