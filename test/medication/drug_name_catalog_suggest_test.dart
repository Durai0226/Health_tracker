import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/services/drug_name_catalog.dart';

/// QA — medicine name auto-suggestion + form (Feature 2). Asset-backed,
/// headless: loads assets/data/drug_names.json (330 entries, each carrying a
/// dosage form). Covers prefix/contains matching, the form that powers the
/// auto-fill, and the negative guards (too-short / unknown queries).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await DrugNameCatalog.ensureLoaded();
  });

  DrugNameEntry? findSuggestion(String query, String name) {
    for (final e in DrugNameCatalog.suggest(query, limit: 25)) {
      if (e.name.toLowerCase() == name.toLowerCase()) return e;
    }
    return null;
  }

  group('suggest — positive + form auto-fill', () {
    test('a prefix query returns suggestions that carry a form', () {
      final r = DrugNameCatalog.suggest('paraceta');
      expect(r, isNotEmpty);
      expect(r.every((e) => e.form != null), isTrue,
          reason: 'every entry in the expanded dataset has a form');
    });

    test('Paracetamol suggests as a tablet', () {
      final e = findSuggestion('paraceta', 'Paracetamol');
      expect(e, isNotNull);
      expect(e!.form, DosageForm.tablet);
      expect(e.generic, 'Paracetamol');
    });

    test('an eye-drop brand carries the drops form', () {
      final e = findSuggestion('ciplox', 'Ciplox Eye Drops');
      expect(e, isNotNull);
      expect(e!.form, DosageForm.drops);
    });

    test('an inhaler brand carries the inhaler form (outside the common 8)', () {
      final e = findSuggestion('asthalin', 'Asthalin Inhaler');
      expect(e, isNotNull);
      expect(e!.form, DosageForm.inhaler);
    });

    test('a topical brand carries the cream form', () {
      final e = findSuggestion('betnovate', 'Betnovate Cream');
      expect(e, isNotNull);
      expect(e!.form, DosageForm.cream);
    });

    test('matching against the generic surfaces brands', () {
      final r = DrugNameCatalog.suggest('salbutamol', limit: 25);
      expect(r.any((e) => e.generic.toLowerCase() == 'salbutamol'), isTrue);
    });

    test('genericFor resolves a brand to its active ingredient', () {
      expect(DrugNameCatalog.genericFor('Dolo 650'), 'Paracetamol');
    });
  });

  group('suggest — negative guards', () {
    test('a single-character query returns nothing', () {
      expect(DrugNameCatalog.suggest('c'), isEmpty);
    });

    test('an empty query returns nothing', () {
      expect(DrugNameCatalog.suggest(''), isEmpty);
    });

    test('an unknown query returns nothing', () {
      expect(DrugNameCatalog.suggest('zzzzzq'), isEmpty);
    });

    test('genericFor returns null for an unknown name', () {
      expect(DrugNameCatalog.genericFor('NotARealMedicine'), isNull);
    });
  });
}
