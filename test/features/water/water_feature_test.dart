import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/hydration_goal.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/models/water_container.dart';
import 'package:tablet_remainder/features/water/models/water_achievement.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';

void main() {
  group('BeverageType Tests', () {
    test('default beverages list is not empty', () {
      expect(BeverageType.defaultBeverages, isNotEmpty);
    });

    test('water has 100% hydration', () {
      final water = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');
      expect(water.hydrationPercent, 100);
      expect(water.hasCaffeine, false);
      expect(water.isAlcoholic, false);
    });

    test('coffee has caffeine', () {
      final coffee = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'coffee');
      expect(coffee.hasCaffeine, true);
      expect(coffee.caffeinePerMl, greaterThan(0));
    });

    test('beer is alcoholic with reduced hydration', () {
      final beer = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'beer');
      expect(beer.isAlcoholic, true);
      expect(beer.hydrationPercent, lessThan(100));
    });

    BeverageType byId(String id) =>
        BeverageType.defaultBeverages.firstWhere((b) => b.id == id);

    test('getEffectiveHydration calculates correctly', () {
      expect(byId('water').getEffectiveHydration(250), 250);

      // This used to assert `coffee < 250`, encoding the folk belief that
      // caffeine dehydrates. Killer 2014 (n=50, deuterium dilution) found
      // coffee and water indistinguishable — total body water 51.5 vs 51.4 kg,
      // 24 h urine 2409 vs 2428 mL — and Maughan's Beverage Hydration Index
      // puts coffee at 0.91, not significantly different from water. A cup of
      // coffee counts as a cup of fluid.
      expect(byId('coffee').getEffectiveHydration(250), 250);
      expect(byId('tea').getEffectiveHydration(200), 200);
      expect(byId('soda').getEffectiveHydration(330), 330);
    });

    test('no non-alcoholic drink is ever credited above its volume', () {
      // BHI ranks milk at 1.50, but it measures 2-hour retention after a bolus,
      // not contribution to a daily target. Crediting 300 ml for a 200 ml glass
      // would be its own falsehood.
      for (final b in BeverageType.defaultBeverages.where((b) => !b.isAlcoholic)) {
        expect(b.hydrationPercent, lessThanOrEqualTo(100),
            reason: '${b.id} claims more fluid than was drunk');
        expect(b.hydrationPercent, greaterThan(0), reason: b.id);
      }
    });

    group('alcohol is dose-derived, not category-assigned', () {
      test('the ABV formula matches Hobson & Maughan', () {
        // ~5 mL extra urine per gram of ethanol; 1 L of 4% ABV beer is
        // 1000 * 0.04 * 0.789 = 31.6 g, and produced +158 mL.
        expect(BeverageType.hydrationPercentForAbv(0), 100);
        expect(BeverageType.hydrationPercentForAbv(40), lessThan(0));
      });

      test('beer and wine are NET HYDRATING (regression)', () {
        // The old table said beer -20% and wine -30%, i.e. a 330 ml beer
        // *dehydrated* you by 66 ml. It does not: a beer is mostly water, and
        // BHI puts lager at 0.99.
        expect(byId('beer').getEffectiveHydration(330), greaterThan(0));
        expect(byId('wine').getEffectiveHydration(150), greaterThan(0));
      });

      test('spirits genuinely go negative', () {
        // 40% ethanol in a small volume is the one case where the drink costs
        // more water than it supplies.
        expect(byId('spirits').getEffectiveHydration(50), lessThan(0));
      });

      test('a stronger drink is always worse than a weaker one', () {
        expect(BeverageType.hydrationPercentForAbv(40),
            lessThan(BeverageType.hydrationPercentForAbv(12)));
        expect(BeverageType.hydrationPercentForAbv(12),
            lessThan(BeverageType.hydrationPercentForAbv(5)));
      });
    });

    test('beverage copyWith works correctly', () {
      final water = BeverageType.defaultBeverages.first;
      final modified = water.copyWith(name: 'Test Water', hydrationPercent: 95);
      
      expect(modified.name, 'Test Water');
      expect(modified.hydrationPercent, 95);
      expect(modified.id, water.id);
    });
  });

  group('WaterContainer Tests', () {
    test('default containers list is not empty', () {
      expect(WaterContainer.defaultContainers, isNotEmpty);
    });

    test('containers have valid capacities', () {
      for (final container in WaterContainer.defaultContainers) {
        expect(container.capacityMl, greaterThan(0));
        expect(container.name, isNotEmpty);
        expect(container.emoji, isNotEmpty);
      }
    });

    test('container copyWith works correctly', () {
      final container = WaterContainer.defaultContainers.first;
      final modified = container.copyWith(
        name: 'Custom Cup',
        capacityMl: 500,
      );
      
      expect(modified.name, 'Custom Cup');
      expect(modified.capacityMl, 500);
      expect(modified.id, container.id);
    });
  });

  group('EnhancedWaterLog Tests', () {
    test('creates log with correct values', () {
      final log = EnhancedWaterLog(
        id: 'test-log',
        time: DateTime.now(),
        amountMl: 250,
        effectiveHydrationMl: 200,
        beverageId: 'coffee',
        beverageName: 'Coffee',
        beverageEmoji: '☕',
        hydrationPercent: 80,
        caffeineAmount: 95,
        isAlcoholic: false,
      );

      expect(log.amountMl, 250);
      expect(log.effectiveHydrationMl, 200);
      expect(log.caffeineAmount, 95);
      expect(log.isAlcoholic, false);
    });

    test('log with note stores note correctly', () {
      final log = EnhancedWaterLog(
        id: 'test-log',
        time: DateTime.now(),
        amountMl: 250,
        effectiveHydrationMl: 250,
        beverageId: 'water',
        beverageName: 'Water',
        beverageEmoji: '💧',
        hydrationPercent: 100,
        note: 'After workout',
      );

      expect(log.note, 'After workout');
    });
  });

  group('DailyWaterData Tests', () {
    test('creates daily data with correct defaults', () {
      final data = DailyWaterData(
        id: 'test-day',
        date: DateTime.now(),
        dailyGoalMl: 2500,
      );

      expect(data.totalIntakeMl, 0);
      expect(data.effectiveHydrationMl, 0);
      expect(data.logs, isEmpty);
      expect(data.goalReached, false);
    });

    test('progress calculation is correct', () {
      final data = DailyWaterData(
        id: 'test-day',
        date: DateTime.now(),
        dailyGoalMl: 2500,
        effectiveHydrationMl: 1250,
      );

      expect(data.progress, 0.5);
    });

    test('drinksCount returns correct count', () {
      final logs = [
        EnhancedWaterLog(
          id: '1',
          time: DateTime.now(),
          amountMl: 250,
          effectiveHydrationMl: 250,
          beverageId: 'water',
          beverageName: 'Water',
          beverageEmoji: '💧',
          hydrationPercent: 100,
        ),
        EnhancedWaterLog(
          id: '2',
          time: DateTime.now(),
          amountMl: 200,
          effectiveHydrationMl: 160,
          beverageId: 'coffee',
          beverageName: 'Coffee',
          beverageEmoji: '☕',
          hydrationPercent: 80,
          caffeineAmount: 76,
        ),
      ];

      final data = DailyWaterData(
        id: 'test-day',
        date: DateTime.now(),
        dailyGoalMl: 2500,
        logs: logs,
      );

      expect(data.drinksCount, 2);
    });
  });

  group('HydrationProfile Tests', () {
    // These used to be `greaterThanOrEqualTo(2000)` / `lessThanOrEqualTo(5000)`
    // and a pair of "A > B" comparisons. A formula that doubled every goal, or
    // dropped a whole term, passed all three — the band is wider than the
    // answer. So each case below pins the EXACT millilitre figure, worked out
    // by hand from the constants HydrationGoalCalculator documents:
    //
    //   baseline = IOM/NASEM total-water AI x 0.80 beverage share
    //              (adult male 3.7 L -> 2960; adult female 2.7 L -> 2160;
    //               male 14-18y 3.3 L -> 2640; pregnancy 3.0 L -> 2400;
    //               lactation 3.8 L -> 3040; 1-3y 1.3 L -> 1040)
    //   kcal     = MET-hours x kg      (sedentary 1.5, light 3, moderate 6,
    //                                   active 9, very active 13; kg clamped
    //                                   to 25..250, defaulting to 70)
    //   activity = max(kcal - 250, 0) x k(T),  k(T) = 1.13 + 0.014(T - 18),
    //              clamped to 0.8..1.38
    //   climate  = (T - 22) x 160 when T > 22, else 0
    //   T        = the climate band's midpoint: cold 5, moderate 18, warm 27,
    //              hot 32, very hot 38
    //   total    = (baseline + activity + climate) clamped to 1200..5000
    //
    // The arithmetic for each case is written out beside it so the expectation
    // can be checked without running anything.

    test('male, 30, 70kg, moderate activity, moderate climate -> 3152 ml', () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 70,
        heightCm: 175,
        age: 30,
        activityLevel: ActivityLevel.moderate,
        climate: ClimateType.moderate,
      );

      // baseline 2960 (3.7 L x 0.8)
      // kcal 6 MET-h x 70 kg = 420; excess 420 - 250 = 170
      // k(18 C) = 1.13 exactly; activity = round(170 x 1.13) = 192
      // climate 0 (18 C is below the 22 C baseline)
      // total = 2960 + 192 = 3152
      expect(profile.calculatedGoalMl, 3152);

      final g = profile.goalBreakdown();
      expect(g.baselineMl, 2960);
      expect(g.activityMl, 192);
      expect(g.climateMl, 0);
      expect(g.conditionMl, 0);
      expect(g.baselineMl + g.activityMl + g.climateMl + g.conditionMl,
          g.totalMl,
          reason: 'the shown working must add up to the number on the dial');
    });

    test('female, 30, 60kg, sedentary, cold -> 2160 ml (baseline only)', () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 60,
        age: 30,
        isMale: false,
        activityLevel: ActivityLevel.sedentary,
        climate: ClimateType.cold,
      );

      // baseline 2160 (2.7 L x 0.8)
      // kcal 1.5 x 60 = 90, which is UNDER the 250 kcal the AI already assumes,
      // so the excess clamps to 0 and no sweat water is added.
      // climate 0 (5 C). total = 2160.
      expect(profile.calculatedGoalMl, 2160);
      expect(profile.goalBreakdown().activityMl, 0,
          reason: 'activity below the baseline 250 kcal must not add water — '
              'clamping the excess at zero is what stops the model paying '
              'twice for ordinary living');
    });

    test('female, 28, 55kg, light activity, warm -> 2800 ml (climate only)',
        () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 55,
        age: 28,
        isMale: false,
        activityLevel: ActivityLevel.light,
        climate: ClimateType.warm,
      );

      // baseline 2160; kcal 3 x 55 = 165 -> excess 0 -> activity 0
      // climate (27 - 22) x 128 = 640
      //
      // 128, not 160: the WHO span behind the heat term is TOTAL water, and it
      // is added to a baseline that already carries beverageShare (0.80). It
      // now carries the same share — see hydration_climate_share_test.dart.
      // total = 2160 + 640 = 2800
      expect(profile.calculatedGoalMl, 2800);
      expect(profile.goalBreakdown().climateMl, 640);
    });

    test('male, 16, 60kg, moderate, moderate -> 2764 ml (teen AI band)', () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 60,
        age: 16,
        activityLevel: ActivityLevel.moderate,
        climate: ClimateType.moderate,
      );

      // baseline 2640 (14-18y male 3.3 L x 0.8) — NOT the 2960 adult figure
      // kcal 6 x 60 = 360; excess 110; k(18) = 1.13; activity = round(124.3) = 124
      // total = 2640 + 124 = 2764
      expect(profile.calculatedGoalMl, 2764);
      expect(profile.goalBreakdown().baselineMl, 2640);
    });

    test('the adult baseline is flat with age — 70 matches 30', () {
      HydrationProfile at(int age) => HydrationProfile(
            id: 'age$age',
            weightKg: 70,
            age: age,
            activityLevel: ActivityLevel.moderate,
            climate: ClimateType.moderate,
          );

      // The formula this replaced cut the goal by 5% over 65. IOM's AI is 3.7 L
      // for men in EVERY adult band including >70y, so the two must be equal —
      // and equal to the same 3152 as the case above.
      expect(at(70).calculatedGoalMl, 3152);
      expect(at(70).calculatedGoalMl, at(30).calculatedGoalMl);
    });

    test('pregnancy and lactation replace the adult baseline', () {
      HydrationProfile f({bool pregnant = false, bool breastfeeding = false}) =>
          HydrationProfile(
            id: 'test',
            weightKg: 65,
            age: 30,
            isMale: false,
            isPregnant: pregnant,
            isBreastfeeding: breastfeeding,
            activityLevel: ActivityLevel.light,
            climate: ClimateType.moderate,
          );

      // kcal 3 MET-h x 65 kg = 195 -> excess 0 -> activity 0, climate 0.
      // Pregnancy 3.0 L x 0.8 = 2400; lactation 3.8 L x 0.8 = 3040. They
      // REPLACE the 2160 adult-female row rather than adding a bonus to it.
      expect(f(pregnant: true).calculatedGoalMl, 2400);
      expect(f(breastfeeding: true).calculatedGoalMl, 3040);
      expect(f().calculatedGoalMl, 2160);
    });

    test('a very small profile is floored at 1200 ml, never below', () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 12,
        age: 2,
        activityLevel: ActivityLevel.sedentary,
        climate: ClimateType.moderate,
      );

      // baseline 1040 (1-3y 1.3 L x 0.8); activity 0; climate 0 -> 1040,
      // which the minGoalMl floor lifts to 1200. Below that a "goal" would be
      // a restriction, which is only ever set through the clinical path.
      expect(profile.calculatedGoalMl, 1200);
    });

    test('an extreme profile is capped at 5000 ml, never above', () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 90,
        age: 45,
        activityLevel: ActivityLevel.veryActive,
        climate: ClimateType.hot,
      );

      // baseline 2960; kcal 13 x 90 = 1170; excess 920
      // k(32 C) = 1.13 + 0.014 x 14 = 1.326; activity = round(1219.92) = 1220
      // climate (32 - 22) x 160 = 1600
      // raw 2960 + 1220 + 1600 = 5780, capped to maxGoalMl 5000.
      expect(profile.calculatedGoalMl, 5000);
    });

    test('high activity increases water goal', () {
      final sedentary = HydrationProfile(
        id: 'test1',
        weightKg: 70,
        activityLevel: ActivityLevel.sedentary,
      );

      final active = HydrationProfile(
        id: 'test2',
        weightKg: 70,
        activityLevel: ActivityLevel.veryActive,
      );

      // sedentary: kcal 1.5 x 70 = 105 -> excess 0 -> 2960 flat.
      // very active: kcal 13 x 70 = 910; excess 660; k(18) = 1.13;
      //              activity = round(745.8) = 746 -> 3706.
      expect(sedentary.calculatedGoalMl, 2960);
      expect(active.calculatedGoalMl, 3706);
      expect(active.calculatedGoalMl, greaterThan(sedentary.calculatedGoalMl));
    });

    test('hot climate increases water goal', () {
      final temperate = HydrationProfile(
        id: 'test1',
        weightKg: 70,
        climate: ClimateType.moderate,
      );

      final hot = HydrationProfile(
        id: 'test2',
        weightKg: 70,
        climate: ClimateType.hot,
      );

      // Both are the default moderate activity, so only the climate differs.
      // temperate: 2960 + 192 = 3152 (as above).
      // hot: excess 170 x k(32) = 1.326 -> 225, plus (32 - 22) x 128 = 1280
      //      -> 2960 + 225 + 1280 = 4465.
      expect(temperate.calculatedGoalMl, 3152);
      expect(hot.calculatedGoalMl, 4465);
      // This assertion worked. It was 1633 against a 160 ml/degree coefficient,
      // with a comment saying it existed so "a future re-tune of the
      // 160 ml/degree coefficient gets noticed instead of shipping silently" —
      // and it is what caught the W-07 re-tune to 128. The heat term is derived
      // from the WHO TOTAL-water span but added to a baseline that already
      // carries beverageShare (0.80), so it now carries the same share.
      expect(hot.calculatedGoalMl - temperate.calculatedGoalMl, 1313);
    });

    test('a condition floor lifts the total; an addition stacks on it', () {
      HydrationProfile withConditions(Set<HydrationCondition> c) =>
          HydrationProfile(
            id: 'test',
            weightKg: 60,
            age: 30,
            isMale: false,
            activityLevel: ActivityLevel.sedentary,
            climate: ClimateType.cold,
            conditions: c,
          );

      // The un-flagged profile computes 2160 (baseline only, from the case
      // above), which is what makes these two easy to read off:
      //  * kidney stones is a FLOOR of 3000 — it lifts 2160 to 3000 rather
      //    than adding 3000 to it.
      //  * recurrent UTI is an ADDITION of 1500 — 2160 + 1500 = 3660.
      //  * both together: the addition applies first (3660), and the 3000
      //    floor is already satisfied, so it changes nothing.
      expect(withConditions({HydrationCondition.kidneyStones}).calculatedGoalMl,
          3000);
      expect(withConditions({HydrationCondition.recurrentUti}).calculatedGoalMl,
          3660);
      expect(
          withConditions({
            HydrationCondition.kidneyStones,
            HydrationCondition.recurrentUti,
          }).calculatedGoalMl,
          3660);
    });

    test('custom goal overrides calculated when useCustomGoal is true', () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 70,
        age: 30,
        activityLevel: ActivityLevel.moderate,
        climate: ClimateType.moderate,
        customGoalMl: 3000,
        useCustomGoal: true,
      );

      // This used to assert only `profile.customGoalMl == 3000`, i.e. that the
      // constructor stored its own argument — true no matter what
      // effectiveGoalMl did. The override is the behaviour worth pinning.
      expect(profile.effectiveGoalMl, 3000);
      expect(profile.calculatedGoalMl, 3152,
          reason: 'the calculation is not destroyed by the override — turning '
              'the custom goal back off must restore it');
      expect(profile.copyWith(useCustomGoal: false).effectiveGoalMl, 3152);
    });

    test('a prescribed fluid ceiling wins over both', () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 70,
        age: 30,
        activityLevel: ActivityLevel.moderate,
        climate: ClimateType.moderate,
        customGoalMl: 3000,
        useCustomGoal: true,
        fluidCeilingMl: 1500,
        conditions: {HydrationCondition.kidneyStones},
      );

      // 1500 is below the calculator's own 1200..5000 clamp floor only in
      // spirit — the point is that the ceiling bypasses the clamp AND outranks
      // both the custom goal and a condition floor that would otherwise demand
      // 3000. Someone with stones and a dialysis limit has a limit.
      expect(profile.isRestricted, isTrue);
      expect(profile.effectiveGoalMl, 1500);
    });
  });

  group('WaterAchievement Tests', () {
    test('all achievements list is not empty', () {
      expect(WaterAchievement.allAchievements, isNotEmpty);
    });

    test('achievement progress calculation is correct', () {
      final achievement = WaterAchievement(
        id: 'test',
        title: 'Test Achievement',
        description: 'Test description',
        emoji: '🏆',
        type: AchievementType.streak,
        targetValue: 10,
        currentValue: 5,
        points: 50,
      );

      expect(achievement.progress, 0.5);
      expect(achievement.isUnlocked, false);
    });

    test('unlocked achievement has progress 1.0', () {
      final achievement = WaterAchievement(
        id: 'test',
        title: 'Test Achievement',
        description: 'Test description',
        emoji: '🏆',
        type: AchievementType.streak,
        targetValue: 10,
        currentValue: 10,
        isUnlocked: true,
        points: 50,
      );

      expect(achievement.progress, 1.0);
      expect(achievement.isUnlocked, true);
    });

    test('tier integer values map correctly', () {
      final bronzeAchievement = WaterAchievement(
        id: 'test',
        title: 'Test',
        description: 'Test',
        emoji: '🏆',
        type: AchievementType.streak,
        targetValue: 3,
        tier: 1, // Bronze
        points: 10,
      );

      expect(bronzeAchievement.tier, 1);
      expect(bronzeAchievement.tierName, 'Bronze');
    });
  });

  group('UserAchievements Tests', () {
    test('new user has zero points', () {
      final userAchievements = UserAchievements(id: 'user');
      expect(userAchievements.totalPoints, 0);
    });

    test('level calculation is correct', () {
      final achievements = [
        WaterAchievement(
          id: 'a1',
          title: 'Test 1',
          description: 'Test',
          emoji: '🏆',
          type: AchievementType.streak,
          targetValue: 3,
          currentValue: 3,
          isUnlocked: true,
          points: 50,
        ),
        WaterAchievement(
          id: 'a2',
          title: 'Test 2',
          description: 'Test',
          emoji: '🏆',
          type: AchievementType.totalVolume,
          targetValue: 1000,
          currentValue: 1000,
          isUnlocked: true,
          points: 50,
        ),
      ];

      // totalPoints is a stored aggregate (accumulated during achievement
      // evaluation), not derived from the list — construct it accordingly.
      final userAchievements = UserAchievements(
        id: 'user',
        achievements: achievements,
        totalPoints: 100,
      );

      expect(userAchievements.totalPoints, 100);
      expect(userAchievements.level, 2); // 100 points / 100 per level = level 2
    });
  });

  group('MonthlyWaterStats Tests', () {
    test('creates monthly stats with correct values', () {
      final stats = MonthlyWaterStats(
        year: 2024,
        month: 1,
        totalIntakeMl: 75000,
        daysTracked: 30,
        daysGoalMet: 25,
        averageDailyMl: 2500,
        currentStreak: 10,
        longestStreak: 15,
      );

      expect(stats.totalIntakeMl, 75000);
      expect(stats.daysTracked, 30);
      expect(stats.completionRate, 25 / 30);
    });
  });

  group('HydrationInsight Tests', () {
    test('creates insight with required fields', () {
      final insight = HydrationInsight(
        id: 'test',
        title: 'Great job!',
        description: 'You are staying hydrated',
        emoji: '💧',
        type: InsightType.tip,
      );

      expect(insight.title, 'Great job!');
      expect(insight.emoji, '💧');
      expect(insight.type, InsightType.tip);
    });

    test('different insight types are available', () {
      expect(InsightType.values, contains(InsightType.tip));
      expect(InsightType.values, contains(InsightType.warning));
      expect(InsightType.values, contains(InsightType.achievement));
      expect(InsightType.values, contains(InsightType.reminder));
      expect(InsightType.values, contains(InsightType.suggestion));
    });
  });
}
