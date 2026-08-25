/// Which drug families relate to which condition page — and, just as
/// importantly, which ones deliberately relate to nothing.
///
/// ## Why the drug CLASS and never the `uses` prose
///
/// The obvious implementation is a regex over each monograph's `uses` text. It
/// was written, run against all 160 monographs, and rejected. The two exhibits
/// that actually carry the argument:
///
/// * **Ketotifen** — class "Antihistamine (anti-allergy medicine)". Its prose
///   says the oral form can "help prevent asthma symptoms over time", so a
///   prose match files a plain antihistamine on the asthma page.
/// * **Furosemide** — class "Water pill (loop diuretic)". Its prose says it is
///   used "sometimes to help lower blood pressure", so a prose match files a
///   loop diuretic under hypertension.
///
/// A `class` string is a curated, short, structured field. `uses` is prose
/// written for a human who already knows what they are holding.
///
/// **Timolol is NOT evidence for this**, and an earlier version of this comment
/// wrongly claimed it was. Its class contains "Beta-blocker" and hits the
/// hypertension cue head-on; it is saved by the glaucoma veto below — and the
/// words that veto keys on also appear in its own `uses`, so a prose matcher
/// carrying the same veto would save it just as well. Keep the veto; drop the
/// argument.
///
/// ## The cost, stated rather than hidden
///
/// Class-only matching loses true positives too, and the asthma page is where
/// it hurts. **Budesonide**, **Fluticasone** and **Mometasone** are inhaled
/// corticosteroids — genuine asthma controllers — and none is linked, because
/// their class strings say "Corticosteroid (anti-inflammatory steroid)" and
/// "Steroid (corticosteroid) — nasal, inhaled, or skin". Those same strings
/// also cover a nasal spray and a skin cream, and a medicine record here does
/// not say which form the user holds. So the miss is the design working as
/// intended — refusing to guess — not an oversight. It is pinned as a known
/// false negative in the tests so nobody has to rediscover it.
///
/// ## The claim this is allowed to make
///
/// Never "you have X". The heading these links appear under is *"Your medicines
/// in this area"*, on a page **the user chose to open** — the subject is the
/// medicine, the predicate is its drug family, and the condition is context the
/// user supplied by navigating there. Everything here is a reading suggestion,
/// which is a different product from a condition profile.
///
/// ## Measured, not estimated
///
/// Every number below came from running this table over the whole asset.
/// `condition_taxonomy_test.dart` pins the resulting sets so that the day a new
/// cue drags Aspirin onto the osteoarthritis page, a test says so.
library;

/// Positive and veto cues for one condition, matched against a monograph's
/// `class` string, lowercased.
typedef ConditionCues = ({List<String> positive, List<String> veto});

abstract final class ConditionTaxonomy {
  /// Cue table, keyed by `ConditionInfo.id`.
  ///
  /// Match counts across `assets/health/drug_info.json` (160 monographs):
  /// hypertension 7 · high-cholesterol 2 · type-2-diabetes 12 · asthma 9 ·
  /// copd 7 · gerd 8 · anxiety 5 · depression 3 · hypothyroidism 1 ·
  /// osteoporosis 1 · afib 0 · osteoarthritis 0 · migraine 0 · ckd 0.
  static const Map<String, ConditionCues> _cues = {
    // Every match here literally names blood pressure in its own class string.
    //
    // `diuretic` was a cue and was REMOVED: it pulled in Furosemide, whose class
    // is "Water pill (loop diuretic)". Loop diuretics are prescribed for fluid
    // overload far more than for hypertension, so that link is the same kind of
    // guess as putting an anticoagulant on the AF page. Spironolactone survives
    // because its own class says "blood-pressure medicine".
    'hypertension': (
      positive: [
        'blood-pressure',
        'ace inhibitor',
        '(arb',
        'calcium channel blocker',
        'beta-blocker',
      ],
      // Timolol's class is "Beta-blocker (commonly glaucoma eye drops)". The
      // beta-blocker cue catches it head-on and this veto lets it go again —
      // which is what a veto list is for, and is a separate point from the
      // class-vs-prose argument above.
      veto: ['glaucoma', 'eye drop', 'eye-pressure', 'migraine'],
    ),

    'high-cholesterol': (
      positive: ['statin', 'cholesterol-lowering', 'lipid'],
      veto: [],
    ),

    'type-2-diabetes': (
      positive: ['diabetes medicine', 'insulin'],
      veto: ['insipidus'],
    ),

    // `bronchodilator` is kept even though it also reaches COPD drugs, because
    // the sentence it produces — "this medicine's drug family (bronchodilator)
    // is commonly used for conditions in this area" — is true on both pages.
    // The veto drops the cough syrup that happens to contain one.
    'asthma': (
      positive: ['asthma', 'bronchodilator', 'inhaled steroid', 'leukotriene'],
      veto: ['cough', 'mucus', 'expectorant'],
    ),
    'copd': (
      positive: ['copd', 'bronchodilator'],
      veto: ['cough', 'mucus', 'expectorant'],
    ),

    'gerd': (
      positive: [
        'acid-reducer',
        'antacid',
        'proton pump',
        'reflux',
        'h2 blocker',
      ],
      // "Antacid / urine alkalizer (effervescent)" is for urinary discomfort.
      veto: ['urine'],
    ),

    'hypothyroidism': (
      positive: ['thyroid'],
      veto: ['overactive', 'antithyroid'],
    ),

    // SSRIs appear on both pages, and that is correct rather than sloppy: they
    // are first-line for both, and the copy claims a drug FAMILY is used in this
    // area, not that the reader has either condition.
    //
    // Clonazepam's class is "Benzodiazepine (anti-seizure and anti-anxiety
    // medicine)". An earlier `anti-seizure` veto excluded it — a FALSE veto, on
    // a medicine whose own class calls it anti-anxiety. Removed.
    'anxiety': (
      positive: ['anti-anxiety', 'benzodiazepine', '(ssri'],
      veto: [],
    ),
    'depression': (
      positive: ['antidepressant', '(ssri'],
      veto: [],
    ),

    'osteoporosis': (
      positive: ['bisphosphonate', 'bone-health', 'calcium and vitamin d'],
      veto: [],
    ),

    // ---- Four conditions link to NOTHING, on purpose ----------------------
    //
    // Refusing to guess is the feature. Each of these has a candidate class
    // sitting right there in the asset, and taking it would be a guess dressed
    // as data. A test pins them empty so a well-meaning future change has to
    // argue with it.

    // Anticoagulants and antiplatelets are prescribed at least as often for
    // DVT, PE and coronary disease. A first pass matched Aspirin and Heparin
    // here; both are wrong. Six blood thinners in the asset, none linked.
    'afib': (positive: [], veto: []),

    // NSAIDs are the only candidate family, and they are prescribed for
    // headache, period pain, injury and fever. Linking Ibuprofen to
    // osteoarthritis says something about the reader that the data cannot.
    'osteoarthritis': (positive: [], veto: []),

    // No triptan monograph in the asset — the word "triptan" appears only twice,
    // both as an SSRI serotonin-syndrome interaction warning — and nothing else
    // migraine-specific. The only headache drugs are general-purpose NSAIDs and
    // paracetamol.
    'migraine': (positive: [], veto: []),

    // No CLASS string in the asset names a kidney indication — verified across
    // all 160.
    //
    // The earlier reason given here, "nothing in the asset is CKD-specific",
    // was simply false: Dapagliflozin's `uses` names chronic kidney disease
    // outright, and Losartan's claims kidney protection. But their classes are
    // "Diabetes medicine (SGLT2 inhibitor)" and "Blood-pressure medicine (ARB)".
    // Linking either here would mean matching prose, which is the one thing
    // this table refuses to do — and the class-scoped reason is the stronger
    // one anyway.
    'ckd': (positive: [], veto: []),
  };

  /// Condition ids this taxonomy knows about.
  static Iterable<String> get conditionIds => _cues.keys;

  /// Ids that deliberately link to nothing.
  static Set<String> get deliberatelyUnlinked => {
        for (final e in _cues.entries)
          if (e.value.positive.isEmpty) e.key,
      };

  /// Whether [drugClass] relates to [conditionId].
  ///
  /// Case-insensitive substring matching on the class string only. A veto wins
  /// over any positive cue.
  static bool classMatches(String drugClass, String conditionId) {
    final cues = _cues[conditionId];
    if (cues == null || cues.positive.isEmpty) return false;
    final c = drugClass.toLowerCase();
    if (cues.veto.any(c.contains)) return false;
    return cues.positive.any(c.contains);
  }

  /// Every condition [drugClass] relates to.
  ///
  /// Note the direction: one pass over the user's medicines resolving each
  /// generic once, then inverted into `Map<conditionId, links>`. Asking the
  /// other way round — "which medicines match THIS condition" — is a scan per
  /// condition, i.e. fourteen passes over the same list.
  static Set<String> conditionsForClass(String drugClass) {
    final c = drugClass.toLowerCase();
    return {
      for (final e in _cues.entries)
        if (e.value.positive.isNotEmpty &&
            !e.value.veto.any(c.contains) &&
            e.value.positive.any(c.contains))
          e.key,
    };
  }

  /// The family phrase for a "why am I seeing this" chip, drawn from the class
  /// string rather than invented — e.g. "calcium channel blocker".
  ///
  /// Returns null when the class has no parenthesised family, so the caller
  /// falls back to the whole class rather than rendering an empty clause.
  static String? familyPhrase(String drugClass) {
    final m = RegExp(r'\(([^)]+)\)').firstMatch(drugClass);
    final inner = m?.group(1)?.trim();
    if (inner == null || inner.isEmpty) return null;
    // "proton pump inhibitor, PPI" -> "proton pump inhibitor". The acronym adds
    // nothing to a sentence already naming the family in words.
    final head = inner.split(',').first.trim();
    return head.isEmpty ? null : head.toLowerCase();
  }
}
