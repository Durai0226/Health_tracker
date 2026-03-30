class WaterReminder {
  final String id;
  final List<DateTime> reminderTimes;
  final int intervalMinutes;
  final bool isEnabled;
  final DateTime? startTime;
  final DateTime? endTime;

  WaterReminder({
    required this.id,
    required this.reminderTimes,
    this.intervalMinutes = 120,
    this.isEnabled = true,
    this.startTime,
    this.endTime,
  });

  WaterReminder copyWith({
    List<DateTime>? reminderTimes,
    int? intervalMinutes,
    bool? isEnabled,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return WaterReminder(
      id: id,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reminderTimes': reminderTimes.map((t) => t.toIso8601String()).toList(),
    'intervalMinutes': intervalMinutes,
    'isEnabled': isEnabled,
    'startTime': startTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
  };

  factory WaterReminder.fromJson(Map<String, dynamic> json) => WaterReminder(
    id: json['id'] ?? '',
    reminderTimes: (json['reminderTimes'] as List<dynamic>?)
        ?.map((t) => DateTime.parse(t as String))
        .toList() ?? [],
    intervalMinutes: json['intervalMinutes'] ?? 120,
    isEnabled: json['isEnabled'] ?? true,
    startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
  );
}
