import 'medicine_enums.dart';

/// Whole CALENDAR days from [from] to [to], time-of-day ignored.
///
/// Must NOT be `to.difference(from).inDays` on local DateTimes: a local day is
/// 23 or 25 hours long across a DST transition, so an elapsed-time diff
/// truncates to one day fewer (spring forward) or reports one day too many
/// after 25h spans accumulate. That off-by-one is load-bearing here — it
/// decides whether a fixed-duration course is still active, which day of an
/// every-X-days parity or an on/off cycle a date falls on, and which titration
/// step applies. Anchoring both ends at UTC midnight removes DST entirely
/// while preserving the civil (local calendar) date.
int _calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// Represents a single scheduled time for medication
class ScheduledTime {
  final int hour;
  final int minute;
  final String? label; // e.g., "Morning", "Afternoon", "Evening", "Bedtime"
  final double dosageAmount;

  /// Opt-in reminder window, in minutes, starting at [hour]:[minute]. Null
  /// (the default) means an exact-time reminder — nothing about existing
  /// schedules changes unless a user explicitly turns this on for a dose.
  /// When set, up to 3 nudges fire across the window (start/mid/end) instead
  /// of one reminder at the exact minute — see reminder_slot_grouping.dart's
  /// windowNudgeMinutes for the placement logic.
  final int? windowMinutes;

  ScheduledTime({
    required this.hour,
    required this.minute,
    this.label,
    this.dosageAmount = 1,
    this.windowMinutes,
  });

  bool get hasWindow => windowMinutes != null && windowMinutes! > 0;

  String get formattedTime {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final amPm = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $amPm';
  }

  DateTime toDateTime([DateTime? date]) {
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  Map<String, dynamic> toJson() => {
    'hour': hour,
    'minute': minute,
    'label': label,
    'dosageAmount': dosageAmount,
    if (windowMinutes != null) 'windowMinutes': windowMinutes,
  };

  factory ScheduledTime.fromJson(Map<String, dynamic> json) => ScheduledTime(
    hour: json['hour'] ?? 8,
    minute: json['minute'] ?? 0,
    label: json['label'],
    dosageAmount: (json['dosageAmount'] ?? 1).toDouble(),
    windowMinutes: json['windowMinutes'],
  );

  ScheduledTime copyWith({
    int? hour,
    int? minute,
    String? label,
    double? dosageAmount,
    int? windowMinutes,
    bool clearWindow = false,
  }) {
    return ScheduledTime(
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      windowMinutes:
          clearWindow ? null : (windowMinutes ?? this.windowMinutes),
    );
  }
}

/// A single dose-escalation step for a titrating medicine — e.g. "Week 2
/// onward: 50mg" instead of one fixed dose forever. Opt-in via
/// [MedicineSchedule.titrationSteps]; a schedule with no steps is completely
/// unaffected — see [MedicineSchedule.effectiveDosageAmount].
class TitrationStep {
  /// Days since the schedule's [MedicineSchedule.startDate] (day 0) at which
  /// this step's [dosageAmount] takes over. Steps are evaluated by picking
  /// the one with the LARGEST offset that is still <= the elapsed days — see
  /// [MedicineSchedule.effectiveDosageAmount].
  final int startDayOffset;
  final double dosageAmount;
  final String? label; // e.g., "Week 2"

  TitrationStep({
    required this.startDayOffset,
    required this.dosageAmount,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'startDayOffset': startDayOffset,
    'dosageAmount': dosageAmount,
    'label': label,
  };

  factory TitrationStep.fromJson(Map<String, dynamic> json) => TitrationStep(
    startDayOffset: json['startDayOffset'] ?? 0,
    dosageAmount: (json['dosageAmount'] ?? 0).toDouble(),
    label: json['label'],
  );

  TitrationStep copyWith({
    int? startDayOffset,
    double? dosageAmount,
    String? label,
  }) {
    return TitrationStep(
      startDayOffset: startDayOffset ?? this.startDayOffset,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      label: label ?? this.label,
    );
  }
}

/// Schedule configuration for a medicine
class MedicineSchedule {
  final FrequencyType frequencyType;
  final List<ScheduledTime> times;
  final int? intervalHours; // For "every X hours"
  final int? intervalDays; // For "every X days"
  final List<int>? specificDays; // 1-7 for Mon-Sun
  final DateTime? startDate;
  final DateTime? endDate;
  final int? durationDays;
  final int? cycleDaysOn; // For cyclical: days on
  final int? cycleDaysOff; // For cyclical: days off
  final MealTiming mealTiming;
  final bool isPRN; // As-needed medication
  final int? maxDailyDoses; // For PRN meds
  final int? minHoursBetweenDoses; // For PRN meds
  // Opt-in weekend override for fixed-time schedules (onceDaily, twiceDaily,
  // etc.) — e.g. "sleep in and take it later on Sat/Sun". Null/empty means no
  // override, so nothing about an existing schedule changes unless a user
  // explicitly turns this on. Deliberately does NOT affect everyXHours (an
  // anchor+interval, not a day-shaped list) or specificDays/everyXDays/
  // cyclical/asNeeded, which already have their own day semantics.
  final List<ScheduledTime>? weekendTimes;
  // Opt-in dose-escalation ("titration") schedule — e.g. "Week 1: 25mg, Week
  // 2: 50mg, Week 3 onward: 100mg" instead of one fixed dose forever.
  // Null/empty means no titration, so nothing about an existing schedule
  // changes unless a user explicitly adds steps — see [effectiveDosageAmount].
  final List<TitrationStep>? titrationSteps;

  MedicineSchedule({
    required this.frequencyType,
    required this.times,
    this.intervalHours,
    this.intervalDays,
    this.specificDays,
    this.startDate,
    this.endDate,
    this.durationDays,
    this.cycleDaysOn,
    this.cycleDaysOff,
    this.mealTiming = MealTiming.anytime,
    this.isPRN = false,
    this.maxDailyDoses,
    this.minHoursBetweenDoses,
    this.weekendTimes,
    this.titrationSteps,
  });

  bool get hasWeekendOverride =>
      weekendTimes != null && weekendTimes!.isNotEmpty;

  bool get isTitrating => titrationSteps != null && titrationSteps!.isNotEmpty;

  /// The dosage amount that applies on [date] for a titrating medicine — e.g.
  /// "Week 1: 25mg, Week 2: 50mg, Week 3 onward: 100mg" instead of one fixed
  /// dose forever. Returns [baseDosageAmount] UNCHANGED when [titrationSteps]
  /// is null/empty (existing medicines are completely unaffected) or when
  /// [startDate] is unset or [date] falls before the first step's offset.
  /// Otherwise picks the step with the LARGEST [TitrationStep.startDayOffset]
  /// that is still <= the days elapsed since [startDate] (day 0).
  ///
  /// Both sides are reduced to CALENDAR days before diffing — see
  /// [_calendarDaysBetween] for why a raw `difference().inDays` between two
  /// local DateTimes is off by one across a DST transition (a titration step
  /// would otherwise escalate the dose a day late).
  double effectiveDosageAmount(DateTime date, double baseDosageAmount) {
    final steps = titrationSteps;
    final start = startDate;
    if (steps == null || steps.isEmpty || start == null) {
      return baseDosageAmount;
    }
    final elapsedDays = _calendarDaysBetween(start, date);

    TitrationStep? best;
    for (final step in steps) {
      if (step.startDayOffset <= elapsedDays &&
          (best == null || step.startDayOffset > best.startDayOffset)) {
        best = step;
      }
    }
    return best?.dosageAmount ?? baseDosageAmount;
  }

  bool get isOngoing => endDate == null && durationDays == null;

  bool isActiveOnDate(DateTime date) {
    // Normalize to date-only. The alarm isolate and the timeline pass a
    // DateTime carrying a time-of-day; using it raw makes `difference().inDays`
    // truncate to the wrong day count (off-by-one for every-X-days / cyclical /
    // duration) and makes the end-date exclusive. Day OFFSETS additionally go
    // through [_calendarDaysBetween] rather than `difference().inDays`, because
    // a DST transition inside the span makes elapsed time drift a whole day.
    final d = DateTime(date.year, date.month, date.day);
    final start = startDate == null
        ? null
        : DateTime(startDate!.year, startDate!.month, startDate!.day);

    if (start != null && d.isBefore(start)) return false;
    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (d.isAfter(end)) return false; // end date is inclusive
    }
    if (durationDays != null && start != null) {
      final daysSinceStart = _calendarDaysBetween(start, d);
      if (daysSinceStart >= durationDays!) return false;
    }

    // Check specific days
    if (frequencyType == FrequencyType.specificDays && specificDays != null) {
      final weekday = d.weekday;
      return specificDays!.contains(weekday);
    }

    // Check cyclical
    if (frequencyType == FrequencyType.cyclical &&
        cycleDaysOn != null && cycleDaysOff != null && start != null) {
      final daysSinceStart = _calendarDaysBetween(start, d);
      final cycleLength = cycleDaysOn! + cycleDaysOff!;
      final dayInCycle = daysSinceStart % cycleLength;
      return dayInCycle < cycleDaysOn!;
    }

    // Check interval days
    if (frequencyType == FrequencyType.everyXDays &&
        intervalDays != null && start != null) {
      final daysSinceStart = _calendarDaysBetween(start, d);
      return daysSinceStart % intervalDays! == 0;
    }

    return true;
  }

  List<DateTime> getScheduledTimesForDate(DateTime date) {
    if (!isActiveOnDate(date)) return [];

    // PRN / as-needed meds have no fixed slots — they are taken ad-hoc and must
    // never generate missed doses or timeline entries.
    if (isPRN || frequencyType == FrequencyType.asNeeded) return [];

    // "Every X hours" fans a single anchor time out across the whole day at the
    // given interval, so the timeline / adherence sees every dose slot.
    if (frequencyType == FrequencyType.everyXHours &&
        intervalHours != null &&
        intervalHours! > 0) {
      final anchor = times.isNotEmpty
          ? times.first
          : ScheduledTime(hour: 8, minute: 0);
      final slots = <DateTime>[];
      var slot = DateTime(date.year, date.month, date.day, anchor.hour, anchor.minute);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59);
      while (!slot.isAfter(endOfDay)) {
        slots.add(slot);
        slot = slot.add(Duration(hours: intervalHours!));
      }
      return slots;
    }

    // Day-based filtering (specificDays / everyXDays / cyclical) is handled by
    // isActiveOnDate above; on active days the fixed [times] are the slots —
    // unless a weekend override applies on a Sat/Sun.
    final isWeekend = date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;
    final effectiveTimes = (isWeekend && hasWeekendOverride) ? weekendTimes! : times;
    return effectiveTimes.map((t) => t.toDateTime(date)).toList()
      ..sort((a, b) => a.compareTo(b));
  }

  String get frequencyDescription {
    switch (frequencyType) {
      case FrequencyType.onceDaily:
        return 'Once daily';
      case FrequencyType.twiceDaily:
        return 'Twice daily';
      case FrequencyType.thriceDaily:
        return '3 times daily';
      case FrequencyType.fourTimesDaily:
        return '4 times daily';
      case FrequencyType.everyXHours:
        return 'Every ${intervalHours ?? 8} hours';
      case FrequencyType.everyXDays:
        return 'Every ${intervalDays ?? 2} days';
      case FrequencyType.specificDays:
        return _getSpecificDaysDescription();
      case FrequencyType.asNeeded:
        return 'As needed';
      case FrequencyType.cyclical:
        return '${cycleDaysOn ?? 21} days on, ${cycleDaysOff ?? 7} days off';
    }
  }

  String _getSpecificDaysDescription() {
    if (specificDays == null || specificDays!.isEmpty) return 'No days selected';
    
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selected = specificDays!.map((d) => dayNames[d - 1]).join(', ');
    return selected;
  }

  Map<String, dynamic> toJson() => {
    'frequencyType': frequencyType.index,
    'times': times.map((t) => t.toJson()).toList(),
    'intervalHours': intervalHours,
    'intervalDays': intervalDays,
    'specificDays': specificDays,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'durationDays': durationDays,
    'cycleDaysOn': cycleDaysOn,
    'cycleDaysOff': cycleDaysOff,
    'mealTiming': mealTiming.index,
    'isPRN': isPRN,
    'maxDailyDoses': maxDailyDoses,
    'minHoursBetweenDoses': minHoursBetweenDoses,
    if (weekendTimes != null)
      'weekendTimes': weekendTimes!.map((t) => t.toJson()).toList(),
    if (titrationSteps != null)
      'titrationSteps': titrationSteps!.map((t) => t.toJson()).toList(),
  };

  factory MedicineSchedule.fromJson(Map<String, dynamic> json) => MedicineSchedule(
    frequencyType: FrequencyType.values[json['frequencyType'] ?? 0],
    times: (json['times'] as List?)?.map((t) => ScheduledTime.fromJson(t)).toList() ?? [],
    intervalHours: json['intervalHours'],
    intervalDays: json['intervalDays'],
    specificDays: (json['specificDays'] as List?)?.cast<int>(),
    startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    durationDays: json['durationDays'],
    cycleDaysOn: json['cycleDaysOn'],
    cycleDaysOff: json['cycleDaysOff'],
    mealTiming: MealTiming.values[json['mealTiming'] ?? 0],
    isPRN: json['isPRN'] ?? false,
    maxDailyDoses: json['maxDailyDoses'],
    minHoursBetweenDoses: json['minHoursBetweenDoses'],
    weekendTimes: (json['weekendTimes'] as List?)
        ?.map((t) => ScheduledTime.fromJson(t))
        .toList(),
    titrationSteps: (json['titrationSteps'] as List?)
        ?.map((t) => TitrationStep.fromJson(t))
        .toList(),
  );

  MedicineSchedule copyWith({
    FrequencyType? frequencyType,
    List<ScheduledTime>? times,
    int? intervalHours,
    int? intervalDays,
    List<int>? specificDays,
    DateTime? startDate,
    DateTime? endDate,
    int? durationDays,
    int? cycleDaysOn,
    int? cycleDaysOff,
    MealTiming? mealTiming,
    bool? isPRN,
    int? maxDailyDoses,
    int? minHoursBetweenDoses,
    List<ScheduledTime>? weekendTimes,
    // See EnhancedMedicine.copyWith's clearDependentId doc — same reason:
    // turning the weekend override back off needs a real clear, not a no-op.
    bool clearWeekendOverride = false,
    List<TitrationStep>? titrationSteps,
    // Same reason as clearWeekendOverride — turning titration back off needs
    // a real clear, not a no-op.
    bool clearTitrationSteps = false,
  }) {
    return MedicineSchedule(
      frequencyType: frequencyType ?? this.frequencyType,
      times: times ?? this.times,
      intervalHours: intervalHours ?? this.intervalHours,
      intervalDays: intervalDays ?? this.intervalDays,
      specificDays: specificDays ?? this.specificDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationDays: durationDays ?? this.durationDays,
      cycleDaysOn: cycleDaysOn ?? this.cycleDaysOn,
      cycleDaysOff: cycleDaysOff ?? this.cycleDaysOff,
      mealTiming: mealTiming ?? this.mealTiming,
      isPRN: isPRN ?? this.isPRN,
      weekendTimes:
          clearWeekendOverride ? null : (weekendTimes ?? this.weekendTimes),
      maxDailyDoses: maxDailyDoses ?? this.maxDailyDoses,
      minHoursBetweenDoses: minHoursBetweenDoses ?? this.minHoursBetweenDoses,
      titrationSteps: clearTitrationSteps
          ? null
          : (titrationSteps ?? this.titrationSteps),
    );
  }

  /// Create a simple once-daily schedule
  factory MedicineSchedule.onceDaily({
    required int hour,
    required int minute,
    DateTime? startDate,
    int? durationDays,
    MealTiming mealTiming = MealTiming.anytime,
  }) {
    return MedicineSchedule(
      frequencyType: FrequencyType.onceDaily,
      times: [ScheduledTime(hour: hour, minute: minute, label: 'Daily')],
      startDate: startDate ?? DateTime.now(),
      durationDays: durationDays,
      mealTiming: mealTiming,
    );
  }

  /// Create a twice-daily schedule
  factory MedicineSchedule.twiceDaily({
    int morningHour = 8,
    int eveningHour = 20,
    DateTime? startDate,
    int? durationDays,
    MealTiming mealTiming = MealTiming.anytime,
  }) {
    return MedicineSchedule(
      frequencyType: FrequencyType.twiceDaily,
      times: [
        ScheduledTime(hour: morningHour, minute: 0, label: 'Morning'),
        ScheduledTime(hour: eveningHour, minute: 0, label: 'Evening'),
      ],
      startDate: startDate ?? DateTime.now(),
      durationDays: durationDays,
      mealTiming: mealTiming,
    );
  }

  /// Create an as-needed (PRN) schedule
  factory MedicineSchedule.asNeeded({
    int? maxDailyDoses,
    int? minHoursBetweenDoses,
  }) {
    return MedicineSchedule(
      frequencyType: FrequencyType.asNeeded,
      times: [],
      isPRN: true,
      maxDailyDoses: maxDailyDoses,
      minHoursBetweenDoses: minHoursBetweenDoses,
    );
  }
}
