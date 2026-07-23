import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'milestone.dart';

/// Evaluates and persists calm, permanent milestones for Steps & Sleep.
///
/// A milestone, once earned, stays earned forever (stored locally as a small
/// id→date map) even if the underlying data later scrolls out of the in-memory
/// window. Strictly on-device, no points, no leaderboards, never pushed — the
/// only surfacing is an opt-in shelf plus a single quiet in-app toast on unlock.
class MilestonesService {
  MilestonesService._();

  static const _kEarned = 'milestones.earned'; // JSON string: { id: isoDate }

  static Map<String, String> _earnedMap() {
    final raw = CleanStorageService.getAppPreference(_kEarned, '');
    if (raw is! String || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _saveEarnedMap(Map<String, String> m) =>
      CleanStorageService.setAppPreference(_kEarned, jsonEncode(m));

  /// The catalog, with each milestone's `earned` flag set to whether it is
  /// satisfied *right now* (before merging with the persisted record).
  static List<Milestone> _catalogNow() {
    // Steps metrics.
    final best = StepService.getBestDay()?.steps ?? 0;
    final streak = StepService.getStreakResult();

    // Sleep metrics.
    final loggedNights = SleepService.getAllSessions().length;
    final bestNight = SleepService.getBestNight()?.sleepScore ?? 0;
    final regular = SleepService.regularitySampleSize() >= 5 &&
        SleepService.regularityIndex() >= 0.8;

    return [
      _def('steps.first_goal', 'First goal reached',
          'You hit your daily step goal.', Symbols.flag_rounded, 'steps',
          streak.longest >= 1),
      _def('steps.10k', '10,000 steps',
          'You walked 10,000 steps in a day.', Symbols.footprint_rounded,
          'steps', best >= 10000),
      _def('steps.15k', '15,000 steps', 'A big day — 15,000 steps.',
          Symbols.footprint_rounded, 'steps', best >= 15000),
      _def('steps.rhythm7', '7-day rhythm',
          'A week of reaching your goal.', Symbols.calendar_view_week_rounded,
          'steps', streak.longest >= 7),
      _def('steps.rhythm30', '30-day rhythm',
          'A month of reaching your goal.', Symbols.calendar_month_rounded,
          'steps', streak.longest >= 30),
      _def('sleep.first', 'First night logged',
          'You started tracking your sleep.', Symbols.bedtime_rounded, 'sleep',
          loggedNights >= 1),
      _def('sleep.week', 'A week of nights', 'Seven nights logged.',
          Symbols.calendar_view_week_rounded, 'sleep', loggedNights >= 7),
      _def('sleep.rested', 'Well rested', 'A night scored 85 or higher.',
          Symbols.self_improvement_rounded, 'sleep', bestNight >= 85),
      _def('sleep.regular', 'Steady rhythm',
          'Your bedtimes were very regular.', Symbols.schedule_rounded, 'sleep',
          regular),
      _def('sleep.nights30', '30 nights logged',
          'A month of sleep in your log.', Symbols.calendar_month_rounded,
          'sleep', loggedNights >= 30),
    ];
  }

  static Milestone _def(String id, String title, String description,
          IconData icon, String feature, bool nowEarned) =>
      Milestone(
        id: id,
        title: title,
        description: description,
        icon: icon,
        feature: feature,
        earned: nowEarned, // temporarily carries "earned right now"
      );

  /// Evaluate all milestones, persist any freshly-earned ones, and report both
  /// the full (earned-first) list and just those newly earned this pass (for a
  /// single quiet unlock toast).
  static Future<({List<Milestone> all, List<Milestone> newlyEarned})>
      sync() async {
    final earned = _earnedMap();
    final now = DateTime.now();
    final all = <Milestone>[];
    final newly = <Milestone>[];
    var changed = false;

    for (final def in _catalogNow()) {
      final wasEarned = earned.containsKey(def.id);
      final freshlyEarned = def.earned && !wasEarned;
      if (freshlyEarned) {
        earned[def.id] = now.toIso8601String();
        changed = true;
      }
      final isEarned = wasEarned || def.earned;
      final m = def.copyWith(
        earned: isEarned,
        earnedAt: isEarned
            ? DateTime.tryParse(earned[def.id] ?? now.toIso8601String())
            : null,
      );
      all.add(m);
      if (freshlyEarned) newly.add(m);
    }

    if (changed) await _saveEarnedMap(earned);

    all.sort((a, b) {
      if (a.earned != b.earned) return a.earned ? -1 : 1;
      return 0;
    });
    return (all: all, newlyEarned: newly);
  }
}
