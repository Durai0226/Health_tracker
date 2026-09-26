import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/hydration_goal.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';

/// A content analysis of 51 water-tracking apps found exactly ONE that
/// mentioned kidney stone disease and ZERO that mentioned CKD. The category is
/// pretty gauges with no clinical content, and the leader explicitly disclaims
/// being a medical app. These are the conditions with real published support
/// for drinking more — and the tests hold them to the published numbers.
void main() {
  HydrationGoal goal(Set<HydrationCondition> c) =>
      HydrationGoalCalculator.compute(
          isMale: true, ageYears: 30, conditions: c);

  group('floors versus additions', () {
    test('kidney stones lift the total to the AUA-implied 3 L floor', () {
      final g = goal({HydrationCondition.kidneyStones});
      expect(g.totalMl, greaterThanOrEqualTo(3000));
      expect(g.conditionMl, greaterThan(0));
    });

    test('a floor lifts, it does not stack on top', () {
      // The guideline figure IS a total — "3 L a day", not "3 L more than you
      // already drink". Adding it would push a moderately active person past
      // 6 L, which is its own hazard.
      final plain = goal(const {});
      final stones = goal({HydrationCondition.kidneyStones});
      expect(stones.totalMl, lessThan(plain.totalMl + 3000));
      expect(stones.totalMl, greaterThanOrEqualTo(3000));
    });

    test('recurrent UTI adds the trial dose on top', () {
      // Hooton 2018 gave 1.5 L IN ADDITION to usual intake, and enrolled
      // low-baseline drinkers — so this one really is additive.
      final plain = goal(const {});
      final uti = goal({HydrationCondition.recurrentUti});
      expect(uti.totalMl - plain.totalMl, 1500);
    });

    test('a floor and an addition combine without double counting', () {
      final both = goal(
          {HydrationCondition.kidneyStones, HydrationCondition.recurrentUti});
      // Addition applies, then the floor only bites if still below it.
      expect(both.totalMl, greaterThan(goal({HydrationCondition.kidneyStones}).totalMl));
      expect(both.totalMl, lessThanOrEqualTo(HydrationGoalCalculator.maxGoalMl));
    });

    test('the highest floor wins when two are set', () {
      final g = goal({HydrationCondition.gout, HydrationCondition.kidneyStones});
      expect(g.totalMl, greaterThanOrEqualTo(3000),
          reason: 'stones (3000) must beat gout (2500), not average with it');
    });

    test('conditions never break the ceiling', () {
      final g = HydrationGoalCalculator.compute(
        isMale: true,
        ageYears: 30,
        activeKcal: 4000,
        ambientC: 40,
        conditions: HydrationCondition.values.toSet(),
      );
      expect(g.totalMl, HydrationGoalCalculator.maxGoalMl);
    });
  });

  group('honesty', () {
    test('every condition explains itself with a citation', () {
      for (final c in HydrationCondition.values) {
        final rule = hydrationConditionRules[c];
        expect(rule, isNotNull, reason: '${c.name} has no rule');
        expect(rule!.basis, isNotEmpty);
        expect(rule.label, isNotEmpty);
        expect(rule.floorMl > 0 || rule.addMl > 0, isTrue,
            reason: '${c.name} claims to change the goal but changes nothing');
      }
    });

    test('gout is labelled as the weak evidence it is', () {
      // Observational case-crossover, self-reported, no trial. Presenting that
      // with the same confidence as Hooton's RCT would be dishonest.
      expect(hydrationConditionRules[HydrationCondition.gout]!.caveat,
          isNotEmpty);
      expect(hydrationConditionRules[HydrationCondition.recurrentUti]!.caveat,
          isEmpty,
          reason: 'a randomised trial needs no hedge');
    });

    test('the basis text reaches the goal breakdown', () {
      final g = goal({HydrationCondition.recurrentUti});
      expect(g.basis.join(' '), contains('Hooton'));
    });
  });

  group('a fluid ceiling always wins', () {
    test('a restriction overrides a condition that would raise the goal', () {
      final p = HydrationProfile(
        id: 'p',
        weightKg: 70,
        conditions: {HydrationCondition.kidneyStones},
        fluidCeilingMl: 1500,
      );
      expect(p.effectiveGoalMl, 1500,
          reason: 'stones plus dialysis is a limit, not a 3 L target');
      expect(p.isRestricted, isTrue);
    });
  });

  group('persistence', () {
    test('conditions round-trip through JSON', () {
      final p = HydrationProfile(
        id: 'p',
        weightKg: 70,
        conditions: {HydrationCondition.gout, HydrationCondition.recurrentUti},
      );
      final back = HydrationProfile.fromJson(p.toJson());
      expect(back.conditions, p.conditions);
    });

    test('stored by NAME, so reordering the enum cannot reassign anyone', () {
      // An index-based encoding means inserting a value silently turns every
      // stored "gout" into something else. For a clinical setting that is not
      // an acceptable failure mode.
      final json = HydrationProfile(
        id: 'p',
        conditions: {HydrationCondition.gout},
      ).toJson();
      expect(json['conditions'], ['gout']);
    });

    test('an unknown condition name is dropped, not thrown', () {
      expect(parseHydrationConditions(['gout', 'not_a_condition']),
          {HydrationCondition.gout});
      expect(parseHydrationConditions(null), isEmpty);
      expect(parseHydrationConditions('garbage'), isEmpty);
    });
  });
}
