import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/med_safety_checker.dart';

void main() {
  group('checkAllergies', () {
    test('flags a direct allergy match', () {
      final w = MedSafetyChecker.checkAllergies(
        name: 'Aspirin 75mg',
        allergies: ['aspirin', 'peanuts'],
      );
      expect(w, hasLength(1));
      expect(w.first.kind, 'allergy');
      expect(w.first.severity, 'high');
      expect(w.first.message.toLowerCase(), contains('aspirin'));
    });

    test('matches via the generic name and substring (sulfa)', () {
      final w = MedSafetyChecker.checkAllergies(
        name: 'Bactrim',
        genericName: 'Sulfamethoxazole/Trimethoprim',
        allergies: ['sulfa drugs'],
      );
      expect(w, isNotEmpty);
    });

    test('does NOT false-alarm on unrelated meds', () {
      final w = MedSafetyChecker.checkAllergies(
        name: 'Metformin',
        allergies: ['penicillin', 'latex'],
      );
      expect(w, isEmpty);
    });

    test('ignores too-short allergy fragments', () {
      final w = MedSafetyChecker.checkAllergies(
        name: 'Ibuprofen',
        allergies: ['pen'], // 3 chars → skipped
      );
      expect(w, isEmpty);
    });
  });

  group('checkDuplicates', () {
    test('flags two meds sharing a generic ingredient', () {
      final w = MedSafetyChecker.checkDuplicates(const [
        MedRef(id: '1', name: 'Tylenol', genericName: 'Acetaminophen'),
        MedRef(id: '2', name: 'Panadol', genericName: 'acetaminophen'),
        MedRef(id: '3', name: 'Metformin', genericName: 'Metformin'),
      ]);
      expect(w, hasLength(1));
      expect(w.first.kind, 'duplicate');
      expect(w.first.message, contains('Tylenol'));
      expect(w.first.message, contains('Panadol'));
    });

    test('does not flag a single medicine', () {
      final w = MedSafetyChecker.checkDuplicates(const [
        MedRef(id: '1', name: 'Aspirin', genericName: 'Aspirin'),
      ]);
      expect(w, isEmpty);
    });

    test('same id twice is not a duplicate', () {
      final w = MedSafetyChecker.checkDuplicates(const [
        MedRef(id: '1', name: 'Aspirin', genericName: 'Aspirin'),
        MedRef(id: '1', name: 'Aspirin', genericName: 'Aspirin'),
      ]);
      expect(w, isEmpty);
    });

    test('falls back to display name when generic is absent', () {
      final w = MedSafetyChecker.checkDuplicates(const [
        MedRef(id: '1', name: 'Vitamin D'),
        MedRef(id: '2', name: 'vitamin d'),
      ]);
      expect(w, hasLength(1));
    });
  });

  group('duplicateOf (a medicine about to be saved)', () {
    test('names the candidate and what it shares an ingredient with', () {
      final w = MedSafetyChecker.duplicateOf(
        const MedRef(id: 'new', name: 'Panadol', genericName: 'Acetaminophen'),
        const [
          MedRef(id: '1', name: 'Tylenol', genericName: 'acetaminophen'),
          MedRef(id: '2', name: 'Metformin', genericName: 'Metformin'),
        ],
      );
      expect(w, isNotNull);
      expect(w!.kind, 'duplicate');
      expect(w.message, contains('Panadol'));
      expect(w.message, contains('Tylenol'));
      expect(w.message, isNot(contains('Metformin')));
      expect(w.message, contains('check with your pharmacist'));
    });

    test('nothing when it shares nothing', () {
      expect(
          MedSafetyChecker.duplicateOf(
            const MedRef(id: 'new', name: 'Aspirin', genericName: 'Aspirin'),
            const [MedRef(id: '2', name: 'Metformin', genericName: 'Metformin')],
          ),
          isNull);
      expect(MedSafetyChecker.duplicateOf(const MedRef(id: 'n', name: 'Aspirin'), const []),
          isNull);
    });

    test('itself, among the others, is not a duplicate of itself', () {
      expect(
          MedSafetyChecker.duplicateOf(
            const MedRef(id: '1', name: 'Aspirin', genericName: 'Aspirin'),
            const [MedRef(id: '1', name: 'Aspirin', genericName: 'Aspirin')],
          ),
          isNull);
    });

    test('with no generic on either side, by name', () {
      final w = MedSafetyChecker.duplicateOf(
        const MedRef(id: 'new', name: 'Vitamin D'),
        const [MedRef(id: '1', name: 'vitamin d')],
      );
      expect(w, isNotNull);
    });

    test('a generic outranks a name: two brands of one ingredient', () {
      final w = MedSafetyChecker.duplicateOf(
        const MedRef(id: 'new', name: 'Crocin', genericName: 'Paracetamol'),
        const [MedRef(id: '1', name: 'Calpol', genericName: 'paracetamol')],
      );
      expect(w, isNotNull);
    });

    test('a brand that happens to read like another is not a match when the generics differ',
        () {
      final w = MedSafetyChecker.duplicateOf(
        const MedRef(id: 'new', name: 'Brand', genericName: 'Ibuprofen'),
        const [MedRef(id: '1', name: 'Brand', genericName: 'Paracetamol')],
      );
      expect(w, isNull);
    });

    test('several matches are all named, each once', () {
      final w = MedSafetyChecker.duplicateOf(
        const MedRef(id: 'new', name: 'Panadol', genericName: 'Paracetamol'),
        const [
          MedRef(id: '1', name: 'Calpol', genericName: 'paracetamol'),
          MedRef(id: '2', name: 'Calpol', genericName: 'Paracetamol'),
          MedRef(id: '3', name: 'Crocin', genericName: 'PARACETAMOL'),
        ],
      );
      expect(w!.message, contains('share its active ingredient with Calpol and Crocin.'),
          reason: 'each name once');
    });

    test('a blank medicine matches nothing', () {
      expect(
          MedSafetyChecker.duplicateOf(
              const MedRef(id: 'n', name: ' '), const [MedRef(id: '1', name: ' ')]),
          isNull);
    });
  });
}
