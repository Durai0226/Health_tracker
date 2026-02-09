
import 'package:hive/hive.dart';

part 'fitness_reminder.g.dart';

@HiveType(typeId: 5)
class FitnessReminder extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // walk, gym, yoga, run, cycling, swimming

  @HiveField(2)
  final String title;

  @HiveField(3)
  final DateTime reminderTime;

  @HiveField(4)
  final String frequency; // daily, weekdays, weekends, custom

  @HiveField(5)
  final int durationMinutes;

  @HiveField(6)
  final bool isEnabled;

  @HiveField(7)
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
}
