import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/services/drug_interaction_service.dart';

/// QA — drug interaction checker (F2). Pure in-memory database, no I/O.
void main() {
  final svc = DrugInteractionService();

  group('checkInteraction — positive', () {
    test('a known interacting pair is flagged (Warfarin + Aspirin)', () {
      final hits = svc.checkInteraction('Warfarin', 'Aspirin');
      expect(hits, isNotEmpty);
    });

    test('order does not matter (Aspirin + Warfarin also flagged)', () {
      expect(svc.checkInteraction('Aspirin', 'Warfarin'), isNotEmpty);
    });

    test('matching is case-insensitive', () {
      expect(svc.checkInteraction('warfarin', 'aspirin'), isNotEmpty);
    });
  });

  group('checkInteraction — negative', () {
    test('two unrelated / unknown drugs return no interaction', () {
      expect(svc.checkInteraction('Foobarium', 'Bazquxil'), isEmpty);
    });

    test('a drug against itself is not a false interaction', () {
      expect(svc.checkInteraction('Aspirin', 'Aspirin'), isEmpty);
    });

    // Regression: _namesMatch's shared-token check used to match on generic
    // pharmacy filler words (dosage forms, common complaint words), so any
    // product literally named "Blood Pressure Tablet" falsely matched the
    // curated interaction table's "Blood Thinners" row via the shared token
    // "blood" -- a false-positive bleeding-risk warning between two
    // completely unrelated drugs.
    test('shared generic filler words (blood, tablet, pressure) do not falsely match', () {
      expect(svc.checkInteraction('Blood Pressure Tablet', 'Melatonin'), isEmpty);
    });
  });

  group('checkInteraction — class-placeholder rows now match real drug names', () {
    // Regression: several curated rows used to store a drug-CLASS name
    // ('SSRI', 'MAO Inhibitors', 'NSAIDs', 'Birth Control', 'Antacids')
    // instead of a real generic/brand name in one slot. Since matching is
    // literal (no class resolution), those rows could never fire against any
    // real medicine a user would actually type -- e.g. the clinically
    // significant Tramadol+Sertraline serotonin-syndrome interaction was
    // silently unreachable even though a near-identical row
    // (Fluoxetine+Tramadol) worked correctly.
    test('Tramadol + a real SSRI (Sertraline) is flagged', () {
      expect(svc.checkInteraction('Tramadol', 'Sertraline'), isNotEmpty);
    });

    test('Sertraline + a real MAOI (Phenelzine) is flagged', () {
      expect(svc.checkInteraction('Sertraline', 'Phenelzine'), isNotEmpty);
    });

    test('Prednisone + a real NSAID (Naproxen) is flagged', () {
      expect(svc.checkInteraction('Prednisone', 'Naproxen'), isNotEmpty);
    });

    test('Ciprofloxacin + a real antacid (Tums) is flagged', () {
      expect(svc.checkInteraction('Ciprofloxacin', 'Tums'), isNotEmpty);
    });

    test('St. John\'s Wort + a real contraceptive (Yasmin) is flagged', () {
      expect(svc.checkInteraction('St. John\'s Wort', 'Yasmin'), isNotEmpty);
    });

    test('Melatonin + a real blood thinner (Warfarin) is flagged', () {
      expect(svc.checkInteraction('Melatonin', 'Warfarin'), isNotEmpty);
    });
  });

  group('checkFoodInteractions', () {
    test('returns a list without throwing for a known drug', () {
      expect(svc.checkFoodInteractions('Warfarin'), isA<List<String>>());
    });

    test('an unknown drug has no food interactions', () {
      expect(svc.checkFoodInteractions('Foobarium'), isEmpty);
    });
  });
}
