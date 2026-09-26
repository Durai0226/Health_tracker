/// Fluid guidance that depends on what the user is taking.
///
/// ## Why this is ours to build
///
/// The "medicine + water reminder" apps on the stores are two independent
/// reminder types in one binary with zero clinical linkage between them. A pure
/// hydration app is structurally incapable of this — it does not know what you
/// take. DlyMinder already stores medicines, with a curated interaction table
/// and a bundled generic-name catalog, in the same database as the water logs.
///
/// The guidance below is real and citable. It is deliberately narrow: only
/// drugs where fluid intake is part of ordinary prescribing advice, not every
/// drug with a renal footnote. Each rule says which direction it pushes and
/// why, and none of it is presented as advice — the app surfaces the guidance
/// and names the drug, and the decision stays between the user and their
/// clinician.
///
/// Keyed on the GENERIC name, resolved by `DrugNameCatalog.genericFor`, so a
/// brand ("Lithosun SR 400", "Septran DS") reaches the same rule as the
/// ingredient.
library;

/// Which way a drug pushes fluid needs.
enum HydrationAdviceDirection {
  /// Drink more than the ordinary target.
  increase,

  /// Worth knowing about, but no change to the number.
  caution,
}

class MedicationHydrationRule {
  /// Lower-case generic name this rule is keyed on.
  final String generic;

  final HydrationAdviceDirection direction;

  /// Minimum daily intake in millilitres, or 0 for "no floor".
  final int floorMl;

  /// One line the user reads.
  final String advice;

  /// Where the guidance comes from.
  final String source;

  /// Set when heat makes the drug riskier — surfaced only on hot days.
  final bool heatSensitive;

  const MedicationHydrationRule({
    required this.generic,
    required this.direction,
    required this.advice,
    required this.source,
    this.floorMl = 0,
    this.heatSensitive = false,
  });
}

/// The curated table. Small on purpose.
const List<MedicationHydrationRule> medicationHydrationRules = [
  MedicationHydrationRule(
    generic: 'lithium',
    direction: HydrationAdviceDirection.increase,
    floorMl: 2500,
    advice: 'Lithium needs a steady 2.5–3 litres a day. Getting dehydrated '
        'raises your lithium level, so watch it in hot weather or if you are '
        'unwell.',
    // Lithium is reabsorbed like sodium, so volume or salt depletion
    // concentrates it. The 2023 Beers Criteria flag the same interactions.
    source: 'FDA/NHS lithium prescribing guidance',
    heatSensitive: true,
  ),
  MedicationHydrationRule(
    generic: 'co-trimoxazole',
    direction: HydrationAdviceDirection.increase,
    floorMl: 2500,
    advice: 'Drink plenty while you are on this — it can form crystals in the '
        'urine if you are not passing enough.',
    source: 'Co-trimoxazole prescribing guidance (urine output >1.5 L/day)',
  ),
  MedicationHydrationRule(
    generic: 'topiramate',
    direction: HydrationAdviceDirection.increase,
    floorMl: 2500,
    advice: 'Topiramate raises the risk of kidney stones, and it can also make '
        'you sweat less — so heat is riskier than usual. Keep fluids up.',
    // Carbonic anhydrase inhibition raises urine pH and drops citrate;
    // oligohidrosis with hyperthermia is a labelled effect.
    source: 'Topiramate labelling (stone risk, oligohidrosis)',
    heatSensitive: true,
  ),
  MedicationHydrationRule(
    generic: 'dapagliflozin',
    direction: HydrationAdviceDirection.increase,
    advice: 'This works by making you pass more urine, so you lose more fluid '
        'than usual. Drink to thirst and be alert for dizziness.',
    source: 'SGLT2 inhibitor labelling (osmotic diuresis)',
  ),
  MedicationHydrationRule(
    generic: 'ciprofloxacin',
    direction: HydrationAdviceDirection.increase,
    advice: 'Stay well hydrated while you are taking this.',
    source: 'Ciprofloxacin patient information',
  ),
  // --- Caution only: these do NOT get a "drink more" floor -----------------
  //
  // Diuretics are prescribed to REMOVE fluid, very often for heart failure,
  // where the same patient may be on a fluid restriction. Telling them to
  // drink more would be directly against their treatment. So the app says what
  // the drug does and stops there.
  MedicationHydrationRule(
    generic: 'furosemide',
    direction: HydrationAdviceDirection.caution,
    advice: 'A diuretic — it is meant to shift fluid, so do not chase a higher '
        'water target because of it. Follow the advice you were given.',
    source: 'Loop diuretic labelling',
  ),
  MedicationHydrationRule(
    generic: 'hydrochlorothiazide',
    direction: HydrationAdviceDirection.caution,
    advice: 'A diuretic. If you also take lithium, this combination raises '
        'lithium levels — worth checking you have been told how to manage it.',
    source: 'Thiazide labelling; 2023 Beers Criteria (lithium interaction)',
  ),
  MedicationHydrationRule(
    generic: 'spironolactone',
    direction: HydrationAdviceDirection.caution,
    advice: 'A diuretic — do not raise your water target because of it.',
    source: 'Potassium-sparing diuretic labelling',
  ),
  MedicationHydrationRule(
    generic: 'lisinopril',
    direction: HydrationAdviceDirection.caution,
    advice: 'If you also take lithium, ACE inhibitors raise lithium levels. '
        'Staying evenly hydrated matters more than usual.',
    source: '2023 Beers Criteria (lithium interaction)',
  ),
];

/// Advice for one drug, or null when there is nothing to say.
MedicationHydrationRule? hydrationRuleForGeneric(String? generic) {
  if (generic == null) return null;
  final g = generic.trim().toLowerCase();
  for (final r in medicationHydrationRules) {
    if (r.generic == g) return r;
  }
  return null;
}

/// Combine the rules for everything a user takes.
class MedicationHydrationAdvice {
  /// Highest floor any "increase" rule asks for. 0 when none apply.
  final int floorMl;

  /// Rules that raise the target.
  final List<MedicationHydrationRule> increases;

  /// Rules that are information only.
  final List<MedicationHydrationRule> cautions;

  const MedicationHydrationAdvice({
    required this.floorMl,
    required this.increases,
    required this.cautions,
  });

  bool get isEmpty => increases.isEmpty && cautions.isEmpty;

  /// True when something the user takes makes hot weather riskier.
  bool get heatSensitive =>
      increases.any((r) => r.heatSensitive) ||
      cautions.any((r) => r.heatSensitive);

  static const empty = MedicationHydrationAdvice(
      floorMl: 0, increases: [], cautions: []);
}

/// Resolve advice for a list of generic names.
///
/// A drug appearing twice (two brands of the same ingredient) is reported once.
MedicationHydrationAdvice hydrationAdviceFor(Iterable<String?> generics) {
  final seen = <String>{};
  final increases = <MedicationHydrationRule>[];
  final cautions = <MedicationHydrationRule>[];
  var floor = 0;

  for (final g in generics) {
    final rule = hydrationRuleForGeneric(g);
    if (rule == null || !seen.add(rule.generic)) continue;
    if (rule.direction == HydrationAdviceDirection.increase) {
      increases.add(rule);
      if (rule.floorMl > floor) floor = rule.floorMl;
    } else {
      cautions.add(rule);
    }
  }

  // A diuretic in the list means we do NOT raise the target, even if something
  // else would. Someone on furosemide for heart failure and co-trimoxazole for
  // an infection must not be told to drink 2.5 L by this app; that call belongs
  // to whoever prescribed the diuretic. The infection advice still shows — as
  // advice, without moving the number.
  if (cautions.isNotEmpty) floor = 0;

  return MedicationHydrationAdvice(
    floorMl: floor,
    increases: increases,
    cautions: cautions,
  );
}
