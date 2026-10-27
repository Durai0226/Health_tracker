import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/clean_storage_service.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../sleep/services/sleep_service.dart';
import '../models/diary_entry.dart';
import 'diary_prompts.dart';

/// Reads what the app knows about today and hands it to [DiaryPrompts].
///
/// Each source is best-effort and independent: one that is empty, or fails,
/// simply adds no signal.
class DiaryPromptSignals {
  const DiaryPromptSignals._();

  static const _dismissedKey = 'diary_prompt_dismissed_on';

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Put today's prompt away. It is back tomorrow, if there is one.
  static Future<void> dismissToday() => CleanStorageService.setAppPreference(
      _dismissedKey, _dayKey(clock.now()));

  static bool get dismissedToday =>
      CleanStorageService.getAppPreference(_dismissedKey, '') ==
      _dayKey(clock.now());

  /// The prompt for today, or null: none worth offering, one already written
  /// today, or one the person put away.
  static Future<DiaryPrompt?> forToday(List<DiaryEntry> entries) async {
    if (dismissedToday) return null;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final wroteToday = entries.any((e) =>
        e.entryAt.year == today.year &&
        e.entryAt.month == today.month &&
        e.entryAt.day == today.day);

    int? sleep;
    try {
      sleep = SleepService.getForDate(today)?.asleepMinutes;
    } catch (_) {}

    var missed = 0;
    try {
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      missed =
          (await MedicineCleanStorageService.getDailySummaryAsync(yesterday))
              .missed;
    } catch (e) {
      debugPrint('⚠️ Diary prompt: dose summary failed: $e');
    }

    int? mood;
    try {
      final since = now.subtract(const Duration(hours: 24));
      final recent = [
        for (final m in await VitalsStorageService.getAllMood())
          if (!m.takenAt.isBefore(since) && !m.takenAt.isAfter(now)) m,
      ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
      if (recent.isNotEmpty) mood = recent.first.moodIndex;
    } catch (_) {}

    return DiaryPrompts.pick(
      wroteToday: wroteToday,
      sleepMinutes: sleep,
      missedDosesYesterday: missed,
      recentMoodIndex: mood,
    );
  }
}
