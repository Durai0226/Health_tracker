import '../../../core/utils/enum_json.dart';
import 'breathing_exercise.dart';

/// One breathing exercise that was finished: which pattern, how many cycles, when.
///
/// Only finished ones: an exercise closed early is not a practice, and writing one
/// would credit time the person did not spend (the same rule the mindful-minutes
/// write follows).
class BreathingRecord {
  const BreathingRecord({
    required this.pattern,
    required this.cycles,
    required this.completedAt,
  });

  final BreathingPattern pattern;
  final int cycles;
  final DateTime completedAt;

  /// How long it took, from the pattern's own timing.
  int get seconds => pattern.totalCycleDuration * cycles;

  Map<String, dynamic> toJson() => {
        'pattern': pattern.index,
        'cycles': cycles,
        'at': completedAt.toIso8601String(),
      };

  /// Null for an entry that cannot be read — a pattern this build does not have,
  /// or a date that does not parse — so one bad record costs one record, not the
  /// whole history.
  static BreathingRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final pattern = EnumJson.atOrNull(BreathingPattern.values, raw['pattern']);
    final at = DateTime.tryParse(raw['at']?.toString() ?? '');
    final cycles = raw['cycles'];
    if (pattern == null || at == null || cycles is! int || cycles < 1) return null;
    return BreathingRecord(pattern: pattern, cycles: cycles, completedAt: at);
  }
}
