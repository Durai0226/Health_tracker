import '../../../core/health/hydration_goal.dart';

/// Activity level for goal calculation
enum ActivityLevel {
  sedentary, // Little to no exercise
  light, // Light exercise 1-3 days/week
  moderate, // Moderate exercise 3-5 days/week
  active, // Hard exercise 6-7 days/week
  veryActive, // Very hard exercise, physical job
}

/// Climate type for goal adjustment
enum ClimateType {
  cold, // < 10°C
  moderate, // 10-25°C
  warm, // 25-30°C
  hot, // 30-35°C
  veryHot, // > 35°C
}

/// User's hydration profile for personalized goal calculation
class HydrationProfile {
  final String id;
  final double? weightKg;
  final int? heightCm;
  final int? age;
  final bool isMale;
  final ActivityLevel activityLevel;
  final ClimateType climate;
  final bool isPregnant;
  final bool isBreastfeeding;
  final int customGoalMl; // User can override calculated goal
  final bool useCustomGoal;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Conditions the user has told us about, each with published support for a
  /// higher intake. See [HydrationCondition].
  ///
  /// Always subordinate to [fluidCeilingMl]: someone with stones AND a dialysis
  /// fluid limit has a limit. [effectiveGoalMl] enforces that ordering.
  final Set<HydrationCondition> conditions;

  /// A prescribed daily fluid **ceiling** in millilitres, or null for the
  /// ordinary "drink at least this much" mode.
  ///
  /// ## The category's dangerous blind spot
  ///
  /// Every hydration app — this one included until now — is built on the
  /// premise that more water is always better. For people on a fluid
  /// restriction that premise is inverted and the app becomes actively harmful:
  /// it sets a target above their limit, nags them toward it, congratulates
  /// them for exceeding it, and awards a badge for going 20% over.
  ///
  /// This is not a niche group. A content analysis of 51 water-tracking apps
  /// (38 Android, 13 iOS) found exactly one that mentioned kidney stone disease
  /// and **zero** that mentioned chronic kidney disease. Restriction is routine
  /// in advanced CKD, dialysis and heart failure: the 2022 AHA/ACC/HFSA heart
  /// failure guidance treats 1.5–2.0 L/day as reasonable in stage D, and the
  /// National Kidney Foundation's position is that the dialysis prescription
  /// tracks residual kidney function rather than any universal number.
  ///
  /// So the app does not invent a limit and does not suggest one. The number
  /// comes from the user's clinician; all this does is stop lying to them.
  ///
  /// Deliberately NOT routed through the ordinary goal clamp: the calculator
  /// floors targets at [HydrationGoalCalculator.minGoalMl] precisely so an odd
  /// profile cannot accidentally produce a restriction, which means a *real*
  /// restriction has to bypass it.
  final int? fluidCeilingMl;

  /// True when the daily number is a limit to stay under, not a target to reach.
  bool get isRestricted => fluidCeilingMl != null && fluidCeilingMl! > 0;

  final bool wakeUpReminderEnabled;
  final int? wakeUpHour;
  final int? bedtimeHour;

  HydrationProfile({
    required this.id,
    this.weightKg,
    this.heightCm,
    this.age,
    this.isMale = true,
    this.activityLevel = ActivityLevel.moderate,
    this.climate = ClimateType.moderate,
    this.isPregnant = false,
    this.isBreastfeeding = false,
    this.customGoalMl = 2500,
    this.useCustomGoal = false,
    this.createdAt,
    this.updatedAt,
    this.fluidCeilingMl,
    this.conditions = const {},
    this.wakeUpReminderEnabled = true,
    this.wakeUpHour = 7,
    this.bedtimeHour = 22,
  });

  /// Representative ambient temperature for the chosen climate band, used to
  /// drive the sweat model. The bands' own doc comments give the ranges; these
  /// are their midpoints (open-ended bands take a sensible interior value).
  double get _climateTempC => switch (climate) {
        ClimateType.cold => 5,
        ClimateType.moderate => 18,
        ClimateType.warm => 27,
        ClimateType.hot => 32,
        ClimateType.veryHot => 38,
      };

  HydrationActivityLevel get _activity => switch (activityLevel) {
        ActivityLevel.sedentary => HydrationActivityLevel.sedentary,
        ActivityLevel.light => HydrationActivityLevel.light,
        ActivityLevel.moderate => HydrationActivityLevel.moderate,
        ActivityLevel.active => HydrationActivityLevel.active,
        ActivityLevel.veryActive => HydrationActivityLevel.veryActive,
      };

  /// Recommended daily intake, delegated to [HydrationGoalCalculator].
  ///
  /// This used to be `weightKg * 33` times an activity factor times a climate
  /// factor times 0.9-if-female, plus fixed pregnancy/breastfeeding bonuses and
  /// a 5% reduction over 65 — a chain of numbers with no source, two of which
  /// were contradicted by the references that do exist (no authority sets a
  /// body-weight hydration goal, and none reduces the target for older adults).
  /// See [HydrationGoalCalculator] for what replaced it and why.
  ///
  /// [activeKcal] is real active energy from the platform health store when the
  /// caller has it; without it the activity level is used as an estimate.
  HydrationGoal goalBreakdown({int? activeKcal, double? ambientC}) =>
      HydrationGoalCalculator.compute(
        isMale: isMale,
        ageYears: age,
        isPregnant: isPregnant,
        isBreastfeeding: isBreastfeeding,
        activeKcal: activeKcal,
        activityLevel: _activity,
        weightKg: weightKg,
        ambientC: ambientC ?? _climateTempC,
        conditions: conditions,
      );

  int get calculatedGoalMl => goalBreakdown().totalMl;

  /// Get the effective daily goal (custom or calculated)
  /// The number shown on the dial.
  ///
  /// Under a restriction this is the CEILING, and every surface that reads it
  /// must treat it as one — see [isRestricted]. It bypasses the calculator's
  /// floor deliberately: that floor exists to stop an odd profile producing an
  /// accidental restriction, so a prescribed one has to go round it.
  int get effectiveGoalMl {
    if (isRestricted) return fluidCeilingMl!;
    return useCustomGoal ? customGoalMl : calculatedGoalMl;
  }

  /// Get activity level as display string
  String get activityLevelString {
    switch (activityLevel) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.light:
        return 'Lightly Active';
      case ActivityLevel.moderate:
        return 'Moderately Active';
      case ActivityLevel.active:
        return 'Active';
      case ActivityLevel.veryActive:
        return 'Very Active';
    }
  }

  /// Get climate as display string
  String get climateString {
    switch (climate) {
      case ClimateType.cold:
        return 'Cold';
      case ClimateType.moderate:
        return 'Moderate';
      case ClimateType.warm:
        return 'Warm';
      case ClimateType.hot:
        return 'Hot';
      case ClimateType.veryHot:
        return 'Very Hot';
    }
  }

  HydrationProfile copyWith({
    double? weightKg,
    int? heightCm,
    int? age,
    bool? isMale,
    ActivityLevel? activityLevel,
    ClimateType? climate,
    bool? isPregnant,
    bool? isBreastfeeding,
    int? customGoalMl,
    bool? useCustomGoal,
    DateTime? updatedAt,
    bool? wakeUpReminderEnabled,
    int? wakeUpHour,
    int? bedtimeHour,
    int? fluidCeilingMl,
    Set<HydrationCondition>? conditions,
    /// Passing null cannot mean "lift the restriction" in a `??` copyWith, and
    /// silently keeping a stale ceiling would be the dangerous direction.
    bool clearFluidCeiling = false,
    /// Same reason as [clearFluidCeiling], for the two fields the goal formula
    /// reads. Clearing the weight or age box on the profile screen used to do
    /// nothing at all: `weightKg ?? this.weightKg` put the old number straight
    /// back, so someone who had entered a wrong weight could change it but
    /// never take it out, and the goal kept being computed from it.
    bool clearWeight = false,
    bool clearAge = false,
  }) {
    return HydrationProfile(
      id: id,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      heightCm: heightCm ?? this.heightCm,
      age: clearAge ? null : (age ?? this.age),
      isMale: isMale ?? this.isMale,
      activityLevel: activityLevel ?? this.activityLevel,
      climate: climate ?? this.climate,
      isPregnant: isPregnant ?? this.isPregnant,
      isBreastfeeding: isBreastfeeding ?? this.isBreastfeeding,
      customGoalMl: customGoalMl ?? this.customGoalMl,
      useCustomGoal: useCustomGoal ?? this.useCustomGoal,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      wakeUpReminderEnabled: wakeUpReminderEnabled ?? this.wakeUpReminderEnabled,
      wakeUpHour: wakeUpHour ?? this.wakeUpHour,
      bedtimeHour: bedtimeHour ?? this.bedtimeHour,
      fluidCeilingMl:
          clearFluidCeiling ? null : (fluidCeilingMl ?? this.fluidCeilingMl),
      conditions: conditions ?? this.conditions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'age': age,
    'isMale': isMale,
    'activityLevel': activityLevel.index,
    'climate': climate.index,
    'isPregnant': isPregnant,
    'isBreastfeeding': isBreastfeeding,
    'customGoalMl': customGoalMl,
    'useCustomGoal': useCustomGoal,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'wakeUpReminderEnabled': wakeUpReminderEnabled,
    'wakeUpHour': wakeUpHour,
    'bedtimeHour': bedtimeHour,
    'fluidCeilingMl': fluidCeilingMl,
    'conditions': conditions.map((c) => c.name).toList(),
  };

  factory HydrationProfile.fromJson(Map<String, dynamic> json) => HydrationProfile(
    id: json['id'] ?? 'default',
    weightKg: json['weightKg']?.toDouble(),
    heightCm: json['heightCm'],
    age: json['age'],
    isMale: json['isMale'] ?? true,
    activityLevel: ActivityLevel.values[json['activityLevel'] ?? 2],
    climate: ClimateType.values[json['climate'] ?? 1],
    isPregnant: json['isPregnant'] ?? false,
    isBreastfeeding: json['isBreastfeeding'] ?? false,
    customGoalMl: json['customGoalMl'] ?? 2500,
    useCustomGoal: json['useCustomGoal'] ?? false,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    wakeUpReminderEnabled: json['wakeUpReminderEnabled'] ?? true,
    wakeUpHour: json['wakeUpHour'] ?? 7,
    bedtimeHour: json['bedtimeHour'] ?? 22,
    fluidCeilingMl: json['fluidCeilingMl'] as int?,
    conditions: parseHydrationConditions(json['conditions']),
  );
}


/// Decode a persisted condition list.
///
/// Stored by NAME, not enum index: an index-based encoding means inserting a
/// value into [HydrationCondition] silently reassigns every stored profile to a
/// different condition, which for clinical settings is not an acceptable
/// failure. Unknown names are dropped rather than throwing, so a profile
/// written by a newer build still loads on an older one.
Set<HydrationCondition> parseHydrationConditions(Object? raw) {
  if (raw is! List) return const {};
  final byName = {for (final c in HydrationCondition.values) c.name: c};
  return {
    for (final e in raw)
      if (byName[e.toString()] != null) byName[e.toString()]!,
  };
}
