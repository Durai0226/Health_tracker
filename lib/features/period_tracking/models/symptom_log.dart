import 'package:hive/hive.dart';

part 'symptom_log.g.dart';

@HiveType(typeId: 34)
enum SymptomType {
  @HiveField(0)
  cramps,
  @HiveField(1)
  headache,
  @HiveField(2)
  backPain,
  @HiveField(3)
  bloating,
  @HiveField(4)
  breastTenderness,
  @HiveField(5)
  fatigue,
  @HiveField(6)
  acne,
  @HiveField(7)
  nausea,
  @HiveField(8)
  insomnia,
  @HiveField(9)
  hotFlashes,
  @HiveField(10)
  dizziness,
  @HiveField(11)
  cravings,
  @HiveField(12)
  constipation,
  @HiveField(13)
  diarrhea,
  @HiveField(14)
  jointPain,
}

@HiveType(typeId: 35)
enum SymptomSeverity {
  @HiveField(0)
  mild,
  @HiveField(1)
  moderate,
  @HiveField(2)
  severe,
}

@HiveType(typeId: 36)
enum MoodType {
  @HiveField(0)
  happy,
  @HiveField(1)
  calm,
  @HiveField(2)
  energetic,
  @HiveField(3)
  sensitive,
  @HiveField(4)
  anxious,
  @HiveField(5)
  irritable,
  @HiveField(6)
  sad,
  @HiveField(7)
  moodSwings,
  @HiveField(8)
  stressed,
  @HiveField(9)
  tired,
  @HiveField(10)
  focused,
  @HiveField(11)
  confused,
}

@HiveType(typeId: 37)
enum EnergyLevel {
  @HiveField(0)
  veryLow,
  @HiveField(1)
  low,
  @HiveField(2)
  medium,
  @HiveField(3)
  high,
  @HiveField(4)
  veryHigh,
}

@HiveType(typeId: 38)
enum SleepQuality {
  @HiveField(0)
  poor,
  @HiveField(1)
  fair,
  @HiveField(2)
  good,
  @HiveField(3)
  excellent,
}

@HiveType(typeId: 39)
class SymptomLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final List<SymptomEntry> symptoms;

  @HiveField(3)
  final List<MoodType> moods;

  @HiveField(4)
  final EnergyLevel? energyLevel;

  @HiveField(5)
  final SleepQuality? sleepQuality;

  @HiveField(6)
  final double? sleepHours;

  @HiveField(7)
  final String? notes;

  @HiveField(8)
  final int? stressLevel; // 1-10

  @HiveField(9)
  final bool? hadIntimacy;

  @HiveField(10)
  final bool? usedProtection;

  SymptomLog({
    required this.id,
    required this.date,
    this.symptoms = const [],
    this.moods = const [],
    this.energyLevel,
    this.sleepQuality,
    this.sleepHours,
    this.notes,
    this.stressLevel,
    this.hadIntimacy,
    this.usedProtection,
  });

  SymptomLog copyWith({
    List<SymptomEntry>? symptoms,
    List<MoodType>? moods,
    EnergyLevel? energyLevel,
    SleepQuality? sleepQuality,
    double? sleepHours,
    String? notes,
    int? stressLevel,
    bool? hadIntimacy,
    bool? usedProtection,
  }) {
    return SymptomLog(
      id: id,
      date: date,
      symptoms: symptoms ?? this.symptoms,
      moods: moods ?? this.moods,
      energyLevel: energyLevel ?? this.energyLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      sleepHours: sleepHours ?? this.sleepHours,
      notes: notes ?? this.notes,
      stressLevel: stressLevel ?? this.stressLevel,
      hadIntimacy: hadIntimacy ?? this.hadIntimacy,
      usedProtection: usedProtection ?? this.usedProtection,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'symptoms': symptoms.map((s) => s.toJson()).toList(),
    'moods': moods.map((m) => m.index).toList(),
    'energyLevel': energyLevel?.index,
    'sleepQuality': sleepQuality?.index,
    'sleepHours': sleepHours,
    'notes': notes,
    'stressLevel': stressLevel,
    'hadIntimacy': hadIntimacy,
    'usedProtection': usedProtection,
  };

  factory SymptomLog.fromJson(Map<String, dynamic> json) => SymptomLog(
    id: json['id'],
    date: DateTime.parse(json['date']),
    symptoms: (json['symptoms'] as List?)?.map((s) => SymptomEntry.fromJson(s)).toList() ?? [],
    moods: (json['moods'] as List?)?.map((m) => MoodType.values[m]).toList() ?? [],
    energyLevel: json['energyLevel'] != null ? EnergyLevel.values[json['energyLevel']] : null,
    sleepQuality: json['sleepQuality'] != null ? SleepQuality.values[json['sleepQuality']] : null,
    sleepHours: json['sleepHours']?.toDouble(),
    notes: json['notes'],
    stressLevel: json['stressLevel'],
    hadIntimacy: json['hadIntimacy'],
    usedProtection: json['usedProtection'],
  );
}

@HiveType(typeId: 40)
class SymptomEntry extends HiveObject {
  @HiveField(0)
  final SymptomType type;

  @HiveField(1)
  final SymptomSeverity severity;

  @HiveField(2)
  final String? notes;

  SymptomEntry({
    required this.type,
    required this.severity,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'severity': severity.index,
    'notes': notes,
  };

  factory SymptomEntry.fromJson(Map<String, dynamic> json) => SymptomEntry(
    type: SymptomType.values[json['type']],
    severity: SymptomSeverity.values[json['severity']],
    notes: json['notes'],
  );
}
