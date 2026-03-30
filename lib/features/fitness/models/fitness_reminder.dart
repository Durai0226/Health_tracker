class FitnessReminder {
  final String id;
  final String type; // walk, gym, yoga, run, cycling, swimming
  final String title;
  final DateTime reminderTime;
  final String frequency; // daily, weekdays, weekends, custom
  final int durationMinutes;
  final bool isEnabled;
  final List<int>? customDays; // 1-7 for custom frequency

  FitnessReminder({
    required this.id,
    required this.type,
    required this.title,
    required this.reminderTime,
    this.frequency = 'daily',
    this.durationMinutes = 30,
    this.isEnabled = true,
    this.customDays,
  });

  String get displayType {
    switch (type) {
      case 'walk':
        return '🚶 Walking';
      case 'gym':
        return '🏋️ Gym';
      case 'yoga':
        return '🧘 Yoga';
      case 'run':
        return '🏃 Running';
      case 'cycling':
        return '🚴 Cycling';
      case 'swimming':
        return '🏊 Swimming';
      default:
        return '💪 Workout';
    }
  }

  String get emoji {
    switch (type) {
      case 'walk':
        return '🚶';
      case 'gym':
        return '🏋️';
      case 'yoga':
        return '🧘';
      case 'run':
        return '🏃';
      case 'cycling':
        return '🚴';
      case 'swimming':
        return '🏊';
      default:
        return '💪';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'reminderTime': reminderTime.toIso8601String(),
    'frequency': frequency,
    'durationMinutes': durationMinutes,
    'isEnabled': isEnabled,
    'customDays': customDays,
  };

  factory FitnessReminder.fromJson(Map<String, dynamic> json) => FitnessReminder(
    id: json['id'] ?? '',
    type: json['type'] ?? 'walk',
    title: json['title'] ?? '',
    reminderTime: DateTime.parse(json['reminderTime']),
    frequency: json['frequency'] ?? 'daily',
    durationMinutes: json['durationMinutes'] ?? 30,
    isEnabled: json['isEnabled'] ?? true,
    customDays: (json['customDays'] as List<dynamic>?)?.cast<int>(),
  );
}
