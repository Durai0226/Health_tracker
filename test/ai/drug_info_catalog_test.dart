import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/drug_info_catalog.dart';

/// QA — offline drug-info KB (Feature C). Asset-backed, headless: loads
/// assets/ai/drug_info.json via rootBundle. Covers the positive question-type
/// routing and the negative/deferral cases that make the caller fall back to
/// the general rule answer instead of a wrong one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await DrugInfoCatalog.ensureLoaded();
  });

  group('DrugInfoCatalog.answer — positive', () {
    test('a "what is it for" question returns the drug purpose', () {
      final a =
          DrugInfoCatalog.answer(question: 'what is it for?', generic: 'Paracetamol');
      expect(a, isNotNull);
      expect(a!.toLowerCase(), contains('pain'));
    });

    test('a side-effect question returns the side-effects section', () {
      final a = DrugInfoCatalog.answer(
          question: 'does it have side effects?', generic: 'Paracetamol');
      expect(a, isNotNull);
      expect(a!.toLowerCase(), contains('common side effects'));
    });

    test('a food question returns with-food guidance', () {
      final a = DrugInfoCatalog.answer(
          question: 'should I take it with food?', generic: 'Amlodipine');
      expect(a, isNotNull);
      expect(a!.toLowerCase(), contains('food'));
    });

    test('a safety/precaution question returns the good-to-know section', () {
      final a = DrugInfoCatalog.answer(
          question: 'is it safe with alcohol?', generic: 'Metformin');
      expect(a, isNotNull);
      expect(a!.toLowerCase(), contains('good to know'));
    });

    test('a general question returns a compact monograph', () {
      final a =
          DrugInfoCatalog.answer(question: 'tell me about this', generic: 'Metformin');
      expect(a, isNotNull);
      expect(a!.toLowerCase(), contains('good to know'));
    });

    test('brand displayName resolves via the generic and shows the brand', () {
      final a = DrugInfoCatalog.answer(
          question: 'what is it for?',
          generic: 'Paracetamol',
          displayName: 'Dolo 650');
      expect(a, isNotNull);
      expect(a, contains('Dolo 650'));
    });

    test('generic is matched case-insensitively', () {
      final a =
          DrugInfoCatalog.answer(question: 'what is it for', generic: 'paracetamol');
      expect(a, isNotNull);
    });
  });

  group('DrugInfoCatalog.answer — negative / deferral', () {
    test('an unknown drug returns null so the caller can fall back', () {
      final a =
          DrugInfoCatalog.answer(question: 'what is it for?', generic: 'Foobarol');
      expect(a, isNull);
    });

    test('a brand with no generic (not a KB key) returns null', () {
      final a =
          DrugInfoCatalog.answer(question: 'what for', displayName: 'Dolo 650');
      expect(a, isNull);
    });

    test('a missed-dose question defers to general advice (null)', () {
      final a = DrugInfoCatalog.answer(
          question: 'what if I miss a dose?', generic: 'Paracetamol');
      expect(a, isNull);
    });

    test('no generic and no displayName returns null', () {
      final a = DrugInfoCatalog.answer(question: 'what for');
      expect(a, isNull);
    });
  });
}
