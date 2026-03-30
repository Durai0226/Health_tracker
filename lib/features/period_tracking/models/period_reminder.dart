class PeriodReminder {
  final String id;
  final int daysBefore;
  final DateTime reminderTime;
  final bool isEnabled;

  PeriodReminder({
    required this.id,
    this.daysBefore = 2,
    required this.reminderTime,
    this.isEnabled = true,
  });

  PeriodReminder copyWith({
    int? daysBefore,
    DateTime? reminderTime,
    bool? isEnabled,
  }) {
    return PeriodReminder(
      id: id,
      daysBefore: daysBefore ?? this.daysBefore,
      reminderTime: reminderTime ?? this.reminderTime,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'daysBefore': daysBefore,
    'reminderTime': reminderTime.toIso8601String(),
    'isEnabled': isEnabled,
  };

  factory PeriodReminder.fromJson(Map<String, dynamic> json) => PeriodReminder(
    id: json['id'] ?? '',
    daysBefore: json['daysBefore'] ?? 2,
    reminderTime: DateTime.parse(json['reminderTime']),
    isEnabled: json['isEnabled'] ?? true,
  );
}
