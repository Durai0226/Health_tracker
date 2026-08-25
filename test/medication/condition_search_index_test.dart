/// Search that finds a condition by the words a person would actually type.
///
/// The three queries pinned first are the ones the shipping predicate cannot
/// serve. `ConditionInfo.matches` tests `name` and `aliases` only, and against
/// all 14 names and 34 aliases, **"chest pain", "swelling" and "statin" each
/// return the empty state** — even though "chest pain" and "swelling" are in
/// `commonSymptoms` and "statin" is in a self-care tip.
///
/// Someone searching a symptom is the most likely visitor this screen has.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/data/condition_library_data.dart';
import 'package:tablet_remainder/features/medication/services/condition_search_index.dart';

void main() {
  late List<({String generic, String klass})> monographs;

  setUpAll(() {
    final raw = File('assets/health/drug_info.json').readAsStringSync();
    monographs = [
      for (final m in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
        (generic: m['generic'] as String, klass: m['class'] as String),
    ];
  });

  setUp(() {
    ConditionSearchIndex.resetForTesting();
    ConditionSearchIndex.build(
      genericsForCondition: () =>
          ConditionSearchIndex.drugTermsFrom(monographs),
    );
  });

  List<String> ids(String q) =>
      ConditionSearchIndex.search(q).map((h) => h.condition.id).toList();

  // ------------------------------------------------- the queries that failed

  group('the three queries the old predicate could not serve', () {
    test('"chest pain" finds something', () {
      // Present in commonSymptoms / whenToSeekHelp on several entries, and in
      // no name or alias anywhere.
      final r = ids('chest pain');
      expect(r, isNotEmpty);
      for (final c in conditionLibrary) {
        expect(c.matches('chest pain'), isFalse,
            reason: 'if the old predicate starts matching this, the premise of '
                'the whole index has changed');
      }
    });

    test('"swelling" finds something', () {
      expect(ids('swelling'), isNotEmpty);
    });

    test('"statin" finds the cholesterol page', () {
      final r = ids('statin');
      expect(r, contains('high-cholesterol'));
      expect(r.first, 'high-cholesterol',
          reason: 'a drug-family hit should rank the page it treats first');
    });
  });

  // ------------------------------------------------------- the drug-name hop

  group('the drug-name hop', () {
    test('a generic finds the page its class links to', () {
      expect(ids('metformin'), contains('type-2-diabetes'));
      expect(ids('amlodipine'), contains('hypertension'));
      expect(ids('salbutamol'), contains('asthma'));
    });

    test('a family phrase works too', () {
      expect(ids('calcium channel blocker'), contains('hypertension'));
      expect(ids('proton pump inhibitor'), contains('gerd'));
    });

    test('the hop respects the taxonomy — no anticoagulant finds the AF page',
        () {
      // The clinical refusal has to hold in SEARCH as well, or the feature
      // leaks the association it declined to make on the page.
      for (final q in ['apixaban', 'warfarin', 'heparin', 'anticoagulant']) {
        expect(ids(q), isNot(contains('afib')), reason: 'query: $q');
      }
    });

    test('a glaucoma beta-blocker does not find hypertension', () {
      expect(ids('timolol'), isNot(contains('hypertension')));
    });
  });

  // ----------------------------------------------------------- the ranking

  group('ranking', () {
    test('a name hit outranks a body hit', () {
      // "asthma" is a name, and also appears in other entries' prose.
      final r = ids('asthma');
      expect(r.first, 'asthma');
    });

    test('an alias hit outranks a symptom hit', () {
      // 'bp' is an alias of hypertension.
      final r = ConditionSearchIndex.search('bp');
      expect(r.first.condition.id, 'hypertension');
      expect(r.first.matchedIn, 'alias');
    });

    test('matchedIn explains a result whose word is not on the card', () {
      final hit = ConditionSearchIndex.search('statin')
          .firstWhere((h) => h.condition.id == 'high-cholesterol');
      expect(hit.matchedIn, isNot('name'),
          reason: 'the user needs to know WHY an entry came back when the word '
              'they typed appears nowhere on it');
    });

    test('ties break on the curated order, not on hash order', () {
      // Two runs of the same query must return the same sequence.
      expect(ids('pain'), ids('pain'));
      expect(ids(''), [for (final c in conditionLibrary) c.id]);
    });
  });

  // -------------------------------------------------------- the old cases

  group('every case the old predicate handled still works', () {
    // From test/medication/condition_library_test.dart, which pins these four.
    test('name, alias, case-insensitivity and non-matches', () {
      final hypertension =
          conditionLibrary.firstWhere((c) => c.id == 'hypertension');
      expect(ids('blood pressure'), contains(hypertension.id));
      expect(ids('BLOOD PRESSURE'), contains(hypertension.id));
      expect(ids('hypertension'), contains(hypertension.id));
      expect(ids('zzzznotacondition'), isEmpty);
    });
  });

  // ------------------------------------------------------------- degradation

  test('an unbuilt index falls back rather than returning nothing', () {
    ConditionSearchIndex.resetForTesting();
    // A mis-ordered init must degrade to the old behaviour, not an empty
    // screen. The widened queries stop working; the basic ones do not.
    expect(ConditionSearchIndex.isBuilt, isFalse);
    expect(
        ConditionSearchIndex.search('hypertension')
            .map((h) => h.condition.id),
        contains('hypertension'));
  });

  // -------------------------------------------------------------- no leakage

  test('the four unlinked conditions gain no drug terms', () {
    final terms = ConditionSearchIndex.drugTermsFrom(monographs);
    for (final id in ['afib', 'osteoarthritis', 'migraine', 'ckd']) {
      expect(terms[id] ?? const <String>[], isEmpty,
          reason: '$id refuses to link medicines, and search must refuse too');
    }
  });
}
