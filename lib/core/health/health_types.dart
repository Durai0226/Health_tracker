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

  const ParsedReminder({
    required this.title,
    this.time,
    this.repeat = 'none',
    this.priority = 'medium',
    this.categoryHint,
    this.customDays,
    this.durationMinutes,
  });
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
