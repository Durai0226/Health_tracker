/// Neutral result types for the AI facade — deliberately free of feature-layer
/// model imports so `lib/core/ai/` stays decoupled. Feature screens map these
/// simple string/enum-string fields onto their own enums.

class ParsedReminder {
  final String title;
  final DateTime? time;

  /// One of: none | daily | weekly | weekdays | weekends | custom
  final String repeat;

  /// One of: low | medium | high
  final String priority;

  /// A best-effort category name hint (e.g. 'Health', 'Work') or null.
  final String? categoryHint;

  /// When [repeat] == 'custom', the specific weekdays (1=Mon … 7=Sun) the user
  /// named (e.g. "every monday and thursday" → [1, 4]). Null otherwise.
  final List<int>? customDays;

  /// Parsed session/event length in minutes ("for 30 minutes", "25 min focus"),
  /// or null when no duration was stated. Feeds the Focus feature's session
  /// length; harmless for plain reminders.
  final int? durationMinutes;

  /// An RFC 5545 `RRULE:` string when the phrase describes a repeat the
  /// six-value [repeat] vocabulary cannot express — "every other Tuesday",
  /// "every 3 days", "monthly", or any of those with an end condition.
  ///
  /// A string rather than a typed rule so this file stays free of feature and
  /// package imports, exactly like every other field here.
  final String? recurrenceRule;

  /// An explicit end date from "until 5 July".
  final DateTime? endsAt;

  /// An explicit occurrence count from "5 times".
  final int? occurrenceLimit;

  /// A heads-up from "30 min before" / "an hour before": how much earlier than
  /// the event the reminder fires. When set, [time] is already that much
  /// earlier and [eventTime] is the event itself.
  final int? leadMinutes;

  /// The event the heads-up is for, when [leadMinutes] is set.
  final DateTime? eventTime;

  /// "until done" / "keep reminding me": keep following up until it is acted on.
  final bool untilDone;

  const ParsedReminder({
    required this.title,
    this.time,
    this.repeat = 'none',
    this.priority = 'medium',
    this.categoryHint,
    this.customDays,
    this.durationMinutes,
    this.recurrenceRule,
    this.endsAt,
    this.occurrenceLimit,
    this.leadMinutes,
    this.eventTime,
    this.untilDone = false,
  });

  ParsedReminder copyWith({
    DateTime? time,
    int? leadMinutes,
    DateTime? eventTime,
    bool? untilDone,
  }) =>
      ParsedReminder(
        title: title,
        time: time ?? this.time,
        repeat: repeat,
        priority: priority,
        categoryHint: categoryHint,
        customDays: customDays,
        durationMinutes: durationMinutes,
        recurrenceRule: recurrenceRule,
        endsAt: endsAt,
        occurrenceLimit: occurrenceLimit,
        leadMinutes: leadMinutes ?? this.leadMinutes,
        eventTime: eventTime ?? this.eventTime,
        untilDone: untilDone ?? this.untilDone,
      );
}


/// A natural-language logging command parsed from free text ("log 150/95",
/// "drank 500ml", "took my pill"). [data] holds the extracted fields.
enum CommandKind {
  logBloodPressure,
  logGlucose,
  logWater,
  takeMedicine,
  logSteps,
  logSleep,
  logPeriod,
  none,
}

class ParsedCommand {
  final CommandKind kind;
  final Map<String, dynamic> data;
  const ParsedCommand(this.kind, [this.data = const {}]);

  bool get isNone => kind == CommandKind.none;
}
