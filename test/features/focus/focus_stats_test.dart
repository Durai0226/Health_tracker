import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/focus/models/detailed_stats.dart';
import 'package:tablet_remainder/features/focus/models/focus_achievement.dart';

/// QA — Focus pure model logic (F7). Stats aggregation + achievement progress.
/// Well-guarded (no bugs found); these lock the behavior in. The Focus
/// dashboard itself needs ~9 services inited to render, so it's out of scope
/// for the headless sim harness this pass (documented).
void main() {
  DailyFocusStats stats({int minutes = 0, int sessions = 0, int completed = 0}) =>
      DailyFocusStats(
        date: DateTime(2026, 1, 1),
        totalMinutes: minutes,
        sessionsCount: sessions,
        completedSessions: completed,
      );

  group('DailyFocusStats', () {
    test('completionRate = completed / sessions', () {
      expect(stats(sessions: 10, completed: 8).completionRate, 0.8);
    });
    test('completionRate guards divide-by-zero (0 sessions)', () {
      expect(stats(sessions: 0, completed: 0).completionRate, 0);
    });
    test('totalHours floors minutes', () {
      expect(stats(minutes: 150).totalHours, 2);
    });
    test('hasData false when empty', () {
      expect(stats().hasData, isFalse);
    });
    test('hasData true with minutes', () {
      expect(stats(minutes: 25).hasData, isTrue);
    });
  });

  group('FocusAchievement.progressPercent', () {
    final type = AchievementType.values.first;
    test('unlocked → 1.0 regardless of progress', () {
      expect(FocusAchievement(type: type, isUnlocked: true, currentProgress: 0).progressPercent, 1.0);
    });
    test('zero progress → 0.0', () {
      expect(FocusAchievement(type: type, currentProgress: 0).progressPercent, 0.0);
    });
    test('over-progress clamps to 1.0', () {
      expect(FocusAchievement(type: type, currentProgress: 999999).progressPercent, 1.0);
    });
  });
}
