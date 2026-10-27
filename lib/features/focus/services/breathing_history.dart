import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/clean_storage_service.dart';
import '../../../core/utils/calendar_day.dart';
import '../models/breathing_exercise.dart';
import '../models/breathing_record.dart';

/// What the exercises add up to.
class BreathingSummary {
  const BreathingSummary({
    required this.sessions,
    required this.minutes,
    required this.thisWeek,
    this.mostUsed,
  });

  final int sessions;

  /// Whole minutes breathed in all, rounded to the nearest.
  final int minutes;

  /// Sessions since Monday.
  final int thisWeek;

  /// The pattern done most often, or null with no sessions. A tie goes to the one
  /// done most recently.
  final BreathingPattern? mostUsed;

  static const empty = BreathingSummary(sessions: 0, minutes: 0, thisWeek: 0);
}

/// The record of finished breathing exercises.
///
/// Until now the only trace was a counter ("complete 50 exercises") — so what was
/// practised, when and how often could not be looked back on.
class BreathingHistory {
  const BreathingHistory._();

  static const _key = 'focusBreathingLog';

  /// The newest this many are kept. Each record is a few bytes; this is a month of
  /// daily practice many times over, and keeps the preference small.
  static const int cap = 300;

  /// Every record, newest first.
  static List<BreathingRecord> all() {
    final raw = CleanStorageService.getAppPreferences()[_key];
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (BreathingRecord.fromJson(r) case final rec?) rec
    ]..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  /// Add a finished exercise.
  static Future<void> record(BreathingPattern pattern, int cycles,
      {DateTime? at}) async {
    if (cycles < 1) return;
    final next = [
      BreathingRecord(
          pattern: pattern, cycles: cycles, completedAt: at ?? clock.now()),
      ...all(),
    ].take(cap).toList();
    try {
      await CleanStorageService.setAppPreference(
          _key, [for (final r in next) r.toJson()]);
    } catch (e) {
      debugPrint('Breathing history write failed: $e');
    }
  }

  /// The totals for [records], with "this week" measured to [now].
  static BreathingSummary summarize(List<BreathingRecord> records, {DateTime? now}) {
    if (records.isEmpty) return BreathingSummary.empty;
    final monday = startOfWeek(now ?? clock.now());
    var seconds = 0;
    var week = 0;
    final counts = <BreathingPattern, int>{};
    final lastUsed = <BreathingPattern, DateTime>{};
    for (final r in records) {
      seconds += r.seconds;
      if (!r.completedAt.isBefore(monday)) week++;
      counts[r.pattern] = (counts[r.pattern] ?? 0) + 1;
      final seen = lastUsed[r.pattern];
      if (seen == null || r.completedAt.isAfter(seen)) lastUsed[r.pattern] = r.completedAt;
    }
    BreathingPattern? best;
    for (final p in counts.keys) {
      if (best == null ||
          counts[p]! > counts[best]! ||
          (counts[p] == counts[best] && lastUsed[p]!.isAfter(lastUsed[best]!))) {
        best = p;
      }
    }
    return BreathingSummary(
      sessions: records.length,
      minutes: (seconds / 60).round(),
      thisWeek: week,
      mostUsed: best,
    );
  }
}
