import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/med_safety_checker.dart';

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
}
