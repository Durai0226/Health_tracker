/// Daily hydration target derived from published intake references and
/// modelled fluid *losses*, rather than from a body-weight rule of thumb.
///
/// ## Why this replaced `HydrationProfile.calculatedGoalMl`
///
/// The old formula was `weightKg * 33`, then multiplied by an activity factor
/// (0.9–1.35), a climate factor (0.9–1.35) and `0.9` if female, plus `+300`
/// pregnant / `+700` breastfeeding and `*0.95` over 65. None of those numbers
/// has a source, and two of them are contradicted by the ones that do:
///
///   * **No authority sets a body-weight-based hydration goal.** Not EFSA, not
///     IOM/NASEM, not WHO, not ACSM. All four publish a fixed *total water*
///     Adequate Intake by sex and age and then say to adjust for sweat losses.
///     The familiar "0.5–1 oz per pound" that most competitors implement is
///     folklore. (Valtin 2002 reviewed the literature behind "8x8" and found no
///     scientific basis for it either.)
///   * **The over-65 reduction is backwards.** IOM's AI is 3.7 L for men and
///     2.7 L for women in *every* adult band from 19 through >70, and EFSA
///     states the elderly value is the same as other adults. What changes with
///     age is thirst sensitivity — the risk, not the requirement. Scaling the
///     target down for the group least likely to notice thirst is the wrong
///     direction.
///   * **The flat 0.9x for women double-counts sex**, which is already the
///     reason the AI table has two columns.
///
/// So this models the actual physiology: a published baseline for ordinary
/// living, plus the water needed to replace what heat and exercise take out.
/// Every term below carries its source, and [HydrationGoal.basis] surfaces them
/// in the UI — a number the user can interrogate is worth more than a number
/// that is merely confident.
///
/// Pure Dart, no I/O, fully unit-testable — same shape as [HydrationPacer] and
/// [StreakEngine], and tested against the published figures directly.
library;

/// Conditions for which a *higher* fluid intake has published support.
///
/// These are the unclaimed high ground in this category. A peer-reviewed
/// content analysis of 51 water-tracking apps (38 Android, 13 iOS) found
/// exactly **one** that mentioned kidney stone disease and **zero** that
/// mentioned chronic kidney disease — the apps are all pretty gauges with no
/// clinical content at all. WaterMinder, the category leader, explicitly
/// disclaims being a medical app.
///
/// Each entry below carries real evidence and, crucially, an honest strength.
/// One of the three rests on a case-crossover study and says so in the UI: a
/// feature that presents weak evidence as strong is worse than no feature.
///
/// The opposite direction — a prescribed fluid *ceiling* — is
/// [HydrationProfile.fluidCeilingMl], and it always wins over anything here.
/// Someone with both stones and advanced CKD has a limit, not a target.
enum HydrationCondition {
  /// Recurrent calcium kidney stones.
  ///
  /// The AUA's Medical Management of Kidney Stones guideline advises clinicians
  /// to tell **all** stone formers to reach a fluid intake producing at least
  /// **2.5 L of urine daily**. Note that is an OUTPUT target — intake typically
  /// needs to be ~3 L or more to achieve it, which is why the app models it as
  /// a floor on intake rather than repeating "2.5 L" at the user.
  ///
  /// Evidence: Borghi 1996, a 5-year randomised prospective trial in 199
  /// first-time idiopathic calcium stone formers, cut recurrence from 27% to
  /// 12%.
  kidneyStones,

  /// Recurrent urinary tract infection.
  ///
  /// The strongest randomised evidence in consumer hydration. Hooton et al.,
  /// JAMA Internal Medicine 2018: open-label RCT, 12 months, 140 premenopausal
  /// women with >=3 cystitis episodes in the prior year AND baseline intake
  /// under 1.5 L/day. Intervention was 1.5 L of water daily on top of usual
  /// intake. Mean cystitis episodes 1.7 (95% CI 1.5-1.8) vs 3.2 (3.0-3.4),
  /// difference 1.5, P < .001.
  ///
  /// The trial enrolled *low* baseline drinkers, so the +1.5 L is added to a
  /// modest baseline rather than piled onto someone already drinking 3 L.
  recurrentUti,

  /// Gout.
  ///
  /// Neogi et al., ACR 2009: internet-based case-crossover study, 535 people
  /// with a gout attack in the prior year, each acting as their own control.
  /// Against 0-1 glasses/day, 5-8 glasses was associated with 40% lower odds of
  /// an attack and >8 glasses with 46% lower.
  ///
  /// **Weakest of the three** — observational, self-reported, and the authors
  /// themselves called for a trial that has not happened. Shipped with the
  /// caveat visible, not buried.
  gout,
}

/// What each condition does to the target, and what backs it.
class HydrationConditionRule {
  /// Minimum daily intake this condition implies, in millilitres. 0 = no floor.
  final int floorMl;

  /// Added on top of the computed baseline, in millilitres. 0 = no addition.
  final int addMl;

  final String label;
  final String basis;

  /// Shown next to the toggle. Empty when the evidence is strong.
  final String caveat;

  const HydrationConditionRule({
    required this.label,
    required this.basis,
    this.floorMl = 0,
    this.addMl = 0,
    this.caveat = '',
  });
}

const Map<HydrationCondition, HydrationConditionRule> hydrationConditionRules = {
  HydrationCondition.kidneyStones: HydrationConditionRule(
    label: 'Kidney stones',
    // A floor, not an addition: the guideline target is urine output, and
    // stacking +1 L onto an already-high computed goal would overshoot.
    floorMl: 3000,
    basis: 'At least 3 L a day, to produce the 2.5 L of urine the AUA '
        'guideline recommends for stone formers (Borghi 1996: recurrence 27% '
        'to 12% over 5 years)',
  ),
  HydrationCondition.recurrentUti: HydrationConditionRule(
    label: 'Recurrent UTI',
    addMl: 1500,
    basis: '+1.5 L a day. Hooton 2018 (JAMA Intern Med, randomised, n=140): '
        '1.7 vs 3.2 cystitis episodes a year, P<0.001',
  ),
  HydrationCondition.gout: HydrationConditionRule(
    label: 'Gout',
    floorMl: 2500,
    basis: 'Around 5-8 glasses a day was associated with 40% lower odds of an '
        'attack (Neogi 2009, n=535)',
    caveat: 'This one is weaker evidence — an observational study, not a '
        'trial. Worth discussing with your doctor rather than relying on.',
  ),
};

/// How hard someone is on their feet, when real energy data is unavailable.
enum HydrationActivityLevel { sedentary, light, moderate, active, veryActive }

/// A computed target, with its working shown.
class HydrationGoal {
  /// Beverage-only baseline from the adequate-intake table.
  final int baselineMl;

  /// Extra to replace sweat from activity *above* what the baseline assumes.
  final int activityMl;

  /// Extra for ambient heat at rest, above the temperate range the baseline
  /// assumes.
  final int climateMl;

  /// Net effect of any selected [HydrationCondition]s — an addition, a floor
  /// lifting the total, or both.
  final int conditionMl;

  /// What to actually drink today.
  final int totalMl;

  /// Plain-language, citable reasons — for display next to the number.
  final List<String> basis;

  const HydrationGoal({
    required this.baselineMl,
    required this.activityMl,
    required this.climateMl,
    required this.totalMl,
    required this.basis,
    this.conditionMl = 0,
  });
}

class HydrationGoalCalculator {
  const HydrationGoalCalculator._();

  /// Beverage share of total water intake.
  ///
  /// IOM: "Moisture in food accounts for about 20% of total water intake",
  /// making beverages ~80%. Their own 19–30y figures are explicit — men 3.7 L
  /// total of which 3.0 L from beverages; women 2.7 L of which 2.2 L. EFSA
  /// agrees at 80%. We track *drinks*, so the target must be the beverage
  /// share, not the total — using the total would silently demand ~700 ml/day
  /// more than anyone means by "drink this much".
  static const double beverageShare = 0.80;

  /// Active energy (kcal/day above resting) already reflected in the adequate
  /// intake, which is a population figure for people living ordinary lives —
  /// not for someone at rest all day.
  ///
  /// This is the term that stops the sweat model double-counting: only activity
  /// *beyond* this adds water. It is an explicit modelling assumption rather
  /// than a published constant, and it is deliberately conservative — set it
  /// too low and every user gets an inflated goal they will never hit.
  static const int baselineActiveKcal = 250;

  /// Ambient temperature the adequate intake assumes. WHO/IPCS reference values
  /// give ~2.9 L/day for adults in "normal conditions" rising to 4.5 L at a
  /// high average temperature of 32 °C, so the baseline sits in the temperate
  /// range and only heat above it adds load.
  static const double baselineAmbientC = 22.0;

  /// Highest ambient temperature the at-rest heat term is derived for.
  ///
  /// The WHO/IPCS pair behind [baselineAmbientC] is ~2.9 L/day in normal
  /// conditions and ~4.5 L at a high average of 32 °C. Past 32 the 160 ml/°C
  /// line is an extrapolation with nothing behind it, and it compounds: the
  /// sweat term already raises its own `k(T)` with temperature, so every
  /// degree beyond the evidence adds heat load twice. A felt temperature of
  /// 45 °C used to put 3680 ml on the at-rest term alone.
  ///
  /// Capped here rather than left to [maxGoalMl], which only ever fixed the
  /// total: [HydrationGoal.climateMl] is shown as a term in its own right.
  static const double climateCeilingC = 32.0;

  /// Millilitres the at-rest heat term adds per degree above
  /// [baselineAmbientC] — the WHO span (4.5 L − 2.9 L) over
  /// ([climateCeilingC] − [baselineAmbientC]) degrees, carrying the same
  /// [beverageShare] the baseline does.
  ///
  /// The raw span is 160 ml/°C, and that was the number here. But the WHO pair
  /// it comes from is TOTAL water, while this is added to a baseline that has
  /// already had [beverageShare] applied for exactly the reason stated there:
  /// we track drinks, not total water. Taking 80% of the baseline and 100% of
  /// the increment asks a warm-weather user to drink the food-moisture share
  /// of the heat load as well — the same ~20% overstatement the baseline
  /// comment exists to prevent, reappearing one term later.
  ///
  /// 160 × 0.80 = 128.
  static const int climateMlPerDegree = (160 * beverageShare) ~/ 1;

  /// Most [HydrationGoal.climateMl] can ever be: the whole WHO span.
  static const int maxClimateMl =
      climateMlPerDegree * ((climateCeilingC - baselineAmbientC) ~/ 1);

  /// Sweat produced per kcal of metabolic work at ambient temperature [tempC].
  ///
  /// ACSM derives the ceiling from first principles: at ~20% mechanical
  /// efficiency, 80% of metabolic energy becomes heat, and evaporating sweat
  /// carries 0.58 kcal/g — so 0.80 / 0.58 = **1.38 mL of sweat per kcal** when
  /// evaporation is doing all the cooling. In cooler air, radiation and
  /// convection carry part of the load, so less sweat is needed.
  ///
  /// Fitting that to ACSM's own observed sweat rates gives
  /// `k = 1.13 + 0.014 x (T − 18)`. The fit validates itself: it reaches the
  /// theoretical 1.38 ceiling at T ≈ 36 °C — skin temperature, which is exactly
  /// the point where dry heat loss goes to zero and evaporation must carry
  /// everything.
  static double sweatMlPerKcal(double tempC) =>
      (1.13 + 0.014 * (tempC - 18.0)).clamp(0.8, 1.38);

  /// Beverage-only baseline in millilitres, from the IOM/NASEM total-water
  /// Adequate Intake table.
  ///
  /// Values (L/day total water): children 1–3y 1.3, 4–8y 1.7; males 9–13y 2.4,
  /// 14–18y 3.3, 19y+ 3.7; females 9–13y 2.1, 14–18y 2.3, 19y+ 2.7; pregnancy
  /// 3.0; lactation 3.8. No Tolerable Upper Level is set. Note the adult figure
  /// is flat across every band including >70y.
  static int baselineDrinkMl({
    required bool isMale,
    int? ageYears,
    bool isPregnant = false,
    bool isBreastfeeding = false,
  }) {
    double totalL;
    // Lactation and pregnancy replace the adult figure rather than adding to
    // it — the IOM table lists them as their own rows. Breastfeeding wins when
    // both are somehow set.
    if (!isMale && isBreastfeeding) {
      totalL = 3.8;
    } else if (!isMale && isPregnant) {
      totalL = 3.0;
    } else {
      final age = ageYears ?? 30;
      if (age < 1) {
        totalL = 0.8;
      } else if (age <= 3) {
        totalL = 1.3;
      } else if (age <= 8) {
        totalL = 1.7;
      } else if (age <= 13) {
        totalL = isMale ? 2.4 : 2.1;
      } else if (age <= 18) {
        totalL = isMale ? 3.3 : 2.3;
      } else {
        // Flat for every adult band, 19 through >70 — deliberately NOT reduced
        // with age.
        totalL = isMale ? 3.7 : 2.7;
      }
    }
    return (totalL * 1000 * beverageShare).round();
  }

  /// Lowest target the app will set. Below this a "goal" stops being a
  /// hydration target and becomes a restriction, which needs the explicit,
  /// clinically-framed path — never a side effect of an odd profile.
  static const int minGoalMl = 1200;

  /// Highest target the app will set for an ordinary profile.
  ///
  /// Not a physiological ceiling — people in real heat and real work need more
  /// — but a guard against a bad input (a mistyped weight, a garbage
  /// temperature) producing a target that is itself a hazard. See
  /// [safeHourlyCeilingMl] for the acute limit, which is the one that matters.
  static const int maxGoalMl = 5000;

  /// Renal free-water clearance ceiling, in millilitres per hour.
  ///
  /// The binding constraint on drinking fast is the kidney, not the stomach:
  /// gastric emptying reaches ~2.4 L/h, but maximal free-water clearance is
  /// ~800–1000 mL/h. IOM's stated reason for setting no Tolerable Upper Level
  /// is that "normally functioning kidneys can handle more than 0.7 L (24 oz)
  /// of fluid per hour" — beyond that, plasma sodium falls.
  ///
  /// Deliberately NOT the US Army TB MED 507 figures (1.42 L/h, 11.4 L/day):
  /// those are heat-casualty ceilings for acclimatised soldiers under work
  /// load, and applying them to someone sitting at a desk would license a
  /// genuinely dangerous rate.
  static const int safeHourlyCeilingMl = 1000;

  /// Compute today's target.
  ///
  /// [activeKcal] should be real active energy from Health Connect / HealthKit
  /// when available — that is what makes this model better than the
  /// competition's, because it measures the load instead of guessing it from
  /// body mass. When it is not available, pass [activityLevel] and
  /// [weightKg] and an estimate is used.
  ///
  /// [ambientC] is the day's felt temperature; omit it to assume temperate.
  static HydrationGoal compute({
    required bool isMale,
    int? ageYears,
    bool isPregnant = false,
    bool isBreastfeeding = false,
    int? activeKcal,
    HydrationActivityLevel activityLevel = HydrationActivityLevel.light,
    double? weightKg,
    double? ambientC,
    Set<HydrationCondition> conditions = const {},
  }) {
    final basis = <String>[];

    final baseline = baselineDrinkMl(
      isMale: isMale,
      ageYears: ageYears,
      isPregnant: isPregnant,
      isBreastfeeding: isBreastfeeding,
    );
    if (!isMale && isBreastfeeding) {
      basis.add('Breastfeeding: 3.8 L total water a day (IOM/NASEM)');
    } else if (!isMale && isPregnant) {
      basis.add('Pregnancy: 3.0 L total water a day (IOM/NASEM)');
    } else {
      basis.add(isMale
          ? 'Adult men: 3.7 L total water a day (IOM/NASEM)'
          : 'Adult women: 2.7 L total water a day (IOM/NASEM)');
    }
    basis.add('About 20% of that comes from food, so the drinks target is '
        '${(baseline / 1000).toStringAsFixed(1)} L');

    // --- Sweat from activity above what the baseline already assumes -------
    final kcal = activeKcal ?? _estimateActiveKcal(activityLevel, weightKg);
    final excessKcal = (kcal - baselineActiveKcal).clamp(0, 100000);
    final temp = ambientC ?? baselineAmbientC;
    final activityMl = (excessKcal * sweatMlPerKcal(temp)).round();
    if (activityMl > 0) {
      basis.add(activeKcal != null
          ? 'Replacing sweat from $kcal kcal of activity today (ACSM)'
          : 'Replacing sweat from your usual activity level (ACSM)');
    }

    // --- Ambient heat at rest ----------------------------------------------
    // WHO/IPCS: adults need ~2.9 L/day in normal conditions and ~4.5 L at a
    // high average temperature of 32 °C. Spread across that 10 °C span, that is
    // roughly 160 ml per degree above the temperate baseline — applied only to
    // the at-rest load, since the activity term already accounts for
    // temperature through k(T).
    var climateMl = 0;
    if (ambientC != null && ambientC > baselineAmbientC) {
      // Clamped to the top of the evidence, not to the raw reading — see
      // [climateCeilingC].
      final effectiveC = ambientC.clamp(baselineAmbientC, climateCeilingC);
      climateMl =
          ((effectiveC - baselineAmbientC) * climateMlPerDegree).round();
      basis.add(ambientC > climateCeilingC
          ? 'Warm day (${ambientC.round()} °C): extra fluid for heat, held at '
              'the ${climateCeilingC.round()} °C figure the WHO range reaches '
              '(WHO)'
          : 'Warm day (${ambientC.round()} °C): extra fluid for heat (WHO)');
    }

    // --- Conditions with published support for a higher intake -------------
    //
    // Additions stack; floors do not. A floor lifts the total to a minimum
    // rather than adding to it, because the guideline figures ARE totals — the
    // AUA's stone target is "3 L a day", not "3 L more than you already drink".
    // Adding it would push a moderately active person past 6 L.
    var withConditions = baseline + activityMl + climateMl;
    var floor = 0;
    for (final c in conditions) {
      final rule = hydrationConditionRules[c];
      if (rule == null) continue;
      withConditions += rule.addMl;
      if (rule.floorMl > floor) floor = rule.floorMl;
      basis.add(rule.basis);
    }
    if (floor > withConditions) withConditions = floor;

    final preConditions = baseline + activityMl + climateMl;
    final total = withConditions.clamp(minGoalMl, maxGoalMl);
    // What the conditions actually contributed to the number shown — never
    // less than nothing. This was a bare `total - preConditions`, which went
    // NEGATIVE the moment baseline + activity + climate alone passed
    // [maxGoalMl]: a profile with no conditions set at all then reported a
    // condition term of, say, -1386 ml.
    final conditionMl = (total - preConditions).clamp(0, total);
    if (total < withConditions) {
      // Say so rather than letting the four terms quietly stop summing to the
      // total. The cap is a guard against a bad input, not a judgement about
      // what this person needs.
      basis.add('Held at ${(maxGoalMl / 1000).toStringAsFixed(0)} L — the app '
          'will not set a higher daily target from a profile alone');
    }

    return HydrationGoal(
      baselineMl: baseline,
      activityMl: activityMl,
      climateMl: climateMl,
      conditionMl: conditionMl,
      totalMl: total,
      basis: basis,
    );
  }

  /// Active kcal/day when no real measurement is available.
  ///
  /// Uses MET-hours above rest, where 1 MET-hour ≈ 1 kcal per kg of body mass —
  /// the standard approximation. Body weight enters *here*, as a multiplier on
  /// energy expenditure, which is the only way it legitimately affects fluid
  /// need: heavier people do more work moving, produce more heat, and sweat
  /// more. It is not a direct divisor on the target.
  static int _estimateActiveKcal(
      HydrationActivityLevel level, double? weightKg) {
    final kg = (weightKg ?? 70).clamp(25.0, 250.0);
    final metHours = switch (level) {
      HydrationActivityLevel.sedentary => 1.5,
      HydrationActivityLevel.light => 3.0,
      HydrationActivityLevel.moderate => 6.0,
      HydrationActivityLevel.active => 9.0,
      HydrationActivityLevel.veryActive => 13.0,
    };
    return (metHours * kg).round();
  }
}
