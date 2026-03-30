enum SymptomType {
  cramps,
  headache,
  backPain,
  backache,
  bloating,
  breastTenderness,
  fatigue,
  acne,
  nausea,
  insomnia,
  hotFlashes,
  dizziness,
  cravings,
  constipation,
  diarrhea,
  jointPain,
  moodSwings,
}

enum SymptomSeverity {
  mild,
  moderate,
  severe,
}

enum MoodType {
  happy,
  calm,
  energetic,
  sensitive,
  anxious,
  irritable,
  sad,
  moodSwings,
  stressed,
  tired,
  focused,
  confused,
}

enum EnergyLevel {
  veryLow,
  low,
  moderate,
  high,
  veryHigh,
}

enum SleepQuality {
  poor,
  fair,
  good,
  excellent,
}

class SymptomLog {
  final String id;
  final DateTime date;
  final List<SymptomEntry> symptomEntries;
  final List<SymptomType> symptoms; // Simple list of symptoms
  final List<MoodType> moods;
  final MoodType? mood; // Single mood for quick logging
  final int? moodIntensity; // 1-5
  final int? severity; // Overall severity 1-5
  final EnergyLevel? energyLevel;
  final SleepQuality? sleepQuality;
  final double? sleepHours;
  final String? notes;
  final int? stressLevel; // 1-10
  final bool? hadIntimacy;
  final bool? usedProtection;
  final bool? protectedIntimacy;
  final bool? highLibido;
  final DateTime? createdAt;

  SymptomLog({
    required this.id,
    required this.date,
    this.symptomEntries = const [],
    this.symptoms = const [],
    this.moods = const [],
    this.mood,
    this.moodIntensity,
    this.severity,
    this.energyLevel,
    this.sleepQuality,
    this.sleepHours,
    this.notes,
    this.stressLevel,
    this.hadIntimacy,
    this.usedProtection,
    this.protectedIntimacy,
    this.highLibido,
    this.createdAt,
  });

  SymptomLog copyWith({
    List<SymptomEntry>? symptomEntries,
    List<SymptomType>? symptoms,
    List<MoodType>? moods,
    MoodType? mood,
    int? moodIntensity,
    int? severity,
    EnergyLevel? energyLevel,
    SleepQuality? sleepQuality,
    double? sleepHours,
    String? notes,
    int? stressLevel,
    bool? hadIntimacy,
    bool? usedProtection,
    bool? protectedIntimacy,
    bool? highLibido,
  }) {
    return SymptomLog(
      id: id,
      date: date,
      symptomEntries: symptomEntries ?? this.symptomEntries,
      symptoms: symptoms ?? this.symptoms,
      moods: moods ?? this.moods,
      mood: mood ?? this.mood,
      moodIntensity: moodIntensity ?? this.moodIntensity,
      severity: severity ?? this.severity,
      energyLevel: energyLevel ?? this.energyLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      sleepHours: sleepHours ?? this.sleepHours,
      notes: notes ?? this.notes,
      stressLevel: stressLevel ?? this.stressLevel,
      hadIntimacy: hadIntimacy ?? this.hadIntimacy,
      usedProtection: usedProtection ?? this.usedProtection,
      protectedIntimacy: protectedIntimacy ?? this.protectedIntimacy,
      highLibido: highLibido ?? this.highLibido,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'symptomEntries': symptomEntries.map((s) => s.toJson()).toList(),
    'symptoms': symptoms.map((s) => s.index).toList(),
    'moods': moods.map((m) => m.index).toList(),
    'mood': mood?.index,
    'moodIntensity': moodIntensity,
    'severity': severity,
    'energyLevel': energyLevel?.index,
    'sleepQuality': sleepQuality?.index,
    'sleepHours': sleepHours,
    'notes': notes,
    'stressLevel': stressLevel,
    'hadIntimacy': hadIntimacy,
    'usedProtection': usedProtection,
    'protectedIntimacy': protectedIntimacy,
    'highLibido': highLibido,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory SymptomLog.fromJson(Map<String, dynamic> json) => SymptomLog(
    id: json['id'],
    date: DateTime.parse(json['date']),
    symptomEntries: (json['symptomEntries'] as List?)?.map((s) => SymptomEntry.fromJson(s)).toList() ?? [],
    symptoms: (json['symptoms'] as List?)?.map((s) => SymptomType.values[s as int]).toList() ?? [],
    moods: (json['moods'] as List?)?.map((m) => MoodType.values[m as int]).toList() ?? [],
    mood: json['mood'] != null ? MoodType.values[json['mood'] as int] : null,
    moodIntensity: json['moodIntensity'] as int?,
    severity: json['severity'] as int?,
    energyLevel: json['energyLevel'] != null ? EnergyLevel.values[json['energyLevel'] as int] : null,
    sleepQuality: json['sleepQuality'] != null ? SleepQuality.values[json['sleepQuality'] as int] : null,
    sleepHours: json['sleepHours']?.toDouble(),
    notes: json['notes'] as String?,
    stressLevel: json['stressLevel'] as int?,
    hadIntimacy: json['hadIntimacy'] as bool?,
    usedProtection: json['usedProtection'] as bool?,
    protectedIntimacy: json['protectedIntimacy'] as bool?,
    highLibido: json['highLibido'] as bool?,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
  );
}

class SymptomEntry {
  final SymptomType type;
  final SymptomSeverity severity;
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
