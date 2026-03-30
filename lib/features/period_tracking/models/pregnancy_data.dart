import 'package:flutter/material.dart';

/// Pregnancy tracking data model
class PregnancyData {
  final String id;
  final DateTime conceptionDate;
  final DateTime dueDate;
  final int currentWeek;
  final int currentDay;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
  final List<PregnancyLog> logs;
  final PregnancySettings settings;

  PregnancyData({
    required this.id,
    required this.conceptionDate,
    required this.dueDate,
    this.currentWeek = 1,
    this.currentDay = 1,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.notes,
    this.logs = const [],
    PregnancySettings? settings,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        settings = settings ?? PregnancySettings();

  /// Calculate current week based on conception date
  int get calculatedWeek {
    final daysSinceConception = DateTime.now().difference(conceptionDate).inDays;
    return (daysSinceConception / 7).floor() + 1;
  }

  /// Calculate current day of pregnancy (1-280)
  int get calculatedDay {
    return DateTime.now().difference(conceptionDate).inDays + 1;
  }

  /// Get current trimester (1, 2, or 3)
  int get trimester {
    if (calculatedWeek <= 12) return 1;
    if (calculatedWeek <= 27) return 2;
    return 3;
  }

  /// Days remaining until due date
  int get daysRemaining {
    return dueDate.difference(DateTime.now()).inDays;
  }

  /// Weeks remaining until due date
  int get weeksRemaining {
    return (daysRemaining / 7).floor();
  }

  /// Progress percentage (0-100)
  double get progressPercent {
    final totalDays = 280; // 40 weeks
    final daysCompleted = calculatedDay;
    return (daysCompleted / totalDays * 100).clamp(0, 100);
  }

  /// Get fetus development info for current week
  FetusInfo get currentFetusInfo => FetusInfo.forWeek(calculatedWeek);

  PregnancyData copyWith({
    DateTime? conceptionDate,
    DateTime? dueDate,
    int? currentWeek,
    int? currentDay,
    bool? isActive,
    String? notes,
    List<PregnancyLog>? logs,
    PregnancySettings? settings,
  }) {
    return PregnancyData(
      id: id,
      conceptionDate: conceptionDate ?? this.conceptionDate,
      dueDate: dueDate ?? this.dueDate,
      currentWeek: currentWeek ?? this.currentWeek,
      currentDay: currentDay ?? this.currentDay,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      notes: notes ?? this.notes,
      logs: logs ?? this.logs,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conceptionDate': conceptionDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'currentWeek': currentWeek,
        'currentDay': currentDay,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'notes': notes,
        'logs': logs.map((l) => l.toJson()).toList(),
        'settings': settings.toJson(),
      };

  factory PregnancyData.fromJson(Map<String, dynamic> json) => PregnancyData(
        id: json['id'],
        conceptionDate: DateTime.parse(json['conceptionDate']),
        dueDate: DateTime.parse(json['dueDate']),
        currentWeek: json['currentWeek'] ?? 1,
        currentDay: json['currentDay'] ?? 1,
        isActive: json['isActive'] ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : null,
        notes: json['notes'],
        logs: (json['logs'] as List?)
                ?.map((l) => PregnancyLog.fromJson(l))
                .toList() ??
            [],
        settings: json['settings'] != null
            ? PregnancySettings.fromJson(json['settings'])
            : null,
      );

  /// Create from last period date (adds 2 weeks for conception)
  factory PregnancyData.fromLastPeriod(DateTime lastPeriodDate) {
    final conception = lastPeriodDate.add(const Duration(days: 14));
    final due = lastPeriodDate.add(const Duration(days: 280));
    return PregnancyData(
      id: 'pregnancy_${DateTime.now().millisecondsSinceEpoch}',
      conceptionDate: conception,
      dueDate: due,
    );
  }
}

/// Daily pregnancy log entry
class PregnancyLog {
  final String id;
  final DateTime date;
  final int week;
  final double? weight;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final List<PregnancySymptom> symptoms;
  final MoodLevel? mood;
  final int? kickCount;
  final String? notes;
  final List<String> photos;

  PregnancyLog({
    required this.id,
    required this.date,
    required this.week,
    this.weight,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.symptoms = const [],
    this.mood,
    this.kickCount,
    this.notes,
    this.photos = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'week': week,
        'weight': weight,
        'bloodPressureSystolic': bloodPressureSystolic,
        'bloodPressureDiastolic': bloodPressureDiastolic,
        'symptoms': symptoms.map((s) => s.index).toList(),
        'mood': mood?.index,
        'kickCount': kickCount,
        'notes': notes,
        'photos': photos,
      };

  factory PregnancyLog.fromJson(Map<String, dynamic> json) => PregnancyLog(
        id: json['id'],
        date: DateTime.parse(json['date']),
        week: json['week'],
        weight: json['weight']?.toDouble(),
        bloodPressureSystolic: json['bloodPressureSystolic'],
        bloodPressureDiastolic: json['bloodPressureDiastolic'],
        symptoms: (json['symptoms'] as List?)
                ?.map((s) => PregnancySymptom.values[s])
                .toList() ??
            [],
        mood: json['mood'] != null ? MoodLevel.values[json['mood']] : null,
        kickCount: json['kickCount'],
        notes: json['notes'],
        photos: (json['photos'] as List?)?.cast<String>() ?? [],
      );
}

/// Pregnancy symptoms
enum PregnancySymptom {
  nausea,
  fatigue,
  backPain,
  headache,
  swelling,
  heartburn,
  constipation,
  insomnia,
  moodSwings,
  cravings,
  frequentUrination,
  braxtonHicks,
  legCramps,
  shortnessOfBreath,
  pelvicPain,
}

/// Mood levels
enum MoodLevel {
  veryBad,
  bad,
  neutral,
  good,
  veryGood,
}

/// Pregnancy settings
class PregnancySettings {
  final bool trackWeight;
  final bool trackBloodPressure;
  final bool trackKicks;
  final bool enableReminders;
  final TimeOfDay? kickCountReminderTime;
  final bool shareWithPartner;

  PregnancySettings({
    this.trackWeight = true,
    this.trackBloodPressure = true,
    this.trackKicks = true,
    this.enableReminders = true,
    this.kickCountReminderTime,
    this.shareWithPartner = false,
  });

  Map<String, dynamic> toJson() => {
        'trackWeight': trackWeight,
        'trackBloodPressure': trackBloodPressure,
        'trackKicks': trackKicks,
        'enableReminders': enableReminders,
        'kickCountReminderTime': kickCountReminderTime != null
            ? '${kickCountReminderTime!.hour}:${kickCountReminderTime!.minute}'
            : null,
        'shareWithPartner': shareWithPartner,
      };

  factory PregnancySettings.fromJson(Map<String, dynamic> json) {
    TimeOfDay? reminderTime;
    if (json['kickCountReminderTime'] != null) {
      final parts = json['kickCountReminderTime'].split(':');
      reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    return PregnancySettings(
      trackWeight: json['trackWeight'] ?? true,
      trackBloodPressure: json['trackBloodPressure'] ?? true,
      trackKicks: json['trackKicks'] ?? true,
      enableReminders: json['enableReminders'] ?? true,
      kickCountReminderTime: reminderTime,
      shareWithPartner: json['shareWithPartner'] ?? false,
    );
  }
}

/// Fetus development information by week
class FetusInfo {
  final int week;
  final String sizeCm;
  final String weightG;
  final String sizeComparison; // Fruit/object comparison
  final String sizeEmoji;
  final String developmentHighlight;
  final List<String> tips;

  const FetusInfo({
    required this.week,
    required this.sizeCm,
    required this.weightG,
    required this.sizeComparison,
    required this.sizeEmoji,
    required this.developmentHighlight,
    this.tips = const [],
  });

  static FetusInfo forWeek(int week) {
    if (week < 1) week = 1;
    if (week > 40) week = 40;
    return _weeklyData[week - 1];
  }

  static const List<FetusInfo> _weeklyData = [
    // Week 1-4
    FetusInfo(week: 1, sizeCm: '0.1', weightG: '<1', sizeComparison: 'Poppy seed', sizeEmoji: '🌱', developmentHighlight: 'Fertilization occurs'),
    FetusInfo(week: 2, sizeCm: '0.1', weightG: '<1', sizeComparison: 'Poppy seed', sizeEmoji: '🌱', developmentHighlight: 'Cells dividing rapidly'),
    FetusInfo(week: 3, sizeCm: '0.2', weightG: '<1', sizeComparison: 'Pinhead', sizeEmoji: '📍', developmentHighlight: 'Implantation begins'),
    FetusInfo(week: 4, sizeCm: '0.4', weightG: '<1', sizeComparison: 'Sesame seed', sizeEmoji: '🫘', developmentHighlight: 'Neural tube forming'),
    
    // Week 5-8
    FetusInfo(week: 5, sizeCm: '0.5', weightG: '<1', sizeComparison: 'Peppercorn', sizeEmoji: '⚫', developmentHighlight: 'Heart begins beating'),
    FetusInfo(week: 6, sizeCm: '0.6', weightG: '<1', sizeComparison: 'Lentil', sizeEmoji: '🫘', developmentHighlight: 'Facial features forming'),
    FetusInfo(week: 7, sizeCm: '1.0', weightG: '<1', sizeComparison: 'Blueberry', sizeEmoji: '🫐', developmentHighlight: 'Arms and legs budding'),
    FetusInfo(week: 8, sizeCm: '1.6', weightG: '1', sizeComparison: 'Raspberry', sizeEmoji: '🍇', developmentHighlight: 'Fingers forming'),
    
    // Week 9-12
    FetusInfo(week: 9, sizeCm: '2.3', weightG: '2', sizeComparison: 'Grape', sizeEmoji: '🍇', developmentHighlight: 'Essential organs formed'),
    FetusInfo(week: 10, sizeCm: '3.1', weightG: '4', sizeComparison: 'Kumquat', sizeEmoji: '🍊', developmentHighlight: 'Fingernails developing'),
    FetusInfo(week: 11, sizeCm: '4.1', weightG: '7', sizeComparison: 'Fig', sizeEmoji: '🫐', developmentHighlight: 'Baby can swallow'),
    FetusInfo(week: 12, sizeCm: '5.4', weightG: '14', sizeComparison: 'Lime', sizeEmoji: '🍋', developmentHighlight: 'Reflexes developing'),
    
    // Week 13-16 (Second trimester)
    FetusInfo(week: 13, sizeCm: '7.4', weightG: '23', sizeComparison: 'Peach', sizeEmoji: '🍑', developmentHighlight: 'Fingerprints forming'),
    FetusInfo(week: 14, sizeCm: '8.7', weightG: '43', sizeComparison: 'Lemon', sizeEmoji: '🍋', developmentHighlight: 'Can make facial expressions'),
    FetusInfo(week: 15, sizeCm: '10.1', weightG: '70', sizeComparison: 'Apple', sizeEmoji: '🍎', developmentHighlight: 'Can sense light'),
    FetusInfo(week: 16, sizeCm: '11.6', weightG: '100', sizeComparison: 'Avocado', sizeEmoji: '🥑', developmentHighlight: 'Can hear sounds'),
    
    // Week 17-20
    FetusInfo(week: 17, sizeCm: '13.0', weightG: '140', sizeComparison: 'Pear', sizeEmoji: '🍐', developmentHighlight: 'Fat layer forming'),
    FetusInfo(week: 18, sizeCm: '14.2', weightG: '190', sizeComparison: 'Bell pepper', sizeEmoji: '🫑', developmentHighlight: 'Can yawn and hiccup'),
    FetusInfo(week: 19, sizeCm: '15.3', weightG: '240', sizeComparison: 'Mango', sizeEmoji: '🥭', developmentHighlight: 'Protective coating forming'),
    FetusInfo(week: 20, sizeCm: '16.4', weightG: '300', sizeComparison: 'Banana', sizeEmoji: '🍌', developmentHighlight: 'Halfway point! Can taste'),
    
    // Week 21-24
    FetusInfo(week: 21, sizeCm: '26.7', weightG: '360', sizeComparison: 'Carrot', sizeEmoji: '🥕', developmentHighlight: 'Eyebrows visible'),
    FetusInfo(week: 22, sizeCm: '27.8', weightG: '430', sizeComparison: 'Papaya', sizeEmoji: '🍈', developmentHighlight: 'Grip getting stronger'),
    FetusInfo(week: 23, sizeCm: '28.9', weightG: '500', sizeComparison: 'Grapefruit', sizeEmoji: '🍊', developmentHighlight: 'Lungs developing'),
    FetusInfo(week: 24, sizeCm: '30.0', weightG: '600', sizeComparison: 'Corn', sizeEmoji: '🌽', developmentHighlight: 'Face fully formed'),
    
    // Week 25-28
    FetusInfo(week: 25, sizeCm: '34.6', weightG: '660', sizeComparison: 'Rutabaga', sizeEmoji: '🥔', developmentHighlight: 'Can respond to voice'),
    FetusInfo(week: 26, sizeCm: '35.6', weightG: '760', sizeComparison: 'Zucchini', sizeEmoji: '🥒', developmentHighlight: 'Eyes can open'),
    FetusInfo(week: 27, sizeCm: '36.6', weightG: '875', sizeComparison: 'Cauliflower', sizeEmoji: '🥦', developmentHighlight: 'Sleep cycles forming'),
    FetusInfo(week: 28, sizeCm: '37.6', weightG: '1000', sizeComparison: 'Eggplant', sizeEmoji: '🍆', developmentHighlight: 'Third trimester begins'),
    
    // Week 29-32
    FetusInfo(week: 29, sizeCm: '38.6', weightG: '1150', sizeComparison: 'Butternut squash', sizeEmoji: '🎃', developmentHighlight: 'Bones hardening'),
    FetusInfo(week: 30, sizeCm: '39.9', weightG: '1320', sizeComparison: 'Cabbage', sizeEmoji: '🥬', developmentHighlight: 'Brain growing rapidly'),
    FetusInfo(week: 31, sizeCm: '41.1', weightG: '1500', sizeComparison: 'Coconut', sizeEmoji: '🥥', developmentHighlight: 'All senses working'),
    FetusInfo(week: 32, sizeCm: '42.4', weightG: '1700', sizeComparison: 'Squash', sizeEmoji: '🎃', developmentHighlight: 'Practicing breathing'),
    
    // Week 33-36
    FetusInfo(week: 33, sizeCm: '43.7', weightG: '1900', sizeComparison: 'Pineapple', sizeEmoji: '🍍', developmentHighlight: 'Immune system developing'),
    FetusInfo(week: 34, sizeCm: '45.0', weightG: '2100', sizeComparison: 'Cantaloupe', sizeEmoji: '🍈', developmentHighlight: 'Lungs maturing'),
    FetusInfo(week: 35, sizeCm: '46.2', weightG: '2400', sizeComparison: 'Honeydew', sizeEmoji: '🍈', developmentHighlight: 'Most organs ready'),
    FetusInfo(week: 36, sizeCm: '47.4', weightG: '2600', sizeComparison: 'Romaine lettuce', sizeEmoji: '🥬', developmentHighlight: 'Head may engage'),
    
    // Week 37-40
    FetusInfo(week: 37, sizeCm: '48.6', weightG: '2900', sizeComparison: 'Swiss chard', sizeEmoji: '🥬', developmentHighlight: 'Full term! Ready anytime'),
    FetusInfo(week: 38, sizeCm: '49.8', weightG: '3100', sizeComparison: 'Leek', sizeEmoji: '🥬', developmentHighlight: 'Brain still developing'),
    FetusInfo(week: 39, sizeCm: '50.7', weightG: '3300', sizeComparison: 'Watermelon', sizeEmoji: '🍉', developmentHighlight: 'Adding fat layers'),
    FetusInfo(week: 40, sizeCm: '51.2', weightG: '3500', sizeComparison: 'Pumpkin', sizeEmoji: '🎃', developmentHighlight: 'Due date! Baby ready'),
  ];
}
