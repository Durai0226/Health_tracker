/// The clinical-precision gate: all 160 monographs, every condition, pinned.
///
/// This is the highest-value test in the Condition Library work. Matching a
/// user's medicine to a condition page is the one place this feature could say
/// something about a person that the data does not support, and the failure mode
/// is silent — a cue widened for a good reason quietly drags an unrelated drug
/// onto a page about a disease.
///
/// So the whole asset is run through the cue table and the resulting sets are
/// pinned. Every number here was MEASURED before it was written down.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/data/condition_library_data.dart';
import 'package:tablet_remainder/features/medication/services/condition_taxonomy.dart';

void main() {
  late List<Map<String, dynamic>> monographs;

  setUpAll(() {
    final raw = File('assets/health/drug_info.json').readAsStringSync();
    monographs = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  });

  List<String> genericsFor(String conditionId) => monographs
      .where((m) =>
          ConditionTaxonomy.classMatches(m['class'] as String, conditionId))
      .map((m) => m['generic'] as String)
      .toList()
    ..sort();

  test('the asset is the size the cue table was measured against', () {
    // If this changes, every count below is measuring a different corpus and
    // must be re-derived rather than adjusted.
    expect(monographs.length, 160);
  });

  // ------------------------------------------------------------ the pinned sets

  group('the whole-asset sweep', () {
    const expected = <String, List<String>>{
      'hypertension': [
        'Amlodipine',
        'Losartan',
        'Metoprolol',
        'Ramipril',
        'Spironolactone',
        'Telmisartan',
        'Telmisartan/Amlodipine',
      ],
      'high-cholesterol': ['Atorvastatin', 'Rosuvastatin'],
      'type-2-diabetes': [
        'Dapagliflozin',
        'Glimepiride',
        'Insulin Aspart',
        'Insulin Glargine',
        'Insulin Isophane (NPH)',
        'Insulin Isophane/Insulin Regular',
        'Insulin Lispro',
        'Insulin Regular (Human)',
        'Insulin Regular (Soluble)',
        'Metformin',
        'Sitagliptin',
        'Vildagliptin',
      ],
      'asthma': [
        'Budesonide/Formoterol',
        'Ipratropium',
        'Ipratropium/Levosalbutamol',
        'Levosalbutamol',
        'Montelukast',
        'Montelukast/Levocetirizine',
        'Salbutamol',
        'Salmeterol/Fluticasone',
        'Tiotropium',
      ],
      'copd': [
        'Budesonide/Formoterol',
        'Ipratropium',
        'Ipratropium/Levosalbutamol',
        'Levosalbutamol',
        'Salbutamol',
        'Salmeterol/Fluticasone',
        'Tiotropium',
      ],
      'gerd': [
        'Aluminium Hydroxide/Magnesium Hydroxide/Simethicone',
        'Esomeprazole',
        'Omeprazole',
        'Oxetacaine/Aluminium Hydroxide/Magnesium Hydroxide',
        'Pantoprazole',
        'Pantoprazole/Domperidone',
        'Rabeprazole',
        'Sodium Alginate/Sodium Bicarbonate/Calcium Carbonate',
      ],
      'hypothyroidism': ['Levothyroxine'],
      'anxiety': [
        'Alprazolam',
        'Clonazepam',
        'Escitalopram',
        'Fluoxetine',
        'Sertraline',
      ],
      'depression': ['Escitalopram', 'Fluoxetine', 'Sertraline'],
      'osteoporosis': ['Calcium Carbonate/Cholecalciferol'],
    };

    expected.forEach((conditionId, generics) {
      test('$conditionId links exactly ${generics.length}', () {
        expect(genericsFor(conditionId), generics);
      });
    });
  });

  // ------------------------------------------------------- the refusals

  group('four conditions link to nothing, on purpose', () {
    for (final id in ['afib', 'osteoarthritis', 'migraine', 'ckd']) {
      test('$id stays empty', () {
        expect(genericsFor(id), isEmpty,
            reason: 'Refusing to guess is the feature here. If you are adding a '
                'cue for $id, read the reason in condition_taxonomy.dart first '
                '— each of these has a candidate class sitting in the asset, '
                'and taking it is a guess dressed as data.');
      });
    }

    test('the taxonomy agrees about which are unlinked', () {
      expect(ConditionTaxonomy.deliberatelyUnlinked,
          {'afib', 'osteoarthritis', 'migraine', 'ckd'});
    });
  });

  // ------------------------------------------------ the specific false positives

  group('negative pins — the reason this matches class, not prose', () {
    ({String generic, String cls}) monograph(String generic) {
      final m = monographs.firstWhere((x) => x['generic'] == generic,
          orElse: () => throw StateError('$generic is not in the asset'));
      return (generic: generic, cls: m['class'] as String);
    }

    test('the veto catches Timolol, which the cue would otherwise take', () {
      final t = monograph('Timolol');
      // Filed under "the veto list earns its keep", NOT under "class beats
      // prose". Its class contains "Beta-blocker" and hits the hypertension cue
      // head-on — and the word the veto keys on, "glaucoma", is in its `uses`
      // too, so a prose matcher with the same veto would also save it. An
      // earlier version of this test presented Timolol as the flagship argument
      // for class-only matching. It is not one.
      expect(t.cls.toLowerCase(), contains('beta-blocker'));
      expect(t.cls.toLowerCase(), contains('glaucoma'));
      expect(ConditionTaxonomy.classMatches(t.cls, 'hypertension'), isFalse);
    });

    test('a fibre laxative is NOT high cholesterol', () {
      // The asset's key is the full 'Ispaghula (Psyllium husk)'. Its `uses`
      // says the fibre can "support healthy cholesterol levels"; its class says
      // "Fiber (bulk-forming) laxative".
      final i = monograph('Ispaghula (Psyllium husk)');
      expect(i.cls.toLowerCase(), contains('laxative'));
      expect((monographs.firstWhere((m) => m['generic'] == i.generic)['uses']
              as String)
          .toLowerCase()
          .contains('cholesterol'), isTrue);
      expect(ConditionTaxonomy.classMatches(i.cls, 'high-cholesterol'), isFalse);
    });

    test('an antihistamine is NOT an asthma medicine', () {
      // The exhibit that actually carries the class-over-prose argument.
      // Ketotifen's class is "Antihistamine (anti-allergy medicine)"; its prose
      // says the oral form can "help prevent asthma symptoms over time".
      final k = monograph('Ketotifen');
      expect(k.cls.toLowerCase(), contains('antihistamine'));
      expect(ConditionTaxonomy.classMatches(k.cls, 'asthma'), isFalse);
    });

    test('no blood thinner lands on the AF page', () {
      // The first pass matched Aspirin and Heparin. Six of these in the asset.
      for (final g in [
        'Aspirin',
        'Heparin',
        'Apixaban',
        'Rivaroxaban',
        'Clopidogrel',
        'Enoxaparin',
      ]) {
        expect(ConditionTaxonomy.classMatches(monograph(g).cls, 'afib'), isFalse,
            reason: '$g is prescribed at least as often for DVT, PE and '
                'coronary disease');
      }
    });

    test('an oral rehydration salt is NOT a diabetes medicine', () {
      // "Oral rehydration solution (sugar and salts)" — a naive sugar/glucose
      // cue would have taken it.
      final o = monograph('Glucose/Electrolytes');
      expect(
          ConditionTaxonomy.classMatches(o.cls, 'type-2-diabetes'), isFalse);
    });

    test('a loop diuretic is NOT filed under hypertension', () {
      // Furosemide DID match while `diuretic` was a cue. Loop diuretics are for
      // fluid overload far more than for blood pressure.
      final f = monograph('Furosemide');
      expect(ConditionTaxonomy.classMatches(f.cls, 'hypertension'), isFalse);
    });

    test('a cough syrup containing a bronchodilator is not an inhaler', () {
      final c = monograph('Levosalbutamol/Ambroxol/Guaifenesin');
      expect(ConditionTaxonomy.classMatches(c.cls, 'asthma'), isFalse);
      expect(ConditionTaxonomy.classMatches(c.cls, 'copd'), isFalse);
    });

    test('a urine alkalizer is not a reflux medicine', () {
      final s = monograph('Sodium bicarbonate/Citric acid');
      expect(ConditionTaxonomy.classMatches(s.cls, 'gerd'), isFalse);
    });
  });

  group('the cost of class-only matching, recorded rather than hidden', () {
    // These are FALSE NEGATIVES, and pinning them is the honest thing to do.
    // Budesonide, Fluticasone and Mometasone are inhaled corticosteroids —
    // genuine asthma controllers — and none is linked, because their class
    // strings ("Corticosteroid (anti-inflammatory steroid)", "Steroid
    // (corticosteroid) — nasal, inhaled, or skin") also describe a nasal spray
    // and a skin cream, and a medicine record does not say which form the user
    // holds.
    //
    // The design refuses to guess, so it declines. That is a cost, not a win,
    // and it should not be discovered by a user wondering why their preventer
    // inhaler is missing from the asthma page.
    for (final g in ['Budesonide', 'Fluticasone', 'Mometasone']) {
      test('$g is an asthma controller this table knowingly misses', () {
        final m = monographs.firstWhere((x) => x['generic'] == g);
        final cls = m['class'] as String;
        expect((m['uses'] as String).toLowerCase(), contains('asthma'),
            reason: 'if the prose stops mentioning asthma this pin is stale');
        expect(ConditionTaxonomy.classMatches(cls, 'asthma'), isFalse,
            reason: 'if this starts passing, someone added a cue that reaches '
                'nasal and topical steroids too — check what else it caught');
      });
    }

    test('the combination inhaler IS linked, which is the distinction', () {
      // Budesonide/Formoterol's class says "asthma/COPD inhaler" outright. The
      // route is in the class, so the link is safe. Plain Budesonide's is not.
      final combo = monographs
          .firstWhere((x) => x['generic'] == 'Budesonide/Formoterol');
      expect(
          ConditionTaxonomy.classMatches(combo['class'] as String, 'asthma'),
          isTrue);
    });
  });

  test('the drugs where PROSE and CLASS disagree side with the class', () {
    // The general form of the anecdotes above, and the real argument for
    // reading `class` and never `uses`.
    //
    // An earlier version of this test was too strong: it assumed that if a
    // condition's name appears only in the prose, any link must have come from
    // the prose. Not so — Ipratropium is linked to asthma by the `bronchodilator`
    // cue, which is squarely in its class. So the claim is narrowed to what is
    // actually true: for the monographs whose CLASS names no relevant family at
    // all, and whose only connection to the condition is a sentence of prose,
    // the matcher must decline.
    //
    // Each pairing below was enumerated from the asset, not guessed.
    const proseOnly = <String, List<String>>{
      // class: "Beta-blocker (commonly glaucoma eye drops)" / "Water pill
      // (loop diuretic)"
      'hypertension': ['Timolol', 'Furosemide'],
      // class: "Fiber (bulk-forming) laxative"
      'high-cholesterol': ['Ispaghula (Psyllium husk)'],
      // Only the genuine false positive. The three inhaled corticosteroids that
      // a prose matcher would ALSO add are true positives this design knowingly
      // loses — they are pinned as costs above, not claimed as wins here.
      'asthma': ['Ketotifen'],
    };

    proseOnly.forEach((conditionId, generics) {
      for (final g in generics) {
        final m = monographs.firstWhere((x) => x['generic'] == g,
            orElse: () => throw StateError('$g is not in the asset'));
        final cls = m['class'] as String;
        final uses = (m['uses'] as String).toLowerCase();

        // The premise: the prose really does mention it.
        final word = switch (conditionId) {
          'hypertension' => 'blood pressure',
          'high-cholesterol' => 'cholesterol',
          _ => 'asthma',
        };
        expect(uses, contains(word),
            reason: '$g no longer mentions $word in its prose, so this pairing '
                'proves nothing — re-derive the list');

        // The conclusion: the matcher declines anyway.
        expect(ConditionTaxonomy.classMatches(cls, conditionId), isFalse,
            reason: '$g was linked to $conditionId on the strength of prose. '
                'class="$cls"');
      }
    });
  });

  // ----------------------------------------------------------- consistency

  group('the table and the library agree', () {
    test('every curated condition has an entry, and vice versa', () {
      final libraryIds = conditionLibrary.map((c) => c.id).toSet();
      expect(ConditionTaxonomy.conditionIds.toSet(), libraryIds,
          reason: 'a condition with no entry silently links to nothing, which '
              'is indistinguishable from a deliberate refusal');
    });

    test('conditionsForClass is the inverse of classMatches', () {
      // The service inverts one pass over the medicines rather than scanning
      // per condition; if the two disagree the inversion is lying.
      for (final m in monographs) {
        final cls = m['class'] as String;
        final forward = {
          for (final id in ConditionTaxonomy.conditionIds)
            if (ConditionTaxonomy.classMatches(cls, id)) id,
        };
        expect(ConditionTaxonomy.conditionsForClass(cls), forward,
            reason: 'disagreed on "$cls"');
      }
    });

    test('no monograph lands on more than three conditions', () {
      // A drug matching many pages means a cue has gone generic. The real
      // maximum today is two (bronchodilators on asthma+copd, SSRIs on
      // anxiety+depression); three is headroom, not a target.
      for (final m in monographs) {
        final n =
            ConditionTaxonomy.conditionsForClass(m['class'] as String).length;
        expect(n, lessThanOrEqualTo(3),
            reason: '${m['generic']} matched $n conditions — "${m['class']}"');
      }
    });
  });

  // --------------------------------------------------------- the why-chip

  group('familyPhrase', () {
    test('pulls the family out of the class string', () {
      expect(
          ConditionTaxonomy.familyPhrase(
              'Blood-pressure medicine (calcium channel blocker)'),
          'calcium channel blocker');
    });

    test('drops a trailing acronym that adds nothing', () {
      expect(
          ConditionTaxonomy.familyPhrase(
              'Acid-reducer (proton pump inhibitor, PPI)'),
          'proton pump inhibitor');
    });

    test('null when there is no parenthesised family', () {
      // So the caller falls back to the whole class rather than rendering
      // "This medicine's drug family () is commonly used…".
      expect(ConditionTaxonomy.familyPhrase('Thyroid hormone replacement'),
          isNull);
    });

    test('every linked monograph yields a usable phrase or a clean null', () {
      for (final m in monographs) {
        final cls = m['class'] as String;
        if (ConditionTaxonomy.conditionsForClass(cls).isEmpty) continue;
        final phrase = ConditionTaxonomy.familyPhrase(cls);
        if (phrase != null) {
          expect(phrase.trim(), isNotEmpty);
          expect(phrase, isNot(contains('(')));
        }
      }
    });
  });
}
