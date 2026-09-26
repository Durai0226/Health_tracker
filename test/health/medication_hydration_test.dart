import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/medication_hydration.dart';

/// The one thing a pure hydration app structurally cannot build: fluid guidance
/// that depends on what the user takes. The "medicine + water reminder" apps on
/// the stores are two independent reminder types in one binary with no clinical
/// linkage at all.
///
/// The dangerous direction here is over-reach, so most of these tests are about
/// what the engine must REFUSE to do.
void main() {
  group('individual rules', () {
    test('lithium asks for a real floor and flags heat', () {
      final r = hydrationRuleForGeneric('Lithium')!;
      expect(r.direction, HydrationAdviceDirection.increase);
      expect(r.floorMl, 2500);
      expect(r.heatSensitive, isTrue,
          reason: 'dehydration concentrates lithium — heat is the risk');
    });

    test('topiramate flags heat too, for a different reason', () {
      // Oligohidrosis: it reduces sweating, so the user overheats rather than
      // simply losing fluid.
      expect(hydrationRuleForGeneric('topiramate')!.heatSensitive, isTrue);
    });

    test('matching is case- and whitespace-insensitive', () {
      expect(hydrationRuleForGeneric('  LITHIUM '), isNotNull);
    });

    test('an unknown or null drug has nothing to say', () {
      expect(hydrationRuleForGeneric('paracetamol'), isNull);
      expect(hydrationRuleForGeneric(null), isNull);
    });

    test('every rule carries a source and advice', () {
      for (final r in medicationHydrationRules) {
        expect(r.source, isNotEmpty, reason: r.generic);
        expect(r.advice, isNotEmpty, reason: r.generic);
        expect(r.generic, r.generic.toLowerCase(),
            reason: 'keys must be lower-case for lookup to work');
      }
    });
  });

  group('combining', () {
    test('the highest floor wins', () {
      final a = hydrationAdviceFor(['lithium', 'ciprofloxacin']);
      expect(a.floorMl, 2500);
      expect(a.increases.length, 2);
    });

    test('the same ingredient under two brands is reported once', () {
      final a = hydrationAdviceFor(['Lithium', 'lithium', 'LITHIUM']);
      expect(a.increases.length, 1);
    });

    test('nothing relevant means nothing shown', () {
      final a = hydrationAdviceFor(['paracetamol', 'atorvastatin', null]);
      expect(a.isEmpty, isTrue);
      expect(a.floorMl, 0);
    });
  });

  group('the refusals — where over-reach would be harmful', () {
    test('a diuretic cancels any "drink more" floor', () {
      // Furosemide is very often prescribed for heart failure, where the same
      // patient may be on a fluid restriction. Telling them to drink 2.5 L
      // because they also have a UTI would be directly against their treatment.
      final a = hydrationAdviceFor(['co-trimoxazole', 'furosemide']);
      expect(a.floorMl, 0,
          reason: 'the diuretic must veto the floor');
      expect(a.increases, isNotEmpty,
          reason: 'the infection advice still shows — as advice, not a number');
      expect(a.cautions, isNotEmpty);
    });

    test('diuretics never carry a floor of their own', () {
      for (final name in ['furosemide', 'hydrochlorothiazide', 'spironolactone']) {
        final r = hydrationRuleForGeneric(name)!;
        expect(r.direction, HydrationAdviceDirection.caution, reason: name);
        expect(r.floorMl, 0, reason: '$name must not raise a target');
      }
    });

    test('a diuretic alone gives information, not a target change', () {
      final a = hydrationAdviceFor(['furosemide']);
      expect(a.floorMl, 0);
      expect(a.increases, isEmpty);
      expect(a.cautions.single.generic, 'furosemide');
    });

    test('the lithium + thiazide interaction is surfaced', () {
      // 2023 Beers Criteria: thiazides raise lithium levels. Both rules should
      // be visible, and the thiazide's presence must not silently remove the
      // lithium advice text.
      final a = hydrationAdviceFor(['lithium', 'hydrochlorothiazide']);
      expect(a.increases.map((r) => r.generic), contains('lithium'));
      expect(a.cautions.map((r) => r.generic), contains('hydrochlorothiazide'));
      expect(a.floorMl, 0, reason: 'the diuretic still vetoes the number');
      expect(a.heatSensitive, isTrue,
          reason: 'lithium heat sensitivity must survive the veto');
    });
  });
}
