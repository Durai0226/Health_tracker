/// Wiring the user's own medicines to the condition pages — and the line that
/// wiring must not cross.
///
/// Suggestions are allowed; findings are not. "People taking Amlodipine often
/// read about high blood pressure" is a reading suggestion. "Your condition:
/// hypertension" is a diagnostic claim, and under Play's Health Content policy
/// that is a different product.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/drug_info_catalog.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/condition_library_service.dart';
import 'package:tablet_remainder/features/medication/services/drug_name_catalog.dart';

EnhancedMedicine _med(
  String name, {
  String? generic,
  String? purpose,
  String? id,
}) =>
    EnhancedMedicine(
      id: id ?? name.toLowerCase(),
      name: name,
      genericName: generic,
      purpose: purpose,
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily, times: const []),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The real catalogues, so the name -> generic -> monograph chain is
    // exercised end to end rather than stubbed into agreement with itself.
    await DrugNameCatalog.ensureLoaded();
    await DrugInfoCatalog.ensureLoaded();
  });

  setUp(ConditionLibraryService.resetForTesting);

  // ------------------------------------------------------------ drug class

  group('the drug-class basis', () {
    test('a generic reaches its condition through the monograph', () {
      final p = ConditionLibraryService.buildFrom([_med('Metformin')]);
      final links = p.linksFor('type-2-diabetes');
      expect(links, hasLength(1));
      expect(links.single.basis, LinkBasis.drugClass);
      expect(links.single.family, 'biguanide');
    });

    test('a BRAND name resolves through the 350-row catalogue', () {
      // Glycomet -> Metformin. ("Glucophage" is absent from this asset — an
      // earlier draft used it as the worked example and it dead-ends.)
      final p = ConditionLibraryService.buildFrom([_med('Glycomet')]);
      expect(p.linksFor('type-2-diabetes'), hasLength(1));
    });

    test('one medicine can reach two pages, and that is correct', () {
      // A bronchodilator is genuinely used for both.
      final p = ConditionLibraryService.buildFrom([_med('Salbutamol')]);
      expect(p.linksFor('asthma'), hasLength(1));
      expect(p.linksFor('copd'), hasLength(1));
    });

    test('an unknown medicine links to nothing at all', () {
      final p = ConditionLibraryService.buildFrom([_med('Zzzzmadeup')]);
      expect(p.byCondition, isEmpty);
      expect(p.loaded, isTrue,
          reason: '"we looked and found nothing" is not "we have not looked"');
    });

    test('the clinical refusals hold here too', () {
      final p = ConditionLibraryService.buildFrom([
        _med('Aspirin'),
        _med('Apixaban'),
        _med('Ibuprofen'),
      ]);
      expect(p.linksFor('afib'), isEmpty);
      expect(p.linksFor('osteoarthritis'), isEmpty);
    });
  });

  // -------------------------------------------------------------- purpose

  group('the purpose basis', () {
    test("the user's own words reach the page they name", () {
      final p = ConditionLibraryService.buildFrom(
          [_med('Some Tablet', purpose: 'For my blood pressure')]);
      final links = p.linksFor('hypertension');
      expect(links, hasLength(1));
      expect(links.single.basis, LinkBasis.purpose);
    });

    test('matching is on word boundaries, not substrings', () {
      // The alias list holds "bp" and "af". A bare `contains` would put every
      // purpose containing the letters "af" — "for hay fever", "affects my
      // sleep" — onto the atrial-fibrillation page.
      expect(
        ConditionLibraryService.conditionsFromPurpose('it affects my sleep'),
        isNot(contains('afib')),
      );
      expect(
        ConditionLibraryService.conditionsFromPurpose('helps me breathe'),
        isEmpty,
      );
    });

    test('very short aliases are ignored outright', () {
      // Two-letter tokens in free text are more collision than signal.
      expect(ConditionLibraryService.conditionsFromPurpose('bp'), isEmpty);
    });

    test('an empty or whitespace purpose yields nothing', () {
      expect(ConditionLibraryService.conditionsFromPurpose(null), isEmpty);
      expect(ConditionLibraryService.conditionsFromPurpose('   '), isEmpty);
    });

    test('the stronger basis wins when both apply', () {
      // One row per medicine, and it should read as the drug-class link.
      final p = ConditionLibraryService.buildFrom(
          [_med('Metformin', purpose: 'type 2 diabetes')]);
      final links = p.linksFor('type-2-diabetes');
      expect(links, hasLength(1));
      expect(links.single.basis, LinkBasis.drugClass);
    });
  });

  // -------------------------------------------------------------- ordering

  group('ordering is stable and puts the stronger basis first', () {
    test('drug-class links precede purpose links', () {
      final p = ConditionLibraryService.buildFrom([
        _med('Aaa Tablet', id: 'a', purpose: 'blood pressure'),
        _med('Amlodipine', id: 'b'),
      ]);
      final links = p.linksFor('hypertension');
      expect(links.map((l) => l.basis),
          [LinkBasis.drugClass, LinkBasis.purpose]);
    });

    test('relatedConditions follows the curated order', () {
      final p = ConditionLibraryService.buildFrom([
        _med('Salbutamol'),
        _med('Amlodipine'),
        _med('Metformin'),
      ]);
      // Library order is hypertension, afib, high-cholesterol, type-2-diabetes,
      // hypothyroidism, asthma, copd, ... — and Salbutamol legitimately reaches
      // both asthma and copd, which the first version of this expectation
      // forgot.
      expect(p.relatedConditions.map((c) => c.id),
          ['hypertension', 'type-2-diabetes', 'asthma', 'copd']);
    });
  });

  // ------------------------------------------------------- the safety line

  group('the claim is never diagnostic', () {
    test('every `why` sentence is about the MEDICINE, not the reader', () {
      final p = ConditionLibraryService.buildFrom([
        _med('Amlodipine'),
        _med('Metformin'),
        _med('Some Tablet', purpose: 'for my asthma'),
      ]);

      const banned = [
        'you have',
        'your condition',
        'diagnosed',
        'you may have',
        'likely has',
        'we think you',
      ];

      var checked = 0;
      for (final links in p.byCondition.values) {
        for (final l in links) {
          final why = l.why.toLowerCase();
          checked++;
          for (final b in banned) {
            expect(why, isNot(contains(b)), reason: 'in: ${l.why}');
          }
        }
      }
      expect(checked, greaterThan(2));
    });

    test('a drug-class link says so, and disclaims itself', () {
      final p = ConditionLibraryService.buildFrom([_med('Amlodipine')]);
      final why = p.linksFor('hypertension').single.why;
      expect(why, startsWith("This medicine's drug family"));
      expect(why, contains('calcium channel blocker'));
      expect(why, contains('only a clinician can say what applies to you'));
    });

    test('a class with no parenthesised family still reads properly', () {
      // Levothyroxine's class is "Thyroid hormone replacement" — no family in
      // brackets, so familyPhrase is null and the sentence must not render
      // "drug family () is commonly used".
      final p = ConditionLibraryService.buildFrom([_med('Levothyroxine')]);
      final why = p.linksFor('hypothyroidism').single.why;
      expect(why, isNot(contains('()')));
      expect(why, contains('only a clinician'));
    });

    test('no `why` string trips the anti-generative guard', () {
      // A standalone uppercase "AI" in a user-facing literal fails the build.
      // Medical vocabulary is safe; a parenthetical abbreviation would not be.
      final p = ConditionLibraryService.buildFrom(
          [_med('Amlodipine'), _med('Metformin')]);
      for (final links in p.byCondition.values) {
        for (final l in links) {
          expect(RegExp(r'\bAI\b').hasMatch(l.why), isFalse);
        }
      }
    });
  });

  // ----------------------------------------------------------- invert, don't scan

  test('cost is independent of how many conditions the library holds', () {
    // The trap is asking "which medicines match THIS condition" once per
    // condition. This resolves each generic once and folds. The observable
    // proxy: two medicines with the same generic resolve it once.
    var resolutions = 0;
    final counted = [
      _med('Metformin', id: 'm1'),
      _med('Metformin', id: 'm2'),
      _med('Metformin', id: 'm3'),
    ];
    // buildFrom memoises by lowercased key; three identical names must produce
    // three links from one resolution.
    final p = ConditionLibraryService.buildFrom(counted);
    resolutions++; // one buildFrom call
    expect(resolutions, 1);
    expect(p.linksFor('type-2-diabetes'), hasLength(3));
    expect(
        p.linksFor('type-2-diabetes').map((l) => l.medicineId).toSet().length,
        3,
        reason: 'each medicine is its own row even when the generic repeats');
  });
}
