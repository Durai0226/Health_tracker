import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/widgets.dart' show IconData;

/// What a person can say they want to keep on top of, on the welcome screen.
///
/// Up to [maxPicks], and none is fine. It decides only what comes FIRST on Today
/// and which tab the app opens on: nothing is hidden, nothing is switched on, and
/// no goal figure is set. (The welcome screen used to save a water goal nobody had
/// chosen as an explicit override; see `WelcomeScreen._saveSetup`. This writes no
/// numbers at all.) Everything it does is undone in Customize Today.
enum WelcomeGoal {
  medicines('Medicines', Symbols.medication_rounded, 'medicine'),
  water('Water', Symbols.water_drop_rounded, 'water'),
  steps('Steps', Symbols.directions_walk_rounded, 'weekly'),
  sleep('Sleep', Symbols.bedtime_rounded, 'weekly'),
  focus('Focus', Symbols.timer_rounded, 'activity'),
  reminders('Reminders', Symbols.notifications_rounded, 'activity');

  const WelcomeGoal(this.label, this.icon, this.todayCard);

  final String label;
  final IconData icon;

  /// The Today card that carries it (see `todayCardIds`).
  final String todayCard;

  /// How many may be picked: a short list stays a list of priorities.
  static const int maxPicks = 3;

  static const String prefKey = 'onboardingGoals';
  static const String todayOrderKey = 'today_card_order';

  /// [picks] after one is tapped: taken off if it was there, put on the end if
  /// not, and refused (unchanged) when that would make more than [maxPicks].
  static List<WelcomeGoal> toggled(List<WelcomeGoal> picks, WelcomeGoal goal) {
    if (picks.contains(goal)) return [for (final p in picks) if (p != goal) p];
    if (picks.length >= maxPicks) return picks;
    return [...picks, goal];
  }

  /// The Today cards to put first, in the order picked, each once. Cards nobody
  /// asked for follow in their usual order (`TodayOrder.normalise` puts them back).
  static List<String> todayOrderFor(List<WelcomeGoal> picks) {
    final out = <String>[];
    for (final p in picks) {
      if (!out.contains(p.todayCard)) out.add(p.todayCard);
    }
    return out;
  }

  /// The tab to open on. Meds, as ever, for someone who said nothing or said
  /// medicines (its empty state leads to "Add your first medicine"); Today for
  /// someone who asked for other things, whose first screen should not be about a
  /// medicine they never mentioned.
  static int landingTab(List<WelcomeGoal> picks) =>
      picks.isEmpty || picks.contains(WelcomeGoal.medicines) ? 1 : 0;

  /// What is stored for [picks].
  static List<String> encode(List<WelcomeGoal> picks) =>
      [for (final p in picks) p.name];

  /// The goals [stored] names, in order; anything else is dropped.
  static List<WelcomeGoal> decode(Object? stored) {
    if (stored is! List) return const [];
    final out = <WelcomeGoal>[];
    for (final s in stored) {
      for (final g in WelcomeGoal.values) {
        if (g.name == s && !out.contains(g)) out.add(g);
      }
    }
    return out.take(maxPicks).toList();
  }
}
