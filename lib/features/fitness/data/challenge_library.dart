import '../models/workout_challenge.dart';

/// Built-in challenge library with pre-designed 30-day challenges
class ChallengeLibrary {
  static final ChallengeLibrary _instance = ChallengeLibrary._internal();
  factory ChallengeLibrary() => _instance;
  ChallengeLibrary._internal();

  List<WorkoutChallenge> get allChallenges => _challenges;

  WorkoutChallenge? getById(String id) {
    try {
      return _challenges.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<WorkoutChallenge> getByCategory(ChallengeCategory category) {
    return _challenges.where((c) => c.category == category).toList();
  }

  List<WorkoutChallenge> getByDifficulty(ChallengeDifficulty difficulty) {
    return _challenges.where((c) => c.difficulty == difficulty).toList();
  }

  static final List<WorkoutChallenge> _challenges = [
    // 30-Day Full Body Challenge
    WorkoutChallenge(
      id: '30_day_full_body',
      name: '30-Day Full Body Challenge',
      description: 'Transform your body in 30 days with this comprehensive full-body workout program.',
      durationDays: 30,
      difficulty: ChallengeDifficulty.beginner,
      category: ChallengeCategory.fullBody,
      estimatedCaloriesTotal: 3000,
      benefits: ['Build overall strength', 'Improve endurance', 'Burn fat', 'Increase flexibility'],
      days: _generateFullBodyDays(),
      createdAt: DateTime(2024, 1, 1),
    ),

    // 30-Day Abs Challenge
    WorkoutChallenge(
      id: '30_day_abs',
      name: '30-Day Abs Challenge',
      description: 'Sculpt your core and build a stronger midsection with progressive ab workouts.',
      durationDays: 30,
      difficulty: ChallengeDifficulty.intermediate,
      category: ChallengeCategory.abs,
      estimatedCaloriesTotal: 1500,
      benefits: ['Stronger core', 'Better posture', 'Reduced back pain', 'Toned abs'],
      days: _generateAbsDays(),
      createdAt: DateTime(2024, 1, 1),
    ),

    // 30-Day Weight Loss Challenge
    WorkoutChallenge(
      id: '30_day_weight_loss',
      name: '30-Day Fat Burn Challenge',
      description: 'High-intensity cardio and strength training to maximize calorie burn.',
      durationDays: 30,
      difficulty: ChallengeDifficulty.intermediate,
      category: ChallengeCategory.weightLoss,
      estimatedCaloriesTotal: 4500,
      benefits: ['Burn fat', 'Boost metabolism', 'Increase stamina', 'Build lean muscle'],
      days: _generateWeightLossDays(),
      createdAt: DateTime(2024, 1, 1),
    ),

    // 30-Day Leg Challenge
    WorkoutChallenge(
      id: '30_day_legs',
      name: '30-Day Leg Challenge',
      description: 'Build strong, toned legs with progressive lower body workouts.',
      durationDays: 30,
      difficulty: ChallengeDifficulty.beginner,
      category: ChallengeCategory.legs,
      estimatedCaloriesTotal: 2500,
      benefits: ['Stronger legs', 'Better balance', 'Increased power', 'Toned thighs'],
      days: _generateLegDays(),
      createdAt: DateTime(2024, 1, 1),
    ),

    // 30-Day Arm Challenge
    WorkoutChallenge(
      id: '30_day_arms',
      name: '30-Day Arm Toning Challenge',
      description: 'Sculpt and strengthen your arms with no-equipment exercises.',
      durationDays: 30,
      difficulty: ChallengeDifficulty.beginner,
      category: ChallengeCategory.arms,
      estimatedCaloriesTotal: 1800,
      benefits: ['Toned arms', 'Upper body strength', 'Better posture', 'Increased definition'],
      days: _generateArmDays(),
      createdAt: DateTime(2024, 1, 1),
    ),
  ];

  static List<ChallengeDay> _generateFullBodyDays() {
    final days = <ChallengeDay>[];
    for (int i = 1; i <= 30; i++) {
      final isRestDay = i % 7 == 0;
      final week = ((i - 1) ~/ 7) + 1;
      final intensity = week <= 1 ? 'Light' : week <= 2 ? 'Moderate' : week <= 3 ? 'Intense' : 'Maximum';
      
      days.add(ChallengeDay(
        dayNumber: i,
        title: isRestDay ? 'Rest Day' : 'Day $i: $intensity Full Body',
        description: isRestDay 
            ? 'Recovery day - stretch and rest'
            : 'Full body workout with progressive intensity',
        workoutId: isRestDay ? null : 'full_body_beginner',
        isRestDay: isRestDay,
        estimatedMinutes: isRestDay ? 0 : 15 + (week * 5),
        estimatedCalories: isRestDay ? 0 : 80 + (week * 20),
      ));
    }
    return days;
  }

  static List<ChallengeDay> _generateAbsDays() {
    final days = <ChallengeDay>[];
    for (int i = 1; i <= 30; i++) {
      final isRestDay = i % 7 == 0;
      final week = ((i - 1) ~/ 7) + 1;
      
      days.add(ChallengeDay(
        dayNumber: i,
        title: isRestDay ? 'Rest Day' : 'Day $i: Core Blast',
        description: isRestDay 
            ? 'Let your muscles recover'
            : 'Focused ab workout',
        workoutId: isRestDay ? null : 'abs_beginner',
        isRestDay: isRestDay,
        estimatedMinutes: isRestDay ? 0 : 10 + (week * 3),
        estimatedCalories: isRestDay ? 0 : 50 + (week * 10),
      ));
    }
    return days;
  }

  static List<ChallengeDay> _generateWeightLossDays() {
    final days = <ChallengeDay>[];
    for (int i = 1; i <= 30; i++) {
      final isRestDay = i % 7 == 0;
      final week = ((i - 1) ~/ 7) + 1;
      
      days.add(ChallengeDay(
        dayNumber: i,
        title: isRestDay ? 'Active Recovery' : 'Day $i: Fat Burner',
        description: isRestDay 
            ? 'Light stretching and walking'
            : 'High-intensity fat burning workout',
        workoutId: isRestDay ? null : 'hiit_burner',
        isRestDay: isRestDay,
        estimatedMinutes: isRestDay ? 15 : 20 + (week * 5),
        estimatedCalories: isRestDay ? 50 : 150 + (week * 25),
      ));
    }
    return days;
  }

  static List<ChallengeDay> _generateLegDays() {
    final days = <ChallengeDay>[];
    for (int i = 1; i <= 30; i++) {
      final isRestDay = i % 7 == 0;
      final week = ((i - 1) ~/ 7) + 1;
      
      days.add(ChallengeDay(
        dayNumber: i,
        title: isRestDay ? 'Rest Day' : 'Day $i: Leg Day',
        description: isRestDay 
            ? 'Recovery and stretching'
            : 'Lower body focused workout',
        workoutId: isRestDay ? null : 'legs_beginner',
        isRestDay: isRestDay,
        estimatedMinutes: isRestDay ? 0 : 12 + (week * 4),
        estimatedCalories: isRestDay ? 0 : 70 + (week * 15),
      ));
    }
    return days;
  }

  static List<ChallengeDay> _generateArmDays() {
    final days = <ChallengeDay>[];
    for (int i = 1; i <= 30; i++) {
      final isRestDay = i % 7 == 0;
      final week = ((i - 1) ~/ 7) + 1;
      
      days.add(ChallengeDay(
        dayNumber: i,
        title: isRestDay ? 'Rest Day' : 'Day $i: Arm Sculpt',
        description: isRestDay 
            ? 'Rest and recover'
            : 'Upper body and arm focused workout',
        workoutId: isRestDay ? null : 'arms_toned',
        isRestDay: isRestDay,
        estimatedMinutes: isRestDay ? 0 : 10 + (week * 3),
        estimatedCalories: isRestDay ? 0 : 50 + (week * 12),
      ));
    }
    return days;
  }
}
