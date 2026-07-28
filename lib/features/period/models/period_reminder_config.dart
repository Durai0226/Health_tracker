/// User preferences for Period reminders.
///
/// Persisted as JSON in `CleanStorageService` app preferences under the key
/// `periodReminderConfig` (no Drift table / schema change), mirroring
/// [WaterReminderConfig]. Every field is JSON-safe so it round-trips untouched.
///
/// All reminders are opt-in (default off). Copy is deliberately discreet — a
/// period notification is sensitive, so it reads gently and never on the pill.
class PeriodReminderConfig {
  /// "Your cycle may start soon" — a heads-up before the predicted start.
  final bool periodSoonEnabled;

  /// Lead time for [periodSoonEnabled], in days before the predicted start.
  final int daysBefore;

  /// A gentle PMS-window note a few days before the predicted start.
  final bool pmsEnabled;

  /// Lead time for [pmsEnabled], in days.
  final int pmsDaysBefore;

  /// "Time to log?" on the predicted start day (logging sharpens predictions).
  final bool logReminderEnabled;

  /// Fertile-window heads-up — only meaningful in Trying-to-Conceive mode, and
  /// always framed as an estimate (never for contraception).
  final bool fertileEnabled;

  /// Time-of-day all period reminders fire at (default 09:00).
  final int reminderHour;
  final int reminderMinute;

  const PeriodReminderConfig({
    this.periodSoonEnabled = false,
    this.daysBefore = 2,
    this.pmsEnabled = false,
    this.pmsDaysBefore = 3,
    this.logReminderEnabled = false,
    this.fertileEnabled = false,
    this.reminderHour = 9,
    this.reminderMinute = 0,
  });

  static const PeriodReminderConfig defaults = PeriodReminderConfig();

  /// True when at least one reminder type is on (used to short-circuit
  /// scheduling / drive the hub's on-off badge).
  bool get anyEnabled =>
      periodSoonEnabled || pmsEnabled || logReminderEnabled || fertileEnabled;

  PeriodReminderConfig copyWith({
    bool? periodSoonEnabled,
    int? daysBefore,
    bool? pmsEnabled,
    int? pmsDaysBefore,
    bool? logReminderEnabled,
    bool? fertileEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return PeriodReminderConfig(
      periodSoonEnabled: periodSoonEnabled ?? this.periodSoonEnabled,
      daysBefore: daysBefore ?? this.daysBefore,
      pmsEnabled: pmsEnabled ?? this.pmsEnabled,
      pmsDaysBefore: pmsDaysBefore ?? this.pmsDaysBefore,
      logReminderEnabled: logReminderEnabled ?? this.logReminderEnabled,
      fertileEnabled: fertileEnabled ?? this.fertileEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'periodSoonEnabled': periodSoonEnabled,
        'daysBefore': daysBefore,
        'pmsEnabled': pmsEnabled,
        'pmsDaysBefore': pmsDaysBefore,
        'logReminderEnabled': logReminderEnabled,
        'fertileEnabled': fertileEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };

  factory PeriodReminderConfig.fromJson(Map<String, dynamic> json) {
    return PeriodReminderConfig(
      periodSoonEnabled: json['periodSoonEnabled'] as bool? ?? false,
      daysBefore: (json['daysBefore'] as num?)?.toInt() ?? 2,
      pmsEnabled: json['pmsEnabled'] as bool? ?? false,
      pmsDaysBefore: (json['pmsDaysBefore'] as num?)?.toInt() ?? 3,
      logReminderEnabled: json['logReminderEnabled'] as bool? ?? false,
      fertileEnabled: json['fertileEnabled'] as bool? ?? false,
      reminderHour: (json['reminderHour'] as num?)?.toInt() ?? 9,
      reminderMinute: (json['reminderMinute'] as num?)?.toInt() ?? 0,
    );
  }
}
