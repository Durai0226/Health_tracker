/// Nothing may tell a fluid-restricted user to drink more.
///
/// Under a prescribed ceiling (dialysis, heart failure) `HydrationProfile`
/// returns `fluidCeilingMl` as the effective goal, so every "progress toward
/// the goal" calculation in the app reads a LIMIT as a TARGET. "Behind" then
/// means "safely under the amount your clinician set", and encouraging the user
/// to close that gap is the opposite of their clinical advice.
///
/// [CoachText.hydrationTip] has refused to do this for a while, and says why in
/// as many words: "Under a prescribed fluid ceiling every line below is wrong —
/// they all encourage drinking more ... No streak framing either: there is
/// nothing to congratulate about approaching a limit."
///
/// Two surfaces never got the same guard, and both of them render on the HOME
/// screen above the fold:
///
///  * `CoachText.dailyBriefing` -> `_crossSignal`, the briefing strip;
///  * `InsightEngine.water`, which feeds `ProactiveNudge`'s banner.
///
/// Both had the flag available at the call site and simply never passed it —
/// `InsightService.gatherAll` hands `WaterService.isFluidRestricted` to
/// `CycleHydrationInsight.forPhase` 120 lines below the `water(...)` call that
/// did not get it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/coach_text.dart';
import 'package:tablet_remainder/core/health/insight_engine.dart';

void main() {
  const coach = CoachText();

  /// Anything that reads as "drink more".
  void expectNoUrgingToDrink(String text, {required String where}) {
    for (final phrase in const [
      'a glass',
      'glass of water',
      'catches you up',
      'catch up',
      'behind',
      'hydration gap',
      'keep sipping',
      'stay ahead',
      'drink up',
    ]) {
      expect(text.toLowerCase(), isNot(contains(phrase)),
          reason: '$where urged a fluid-restricted user to drink: "$text"');
    }
  }

  group('the Home briefing strip', () {
    /// A dialysis user on a 1500ml ceiling who has had 500ml by 14:00:
    /// waterPct = 33, which every un-guarded branch calls "behind".
    String briefing({
      int waterPct = 33,
      int medsOutstanding = 0,
      int medsTotal = 2,
      int hour = 14,
      required bool restricted,
    }) =>
        coach.dailyBriefing(
          medsOutstanding: medsOutstanding,
          medsTotal: medsTotal,
          waterPct: waterPct,
          focusMinutes: 30,
          remindersLeft: 0,
          hour: hour,
          isRestricted: restricted,
        );

    test('does not tell a restricted user their water is behind', () {
      expectNoUrgingToDrink(briefing(restricted: true),
          where: 'dailyBriefing');
    });

    test('does not pair a dose with a glass of water either', () {
      // The cross-signal branch: water "behind" AND a dose outstanding.
      expectNoUrgingToDrink(briefing(restricted: true, medsOutstanding: 1),
          where: 'dailyBriefing cross-signal');
    });

    test('at every percentage below the ceiling', () {
      for (final pct in const [0, 10, 33, 50, 59]) {
        expectNoUrgingToDrink(briefing(waterPct: pct, restricted: true),
            where: 'dailyBriefing at $pct%');
      }
    });

    test('premise: an unrestricted user at the same numbers IS urged', () {
      // Without this the assertions above would pass on a branch that never
      // fires for anyone.
      final s = briefing(restricted: false).toLowerCase();
      expect(s, contains('water'),
          reason: 'the un-guarded path must still produce the water nudge, '
              'or these tests are not exercising the branch they claim to');
    });
  });

  group('the proactive nudge', () {
    test('no "behind on water" banner under a ceiling', () {
      final i = InsightEngine.water(
        intakeMl: 300,
        goalMl: 1500,
        behind: true,
        deficitMl: 450,
        isRestricted: true,
      );
      expect(i, isNull,
          reason: 'this is the banner ProactiveNudge renders on Home');
    });

    test('reaching the ceiling is not congratulated', () {
      final i = InsightEngine.water(
        intakeMl: 1500,
        goalMl: 1500,
        isRestricted: true,
      );
      expect(i, isNull,
          reason: '"You hit your 1500ml goal today — great consistency" for '
              'crossing a clinical limit');
    });

    test('nor is a streak of reaching it', () {
      final i = InsightEngine.water(
        intakeMl: 1400,
        goalMl: 1500,
        streakDays: 5,
        isRestricted: true,
      );
      expect(i, isNull,
          reason: 'there is nothing to congratulate about approaching a limit');
    });

    test('premise: each of those fires for an unrestricted user', () {
      expect(
          InsightEngine.water(
              intakeMl: 300, goalMl: 1500, behind: true, deficitMl: 450)?.id,
          'water_behind');
      expect(InsightEngine.water(intakeMl: 1500, goalMl: 1500)?.id,
          'water_goal');
      expect(InsightEngine.water(intakeMl: 1400, goalMl: 1500, streakDays: 5)?.id,
          'water_streak');
    });
  });
}
